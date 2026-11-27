import Foundation
import Testing
@testable import picBrawlers

@MainActor
final class FakeMatchTransport: MatchTransport {
    let localSides: Set<MatchSide>
    let incoming: AsyncStream<MatchMessage>
    private let continuation: AsyncStream<MatchMessage>.Continuation
    private(set) var sent: [MatchMessage] = []
    var failure: (any Error)?

    init(localSides: Set<MatchSide>) {
        self.localSides = localSides
        (incoming, continuation) = AsyncStream.makeStream()
    }

    func send(_ message: MatchMessage) async throws {
        if let failure { throw failure }
        sent.append(message)
    }

    func deliver(_ message: MatchMessage) { continuation.yield(message) }
}

@MainActor
final class HapticsSpy: HapticsService {
    private(set) var events: [HapticEvent] = []
    func play(_ event: HapticEvent) { events.append(event) }
}

@Suite("Fight view model")
@MainActor
struct FightViewModelTests {
    private let fixture = FightFixture(hostTank: .shield)
    private let haptics = HapticsSpy()
    private let announcer = AnnouncerSpy()

    private func makeViewModel(
        localSides: Set<MatchSide> = [.host, .guest],
        first: MatchSide = .host,
        state: MatchState? = nil
    ) throws -> (FightViewModel, FakeMatchTransport) {
        let transport = FakeMatchTransport(localSides: localSides)
        let viewModel = FightViewModel(
            state: try state ?? fixture.start(first: first),
            cards: fixture.hostCards + fixture.guestCards,
            playerNames: [.host: "Anna", .guest: "Ben"],
            transport: transport,
            haptics: haptics,
            announcer: announcer,
            turnSeconds: 30,
            // The timer never fires on its own; tests call `tick()`.
            sleep: { _ in try await Task.sleep(for: .seconds(3600)) }
        )
        return (viewModel, transport)
    }

    /// Picks the host's two default attacks on the guest's support.
    private func chooseTwoAttacks(_ viewModel: FightViewModel) {
        viewModel.select(fixture.hostDealer)
        viewModel.choose(.attack)
        viewModel.target(guest(fixture.guestSupport))
        viewModel.select(fixture.hostSupport)
        viewModel.choose(.attack)
        viewModel.target(guest(fixture.guestSupport))
    }

    // MARK: Starting

    @Test func passAndPlayCoversTheBoardUntilTheFirstPlayerIsReady() throws {
        let (viewModel, _) = try makeViewModel(first: .guest)
        #expect(viewModel.phase == .handover(.guest))

        viewModel.beginTurn()
        #expect(viewModel.phase == .choosing)
        #expect(viewModel.remainingSeconds == 30)
        #expect(viewModel.perspective == .guest)
    }

    @Test func aRealFightStartsWithChoosingOrWaiting() throws {
        #expect(try makeViewModel(localSides: [.host]).0.phase == .choosing)
        #expect(try makeViewModel(localSides: [.guest]).0.phase == .waiting)
        #expect(try makeViewModel(localSides: [.guest]).0.perspective == .guest)
    }

    @Test func assistiveTechnologyDoublesTheTurnTime() {
        #expect(FightViewModel.turnSeconds(usesAssistiveTechnology: false) == 30)
        #expect(FightViewModel.turnSeconds(usesAssistiveTechnology: true) == 60)
    }

    // MARK: Choosing

    @Test func choosingACardAMoveAndATargetAddsAnAction() throws {
        let (viewModel, _) = try makeViewModel(localSides: [.host])
        viewModel.select(fixture.hostDealer)
        #expect(viewModel.selectedActor == fixture.hostDealer)
        viewModel.choose(.attack)
        #expect(Set(viewModel.legalTargets) == [guest(fixture.guestTank), guest(fixture.guestDealer), guest(fixture.guestSupport)])

        viewModel.target(guest(fixture.guestTank))
        #expect(viewModel.pending == [attack(fixture.hostDealer, guest(fixture.guestTank))])
        #expect(viewModel.selectedActor == nil)
        #expect(haptics.events == [.selection, .selection])
    }

    @Test func aSelfOnlySpecialIsAddedWithoutATarget() throws {
        let (viewModel, _) = try makeViewModel(localSides: [.host])
        viewModel.select(fixture.hostTank)
        viewModel.choose(.special)
        #expect(viewModel.pending == [special(fixture.hostTank, host(fixture.hostTank))])
    }

