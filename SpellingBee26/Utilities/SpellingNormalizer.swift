import Foundation

enum SpellingNormalizer {
    private static let letterHomophones: [String: Character] = [
        "a": "a", "ay": "a",
        "b": "b", "be": "b", "bee": "b",
        "c": "c", "cee": "c", "see": "c", "sea": "c",
        "d": "d", "dee": "d",
        "e": "e", "ee": "e",
        "f": "f", "eff": "f",
        "g": "g", "gee": "g", "jee": "g",
        "h": "h", "aitch": "h", "edge": "h",
        "i": "i", "eye": "i",
        "j": "j", "jay": "j",
        "k": "k", "kay": "k",
        "l": "l", "el": "l", "ell": "l",
        "m": "m", "em": "m",
        "n": "n", "en": "n",
        "o": "o", "oh": "o",
        "p": "p", "pee": "p",
        "q": "q", "cue": "q", "queue": "q",
        "r": "r", "are": "r", "ar": "r",
        "s": "s", "ess": "s",
        "t": "t", "tee": "t",
        "u": "u", "you": "u",
        "v": "v", "vee": "v",
        "w": "w", "doubleu": "w", "dubya": "w",
        "x": "x", "ex": "x",
        "y": "y", "why": "y",
        "z": "z", "ze": "z", "zee": "z"
    ]

    static func parseSpelling(from transcript: String) -> String {
        let cleaned = transcript
            .lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: ".", with: " ")

        let tokens = cleaned
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)

        var letters: [Character] = []
        var index = 0

        while index < tokens.count {
            let token = tokens[index]

            if token == "double", index + 1 < tokens.count {
                let next = tokens[index + 1]
                if next == "u" {
                    letters.append("w")
                    letters.append("w")
                    index += 2
                    continue
                }
            }

            if let mapped = letterHomophones[token] {
                letters.append(mapped)
            } else if token.count == 1, let char = token.first, char.isLetter {
                letters.append(char)
            }

            index += 1
        }

        return String(letters)
    }

    static func compact(_ text: String) -> String {
        text.lowercased().filter(\.isLetter)
    }

    static func spacedLowercase(_ text: String) -> String {
        text
            .lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isWhitespace })
            .map(String.init)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    static func matches(recognized: String, acceptedSpellings: [String]) -> Bool {
        let parsed = parseSpelling(from: recognized)
        let candidates = [
            parsed,
            compact(recognized),
            compact(parsed)
        ]

        for accepted in acceptedSpellings {
            let acceptedCompact = compact(accepted)
            let acceptedSpaced = spacedLowercase(accepted)

            for candidate in candidates where !candidate.isEmpty {
                if candidate == acceptedCompact {
                    return true
                }

                if acceptedSpaced.contains(" "), spacedLowercase(candidate) == acceptedSpaced {
                    return true
                }
            }
        }

        return false
    }
}
