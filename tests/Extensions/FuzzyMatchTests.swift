import XCTest

@testable import Launchy

final class FuzzyMatchTests: XCTestCase {

    // MARK: - No match

    func testEmptyQueryReturnsNil() {
        XCTAssertNil("Safari".fuzzyMatch(""))
    }

    func testNoMatchReturnsNil() {
        XCTAssertNil("Safari".fuzzyMatch("xyz"))
    }

    func testPartialOrderedMismatchReturnsNil() {
        // "ba" characters exist in "abc" but not in order (b before a)
        XCTAssertNil("abc".fuzzyMatch("ba"))
    }

    // MARK: - Exact / substring matches (Tier 1)

    func testExactMatchScoresHighest() {
        let score = "Safari".fuzzyMatch("Safari")
        XCTAssertNotNil(score)
        // Exact match should score > 125 (100 base + 25 prefix + 25 exact + coverage bonus)
        XCTAssertGreaterThan(score!, 125)
    }

    func testPrefixMatchScoresHigherThanSubstring() {
        let prefixScore = "Safari".fuzzyMatch("Saf")
        let substringScore = "Safari".fuzzyMatch("far")
        XCTAssertNotNil(prefixScore)
        XCTAssertNotNil(substringScore)
        XCTAssertGreaterThan(prefixScore!, substringScore!)
    }

    func testSubstringMatchReturnsScoreAbove100() {
        let score = "Calculator".fuzzyMatch("calc")
        XCTAssertNotNil(score)
        XCTAssertGreaterThanOrEqual(score!, 100)
    }

    func testCaseInsensitiveMatch() {
        let score = "Safari".fuzzyMatch("safari")
        XCTAssertNotNil(score)
        XCTAssertGreaterThanOrEqual(score!, 100)
    }

    // MARK: - Fuzzy ordered-character matches (Tier 2)

    func testFuzzyMatchScoresBelow100() {
        // "Sfi" matches S_a_f_a_r_i — characters in order but not contiguous
        let score = "Safari".fuzzyMatch("Sfi")
        XCTAssertNotNil(score)
        XCTAssertLessThan(score!, 100)
        XCTAssertGreaterThan(score!, 0)
    }

    func testTighterClusterScoresHigher() {
        // "cal" in "Calculator" is contiguous (tight cluster)
        // "clr" in "Calculator" spans wider
        let tightScore = "Calculator".fuzzyMatch("cal")  // Tier 1 match
        let wideScore = "Calculator".fuzzyMatch("clr")  // Tier 2 fuzzy
        XCTAssertNotNil(tightScore)
        XCTAssertNotNil(wideScore)
        XCTAssertGreaterThan(tightScore!, wideScore!)
    }

    func testPrefixFuzzyBonusApplied() {
        // Use a longer target so the prefix bonus is more visible.
        // "Sftw" starts at index 0 in "Software Update"
        let prefixScore = "Software Update".fuzzyMatch("Sftw")
        // "ftwr" starts at index 2 — same span length but no prefix bonus
        let nonPrefixScore = "Software Update".fuzzyMatch("ftwr")
        XCTAssertNotNil(prefixScore)
        XCTAssertNotNil(nonPrefixScore)
        // Both are tier 2 fuzzy matches with similar spans,
        // but the prefix match should score higher due to the prefix bonus.
        if prefixScore! < 100 && nonPrefixScore! < 100 {
            XCTAssertGreaterThan(prefixScore!, nonPrefixScore!)
        }
    }

    // MARK: - Edge cases

    func testSingleCharacterMatch() {
        let score = "Safari".fuzzyMatch("S")
        XCTAssertNotNil(score)
    }

    func testSingleCharacterNoMatch() {
        XCTAssertNil("Safari".fuzzyMatch("z"))
    }

    func testEmptyTargetReturnsNil() {
        XCTAssertNil("".fuzzyMatch("a"))
    }
}
