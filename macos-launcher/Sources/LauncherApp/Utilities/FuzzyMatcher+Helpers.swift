import Foundation

extension FuzzyMatcher {
    static func maxInt16(_ a: Int16, _ b: Int16) -> Int16 {
        a >= b ? a : b
    }

    static func mapScalarIndicesToCharacterIndices(_ scalars: [Int], mapping: [Int]) -> [Int] {
        var set = Set<Int>()
        for scalarIndex in scalars {
            guard scalarIndex >= 0, scalarIndex < mapping.count else { continue }
            set.insert(mapping[scalarIndex])
        }
        return set.sorted()
    }

    static func lowercaseScalar(_ scalar: UInt32) -> UInt32 {
        guard let unicodeScalar = UnicodeScalar(scalar) else { return scalar }
        let lowered = String(unicodeScalar).lowercased()
        return lowered.unicodeScalars.first?.value ?? scalar
    }

    static func isWhitespace(_ scalar: UInt32) -> Bool {
        guard let unicodeScalar = UnicodeScalar(scalar) else { return false }
        return CharacterSet.whitespacesAndNewlines.contains(unicodeScalar)
    }
}
