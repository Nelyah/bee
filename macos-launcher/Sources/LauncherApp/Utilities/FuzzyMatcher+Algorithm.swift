import Foundation

extension FuzzyMatcher {
    // MARK: - Matching Algorithms

    static func fuzzyMatchV2(
        caseSensitive: Bool,
        normalize: Bool,
        input: ScalarChars,
        pattern: [UInt32]
    ) -> MatchResult? {
        let m = pattern.count
        if m == 0 {
            return MatchResult(score: 0, matchedScalarIndices: [])
        }

        let n = input.length
        if m > n {
            return nil
        }

        guard let phase1 = runFuzzyPhase1(
            caseSensitive: caseSensitive,
            normalize: normalize,
            input: input,
            pattern: pattern
        ) else {
            return nil
        }

        if m == 1 {
            let score = Int(phase1.maxScore)
            let indices = [phase1.minIdx + phase1.maxScorePos]
            return MatchResult(score: score, matchedScalarIndices: indices)
        }

        let phase2 = fillScoreMatrix(phase1: phase1, pattern: pattern)
        let positions = backtrackPositions(phase2: phase2)
        return MatchResult(score: Int(phase2.maxScore), matchedScalarIndices: positions)
    }

    private struct FuzzyPhase1 {
        let minIdx: Int
        let maxIdx: Int
        let lastIdx: Int
        let maxScore: Int16
        let maxScorePos: Int
        let f: [Int32]
        let t: [UInt32]
        let b: [Int16]
        let h0: [Int16]
        let c0: [Int16]
    }

    private static func runFuzzyPhase1(
        caseSensitive: Bool,
        normalize: Bool,
        input: ScalarChars,
        pattern: [UInt32]
    ) -> FuzzyPhase1? {
        let m = pattern.count
        let (minIdx, maxIdx) = asciiFuzzyIndex(input: input, pattern: pattern, caseSensitive: caseSensitive)
        if minIdx < 0 {
            return nil
        }

        let scopedCount = maxIdx - minIdx
        var t = Array(repeating: UInt32(0), count: scopedCount)
        input.copyScalars(into: &t, from: minIdx)

        var h0 = Array(repeating: Int16(0), count: scopedCount)
        var c0 = Array(repeating: Int16(0), count: scopedCount)
        var b = Array(repeating: Int16(0), count: scopedCount)
        var f = Array(repeating: Int32(0), count: m)

        var maxScore: Int16 = 0
        var maxScorePos = 0
        var pidx = 0
        var lastIdx = 0
        let pchar0 = pattern[0]
        var pchar = pattern[0]
        var prevH0: Int16 = 0
        var prevClass = initialCharClass
        var inGap = false

        for off in 0 ..< t.count {
            var char = t[off]
            let charClass = charClassOf(char)

            char = normalizeScalarForMatch(char, caseSensitive: caseSensitive, normalize: normalize)
            t[off] = char

            let bonus = bonusMatrix[prevClass.rawValue][charClass.rawValue]
            b[off] = bonus
            prevClass = charClass

            if char == pchar {
                if pidx < m {
                    f[pidx] = Int32(off)
                    pidx += 1
                    pchar = pattern[min(pidx, m - 1)]
                }
                lastIdx = off
            }

            if char == pchar0 {
                let score = scoreMatch + bonus * bonusFirstCharMultiplier
                h0[off] = score
                c0[off] = 1
                if m == 1, score >= maxScore {
                    maxScore = score
                    maxScorePos = off
                    if bonus >= bonusBoundary {
                        break
                    }
                }
                inGap = false
            } else {
                let gapScore = inGap ? scoreGapExtension : scoreGapStart
                h0[off] = maxInt16(prevH0 + gapScore, 0)
                c0[off] = 0
                inGap = true
            }
            prevH0 = h0[off]
        }

        if pidx != m {
            return nil
        }

        return FuzzyPhase1(
            minIdx: minIdx,
            maxIdx: maxIdx,
            lastIdx: lastIdx,
            maxScore: maxScore,
            maxScorePos: maxScorePos,
            f: f,
            t: t,
            b: b,
            h0: h0,
            c0: c0
        )
    }

