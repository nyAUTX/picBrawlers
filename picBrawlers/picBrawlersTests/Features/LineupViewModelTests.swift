import CoreGraphics
import Foundation
import Testing
@testable import picBrawlers

@MainActor
final class AnnouncerSpy: AccessibilityAnnouncing {
    private(set) var messages: [String] = []
    func announce(_ message: String) { messages.append(message) }
}

actor SleepRecorder {
    private(set) var durations: [Duration] = []
    func record(_ duration: Duration) { durations.append(duration) }
}

@Suite("Lineup view model")
@MainActor
struct LineupViewModelTests {
    private let announcer = AnnouncerSpy()
    private let recorder = SleepRecorder()

    private func makeViewModel(sleep: Sleeper? = nil) -> LineupViewModel {
        let recorder = recorder
        return LineupViewModel(
            cards: FighterCard.demoLineup,
            announcer: announcer,
            sleep: sleep ?? { duration in await recorder.record(duration) },
            now: { Date(timeIntervalSince1970: 0) }
        )
    }

    /// Reports the card frames a laid-out lineup would report.
    private func layOut(_ viewModel: LineupViewModel) {
        viewModel.updateLineupBounds(CGRect(x: 0, y: 0, width: 378, height: 300))
        for (index, card) in viewModel.cards.enumerated() {
            viewModel.updateFrame(CGRect(x: Double(index) * 134, y: 0, width: 110, height: 300), for: card.id)
        }
    }

    @Test func startsWithAllCardsFlat() {
        let viewModel = makeViewModel()
        #expect(viewModel.cards.count == 3)
        #expect(viewModel.cards.allSatisfy { !$0.isCrumpled })
        #expect(viewModel.ironing == nil)
    }

    @Test func everyCardHasItsOwnStableCrumpleSeed() {
        let first = makeViewModel().cards.map(\.crumpleSeed)
        let second = makeViewModel().cards.map(\.crumpleSeed)
        #expect(first == second)
        #expect(Set(first).count == 3)
    }

    @Test func aHitCrumplesTheFirstFlatCardAndAnnouncesIt() {
        let viewModel = makeViewModel()
        viewModel.crumpleNext()
        #expect(viewModel.cards.map(\.isCrumpled) == [true, false, false])
        #expect(announcer.messages == ["Oma Gerti ist zerknittert"])
    }

    @Test func whenEveryCardIsCrumpledAHitChangesNothing() {
        let viewModel = makeViewModel()
        viewModel.crumpleNext(); viewModel.crumpleNext(); viewModel.crumpleNext()
        viewModel.crumpleNext()
        #expect(viewModel.cards.allSatisfy { $0.isCrumpled })
        #expect(announcer.messages.count == 3)
    }

    @Test func twoCardsInOneTurnAreStaggered() async {
        let viewModel = makeViewModel()
        await viewModel.crumpleTwo()
        #expect(viewModel.cards.map(\.isCrumpled) == [true, true, false])
        #expect(await recorder.durations == [.milliseconds(120)])
        #expect(announcer.messages == ["Oma Gerti ist zerknittert", "Kevin ist zerknittert"])
    }

    @Test func ironingWalksTheIronOverOnlyTheCrumpledCards() async {
        let viewModel = makeViewModel()
        layOut(viewModel)
        viewModel.crumpleNext()
        viewModel.crumpleNext()
        viewModel.startIroning(reduceMotion: false)

        let session = try! #require(viewModel.ironing)
        #expect(session.itinerary.ironedCards == [0, 1])
        #expect(viewModel.isIroning)

        await viewModel.ironTask?.value
        #expect(viewModel.cards.allSatisfy { !$0.isCrumpled })
        #expect(viewModel.ironing == nil)
        // One wait until each card is done, one until the iron has left.
        #expect(await recorder.durations.count == 3)
        #expect(announcer.messages.last == "Alle Karten sind wieder glatt")
        #expect(announcer.messages.filter { $0 == "Alle Karten sind wieder glatt" }.count == 1)
    }

