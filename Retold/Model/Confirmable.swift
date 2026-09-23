import Foundation

/// Why a value exists and where its text came from. NOT persisted directly (not Codable);
/// the persisted form is StoredProvenance.
enum Provenance: Hashable, Sendable {
    case userTyped
    case userConfirmed(proposedBy: Origin)
    case transcriptQuote(captureID: UUID, start: TimeInterval, end: TimeInterval)
    case model
    case deck(promptID: String)
}

/// Flat persisted form of Provenance. Exactly one `kind`; the optionals that kind needs are
/// set, the rest nil.
struct StoredProvenance: Codable, Hashable, Sendable {
    enum Kind: String, Codable, Hashable, Sendable {
        case userTyped, userConfirmed, transcriptQuote, model, deck
    }

    var kind: Kind
    var proposedBy: Origin?
    var captureID: UUID?
    var start: TimeInterval?
    var end: TimeInterval?
    var promptID: String?

    init(_ p: Provenance) {
        switch p {
        case .userTyped:
            kind = .userTyped
        case .userConfirmed(let proposedBy):
            kind = .userConfirmed
            self.proposedBy = proposedBy
        case .transcriptQuote(let captureID, let start, let end):
            kind = .transcriptQuote
            self.captureID = captureID
            self.start = start
            self.end = end
        case .model:
            kind = .model
        case .deck(let promptID):
            kind = .deck
            self.promptID = promptID
        }
    }

    /// nil if the fields don't form a valid case for `kind`:
    /// userTyped/model need all five optionals nil; userConfirmed needs only proposedBy;
    /// transcriptQuote needs captureID/start/end; deck needs only promptID.
    var provenance: Provenance? {
        switch kind {
        case .userTyped, .model:
            guard proposedBy == nil, captureID == nil, start == nil, end == nil, promptID == nil else {
                return nil
            }
            return kind == .userTyped ? .userTyped : .model
        case .userConfirmed:
            guard let proposedBy, captureID == nil, start == nil, end == nil, promptID == nil else {
                return nil
            }
            return .userConfirmed(proposedBy: proposedBy)
        case .transcriptQuote:
            guard let captureID, let start, let end, proposedBy == nil, promptID == nil else {
                return nil
            }
            return .transcriptQuote(captureID: captureID, start: start, end: end)
        case .deck:
            guard let promptID, proposedBy == nil, captureID == nil, start == nil, end == nil else {
                return nil
            }
            return .deck(promptID: promptID)
        }
    }
}

enum ConfirmableDecodingError: Error, Equatable {
    case malformedProvenance
    case invalidStatusProvenance
}

/// A value the user did not necessarily author, tracked with status and provenance
/// (PLAN section 5.1 Rule 1). Construction is factory-only so that no status/provenance
/// pair outside the section-2 table can be built or mutated into existence.
struct Confirmable<T: Codable & Hashable & Sendable>: Codable, Hashable, Sendable {
    private(set) var value: T
    private(set) var status: ConfirmStatus
    private var stored: StoredProvenance

    /// The decoder and factories guarantee non-nil, so the failure path is unreachable
    /// by design — no force-unwrap anywhere.
    var provenance: Provenance {
        guard let p = stored.provenance else {
            preconditionFailure("Confirmable stored malformed provenance")
        }
        return p
    }

    /// The Rule-1 invariant (docs/R1-DATAMODEL-SPEC.md section 2), in one place:
    /// .proposed allows .model/.deck/.transcriptQuote; .confirmed allows
    /// .userTyped/.userConfirmed/.transcriptQuote; .rejected allows .model/.deck/.transcriptQuote.
    static func isValid(status: ConfirmStatus, provenance: Provenance) -> Bool {
        switch status {
        case .proposed, .rejected:
            switch provenance {
            case .model, .deck, .transcriptQuote: return true
            case .userTyped, .userConfirmed: return false
            }
        case .confirmed:
            switch provenance {
            case .userTyped, .userConfirmed, .transcriptQuote: return true
            case .model, .deck: return false
            }
        }
    }

    // The ONLY ways to make one. The memberwise path is private.
    private init(value: T, status: ConfirmStatus, stored: StoredProvenance) {
        self.value = value
        self.status = status
        self.stored = stored
    }

    static func proposedByModel(_ value: T) -> Confirmable {
        Confirmable(value: value, status: .proposed, stored: StoredProvenance(.model))
    }

    static func proposedByDeck(_ value: T, promptID: String) -> Confirmable {
        Confirmable(value: value, status: .proposed, stored: StoredProvenance(.deck(promptID: promptID)))
    }

    static func proposedQuote(_ value: T, span: VerifiedSpan) -> Confirmable {
        Confirmable(
            value: value,
            status: .proposed,
            stored: StoredProvenance(.transcriptQuote(captureID: span.captureID, start: span.start, end: span.end))
        )
    }

    static func userTyped(_ value: T) -> Confirmable {
        Confirmable(value: value, status: .confirmed, stored: StoredProvenance(.userTyped))
    }

    /// .proposed -> .confirmed. Provenance: .model -> .userConfirmed(proposedBy: .model),
    /// .deck -> .userConfirmed(proposedBy: .deck), .transcriptQuote stays as is.
    /// Returns false and changes nothing unless status was .proposed.
    @discardableResult
    mutating func confirm() -> Bool {
        guard status == .proposed else { return false }
        switch provenance {
        case .model:
            stored = StoredProvenance(.userConfirmed(proposedBy: .model))
        case .deck:
            stored = StoredProvenance(.userConfirmed(proposedBy: .deck))
        case .transcriptQuote:
            break
        case .userTyped, .userConfirmed:
            return false
        }
        status = .confirmed
        return true
    }

    /// .proposed -> .rejected, provenance unchanged. False and no change otherwise.
    @discardableResult
    mutating func reject() -> Bool {
        guard status == .proposed else { return false }
        status = .rejected
        return true
    }

    /// Any state -> value replaced, .confirmed, .userTyped.
    mutating func replaceByUser(_ value: T) {
        self.value = value
        status = .confirmed
        stored = StoredProvenance(.userTyped)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let value = try container.decode(T.self, forKey: .value)
        let status = try container.decode(ConfirmStatus.self, forKey: .status)
        let stored = try container.decode(StoredProvenance.self, forKey: .stored)
        guard let provenance = stored.provenance else {
            throw ConfirmableDecodingError.malformedProvenance
        }
        guard Confirmable.isValid(status: status, provenance: provenance) else {
            throw ConfirmableDecodingError.invalidStatusProvenance
        }
        self.init(value: value, status: status, stored: stored)
    }
}
