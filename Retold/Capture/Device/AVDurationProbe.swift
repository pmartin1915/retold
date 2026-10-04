import AVFoundation

/// Real AudioDurationProbe: the written length of a closed audio file.
struct AVDurationProbe: AudioDurationProbe {
    func duration(of audioURL: URL) -> TimeInterval? {
        do {
            let file = try AVAudioFile(forReading: audioURL)
            let sampleRate = file.processingFormat.sampleRate
            guard sampleRate > 0 else { return nil }
            return Double(file.length) / sampleRate
        } catch {
            return nil
        }
    }
}
