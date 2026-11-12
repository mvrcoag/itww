import Foundation

public struct DiffSegment: Equatable, Identifiable, Sendable {
    public enum Kind: Equatable, Sendable {
        case unchanged
        case removed
        case added
    }

    public let id: Int
    public let kind: Kind
    public let text: String

    public init(id: Int, kind: Kind, text: String) {
        self.id = id
        self.kind = kind
        self.text = text
    }
}

public enum WordDiff {
    /// Computes a readable token-level diff between `original` and `revised`,
    /// preserving whitespace tokens and merging consecutive runs of the same kind.
    public static func compute(original: String, revised: String) -> [DiffSegment] {
        if original == revised {
            return original.isEmpty ? [] : [DiffSegment(id: 0, kind: .unchanged, text: original)]
        }

        let oldTokens = tokenize(original)
        let newTokens = tokenize(revised)

        // Myers diff via Swift's CollectionDifference.
        let diff = newTokens.difference(from: oldTokens)

        var removedIndices = Set<Int>()
        var insertedByOffset = [Int: String]()

        for change in diff {
            switch change {
            case .remove(let offset, _, _):
                removedIndices.insert(offset)
            case .insert(let offset, let element, _):
                insertedByOffset[offset] = element
            }
        }

        var rawSegments: [(DiffSegment.Kind, String)] = []
        var oldIndex = 0
        var newIndex = 0

        while oldIndex < oldTokens.count || newIndex < newTokens.count {
            if let inserted = insertedByOffset[newIndex] {
                rawSegments.append((.added, inserted))
                newIndex += 1
            } else if oldIndex < oldTokens.count, removedIndices.contains(oldIndex) {
                rawSegments.append((.removed, oldTokens[oldIndex]))
                oldIndex += 1
            } else if oldIndex < oldTokens.count, newIndex < newTokens.count {
                rawSegments.append((.unchanged, newTokens[newIndex]))
                oldIndex += 1
                newIndex += 1
            } else {
                break
            }
        }

        // Merge consecutive segments of identical kind.
        var merged: [DiffSegment] = []
        for (kind, token) in rawSegments {
            if let last = merged.last, last.kind == kind {
                merged[merged.count - 1] = DiffSegment(
                    id: last.id,
                    kind: kind,
                    text: last.text + token
                )
            } else {
                merged.append(DiffSegment(id: merged.count, kind: kind, text: token))
            }
        }

        return merged
    }

    static func tokenize(_ input: String) -> [String] {
        guard !input.isEmpty else { return [] }
        var tokens: [String] = []
        var current = ""
        var currentCategory: TokenCategory?

        for scalar in input {
            let category = TokenCategory.classify(scalar)
            if let existing = currentCategory, existing == category, category != .punctuation {
                current.append(scalar)
            } else {
                if !current.isEmpty {
                    tokens.append(current)
                }
                current = String(scalar)
                currentCategory = category
            }
        }

        if !current.isEmpty {
            tokens.append(current)
        }
        return tokens
    }

    private enum TokenCategory: Equatable {
        case word
        case whitespace
        case punctuation

        static func classify(_ char: Character) -> TokenCategory {
            if char.isWhitespace || char.isNewline {
                return .whitespace
            } else if char.isLetter || char.isNumber || char == "'" || char == "’" {
                return .word
            } else {
                return .punctuation
            }
        }
    }
}