    private struct FuzzyPhase2 {
        let minIdx: Int
        let lastIdx: Int
        let maxScore: Int16
        let maxScorePos: Int
        let f: [Int32]
        let b: [Int16]
        let h: [Int16]
        let c: [Int16]
        let width: Int
    }

    private static func fillScoreMatrix(phase1: FuzzyPhase1, pattern: [UInt32]) -> FuzzyPhase2 {
        let m = pattern.count
        let f0 = Int(phase1.f[0])
        let width = phase1.lastIdx - f0 + 1

        var h = Array(repeating: Int16(0), count: width * m)
        var c = Array(repeating: Int16(0), count: width * m)

        for i in 0 ..< width {
            h[i] = phase1.h0[f0 + i]
            c[i] = phase1.c0[f0 + i]
        }

        var maxScore = phase1.maxScore
        var maxScorePos = phase1.maxScorePos

        for (offset, fval) in phase1.f.dropFirst().enumerated() {
            let fpos = Int(fval)
            let pchar = pattern[offset + 1]
            let pidx = offset + 1
            let row = pidx * width
            var inGap = false

            let tsub = Array(phase1.t[fpos ... phase1.lastIdx])
            let bsub = Array(phase1.b[fpos ... phase1.lastIdx])
            var csub = Array(repeating: Int16(0), count: tsub.count)
            var hsub = Array(repeating: Int16(0), count: tsub.count)

            let diagStart = row - width + fpos - f0 - 1
            let diagRange = diagStart ..< (diagStart + tsub.count)
            let cdiag = Array(c[diagRange])
            let hdiag = Array(h[diagRange])

            let leftStart = row + fpos - f0 - 1
            let leftRange = leftStart ..< (leftStart + tsub.count)
            var hleft = Array(h[leftRange])
            hleft[0] = 0

            for idx in 0 ..< tsub.count {
                let col = idx + fpos
                var s1: Int16 = 0
                let s2 = hleft[idx] + (inGap ? scoreGapExtension : scoreGapStart)
                var consecutive: Int16 = 0

                if pchar == tsub[idx] {
                    s1 = hdiag[idx] + scoreMatch
                    var bonus = bsub[idx]
                    consecutive = cdiag[idx] + 1
                    if consecutive > 1 {
                        let fb = phase1.b[col - Int(consecutive) + 1]
                        if bonus >= bonusBoundary, bonus > fb {
                            consecutive = 1
                        } else {
                            bonus = maxInt16(bonus, maxInt16(bonusConsecutive, fb))
                        }
                    }
                    if s1 + bonus < s2 {
                        s1 += bsub[idx]
                        consecutive = 0
                    } else {
                        s1 += bonus
                    }
                }

                csub[idx] = consecutive
                inGap = s1 < s2
                let score = maxInt16(maxInt16(s1, s2), 0)
                if pidx == m - 1, score >= maxScore {
                    maxScore = score
                    maxScorePos = col
                }
                hsub[idx] = score
            }

            for idx in 0 ..< tsub.count {
                h[row + fpos - f0 + idx] = hsub[idx]
                c[row + fpos - f0 + idx] = csub[idx]
            }
        }

        return FuzzyPhase2(
            minIdx: phase1.minIdx,
            lastIdx: phase1.lastIdx,
            maxScore: maxScore,
            maxScorePos: maxScorePos,
            f: phase1.f,
            b: phase1.b,
            h: h,
            c: c,
            width: width
        )
    }

    private static func backtrackPositions(phase2: FuzzyPhase2) -> [Int] {
        var positions: [Int] = []
        var j = phase2.maxScorePos
        var i = phase2.f.count - 1
        var preferMatch = true
        let f0 = Int(phase2.f[0])

        while true {
            let row = i * phase2.width
            let j0 = j - f0
            let s = phase2.h[row + j0]

            var s1: Int16 = 0
            var s2: Int16 = 0
            if i > 0, j >= Int(phase2.f[i]) {
                s1 = phase2.h[row - phase2.width + j0 - 1]
            }
            if j > Int(phase2.f[i]) {
                s2 = phase2.h[row + j0 - 1]
            }

            if s > s1, s > s2 || (s == s2 && preferMatch) {
                positions.append(j + phase2.minIdx)
                if i == 0 {
                    break
                }
                i -= 1
            }

            let idx = row + j0
            if idx + 1 < phase2.c.count, idx + phase2.width + 1 < phase2.c.count {
                preferMatch = phase2.c[idx] > 1 || phase2.c[idx + phase2.width + 1] > 0
            } else {
                preferMatch = phase2.c[idx] > 1
            }
            j -= 1
        }

        return positions.reversed()
    }

