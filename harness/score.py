#!/usr/bin/env python3
"""Scores transcription harness reports (harness/Core/ListenHarness.swift output).

Per fixture and per path (live finals, file pass over the recording, file pass over the source):
  - WER with substitutions, deletions, insertions;
  - the longest run of consecutive reference words missing from the transcript ("dropped chunk");
  - lag: time to first volatile and first final, final latency (arrival minus the wall time the
    end of its audio was pushed) median and p90, stop-to-done;
  - plumbing: buffers, converter drops, volatile results per second, file pass seconds per audio minute.

Usage:
  score.py REPORT.json [--label NAME] [--baseline METRICS.json] [--metrics-out OUT.json] [--markdown-out OUT.md]
Markdown goes to stdout unless --markdown-out is given.
"""
import argparse
import json
import re
import statistics
import sys

WORD = re.compile(r"[a-z0-9]+")


def normalize(text):
    text = text.lower().replace("’", "'").replace("'", "")
    text = re.sub(r"[-–—/]", " ", text)
    return WORD.findall(text)


def align(ref, hyp):
    """Levenshtein alignment. Returns ops over the reference: list of (op, ref_index or None)."""
    n, m = len(ref), len(hyp)
    d = [[0] * (m + 1) for _ in range(n + 1)]
    for i in range(n + 1):
        d[i][0] = i
    for j in range(m + 1):
        d[0][j] = j
    for i in range(1, n + 1):
        ri = ref[i - 1]
        row, prev = d[i], d[i - 1]
        for j in range(1, m + 1):
            cost = 0 if ri == hyp[j - 1] else 1
            row[j] = min(prev[j - 1] + cost, prev[j] + 1, row[j - 1] + 1)
    ops = []
    i, j = n, m
    while i > 0 or j > 0:
        if i > 0 and j > 0 and d[i][j] == d[i - 1][j - 1] + (0 if ref[i - 1] == hyp[j - 1] else 1):
            ops.append(("C" if ref[i - 1] == hyp[j - 1] else "S", i - 1))
            i, j = i - 1, j - 1
        elif i > 0 and d[i][j] == d[i - 1][j] + 1:
            ops.append(("D", i - 1))
            i -= 1
        else:
            ops.append(("I", None))
            j -= 1
    ops.reverse()
    return ops


def word_scores(reference, hypothesis):
    ref, hyp = normalize(reference), normalize(hypothesis)
    ops = align(ref, hyp)
    s = sum(1 for o, _ in ops if o == "S")
    dl = sum(1 for o, _ in ops if o == "D")
    ins = sum(1 for o, _ in ops if o == "I")
    longest, run, best_end = 0, 0, -1
    for o, idx in ops:
        if o == "D":
            run += 1
            if run > longest:
                longest, best_end = run, idx
        elif o in ("C", "S"):
            run = 0
        # insertions do not break a run of missing reference words
    missing = " ".join(ref[best_end - longest + 1:best_end + 1]) if longest else ""
    return {
        "refWords": len(ref),
        "sub": s,
        "del": dl,
        "ins": ins,
        "wer": (s + dl + ins) / len(ref) if ref else 0.0,
        "longestMissing": longest,
        "longestMissingText": missing,
    }


def ordered_text(segments):
    return " ".join(seg["text"] for seg in sorted(segments, key=lambda e: (e["start"], e["end"])))


def push_wall(pushes, audio_time):
    for audio, wall in pushes:
        if audio >= audio_time - 1e-6:
            return wall
    return pushes[-1][1] if pushes else 0.0


def pct(values, q):
    if not values:
        return None
    values = sorted(values)
    k = max(0, min(len(values) - 1, int(round(q * (len(values) - 1)))))
    return values[k]


