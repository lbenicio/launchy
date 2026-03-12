import Foundation

extension String {
    /// Attempts to fuzzy-match `query` against this string.
    ///
    /// Returns an optional `Double` score:
    /// - `nil` means no match at all (not every query character was found in order).
    /// - A higher score indicates a better match.
    ///
    /// Scoring tiers:
    /// 1. **Exact substring** (`localizedStandardContains`): base score of `100`,
    ///    boosted further if the match is a prefix.
    /// 2. **Fuzzy ordered-character match**: score between `0` and `< 100`, based on
    ///    how tightly the matched characters cluster together.
    func fuzzyMatch(_ query: String) -> Double? {
        let normalizedTarget = self.lowercased()
        let normalizedQuery = query.lowercased()

        guard !normalizedQuery.isEmpty else { return nil }

        // --- Tier 1: Standard substring / locale-aware contains ---
        if self.localizedStandardContains(query) {
            var score: Double = 100.0

            // Bonus for prefix match
            if normalizedTarget.hasPrefix(normalizedQuery) {
                score += 25.0
            }

            // Bonus for exact (full-string) match
            if normalizedTarget == normalizedQuery {
                score += 25.0
            }

            // Bonus for shorter targets (more relevant when query covers more of the string)
            let coverage = Double(normalizedQuery.count) / Double(max(normalizedTarget.count, 1))
            score += coverage * 10.0

            return score
        }

        // --- Tier 2: Fuzzy ordered-character match ---
        // Every character in the query must appear in the target in order,
        // but not necessarily contiguously.
        let targetChars = Array(normalizedTarget)
        let queryChars = Array(normalizedQuery)

        var targetIndex = 0
        var matchedIndices: [Int] = []
        matchedIndices.reserveCapacity(queryChars.count)

        for queryChar in queryChars {
            var found = false
            while targetIndex < targetChars.count {
                if targetChars[targetIndex] == queryChar {
                    matchedIndices.append(targetIndex)
                    targetIndex += 1
                    found = true
                    break
                }
                targetIndex += 1
            }
            if !found {
                return nil  // Not all query characters found in order
            }
        }

        guard let firstMatch = matchedIndices.first, let lastMatch = matchedIndices.last else {
            return nil
        }

        // The span of matched characters in the target (smaller span = tighter cluster = better).
        let span = lastMatch - firstMatch + 1
        let queryLength = queryChars.count

        // Closeness: ratio of query length to the span it covers (1.0 = perfectly contiguous).
        let closeness = Double(queryLength) / Double(max(span, 1))

        // Coverage: how much of the target string the query touches.
        let coverage = Double(queryLength) / Double(max(targetChars.count, 1))

        // Bonus for matching at the very start of the string.
        let prefixBonus: Double = (firstMatch == 0) ? 0.1 : 0.0

        // Combine into a score in the range (0, 100).
        // Closeness is the dominant factor; coverage and prefix are secondary.
        let score =
            (closeness * 60.0 + coverage * 25.0 + prefixBonus * 15.0)
            * 0.99  // Ensure it stays strictly below 100

        return score
    }
}
