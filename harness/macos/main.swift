import Foundation

// macOS host for the transcription harness: compiles the app's platform-neutral capture sources
// directly (see the listen-harness workflow) and writes the raw report JSON.
// Usage: listen-harness <fixtures dir> <work dir> <out.json>
let arguments = CommandLine.arguments
guard arguments.count == 4 else {
    FileHandle.standardError.write(Data("usage: listen-harness <fixtures> <work> <out.json>\n".utf8))
    exit(2)
}
let fixtures = HarnessFixture.load(from: URL(fileURLWithPath: arguments[1], isDirectory: true))
ListenHarness.log("macOS host: \(fixtures.count) fixtures")
let report = await ListenHarness.runAll(fixtures: fixtures, host: "macOS",
                                        workDirectory: URL(fileURLWithPath: arguments[2], isDirectory: true))
try ListenHarness.encode(report).write(to: URL(fileURLWithPath: arguments[3]))
ListenHarness.log("wrote \(arguments[3])")