def score_live(fixture):
    live = fixture.get("live")
    if not live or live.get("error"):
        return {"error": (live or {}).get("error", "no live run")}
    events = live["events"]
    finals = [e for e in events if e["kind"] == "final"]
    volatiles = [e for e in events if e["kind"] == "volatile"]
    pushes = live["pushes"]
    out = word_scores(fixture["reference"], ordered_text(finals))
    final_lat = [e["wall"] - push_wall(pushes, e["end"]) for e in finals if e["wall"] <= live["stopWall"]]
    vol_lat = [e["wall"] - push_wall(pushes, e["end"]) for e in volatiles]
    duration = fixture["duration"] or 1.0
    out.update({
        "path": live["path"],
        "completed": live["completed"],
        "writeError": live["writeError"],
        "buffers": live["buffers"],
        "convertDrops": live["convertDrops"],
        "finals": len(finals),
        "finalsAfterStop": sum(1 for e in finals if e["wall"] > live["stopWall"]),
        "volatiles": len(volatiles),
        "volatilesPerSec": len(volatiles) / duration,
        "firstVolatile": min((e["wall"] for e in volatiles), default=None),
        "firstFinal": min((e["wall"] for e in finals), default=None),
        "finalLatP50": statistics.median(final_lat) if final_lat else None,
        "finalLatP90": pct(final_lat, 0.9),
        "volatileLatP50": statistics.median(vol_lat) if vol_lat else None,
        "stopToDone": live["doneWall"] - live["stopWall"],
        "transcript": ordered_text(finals),
    })
    return out


def score_file(fixture, key):
    fp = fixture.get(key)
    if not fp or fp.get("error"):
        return {"error": (fp or {}).get("error", "no file pass")}
    out = word_scores(fixture["reference"], ordered_text(fp["segments"]))
    out["elapsed"] = fp["elapsed"]
    out["secPerAudioMin"] = fp["elapsed"] / (fixture["duration"] / 60.0) if fixture["duration"] else None
    out["transcript"] = ordered_text(fp["segments"])
    return out


def aggregate(rows, key):
    ok = [r[key] for r in rows if "error" not in r[key]]
    words = sum(r["refWords"] for r in ok)
    errs = sum(r["sub"] + r["del"] + r["ins"] for r in ok)
    agg = {
        "fixtures": len(ok),
        "refWords": words,
        "wer": errs / words if words else None,
        "deleted": sum(r["del"] for r in ok),
        "longestMissing": max((r["longestMissing"] for r in ok), default=None),
    }
    if key == "live":
        lat = [r["live"]["finalLatP50"] for r in rows if "error" not in r["live"] and r["live"]["finalLatP50"] is not None]
        p90 = [r["live"]["finalLatP90"] for r in rows if "error" not in r["live"] and r["live"]["finalLatP90"] is not None]
        first = [r["live"]["firstFinal"] for r in rows if "error" not in r["live"] and r["live"]["firstFinal"] is not None]
        agg.update({
            "finalLatP50": statistics.median(lat) if lat else None,
            "finalLatP90": max(p90) if p90 else None,
            "firstFinal": statistics.median(first) if first else None,
            "convertDrops": sum(r["live"]["convertDrops"] for r in rows if "error" not in r["live"]),
        })
    return agg


def score_fixtures(fixtures):
    rows = []
    for fx in fixtures:
        rows.append({
            "name": fx["name"],
            "duration": fx["duration"],
            "live": score_live(fx),
            "fileRec": score_file(fx, "fileFromRecording"),
            "fileSrc": score_file(fx, "fileFromSource"),
        })
    return {
        "fixtures": rows,
        "aggregate": {k: aggregate(rows, k) for k in ("live", "fileRec", "fileSrc")} if rows else {},
    }


def score_report(report):
    """v2 report: one entry per tuning in report["variants"]; the first is the baseline."""
    variants = []
    for v in report.get("variants", []):
        scored = score_fixtures(v.get("fixtures", []))
        scored["variant"] = v["tuning"]["name"]
        scored["tuning"] = v["tuning"]
        scored["probe"] = report.get("probe", {})
        variants.append(scored)
    return {
        "schema": report.get("schema"),
        "probe": report.get("probe", {}),
        "order": report.get("order", {}),
        "variants": variants,
        "engines": [score_engine(e) for e in report.get("engines", [])],
    }


