import Foundation
import Testing
@testable import picBrawlers

@Suite("Stat roll")
struct StatRollerTests {
    @Test(arguments: CardCategory.allCases)
    func rolledStatsStayInsideTheCategoryRanges(category: CardCategory) {
        for seed in UInt64(0)..<200 {
            var generator = SeededGenerator(seed: seed)
            let stats = StatRoller.roll(for: category, using: &generator)
            #expect(category.healthRange.contains(stats.health))
            #expect(category.damageRange.contains(stats.damage))
        }
    }

    @Test func theSameSeedRollsTheSameStats() {
        var first = SeededGenerator(seed: 42)
        var second = SeededGenerator(seed: 42)
        #expect(StatRoller.roll(for: .tank, using: &first) == StatRoller.roll(for: .tank, using: &second))
    }

    @Test func differentSeedsRollDifferentStats() {
        let rolls = (UInt64(0)..<20).map { seed in
            var generator = SeededGenerator(seed: seed)
            return StatRoller.roll(for: .damageDealer, using: &generator)
        }
        #expect(Set(rolls).count > 1)
    }

    @Test func rangesMatchThePlan() {
        #expect(CardCategory.tank.healthRange == 130...170)
        #expect(CardCategory.tank.damageRange == 10...20)
        #expect(CardCategory.damageDealer.healthRange == 60...90)
        #expect(CardCategory.damageDealer.damageRange == 30...45)
        #expect(CardCategory.support.healthRange == 90...110)
        #expect(CardCategory.support.damageRange == 12...22)
    }
}

@Suite("Special effects")
struct SpecialEffectTests {
    @Test func eachCategoryAllowsItsOwnEffects() {
        #expect(CardCategory.tank.allowedEffects == [.taunt, .shield])
        #expect(CardCategory.damageDealer.allowedEffects == [.burst, .dot])
        #expect(CardCategory.support.allowedEffects == [.heal, .shield, .buff])
    }

    @Test func everyEffectBelongsToAtLeastOneCategory() {
        let allowed = Set(CardCategory.allCases.flatMap(\.allowedEffects))
        #expect(allowed == Set(SpecialEffect.allCases))
    }
}

@Suite("Card name")
struct CardNameTests {
    @Test func trimsAndCollapsesWhitespace() {
        #expect(CardName.normalized("  Oma   Gerti \n") == "Oma Gerti")
    }

    @Test(arguments: ["", "   ", "\n\t"])
    func emptyNamesAreRejected(name: String) {
        #expect(CardName.issue(for: name) == .empty)
    }

    @Test func namesUpToTheLimitAreFine() {
        let name = String(repeating: "a", count: CardName.maxLength)
        #expect(CardName.issue(for: name) == nil)
        #expect(CardName.issue(for: "Oma Gerti") == nil)
    }

    @Test func longerNamesAreRejected() {
        let name = String(repeating: "a", count: CardName.maxLength + 1)
        #expect(CardName.issue(for: name) == .tooLong)
    }

    @Test func surroundingSpacesDontCountTowardsTheLimit() {
        let name = "  " + String(repeating: "a", count: CardName.maxLength) + "  "
        #expect(CardName.issue(for: name) == nil)
    }
}

@Suite("Card factory")
struct CardFactoryTests {
    private let id = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
    private let date = Date(timeIntervalSince1970: 1_000)

    private func text(effect: SpecialEffect, weaknesses: [String] = ["Spritpreis"]) -> CardText {
        CardText(
            attack: .init(name: " Gulaschkanone ", description: "Heiß."),
            special: .init(name: "Kittelschürze", description: "Hält dicht.", effect: effect),
            weaknesses: weaknesses,
            photoDescription: "Frau mit Kochlöffel"
        )
    }

    private func make(category: CardCategory = .tank, text: CardText, seed: UInt64 = 7) -> FighterCard {
        var generator = SeededGenerator(seed: seed)
        return CardFactory.makeCard(
            id: id, name: "  Oma  Gerti ", category: category, text: text,
            imageData: Data([1, 2, 3]), playerID: "player-1", createdAt: date, using: &generator
        )
    }

    @Test func buildsACardWithRolledStatsAndTheAIText() {
        let card = make(text: text(effect: .shield))
        var generator = SeededGenerator(seed: 7)
        #expect(card.stats == StatRoller.roll(for: .tank, using: &generator))
        #expect(card.id == id)
        #expect(card.name == "Oma Gerti")
        #expect(card.attack.name == "Gulaschkanone")
        #expect(card.special.effect == .shield)
        #expect(card.weaknesses == ["Spritpreis"])
        #expect(card.photoDescription == "Frau mit Kochlöffel")
        #expect(card.imageData == Data([1, 2, 3]))
        #expect(card.createdAt == date)
    }

    @Test func theCreatorStartsAsTheOwner() {
        let card = make(text: text(effect: .shield))
        #expect(card.creatorID == "player-1")
        #expect(card.ownerID == "player-1")
    }

    @Test func anEffectTheCategoryDoesntAllowIsReplaced() {
        let card = make(category: .tank, text: text(effect: .heal))
        #expect(card.special.effect == CardCategory.tank.allowedEffects[0])
    }

    @Test func keepsAtMostThreeNonEmptyWeaknesses() {
        let card = make(text: text(effect: .taunt, weaknesses: ["Spritpreis", " ", "Schlagloch", "Radfahrer", "Funkloch"]))
        #expect(card.weaknesses == ["Spritpreis", "Schlagloch", "Radfahrer"])
    }
}
