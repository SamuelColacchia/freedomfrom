import Foundation
import Testing

@testable import FreedomFromKit

@Suite("A category is counted as a category, never as an app")
struct ChosenTargetsTests {
    @Test("apps alone read as apps")
    func appsOnly() {
        #expect(ChosenTargets(apps: 3).words == "3 apps")
        #expect(ChosenTargets(apps: 1).words == "1 app")
    }

    // The bug this suite exists for: picking a whole category in the system
    // picker leaves `applicationTokens` empty and puts one token in
    // `categoryTokens`, so a flattened count said "1 app" for a set that
    // shields a dozen.
    @Test("a whole category is one category, and never one app")
    func categoryIsNotAnApp() {
        let chosen = ChosenTargets(categories: 1)
        #expect(chosen.picked == 1)
        #expect(chosen.words == "1 category")
        #expect(!chosen.words.contains("app"))
    }

    @Test("categories and apps are named apart, not summed into one noun")
    func mixed() {
        #expect(ChosenTargets(apps: 2, categories: 1).words == "2 apps and 1 category")
        #expect(ChosenTargets(apps: 1, categories: 2).words == "1 app and 2 categories")
    }

    @Test("websites join the sentence without displacing either")
    func withDomains() {
        #expect(ChosenTargets(apps: 2).words(alsoDomains: 1) == "2 apps and 1 website")
        #expect(
            ChosenTargets(apps: 2, categories: 1).words(alsoDomains: 2)
                == "2 apps, 1 category and 2 websites"
        )
        #expect(ChosenTargets(categories: 1).words(alsoDomains: 1) == "1 category and 1 website")
    }

    @Test("a kind with nothing in it is not mentioned at all")
    func zeroesAreSilent() {
        #expect(ChosenTargets(apps: 0, categories: 2).words == "2 categories")
        #expect(ChosenTargets(apps: 2, categories: 0).words(alsoDomains: 0) == "2 apps")
    }

    // `picked` is what the big number on Targets shows and what coverage counts,
    // because each token is one thing the store is told to shield. It is the
    // *noun* that was wrong, not the arithmetic.
    @Test("picked counts every token the picker minted, of either kind")
    func pickedCountsBothKinds() {
        #expect(ChosenTargets(apps: 2, categories: 1).picked == 3)
        #expect(ChosenTargets().picked == 0)
        #expect(ChosenTargets().isEmpty)
        #expect(!ChosenTargets(categories: 1).isEmpty)
    }

    @Test("an empty set says nothing rather than saying nothing chosen")
    func emptyIsEmptyString() {
        #expect(ChosenTargets().words.isEmpty)
        #expect(ChosenTargets().words(alsoDomains: 0).isEmpty)
    }
}