def score_engine(run):
    """An extra file-only engine (Whisper): WER etc. per fixture over the source recording."""
    rows = []
    for fx in run.get("fixtures", []):
        fp = fx.get("filePass") or {}
        if fp.get("error"):
            rows.append({"name": fx["name"], "error": fp["error"]})
            continue
        r = word_scores(fx["reference"], ordered_text(fp.get("segments", [])))
        r.update({"name": fx["name"], "elapsed": fp.get("elapsed", 0.0),
                  "secPerAudioMin": fp.get("elapsed", 0.0) / (fx["duration"] / 60.0) if fx.get("duration") else None,
                  "peakExtraMB": fx.get("peakExtraMB", 0.0),
                  "transcript": ordered_text(fp.get("segments", []))})
        rows.append(r)
    ok = [r for r in rows if "error" not in r]
    words = sum(r["refWords"] for r in ok)
    spm = [r["secPerAudioMin"] for r in ok if r["secPerAudioMin"] is not None]
    return {
        "name": run["name"], "model": run.get("model"), "error": run.get("error"),
        "downloadSeconds": run.get("downloadSeconds"), "loadSeconds": run.get("loadSeconds"),
        "loadPeakExtraMB": run.get("loadPeakExtraMB"),
        "fixtures": rows,
        "aggregate": {
            "fixtures": len(ok),
            "wer": sum(r["sub"] + r["del"] + r["ins"] for r in ok) / words if words else None,
            "deleted": sum(r["del"] for r in ok),
            "longestMissing": max((r["longestMissing"] for r in ok), default=None),
            "secPerAudioMin": statistics.median(spm) if spm else None,
            "peakExtraMB": max((r["peakExtraMB"] for r in ok), default=None),
            "failed": len(rows) - len(ok),
        },
    }


def engines_markdown(report_metrics):
    """All engines on the same fixtures: Apple's file pass per tuning next to each extra engine."""
    engines = report_metrics.get("engines") or []
    if not engines:
        return ""
    lines = ["### Engines, file pass over the same recordings", "",
             "| engine | WER | words deleted | longest missing | s per audio min | peak extra MB | download / load (s) |",
             "|---|---|---|---|---|---|---|"]
    for v in report_metrics["variants"]:
        agg = (v.get("aggregate") or {}).get("fileSrc")
        if not agg:
            continue
        spm = [r["fileSrc"].get("secPerAudioMin") for r in v["fixtures"] if "error" not in r["fileSrc"]]
        spm = [x for x in spm if x is not None]
        mem = [r.get("peakExtraMB") for r in v["fixtures"] if r.get("peakExtraMB") is not None]
        lines.append(f"| Apple SpeechTranscriber ({v['variant']}) | {fmt(agg['wer'], 'pct')} | {fmt(agg['deleted'], 'int')} "
                     f"| {fmt(agg['longestMissing'], 'int')} | {fmt(statistics.median(spm) if spm else None)} "
                     f"| {fmt(max(mem) if mem else None)} (live + file) | – |")
    for e in engines:
        a = e["aggregate"]
        if e.get("error"):
            lines.append(f"| {e['name']} | error: {e['error'][:80]} | | | | {fmt(e.get('loadPeakExtraMB'))} | {fmt(e.get('downloadSeconds'))} / {fmt(e.get('loadSeconds'))} |")
            continue
        lines.append(f"| {e['name']} (`{e['model']}`) | {fmt(a['wer'], 'pct')} | {fmt(a['deleted'], 'int')} "
                     f"| {fmt(a['longestMissing'], 'int')} | {fmt(a['secPerAudioMin'])} "
                     f"| {fmt(max(a['peakExtraMB'] or 0, e.get('loadPeakExtraMB') or 0))} "
                     f"| {fmt(e.get('downloadSeconds'))} / {fmt(e.get('loadSeconds'))} |")
    lines += ["", "Whisper has no live path here: it is compared as the saved-audio pass only (live latency is Apple's).", ""]
    lines += ["<details><summary>Engine transcripts</summary>", ""]
    for e in engines:
        for r in e["fixtures"]:
            if "error" in r:
                lines.append(f"- **{r['name']} / {e['name']}**: error {r['error'][:120]}")
            else:
                lines.append(f"- **{r['name']} / {e['name']}**: missing \"{r['longestMissingText']}\"; heard: {r['transcript']}")
    lines += ["", "</details>", ""]
    return "\n".join(lines)


