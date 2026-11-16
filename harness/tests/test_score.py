import json, os, sys, unittest
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import score


class ScoreTests(unittest.TestCase):
    def test_perfect(self):
        s = score.word_scores("Hello, there. It's me!", "hello there its me")
        self.assertEqual((s["wer"], s["longestMissing"]), (0.0, 0))

    def test_dropped_chunk(self):
        ref = "one two three four five six seven eight"
        s = score.word_scores(ref, "one two seven eight")
        self.assertEqual(s["del"], 4)
        self.assertEqual(s["longestMissing"], 4)
        self.assertEqual(s["longestMissingText"], "three four five six")
        self.assertAlmostEqual(s["wer"], 0.5)

    def test_substitution_breaks_run(self):
        s = score.word_scores("a b c d e", "a x e")
        self.assertEqual(s["sub"] + s["del"], 3)
        self.assertEqual(s["longestMissing"], 2)

    def test_report_and_markdown(self):
        fixtures = [{"name": "f", "reference": "the cat sat on the mat", "duration": 3.0,
                             "live": {"path": "converter", "pushes": [[1, 1.0], [2, 2.0], [3, 3.0]],
                                      "events": [{"kind": "volatile", "text": "the", "start": 0, "end": 0.5, "wall": 1.4},
                                                 {"kind": "final", "text": "the cat", "start": 0, "end": 1.0, "wall": 1.8},
                                                 {"kind": "final", "text": "the mat", "start": 2, "end": 3.0, "wall": 3.5}],
                                      "stopWall": 3.0, "doneWall": 3.6, "completed": True, "writeError": False,
                                      "convertDrops": 0, "buffers": 3},
                             "fileFromRecording": {"segments": [{"kind": "final", "text": "the cat sat on the mat", "start": 0, "end": 3, "wall": 0}], "elapsed": 1.5},
                             "fileFromSource": {"segments": [], "elapsed": 1.0, "error": "boom"}}]
        tuning = {"name": "current", "fastResults": False, "prepareModel": False, "flushConverter": False, "useContext": False}
        fast = dict(tuning, name="fast", fastResults=True)
        rep = {"schema": "retold-listen-harness/v2", "probe": {"host": "t", "routeAfter": "speech:en-US"},
               "order": {"f": ["current", "fast"]},
               "variants": [{"tuning": tuning, "fixtures": fixtures}, {"tuning": fast, "fixtures": fixtures}]}
        full = score.score_report(rep)
        m = full["variants"][0]
        live = m["fixtures"][0]["live"]
        self.assertEqual(live["longestMissing"], 2)        # "sat on"
        self.assertEqual(live["finalsAfterStop"], 1)
        self.assertAlmostEqual(live["finalLatP50"], 0.8)   # only the pre-stop final counts
        self.assertEqual(m["fixtures"][0]["fileRec"]["wer"], 0.0)
        self.assertAlmostEqual(m["fixtures"][0]["fileRec"]["secPerAudioMin"], 30.0)
        md = score.report_markdown(full, "test")
        self.assertIn("live finals", md)
        self.assertIn("(+0.0)", md)
        self.assertIn("| fast | fastResults |", md)
        self.assertIn("f: current > fast", md)

    def test_engines(self):
        tuning = {"name": "current", "fastResults": False, "prepareModel": False, "flushConverter": False, "useContext": False}
        fixture = {"name": "f", "reference": "one two three four", "duration": 30.0,
                   "live": {"error": "x"}, "fileFromRecording": {"error": "x"},
                   "fileFromSource": {"segments": [{"kind": "final", "text": "one two", "start": 0, "end": 1, "wall": 0}], "elapsed": 3.0},
                   "peakExtraMB": 40.0}
        rep = {"probe": {}, "variants": [{"tuning": tuning, "fixtures": [fixture]}],
               "engines": [{"name": "whisper-base.en", "model": "m", "downloadSeconds": 20, "loadSeconds": 5,
                            "loadPeakExtraMB": 300, "fixtures": [
                                {"name": "f", "reference": "one two three four", "duration": 30.0, "peakExtraMB": 250,
                                 "filePass": {"segments": [{"kind": "final", "text": "One two three four.", "start": 0, "end": 2, "wall": 0}], "elapsed": 6.0}}]},
                           {"name": "whisper-turbo", "model": "t", "error": "Not enough free space", "fixtures": []}]}
        m = score.score_report(rep)
        self.assertEqual(m["engines"][0]["aggregate"]["wer"], 0.0)
        self.assertAlmostEqual(m["engines"][0]["aggregate"]["secPerAudioMin"], 12.0)
        md = score.report_markdown(m, "t")
        self.assertIn("| whisper-base.en (`m`) | 0.0%", md)
        self.assertIn("| Apple SpeechTranscriber (current) | 50.0%", md)
        self.assertIn("error: Not enough free space", md)

    def test_empty_report(self):
        md = score.report_markdown(score.score_report({"probe": {"host": "x"}, "variants": []}), "empty")
        self.assertIn("No fixtures were transcribed", md)


if __name__ == "__main__":
    unittest.main()