    @Test func enemyCrumpledAndUsedCardsCannotBeSelected() throws {
        var state = try fixture.start()
        state.setHealth(0, of: host(fixture.hostSupport))
        let (viewModel, _) = try makeViewModel(localSides: [.host], state: state)

        viewModel.select(fixture.guestTank)
        viewModel.select(fixture.hostSupport)
        #expect(viewModel.selectedActor == nil)

        viewModel.select(fixture.hostDealer)
        viewModel.choose(.attack)
        viewModel.target(guest(fixture.guestTank))
        viewModel.select(fixture.hostDealer)
        #expect(viewModel.selectedActor == nil)
        #expect(haptics.events.filter { $0 == .invalidAction }.count == 3)
    }

    @Test func anIllegalTargetIsRefused() throws {
        let (viewModel, _) = try makeViewModel(localSides: [.host])
        viewModel.select(fixture.hostDealer)
        viewModel.choose(.attack)
        viewModel.target(host(fixture.hostSupport))
        #expect(viewModel.pending.isEmpty)
        #expect(haptics.events.last == .invalidAction)
    }

    @Test func aSpecialThatIsRechargingIsRefused() throws {
        var state = try fixture.start()
        state.update(host(fixture.hostDealer)) { $0.specialReadyIn = 1 }
        let (viewModel, _) = try makeViewModel(localSides: [.host], state: state)
        viewModel.select(fixture.hostDealer)
        viewModel.choose(.special)
        #expect(viewModel.selectedMove == nil)
        #expect(haptics.events.last == .invalidAction)
    }

    @Test func aChosenActionCanBeTakenBack() throws {
        let (viewModel, _) = try makeViewModel(localSides: [.host])
        chooseTwoAttacks(viewModel)
        #expect(viewModel.canSubmit)
        viewModel.removeAction(at: 0)
        #expect(viewModel.pending.map(\.actor) == [fixture.hostSupport])
        #expect(!viewModel.canSubmit)
    }

    // MARK: Playing