def fmt(v, kind="s"):
    if v is None:
        return "–"
    if kind == "pct":
        return f"{v * 100:.1f}%"
    if kind == "int":
        return str(int(v))
    return f"{v:.2f}"


def delta(now, base, kind):
    if now is None or base is None:
        return ""
    d = now - base
    if kind == "pct":
        return f" ({d * 100:+.1f})"
    if kind == "int":
        return f" ({int(d):+d})"
    return f" ({d:+.2f})"


def comparison(report_metrics):
    """One row per tuning: the numbers that decide the defaults."""
    lines = ["| tuning | settings | live WER | file pass WER | live longest missing | file longest missing | first final (s) | final lag p50 / worst p90 (s) |",
             "|---|---|---|---|---|---|---|---|"]
    for v in report_metrics["variants"]:
        agg = v.get("aggregate") or {}
        if not agg:
            continue
        t = v["tuning"]
        on = [k for k in ("fastResults", "prepareModel", "flushConverter", "useContext") if t.get(k)]
        lv, fr = agg["live"], agg["fileRec"]
        lines.append(f"| {v['variant']} | {', '.join(on) or 'shipping today'} | {fmt(lv['wer'], 'pct')} | {fmt(fr['wer'], 'pct')} "
                     f"| {fmt(lv['longestMissing'], 'int')} | {fmt(fr['longestMissing'], 'int')} "
                     f"| {fmt(lv.get('firstFinal'))} | {fmt(lv.get('finalLatP50'))} / {fmt(lv.get('finalLatP90'))} |")
    return "\n".join(lines) + "\n"


def report_markdown(report_metrics, label, baseline_metrics=None):
    """Whole report: probe, comparison table, then each tuning against the first (or a baseline file)."""
    variants = report_metrics["variants"]
    if not variants or not any(v["fixtures"] for v in variants):
        return (markdown({"probe": report_metrics["probe"], "variant": "-", "fixtures": [], "aggregate": {}}, label)
                + engines_markdown(report_metrics))
    out = [f"# Listening harness: {label}", "", comparison(report_metrics), "", engines_markdown(report_metrics)]
    base = baseline_metrics or variants[0]
    for v in variants:
        out.append(markdown(v, label, None if v is base else base))
    order = report_metrics.get("order") or {}
    if order:
        out.append("Tuning order per fixture (rotated so a warm model is not credited to one tuning): "
                   + "; ".join(f"{k}: {' > '.join(o)}" for k, o in sorted(order.items())) + "\n")
    return "\n".join(out)


