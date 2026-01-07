import Foundation

extension FuzzyMatcher {
    // MARK: - Character Helpers

    static func initializeIfNeeded() {
        guard !isInitialized else { return }

        for i in 0 ..< asciiCharClasses.count {
            let scalar = UInt32(i)
            guard let char = UnicodeScalar(scalar) else { continue }
            if char >= "a", char <= "z" {
                asciiCharClasses[i] = .lower
            } else if char >= "A", char <= "Z" {
                asciiCharClasses[i] = .upper
            } else if char >= "0", char <= "9" {
                asciiCharClasses[i] = .number
            } else if whiteScalarValues.contains(scalar) {
                asciiCharClasses[i] = .white
            } else if delimiterScalarValues.contains(scalar) {
                asciiCharClasses[i] = .delimiter
            } else {
                asciiCharClasses[i] = .nonWord
            }
        }

        for prev in CharClass.allCases {
            for cur in CharClass.allCases {
                bonusMatrix[prev.rawValue][cur.rawValue] = bonusFor(prev: prev, current: cur)
            }
        }

        isInitialized = true
    }

    static func charClassOf(_ scalar: UInt32) -> CharClass {
        if scalar < 128 {
            return asciiCharClasses[Int(scalar)]
        }
        return charClassOfNonAscii(scalar)
    }

    static func charClassOfNonAscii(_ scalar: UInt32) -> CharClass {
        guard let unicodeScalar = UnicodeScalar(scalar) else { return .nonWord }
        if CharacterSet.lowercaseLetters.contains(unicodeScalar) {
            return .lower
        } else if CharacterSet.uppercaseLetters.contains(unicodeScalar) {
            return .upper
        } else if CharacterSet.decimalDigits.contains(unicodeScalar) {
            return .number
        } else if CharacterSet.letters.contains(unicodeScalar) {
            return .letter
        } else if CharacterSet.whitespacesAndNewlines.contains(unicodeScalar) {
            return .white
        } else if delimiterScalarValues.contains(scalar) {
            return .delimiter
        }
        return .nonWord
    }

    static func bonusFor(prev: CharClass, current: CharClass) -> Int16 {
        if current.rawValue > CharClass.nonWord.rawValue {
            switch prev {
            case .white:
                return bonusBoundaryWhite
            case .delimiter:
                return bonusBoundaryDelimiter
            case .nonWord:
                return bonusBoundary
            default:
                break
            }
        }

        if (prev == .lower && current == .upper) || (prev != .number && current == .number) {
            return bonusCamel123
        }

        switch current {
        case .nonWord, .delimiter:
            return bonusNonWord
        case .white:
            return bonusBoundaryWhite
        default:
            return 0
        }
    }

    static func bonusAt(_ input: ScalarChars, _ idx: Int) -> Int16 {
        if idx == 0 {
            return bonusBoundaryWhite
        }
        let prev = charClassOf(input.get(idx - 1))
        let cur = charClassOf(input.get(idx))
        return bonusMatrix[prev.rawValue][cur.rawValue]
    }
}