    @Test func withReduceMotionCardsFadeFlatWithoutAnIron() {
        let viewModel = makeViewModel()
        layOut(viewModel)
        viewModel.crumpleNext()
        viewModel.startIroning(reduceMotion: true)
        #expect(viewModel.ironing == nil)
        #expect(viewModel.cards.allSatisfy { !$0.isCrumpled })
        #expect(announcer.messages.last == "Alle Karten sind wieder glatt")
    }

    @Test func withoutALayoutCardsFadeFlatInstead() {
        let viewModel = makeViewModel()
        viewModel.crumpleNext()
        viewModel.startIroning(reduceMotion: false)
        #expect(viewModel.ironing == nil)
        #expect(viewModel.cards.allSatisfy { !$0.isCrumpled })
    }

    @Test func nothingCrumpledMeansNothingToIron() {
        let viewModel = makeViewModel()
        layOut(viewModel)
        viewModel.startIroning(reduceMotion: false)
        #expect(viewModel.ironing == nil)
        #expect(announcer.messages.isEmpty)
    }

    @Test func skippingFlattensEveryCardAtOnce() async {
        let viewModel = makeViewModel(sleep: { _ in try await Task.sleep(for: .seconds(3600)) })
        layOut(viewModel)
        viewModel.crumpleNext()
        viewModel.crumpleNext()
        viewModel.startIroning(reduceMotion: false)
        #expect(viewModel.isIroning)

        viewModel.skipIroning()
        #expect(viewModel.ironing == nil)
        #expect(viewModel.cards.allSatisfy { !$0.isCrumpled })
        #expect(announcer.messages.last == "Alle Karten sind wieder glatt")
        await viewModel.ironTask?.value
        #expect(announcer.messages.filter { $0 == "Alle Karten sind wieder glatt" }.count == 1)
    }

    @Test func aCardCrumpledWhileTheIronRunsStaysCrumpled() async {
        let viewModel = makeViewModel(sleep: { _ in try await Task.sleep(for: .seconds(3600)) })
        layOut(viewModel)
        viewModel.crumpleNext()
        viewModel.startIroning(reduceMotion: false)
        viewModel.crumpleNext()               // Kevin, not part of this pass
        viewModel.skipIroning()
        #expect(viewModel.cards.map(\.isCrumpled) == [false, true, false])
    }
}

@Suite("Fighter card accessibility")
struct FighterCardAccessibilityTests {
    @Test func voiceOverReadsTheWholeCardAsOneSentence() {
        let oma = FighterCard.demoLineup[0]
        #expect(oma.accessibilityLabel(isCrumpled: false)
            == "Oma Gerti, Tank, 150 Leben, 15 Schaden, Angriff: Gulaschkanone, Spezialfähigkeit: Kittelschürze")
    }

    @Test func aCrumpledCardSaysSo() {
        let bello = FighterCard.demoLineup[2]
        #expect(bello.accessibilityLabel(isCrumpled: true)
            == "Bello, Support, 110 Leben, 20 Schaden, Angriff: Kampfhund, Spezialfähigkeit: Stoßlüften, zerknittert")
    }

    @Test func thePhotoDescriptionIsReadWhenThereIsOne() {
        var oma = FighterCard.demoLineup[0]
        oma.photoDescription = "Frau mit Kochlöffel"
        #expect(oma.accessibilityLabel(isCrumpled: false).hasSuffix("Spezialfähigkeit: Kittelschürze, Foto: Frau mit Kochlöffel"))
    }

    @Test(arguments: [(CardCategory.tank, "Tank"), (.damageDealer, "Damage Dealer"), (.support, "Support")])
    func categoriesHaveTheirGermanNames(category: CardCategory, title: String) {
        #expect(category.title == title)
    }
}