def markdown(metrics, label, baseline=None):
    probe = metrics["probe"]
    lines = [f"## Listening harness: {label} (variant `{metrics['variant']}`)", ""]
    lines.append(f"Host {probe.get('host')} ({probe.get('os')}), locale `{probe.get('locale')}`, "
                 f"SpeechTranscriber available: {probe.get('speechTranscriberAvailable')}, "
                 f"route before/after prefetch: `{probe.get('routeBefore')}` / `{probe.get('routeAfter')}`"
                 + (f", prefetch {probe.get('prefetchSeconds', 0):.0f}s"
                    + (" (timed out)" if probe.get("prefetchTimedOut") else "") if probe.get("prefetchSeconds") else ""))
    for note in probe.get("notes", []):
        lines.append(f"- {note}")
    if not metrics["fixtures"]:
        lines += ["", "**No fixtures were transcribed on this host.**"]
        return "\n".join(lines) + "\n"
    agg = metrics["aggregate"]
    base = (baseline or {}).get("aggregate", {})
    lines += ["", "### Totals" + (" (change vs baseline in brackets)" if baseline else ""), "",
              "| path | WER | words deleted | longest missing stretch | final lag p50 / worst p90 (s) | first final (s) | converter drops |",
              "|---|---|---|---|---|---|---|"]
    names = {"live": "live finals (kept today)", "fileRec": "file pass, recorded m4a", "fileSrc": "file pass, source wav"}
    for key in ("live", "fileRec", "fileSrc"):
        a, b = agg[key], base.get(key, {})
        lat = (f"{fmt(a.get('finalLatP50'))}{delta(a.get('finalLatP50'), b.get('finalLatP50'), 's')} / "
               f"{fmt(a.get('finalLatP90'))}{delta(a.get('finalLatP90'), b.get('finalLatP90'), 's')}") if key == "live" else "–"
        first = f"{fmt(a.get('firstFinal'))}{delta(a.get('firstFinal'), b.get('firstFinal'), 's')}" if key == "live" else "–"
        drops = fmt(a.get("convertDrops"), "int") if key == "live" else "–"
        lines.append(f"| {names[key]} | {fmt(a['wer'], 'pct')}{delta(a['wer'], b.get('wer'), 'pct')} "
                     f"| {fmt(a['deleted'], 'int')}{delta(a['deleted'], b.get('deleted'), 'int')} "
                     f"| {fmt(a['longestMissing'], 'int')}{delta(a['longestMissing'], b.get('longestMissing'), 'int')} words "
                     f"| {lat} | {first} | {drops} |")
    lines += ["", "### Per fixture", "",
              "| fixture | audio (s) | live WER | file WER (m4a) | live longest missing | file longest missing | first volatile / final (s) | final lag p50 / p90 (s) | stop to done (s) | volatiles/s | file pass s per audio min |",
              "|---|---|---|---|---|---|---|---|---|---|---|"]
    for r in metrics["fixtures"]:
        lv, fr = r["live"], r["fileRec"]
        if "error" in lv:
            live_cols = [f"error: {lv['error'][:60]}", "", "", "", "", "", ""]
        else:
            live_cols = [fmt(lv["wer"], "pct"), None, f"{lv['longestMissing']}", None,
                         f"{fmt(lv['firstVolatile'])} / {fmt(lv['firstFinal'])}",
                         f"{fmt(lv['finalLatP50'])} / {fmt(lv['finalLatP90'])}", fmt(lv["stopToDone"])]
        file_wer = fmt(fr["wer"], "pct") if "error" not in fr else f"error: {fr['error'][:40]}"
        file_gap = str(fr["longestMissing"]) if "error" not in fr else ""
        vps = fmt(lv.get("volatilesPerSec")) if "error" not in lv else ""
        spm = fmt(fr.get("secPerAudioMin")) if "error" not in fr else ""
        lines.append(f"| {r['name']} | {fmt(r['duration'])} | {live_cols[0]} | {file_wer} | {live_cols[2]} | {file_gap} "
                     f"| {live_cols[4]} | {live_cols[5]} | {live_cols[6]} | {vps} | {spm} |")
    lines += ["", "<details><summary>Longest missing stretches and transcripts</summary>", ""]
    for r in metrics["fixtures"]:
        for key in ("live", "fileRec"):
            x = r[key]
            if "error" in x:
                continue
            lines.append(f"- **{r['name']} / {names[key]}**: missing \"{x['longestMissingText']}\"")
            lines.append(f"  - heard: {x['transcript']}")
    lines += ["", "</details>", ""]
    return "\n".join(lines) + "\n"


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("report")
    ap.add_argument("--label", default="run")
    ap.add_argument("--baseline")
    ap.add_argument("--metrics-out")
    ap.add_argument("--markdown-out")
    args = ap.parse_args(argv)
    with open(args.report, encoding="utf-8") as f:
        report = json.load(f)
    metrics = score_report(report)
    baseline = None
    if args.baseline:
        with open(args.baseline, encoding="utf-8") as f:
            baseline = json.load(f)["variants"][0]
    md = report_markdown(metrics, args.label, baseline)
    if args.metrics_out:
        with open(args.metrics_out, "w", encoding="utf-8") as f:
            json.dump(metrics, f, indent=1)
    if args.markdown_out:
        with open(args.markdown_out, "a", encoding="utf-8") as f:
            f.write(md)
    else:
        sys.stdout.write(md)
    return 0


if __name__ == "__main__":
    sys.exit(main())