    private struct ExactMatchParams {
        let caseSensitive: Bool
        let normalize: Bool
        let input: ScalarChars
        let pattern: [UInt32]
    }

    private struct ScoreParams {
        let caseSensitive: Bool
        let normalize: Bool
        let input: ScalarChars
        let pattern: [UInt32]
    }

    static func exactMatch(
        caseSensitive: Bool,
        normalize: Bool,
        input: ScalarChars,
        pattern: [UInt32],
        boundary: Bool
    ) -> MatchResult? {
        let params = ExactMatchParams(
            caseSensitive: caseSensitive,
            normalize: normalize,
            input: input,
            pattern: pattern
        )
        return exactMatchNaive(params: params, boundary: boundary)
    }

    private static func exactMatchNaive(params: ExactMatchParams, boundary: Bool) -> MatchResult? {
        if params.pattern.isEmpty {
            return MatchResult(score: 0, matchedScalarIndices: [])
        }

        let lenRunes = params.input.length
        let lenPattern = params.pattern.count
        if lenRunes < lenPattern {
            return nil
        }

        let (idx, _) = asciiFuzzyIndex(
            input: params.input,
            pattern: params.pattern,
            caseSensitive: params.caseSensitive
        )
        if idx < 0 {
            return nil
        }

        var pidx = 0
        var bestPos = -1
        var bestBonus: Int16 = -1
        var state = BoundaryMatchState()

        var index = 0
        while index < lenRunes {
            let index_ = index
            let char = normalizeScalarForMatch(
                params.input.get(index_),
                caseSensitive: params.caseSensitive,
                normalize: params.normalize
            )
            let pchar = params.pattern[pidx]

            let context = BoundaryMatchContext(
                input: params.input,
                index: index_,
                pidx: pidx,
                lenPattern: lenPattern
            )
            if char == pchar, acceptBoundaryMatch(
                boundary: boundary,
                context: context,
                state: &state
            ) {
                pidx += 1
                if pidx == lenPattern {
                    if state.bonus > bestBonus {
                        bestPos = index
                        bestBonus = state.bonus
                    }
                    if state.bonus >= bonusBoundary {
                        break
                    }
                    index = max(index - pidx + 1, -1)
                    pidx = 0
                    state = BoundaryMatchState()
                }
            } else {
                index = max(index - pidx, -1)
                pidx = 0
                state = BoundaryMatchState()
            }
            index += 1
        }

        if bestPos >= 0 {
            let matchedRange = (bestPos - lenPattern + 1) ... bestPos
            let indices = Array(matchedRange)
            return MatchResult(
                score: Int(bestBonus) + lenPattern * Int(scoreMatch),
                matchedScalarIndices: indices
            )
        }
        return nil
    }

    private struct BoundaryMatchContext {
        let input: ScalarChars
        let index: Int
        let pidx: Int
        let lenPattern: Int
    }

    private struct BoundaryMatchState {
        var bonus: Int16 = 0
        var boundaryBonus: Int16 = 0
    }

    private static func acceptBoundaryMatch(
        boundary: Bool,
        context: BoundaryMatchContext,
        state: inout BoundaryMatchState
    ) -> Bool {
        if context.pidx == 0 {
            state.bonus = bonusAt(context.input, context.index)
        }
        guard boundary else { return true }

        if context.pidx == 0 {
            state.boundaryBonus = state.bonus
        }
        var ok = state.boundaryBonus >= bonusBoundary
        if ok, context.pidx == 0 {
            ok = context.index == 0
                || charClassOf(context.input.get(context.index - 1)).rawValue
                <= CharClass.delimiter.rawValue
        }
        if ok, context.pidx == context.lenPattern - 1 {
            ok = context.index == context.input.length - 1
                || charClassOf(context.input.get(context.index + 1)).rawValue
                <= CharClass.delimiter.rawValue
        }
        return ok
    }