    @Test func submittingPlaysBothActionsAndSendsTheTurn() async throws {
        let (viewModel, transport) = try makeViewModel(localSides: [.host])
        chooseTwoAttacks(viewModel)
        await viewModel.submitTurn()

        #expect(viewModel.state.health(guest(fixture.guestSupport)) == 100 - 40 - 20)
        #expect(viewModel.pending.isEmpty)
        #expect(viewModel.phase == .reviewing)
        #expect(!viewModel.log.isEmpty)
        #expect(haptics.events.last == .hit)
        #expect(transport.sent == [.turn(
            number: 1,
            actions: [attack(fixture.hostDealer, guest(fixture.guestSupport)), attack(fixture.hostSupport, guest(fixture.guestSupport))],
            stateHash: viewModel.state.stateHash
        )])
    }

    @Test func afterTheReviewTheNextPlayerGetsThePhone() async throws {
        let (viewModel, _) = try makeViewModel()
        viewModel.beginTurn()
        chooseTwoAttacks(viewModel)
        await viewModel.submitTurn()
        #expect(viewModel.perspective == .host) // the board doesn't flip during the review
        viewModel.continueAfterReview()
        #expect(viewModel.phase == .handover(.guest))
        viewModel.beginTurn()
        #expect(viewModel.perspective == .guest)
    }

    @Test func inARealFightTheOpponentsTurnIsAwaited() async throws {
        let (viewModel, _) = try makeViewModel(localSides: [.host])
        chooseTwoAttacks(viewModel)
        await viewModel.submitTurn()
        viewModel.continueAfterReview()
        #expect(viewModel.phase == .waiting)
    }

    @Test func aFailedSendShowsAnError() async throws {
        let (viewModel, transport) = try makeViewModel(localSides: [.host])
        transport.failure = URLError(.networkConnectionLost)
        chooseTwoAttacks(viewModel)
        await viewModel.submitTurn()
        #expect(viewModel.phase == .failed(AppError(title: String(localized: "Zug konnte nicht gesendet werden"), cause: .offline)))
    }

    // MARK: Timer

    @Test func theTimerCountsDownAndWarnsBeforeTimeRunsOut() async throws {
        let (viewModel, _) = try makeViewModel(localSides: [.host])
        for _ in 1...20 { await viewModel.tick() }
        #expect(viewModel.remainingSeconds == 10)
        #expect(announcer.messages.last == String(localized: "Noch 10 Sekunden"))

        for _ in 1...5 { await viewModel.tick() }
        #expect(announcer.messages.last == String(localized: "Noch 5 Sekunden"))
        #expect(haptics.events.last == .invalidAction)
    }

    @Test func runningOutOfTimeSkipsTheTurn() async throws {
        let (viewModel, transport) = try makeViewModel(localSides: [.host])
        viewModel.select(fixture.hostDealer)
        for _ in 1...30 { await viewModel.tick() }

        #expect(viewModel.state.activeSide == .guest)
        #expect(viewModel.state[.host].skippedTurns == 1)
        #expect(viewModel.selectedActor == nil)
        #expect(viewModel.phase == .reviewing)
        #expect(transport.sent == [.timeout(number: 1, stateHash: viewModel.state.stateHash)])
    }

    @Test func theTimerOnlyRunsWhileChoosing() async throws {
        let (viewModel, _) = try makeViewModel()
        await viewModel.tick()
        #expect(viewModel.remainingSeconds == 30)
    }

    // MARK: End

    @Test func winningShowsTheResultAfterTheReview() async throws {
        var state = try fixture.start()
        state.setHealth(0, of: guest(fixture.guestTank))
        state.setHealth(0, of: guest(fixture.guestDealer))
        state.setHealth(10, of: guest(fixture.guestSupport))
        let (viewModel, _) = try makeViewModel(localSides: [.host], state: state)

        viewModel.select(fixture.hostDealer)
        viewModel.choose(.attack)
        viewModel.target(guest(fixture.guestSupport))
        #expect(viewModel.canSubmit)
        await viewModel.submitTurn()
        viewModel.continueAfterReview()

        guard case .finished(let result) = viewModel.phase else {
            Issue.record("Expected the finished phase, got \(viewModel.phase)")
            return
        }
        #expect(result.winner == .host)
        #expect(result.stakedCardID == fixture.guestDealer)
        #expect(haptics.events.last == .success)
    }

    @Test func resigningEndsTheFightForTheOpponent() async throws {
        let (viewModel, transport) = try makeViewModel(localSides: [.host])
        await viewModel.resign()
        guard case .finished(let result) = viewModel.phase else {
            Issue.record("Expected the finished phase")
            return
        }
        #expect(result.winner == .guest)
        #expect(transport.sent == [.resign(.host)])
        #expect(haptics.events.last == .failure)
    }

    @Test func ironingFlattensEveryCard() async throws {
        let (viewModel, _) = try makeViewModel(localSides: [.host])
        chooseTwoAttacks(viewModel)
        await viewModel.submitTurn()
        viewModel.iron()
        #expect(!viewModel.isIroned) // not while the fight is running

        await viewModel.resign()
        viewModel.iron()
        #expect(viewModel.state.health(guest(fixture.guestSupport)) == 100)
        #expect(viewModel.isIroned)
    }

    // MARK: Receiving

    @Test func aReceivedTurnIsAppliedWhenTheHashesMatch() async throws {
        let (viewModel, _) = try makeViewModel(localSides: [.guest])
        let actions = [attack(fixture.hostDealer, guest(fixture.guestTank)), attack(fixture.hostSupport, guest(fixture.guestTank))]
        let expected = try FightEngine.play(actions, in: viewModel.state).state

        viewModel.receive(.turn(number: 1, actions: actions, stateHash: expected.stateHash))
        #expect(viewModel.state == expected)
        #expect(viewModel.phase == .reviewing)
        viewModel.continueAfterReview()
        #expect(viewModel.phase == .choosing)
    }

    @Test func aDifferentHashStopsTheFight() throws {
        let (viewModel, _) = try makeViewModel(localSides: [.guest])
        let actions = [attack(fixture.hostDealer, guest(fixture.guestTank)), attack(fixture.hostSupport, guest(fixture.guestTank))]
        viewModel.receive(.turn(number: 1, actions: actions, stateHash: "manipuliert"))
        #expect(viewModel.phase == .failed(AppError(title: String(localized: "Kampf abgebrochen"), cause: .outOfSync)))
    }

    @Test func aTurnForTheLocalSideIsIgnored() throws {
        let (viewModel, _) = try makeViewModel(localSides: [.host])
        let before = viewModel.state
        viewModel.receive(.resign(.host))
        #expect(viewModel.state == before)
        #expect(viewModel.phase == .choosing)
    }

    // MARK: Texts

    @Test func eventsReadAsGermanSentences() throws {
        let (viewModel, _) = try makeViewModel()
        let names = viewModel.cards
        let tank = guest(fixture.guestTank)
        #expect(MatchEvent.crumpled(tank).text(names: names) == "\(names[fixture.guestTank]!.name) ist zerknittert")
        #expect(MatchEvent.hit(tank, cause: .attack, healthLost: 15, absorbed: 0).text(names: names)
            == "\(names[fixture.guestTank]!.name) verliert 15 Leben")
        #expect(MatchEvent.hit(tank, cause: .attack, healthLost: 5, absorbed: 10).text(names: names)
            == "\(names[fixture.guestTank]!.name) verliert 5 Leben, der Schild fängt 10 ab")
        #expect(MatchEvent.turnStarted(.guest, turn: 2).text(names: names) == nil)
    }
}
