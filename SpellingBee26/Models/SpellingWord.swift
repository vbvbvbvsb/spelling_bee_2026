import Foundation

struct SpellingWord: Codable, Identifiable, Hashable {
    let id: String
    let primarySpelling: String
    let acceptedSpellings: [String]
    let definition: String
    let exampleSentence: String
}
