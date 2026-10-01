import Foundation

struct VerifiedReferent: Equatable, Sendable {
    let span: VerifiedSpan
    let kind: ReferentKind
}

/// The deterministic merge of every window's verified extract (PLAN section 6.3 item 4).
/// Contains verified spans and one period title from the user's own list; nothing else.
struct MergedExtract: Equatable, Sendable {
    var periodTitle: String?
    var people: [VerifiedSpan] = []
    var places: [VerifiedSpan] = []
    var timeCues: [VerifiedSpan] = []
    var referents: [VerifiedReferent] = []
    var titleSpan: VerifiedSpan?
}

enum ExtractMerger {
    /// A title is at most this many words (PLAN section 6.2 `titleSpan`).
    static let maxTitleWords = 8

    /// Verifies each window's strings against that window, then merges. A string that does not
    /// verify is dropped without a trace. Order is by first occurrence (audio start, then
    /// window order); duplicates are removed by normalised text, which also collapses the
    /// same quotation seen in two overlapping windows. `periodTitle` is the title (spelled as in
    /// `periodTitles`) named by most windows, the earliest window winning ties; a name that is
    /// not in `periodTitles` counts for nothing.
    static func merge(
        _ results: [(window: TranscriptWindow, extract: WindowExtract)],
        periodTitles: [String]
    ) -> MergedExtract {
        var merged = MergedExtract()
        var seen = Set<String>()
        var periodVotes: [String: Int] = [:]
        var periodOrder: [String] = []

        func collect(_ candidates: [String], window: TranscriptWindow, namespace: String) -> [VerifiedSpan] {
            var out: [VerifiedSpan] = []
            for candidate in candidates {
                guard let span = SpanVerifier.verify(candidate, in: window) else { continue }
                if seen.insert(namespace + "|" + SpanVerifier.phraseKey(span.text)).inserted {
                    out.append(span)
                }
            }
            return out
        }

        var referents: [VerifiedReferent] = []
        for (window, extract) in results {
            merged.people += collect(extract.people, window: window, namespace: "person")
            merged.places += collect(extract.places, window: window, namespace: "place")
            merged.timeCues += collect(extract.timeCues, window: window, namespace: "time")
            for raw in extract.referents {
                guard let span = SpanVerifier.verify(raw.span, in: window) else { continue }
                if seen.insert("referent|" + SpanVerifier.phraseKey(span.text)).inserted {
                    referents.append(VerifiedReferent(span: span, kind: raw.kind))
                }
            }
            if merged.titleSpan == nil,
               let candidate = extract.titleSpan,
               let span = SpanVerifier.verify(candidate, in: window),
               span.text.split(whereSeparator: \.isWhitespace).count <= maxTitleWords {
                merged.titleSpan = span
            }
            if let name = extract.periodName,
               let canonical = canonicalTitle(name, in: periodTitles) {
                if periodVotes[canonical] == nil { periodOrder.append(canonical) }
                periodVotes[canonical, default: 0] += 1
            }
        }

        func ordered(_ a: VerifiedSpan, _ b: VerifiedSpan) -> Bool {
            (a.start, a.end, a.text) < (b.start, b.end, b.text)
        }
        merged.people.sort(by: ordered)
        merged.places.sort(by: ordered)
        merged.timeCues.sort(by: ordered)
        merged.referents = referents.sorted { ordered($0.span, $1.span) }
        // `periodOrder` is first-vote order, so a strict ">" keeps the earliest title on ties.
        var best: String?
        for title in periodOrder {
            guard let current = best else { best = title; continue }
            if (periodVotes[title] ?? 0) > (periodVotes[current] ?? 0) { best = title }
        }
        merged.periodTitle = best
        return merged
    }

    private static func canonicalTitle(_ name: String, in titles: [String]) -> String? {
        let wanted = SpanVerifier.phraseKey(name)
        guard !wanted.isEmpty else { return nil }
        return titles.first { SpanVerifier.phraseKey($0) == wanted }
    }
}