    static func prefixMatch(
        caseSensitive: Bool,
        normalize: Bool,
        input: ScalarChars,
        pattern: [UInt32]
    ) -> MatchResult? {
        if pattern.isEmpty {
            return MatchResult(score: 0, matchedScalarIndices: [])
        }

        var trimmedLen = 0
        if let first = pattern.first, !isWhitespace(first) {
            trimmedLen = input.leadingWhitespaces()
        }

        if input.length - trimmedLen < pattern.count {
            return nil
        }

        for index in 0 ..< pattern.count {
            var char = input.get(trimmedLen + index)
            if !caseSensitive {
                char = lowercaseScalar(char)
            }
            if normalize {
                char = normalizeScalar(char)
            }
            if char != pattern[index] {
                return nil
            }
        }

        let sidx = trimmedLen
        let eidx = trimmedLen + pattern.count
        let scoreParams = ScoreParams(
            caseSensitive: caseSensitive,
            normalize: normalize,
            input: input,
            pattern: pattern
        )
        let score = calculateScore(params: scoreParams, start: sidx, end: eidx).score
        let positions = Array(sidx ..< eidx)
        return MatchResult(score: score, matchedScalarIndices: positions)
    }

    static func suffixMatch(
        caseSensitive: Bool,
        normalize: Bool,
        input: ScalarChars,
        pattern: [UInt32]
    ) -> MatchResult? {
        let lenRunes = input.length
        var trimmedLen = lenRunes
        if pattern.isEmpty || !isWhitespace(pattern.last ?? 0) {
            trimmedLen -= input.trailingWhitespaces()
        }

        if pattern.isEmpty {
            return MatchResult(score: 0, matchedScalarIndices: [])
        }

        let diff = trimmedLen - pattern.count
        if diff < 0 {
            return nil
        }

        for index in 0 ..< pattern.count {
            var char = input.get(index + diff)
            if !caseSensitive {
                char = lowercaseScalar(char)
            }
            if normalize {
                char = normalizeScalar(char)
            }
            if char != pattern[index] {
                return nil
            }
        }

        let sidx = trimmedLen - pattern.count
        let eidx = trimmedLen
        let scoreParams = ScoreParams(
            caseSensitive: caseSensitive,
            normalize: normalize,
            input: input,
            pattern: pattern
        )
        let score = calculateScore(params: scoreParams, start: sidx, end: eidx).score
        let positions = Array(sidx ..< eidx)
        return MatchResult(score: score, matchedScalarIndices: positions)
    }

    static func equalMatch(
        caseSensitive: Bool,
        normalize: Bool,
        input: ScalarChars,
        pattern: [UInt32]
    ) -> MatchResult? {
        let lenPattern = pattern.count
        if lenPattern == 0 {
            return nil
        }

        var trimmedStart = 0
        if let first = pattern.first, !isWhitespace(first) {
            trimmedStart = input.leadingWhitespaces()
        }

        var trimmedEnd = 0
        if let last = pattern.last, !isWhitespace(last) {
            trimmedEnd = input.trailingWhitespaces()
        }

        if input.length - trimmedStart - trimmedEnd != lenPattern {
            return nil
        }

        let runes = input.scalars
        var match = true
        for idx in 0 ..< lenPattern {
            let char = runes[idx + trimmedStart].value
            if !caseSensitive {
                if lowercaseScalar(pattern[idx]) != lowercaseScalar(char) {
                    match = false
                    break
                }
            } else if normalize {
                if normalizeScalar(pattern[idx]) != normalizeScalar(char) {
                    match = false
                    break
                }
            } else if char != pattern[idx] {
                match = false
                break
            }
        }

        if match {
            let score = (Int(scoreMatch) + Int(bonusBoundaryWhite)) * lenPattern
                + (Int(bonusFirstCharMultiplier) - 1) * Int(bonusBoundaryWhite)
            let sidx = trimmedStart
            let eidx = trimmedStart + lenPattern
            let positions = Array(sidx ..< eidx)
            return MatchResult(score: score, matchedScalarIndices: positions)
        }

        return nil
    }

