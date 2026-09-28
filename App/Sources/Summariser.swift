import Foundation
import WatchLaterCore
#if canImport(FoundationModels)
import FoundationModels
import NaturalLanguage
#endif

/// Makes a Digest from what was said, with Apple's on-device model — nothing
/// leaves the device. A long video is read in pieces (the model takes a few
/// thousand words at a time): each piece becomes a few sentences of notes, and
/// the notes become the summary, key points and questions.
enum Summariser {
    /// Why it can or cannot run here — said under the button, never a grey button.
    enum Readiness: Equatable {
        case ready, notThisDevice, turnedOff, stillDownloading, olderSystem, unknown
        var why: String? {
            switch self {
            case .ready: return nil
            case .notThisDevice: return "This device cannot run Apple Intelligence. A summary made on your other device shows up here by itself."
            case .turnedOff: return "Apple Intelligence is switched off. Turn it on in Settings › Apple Intelligence & Siri, then try again."
            case .stillDownloading: return "Apple Intelligence is still getting ready on this device (it downloads once). Try again in a while."
            case .olderSystem: return "Summaries need iOS 26 or macOS 26 on this device."
            case .unknown: return "Apple Intelligence is not available right now. Try again later."
            }
        }
    }

    static var readiness: Readiness {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available: return .ready
            case .unavailable(.deviceNotEligible): return .notThisDevice
            case .unavailable(.appleIntelligenceNotEnabled): return .turnedOff
            case .unavailable(.modelNotReady): return .stillDownloading
            default: return .unknown
            }
        }
        return .olderSystem
        #else
        return .olderSystem
        #endif
    }

    struct Failed: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    /// `progress` gets "Reading part 2 of 5" as it goes.
    static func digest(_ t: WatchLaterCore.Transcript, title: String, progress: @escaping @MainActor (String) -> Void) async throws -> Digest {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return try await Model.digest(t, title: title, progress: progress)
        }
        #endif
        throw Failed(message: Readiness.olderSystem.why ?? "")
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
private enum Model {
    /// The gentler guardrails Apple made for transforming the user's own
    /// material: the default ones refused a swimming-exercise video as
    /// "sensitive" (tried on the Mac, 2026-09-28). They cover plain-text
    /// answers, which is why the answer is text in `Digest.form`.
    static var model: SystemLanguageModel { SystemLanguageModel(guardrails: .permissiveContentTransformations) }

    /// "Write in the language of the video" gave Spanish for an English video;
    /// naming the language works — so it is found first, on the device.
    static func language(of t: WatchLaterCore.Transcript) -> String {
        let sample = String(t.lines.map(\.s).joined(separator: " ").prefix(4_000))
        let code = NLLanguageRecognizer.dominantLanguage(for: sample)?.rawValue ?? "en"
        return Locale(identifier: "en").localizedString(forLanguageCode: code) ?? "English"
    }

    static func instructions(_ language: String) -> String {
        """
        You help someone remember what they learned from a video. You are given what was said in it \
        (automatic subtitles, so words may be misheard). Stay with what the video says; do not add \
        facts of your own. Write everything in \(language).
        """
    }

    static func digest(_ t: WatchLaterCore.Transcript, title: String, progress: @escaping @MainActor (String) -> Void) async throws -> Digest {
        var pieces = Reading.pieces(t.lines)
        guard !pieces.isEmpty else { throw Summariser.Failed(message: "This video has no words to read.") }
        let rules = instructions(language(of: t))
        do {
            // Long videos: each piece becomes four sentences of notes; if the
            // notes are still long, they are read again the same way.
            var round = 0
            while pieces.count > 1 {
                round += 1
                var notes: [String] = []
                for (i, p) in pieces.enumerated() {
                    await progress(round == 1 ? "Reading part \(i + 1) of \(pieces.count)…" : "Putting the notes together…")
                    let s = LanguageModelSession(model: model, instructions: rules)
                    let r = try await s.respond(to: "Video: \(title)\n\nPart \(i + 1) of what was said:\n\(p)\n\nWrite four sentences of notes on this part.")
                    notes.append(r.content)
                }
                pieces = Reading.pieces(notes.map { WatchLaterCore.Transcript.Line(t: 0, s: $0) })
            }
            await progress("Writing the summary…")
            let s = LanguageModelSession(model: model, instructions: rules)
            let r = try await s.respond(to: "Video: \(title)\n\nWhat was said (or notes on it):\n\(pieces[0])\n\n\(Digest.form)")
            guard let d = Digest.parse(r.content) else {
                throw Summariser.Failed(message: "Apple Intelligence gave an answer the app could not read. Try Summarise again.")
            }
            return d
        } catch let e as LanguageModelSession.GenerationError {
            switch e {
            case .guardrailViolation:
                throw Summariser.Failed(message: "Apple Intelligence would not summarise this one (its safety rules). The subtitles are still there to read.")
            case .exceededContextWindowSize:
                throw Summariser.Failed(message: "A part was too long for the model. Please tell Claude which video it was.")
            default:
                throw Summariser.Failed(message: "Apple Intelligence would not summarise this one: \(e.localizedDescription)")
            }
        }
    }
}
#endif
