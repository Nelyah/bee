import Foundation

extension FuzzyMatcher {
    // MARK: - Scoring Constants (from fzf)

    static let scoreMatch: Int16 = 16
    static let scoreGapStart: Int16 = -3
    static let scoreGapExtension: Int16 = -1

    static let bonusBoundary: Int16 = scoreMatch / 2
    static let bonusNonWord: Int16 = scoreMatch / 2
    static let bonusCamel123: Int16 = bonusBoundary + scoreGapExtension
    static let bonusConsecutive: Int16 = -(scoreGapStart + scoreGapExtension)
    static let bonusFirstCharMultiplier: Int16 = 2

    static var bonusBoundaryWhite: Int16 = bonusBoundary + 2
    static var bonusBoundaryDelimiter: Int16 = bonusBoundary + 1

    static let whiteScalarValues: Set<UInt32> = [
        0x20, // space
        0x09, // tab
        0x0A, // line feed
        0x0B, // vertical tab
        0x0C, // form feed
        0x0D, // carriage return
        0x85, // next line
        0xA0, // non-breaking space
    ]

    static let delimiterScalarValues: Set<UInt32> = [
        0x2F, // /
        0x2C, // ,
        0x3A, // :
        0x3B, // ;
        0x7C, // |
    ]

    enum CharClass: Int, CaseIterable {
        case white
        case nonWord
        case delimiter
        case lower
        case upper
        case letter
        case number
    }

    static var initialCharClass: CharClass = .white
    static var asciiCharClasses: [CharClass] = Array(repeating: .nonWord, count: 128)
    static var bonusMatrix: [[Int16]] = Array(
        repeating: Array(repeating: 0, count: CharClass.allCases.count),
        count: CharClass.allCases.count
    )
    static var isInitialized = false
}
