import Foundation

struct ScalarChars {
    let scalars: [UnicodeScalar]
    let scalarToCharacterIndex: [Int]
    let isASCII: Bool
    let bytes: [UInt8]

    init(_ string: String) {
        var scalars: [UnicodeScalar] = []
        var mapping: [Int] = []
        var ascii = true
        var bytes: [UInt8] = []

        var charIndex = 0
        for char in string {
            for scalar in String(char).unicodeScalars {
                scalars.append(scalar)
                mapping.append(charIndex)
                if scalar.value >= 128 {
                    ascii = false
                } else {
                    bytes.append(UInt8(scalar.value))
                }
            }
            charIndex += 1
        }

        self.scalars = scalars
        scalarToCharacterIndex = mapping
        isASCII = ascii
        self.bytes = ascii ? bytes : []
    }

    var length: Int { scalars.count }

    func get(_ index: Int) -> UInt32 {
        scalars[index].value
    }

    func leadingWhitespaces() -> Int {
        var count = 0
        for scalar in scalars {
            if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                count += 1
            } else {
                break
            }
        }
        return count
    }

    func trailingWhitespaces() -> Int {
        guard !scalars.isEmpty else { return 0 }
        var count = 0
        var idx = scalars.count - 1
        while idx >= 0 {
            if CharacterSet.whitespacesAndNewlines.contains(scalars[idx]) {
                count += 1
            } else {
                break
            }
            idx -= 1
        }
        return count
    }

    func copyScalars(into buffer: inout [UInt32], from start: Int) {
        for i in 0 ..< buffer.count {
            buffer[i] = scalars[start + i].value
        }
    }
}