    private static func calculateScore(
        params: ScoreParams,
        start: Int,
        end: Int
    ) -> (score: Int, positions: [Int]) {
        var pidx = 0
        var score = 0
        var inGap = false
        var consecutive = 0
        var firstBonus: Int16 = 0
        var positions: [Int] = []

        var prevClass = initialCharClass
        if start > 0 {
            prevClass = charClassOf(params.input.get(start - 1))
        }

        for idx in start ..< end {
            var char = params.input.get(idx)
            let charClass = charClassOf(char)
            if !params.caseSensitive {
                if char >= 65, char <= 90 {
                    char += 32
                } else if char > 127 {
                    char = lowercaseScalar(char)
                }
            }
            if params.normalize {
                char = normalizeScalar(char)
            }
            let pchar = params.pattern[pidx]

            if char == pchar {
                positions.append(idx)
                score += Int(scoreMatch)
                var bonus = bonusMatrix[prevClass.rawValue][charClass.rawValue]
                if consecutive == 0 {
                    firstBonus = bonus
                } else {
                    bonus = maxInt16(bonus, maxInt16(bonusConsecutive, firstBonus))
                }
                if pidx == 0 {
                    bonus *= bonusFirstCharMultiplier
                }
                score += Int(bonus)
                pidx += 1
                consecutive += 1
            } else {
                if inGap {
                    score += Int(scoreGapExtension)
                } else {
                    score += Int(scoreGapStart)
                    inGap = true
                }
                consecutive = 0
                firstBonus = 0
            }

            prevClass = charClass
        }

        return (score, positions)
    }

    private static func normalizeScalarForMatch(
        _ scalar: UInt32,
        caseSensitive: Bool,
        normalize: Bool
    ) -> UInt32 {
        var char = scalar
        if !caseSensitive {
            if char >= 65, char <= 90 {
                char += 32
            } else if char > 127 {
                char = lowercaseScalar(char)
            }
        }
        if normalize {
            char = normalizeScalar(char)
        }
        return char
    }

    // MARK: - Fast ASCII scan

    static func asciiFuzzyIndex(
        input: ScalarChars,
        pattern: [UInt32],
        caseSensitive: Bool
    ) -> (Int, Int) {
        if !input.isASCII {
            return (0, input.length)
        }
        if !pattern.allSatisfy({ $0 < 128 }) {
            return (-1, -1)
        }

        var firstIdx = 0
        var idx = 0
        var lastIdx = 0
        var b: UInt8 = 0

        for pidx in 0 ..< pattern.count {
            b = UInt8(pattern[pidx])
            idx = trySkip(bytes: input.bytes, caseSensitive: caseSensitive, byte: b, from: idx)
            if idx < 0 {
                return (-1, -1)
            }
            if pidx == 0, idx > 0 {
                firstIdx = idx - 1
            }
            lastIdx = idx
            idx += 1
        }

        var bu = b
        if !caseSensitive, b >= 97, b <= 122 {
            bu = b - 32
        }
        let scope = Array(input.bytes[lastIdx...])
        for offset in stride(from: scope.count - 1, through: 0, by: -1) {
            if scope[offset] == b || scope[offset] == bu {
                return (firstIdx, lastIdx + offset + 1)
            }
        }
        return (firstIdx, lastIdx + 1)
    }

    static func trySkip(
        bytes: [UInt8],
        caseSensitive: Bool,
        byte: UInt8,
        from: Int
    ) -> Int {
        if from >= bytes.count {
            return -1
        }
        let slice = bytes[from...]
        var idx = slice.firstIndex(of: byte)
        if idx == from {
            return from
        }
        if !caseSensitive, byte >= 97, byte <= 122 {
            let upper = byte - 32
            let searchEnd = idx ?? bytes.count
            if let uidx = bytes[from ..< searchEnd].firstIndex(of: upper) {
                idx = uidx
            }
        }
        guard let finalIdx = idx else { return -1 }
        return finalIdx
    }
}
