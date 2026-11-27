import Foundation
import Observation
import OSLog

/// A running fight on this phone: the player picks two actions, they play out together, then the turn
/// passes. In pass-and-play (debug builds only) both players share the phone and hand it over.
@Observable
final class FightViewModel: Identifiable {
    enum Phase: Equatable {
        /// Pass-and-play: the board is covered until this side's player has the phone.
        case handover(MatchSide)
        /// A player on this phone picks actions; the turn timer runs.
        case choosing
        /// The opponent plays their turn on the other phone.
        case waiting
        /// The turn that just played, shown in the log until the player continues.
        case reviewing
        case finished(MatchResult)
        case failed(AppError)
    }

    private(set) var state: MatchState
    private(set) var phase: Phase
    /// The actions picked so far this turn, in the order they will play.
    private(set) var pending: [FightAction] = []
    private(set) var selectedActor: UUID?
    private(set) var selectedMove: FightAction.Move?
    private(set) var remainingSeconds: Int
    /// What happened in the last turn, as sentences.
    private(set) var log: [String] = []
    private(set) var isIroned = false
    /// The side shown at the bottom: the player holding the phone. In pass-and-play it changes only
    /// when the next player takes over, so the board doesn't flip while the last turn is reviewed.
    private(set) var perspective: MatchSide

    let cards: [UUID: FighterCard]
    let playerNames: [MatchSide: String]
    let turnSeconds: Int

    private let transport: any MatchTransport
    private let haptics: any HapticsService
    private let announcer: any AccessibilityAnnouncing
    private let sleep: Sleeper
    private var timerTask: Task<Void, Never>?

    private static let logger = Logger(subsystem: "at.fhooe.picBrawlers", category: "Fight")
    /// Seconds left at which VoiceOver announces the time.
    private static let announcedSeconds: Set<Int> = [10, 5]
    private static let warningSeconds = 5

    init(
        state: MatchState,
        cards: [FighterCard],
        playerNames: [MatchSide: String],
        transport: any MatchTransport,
        haptics: any HapticsService,
        announcer: any AccessibilityAnnouncing,
        turnSeconds: Int,
        sleep: @escaping Sleeper = { try await Task.sleep(for: $0) }
    ) {
        self.state = state
        self.cards = Dictionary(cards.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        self.playerNames = playerNames
        self.transport = transport
        self.haptics = haptics
        self.announcer = announcer
        self.turnSeconds = turnSeconds
        self.sleep = sleep
        remainingSeconds = turnSeconds
        perspective = transport.localSides.count > 1 ? state.activeSide : transport.localSides.first ?? .host
        phase = .waiting
        phase = phaseForCurrentTurn()
        if phase == .choosing { startTimer() }
    }

    /// VoiceOver and Switch Control users get twice the time; a fixed 30 seconds would shut them out.
    static func turnSeconds(usesAssistiveTechnology: Bool) -> Int {
        let duration = usesAssistiveTechnology ? FightRules.assistedTurnDuration : FightRules.turnDuration
        return Int(duration.components.seconds)
    }

    // MARK: Reading

    var isPassAndPlay: Bool { transport.localSides.count > 1 }

    func name(of side: MatchSide) -> String { playerNames[side] ?? "" }

    /// Where the chosen move may go. Empty until a card and a move are picked.
    var legalTargets: [FighterRef] {
        guard let selectedActor, let selectedMove else { return [] }
        return FightEngine.legalTargets(for: selectedActor, move: selectedMove, in: state)
    }

    /// Whether a card of the active side can still act this turn.
    func canAct(_ cardID: UUID) -> Bool {
        guard phase == .choosing, !isTurnDecided,
              let ref = state.ref(of: cardID), ref.side == state.activeSide,
              let fighter = state.fighter(ref), !fighter.isCrumpled
        else { return false }
        return !pending.contains { $0.actor == cardID }
    }

    /// The picked actions make a complete turn (or win the fight before the second one).
    var canSubmit: Bool {
        phase == .choosing && !pending.isEmpty && (try? FightEngine.play(pending, in: state)) != nil
    }

    /// The picked actions already win the fight, so no more can be added.
    private var isTurnDecided: Bool {
        guard !pending.isEmpty, let result = try? FightEngine.play(pending, in: state) else { return false }
        return result.state.isOver
    }

    // MARK: Choosing

    func select(_ cardID: UUID) {
        guard canAct(cardID), pending.count < state.requiredActionCount else {
            haptics.play(.invalidAction)
            return
        }
        selectedActor = cardID
        selectedMove = nil
        haptics.play(.selection)
    }

    func choose(_ move: FightAction.Move) {
        guard let selectedActor else { return }
        let targets = FightEngine.legalTargets(for: selectedActor, move: move, in: state)
        guard !targets.isEmpty else {
            haptics.play(.invalidAction)
            return
        }
        selectedMove = move
        // A self-only special (taunt, a tank's shield) has nothing to aim at.
        if targets == [state.ref(of: selectedActor)] {
            add(FightAction(actor: selectedActor, move: move, target: targets[0]))
        }
    }

    func target(_ ref: FighterRef) {
        guard let selectedActor, let selectedMove, legalTargets.contains(ref) else {
            haptics.play(.invalidAction)
            return
        }
        add(FightAction(actor: selectedActor, move: selectedMove, target: ref))
    }

    /// A tap on any card: a target while a move waits for one, otherwise picking the card to act.
    func tap(_ ref: FighterRef) {
        if selectedMove != nil {
            target(ref)
        } else {
            select(ref.cardID)
        }
    }

    /// Picks a card and its move in one go, as the VoiceOver actions on a card do.
    func choose(_ move: FightAction.Move, for cardID: UUID) {
        select(cardID)
        guard selectedActor == cardID else { return }
        choose(move)
    }

    func cancelSelection() {
        selectedActor = nil
        selectedMove = nil
    }

    func removeAction(at index: Int) {
        guard pending.indices.contains(index) else { return }
        pending.remove(at: index)
    }

    private func add(_ action: FightAction) {
        pending.append(action)
        cancelSelection()
        haptics.play(.selection)
    }

    // MARK: Turns

    /// Pass-and-play: the next player has the phone and starts their turn.
    func beginTurn() {
        guard case .handover(let side) = phase else { return }
        perspective = side
        phase = .choosing
        startTimer()
    }

    /// Plays the picked actions together and sends them to the other phone.
    func submitTurn() async {
        guard canSubmit else { return }
        let turnNumber = state.turn
        let actions = pending
        do {
            let result = try FightEngine.play(actions, in: state)
            stopTimer()
            pending = []
            cancelSelection()
            show(result)
            try await transport.send(.turn(number: turnNumber, actions: actions, stateHash: result.state.stateHash))
        } catch let violation as RuleViolation {
            Self.logger.error("Rejected own turn: \(String(describing: violation), privacy: .public)")
            haptics.play(.invalidAction)
        } catch {
            phase = .failed(AppError(title: String(localized: "Zug konnte nicht gesendet werden"), error: error))
        }
    }

    /// One second of the turn timer. At zero the turn is skipped.
    func tick() async {
        guard phase == .choosing, remainingSeconds > 0 else { return }
        remainingSeconds -= 1
        if Self.announcedSeconds.contains(remainingSeconds) {
            announcer.announce(String(localized: "Noch \(remainingSeconds) Sekunden"))
        }
        if remainingSeconds == Self.warningSeconds { haptics.play(.invalidAction) }
        guard remainingSeconds == 0 else { return }

        stopTimer()
        pending = []
        cancelSelection()
        let turnNumber = state.turn
        guard let result = try? FightEngine.skipTurn(in: state) else { return }
        show(result)
        do {
            try await transport.send(.timeout(number: turnNumber, stateHash: result.state.stateHash))
        } catch {
            phase = .failed(AppError(title: String(localized: "Zug konnte nicht gesendet werden"), error: error))
        }
    }

    func continueAfterReview() {
        guard phase == .reviewing else { return }
        if let result = state.result {
            finish(result)
            return
        }
        phase = phaseForCurrentTurn()
        if phase == .choosing { startTimer() }
    }

    /// The player holding the phone gives up.
    func resign() async {
        let side = perspective
        guard let result = try? FightEngine.resign(side, in: state) else { return }
        stopTimer()
        state = result.state
        if let matchResult = state.result { finish(matchResult) }
        do {
            try await transport.send(.resign(side))
        } catch {
            Self.logger.error("Sending the resignation failed: \(String(describing: error), privacy: .public)")
        }
    }

    /// After the fight: every card back to fresh.
    func iron() {
        guard state.isOver, !isIroned else { return }
        state = state.ironed()
        isIroned = true
        announcer.announce(String(localized: "Alle Karten sind wieder glatt"))
    }

    // MARK: The other phone

    /// Listens to the other phone until the fight screen goes away.
    func run() async {
        for await message in transport.incoming {
            receive(message)
        }
    }

    /// Applies a message from the other phone. Everything received is untrusted: it must fit the
    /// current turn, follow the rules and lead to the same state hash.
    func receive(_ message: MatchMessage) {
        guard !state.isOver else { return }
        do {
            switch message {
            case let .turn(number, actions, hash):
                guard state.activeSide.isRemote(in: transport), number == state.turn else { return }
                try apply(FightEngine.play(actions, in: state), expectedHash: hash)
            case let .timeout(number, hash):
                guard state.activeSide.isRemote(in: transport), number == state.turn else { return }
                try apply(FightEngine.skipTurn(in: state), expectedHash: hash)
            case let .resign(side):
                guard side.isRemote(in: transport) else { return }
                let result = try FightEngine.resign(side, in: state)
                state = result.state
                if let matchResult = state.result { finish(matchResult) }
            }
        } catch {
            outOfSync(error)
        }
    }

    private func apply(_ result: TurnResult, expectedHash: String) throws {
        guard result.state.stateHash == expectedHash else { throw AppError(title: "", cause: .outOfSync) }
        show(result)
    }

    private func outOfSync(_ error: any Error) {
        Self.logger.error("Fight out of sync: \(String(describing: error), privacy: .public)")
        stopTimer()
        phase = .failed(AppError(title: String(localized: "Kampf abgebrochen"), cause: .outOfSync))
    }

    // MARK: Helpers

    private func show(_ result: TurnResult) {
        state = result.state
        log = result.events.compactMap { $0.text(names: cards, playerNames: playerNames) }
        if let haptic = Self.haptic(for: result.events) { haptics.play(haptic) }
        if !log.isEmpty { announcer.announce(log.joined(separator: ". ")) }
        phase = .reviewing
    }

    private func finish(_ result: MatchResult) {
        stopTimer()
        phase = .finished(result)
        let won = isPassAndPlay || transport.localSides.contains(result.winner)
        haptics.play(won ? .success : .failure)
        announcer.announce(String(localized: "\(name(of: result.winner)) gewinnt"))
    }

    private func phaseForCurrentTurn() -> Phase {
        if isPassAndPlay { return .handover(state.activeSide) }
        return transport.localSides.contains(state.activeSide) ? .choosing : .waiting
    }

    private func startTimer() {
        stopTimer()
        remainingSeconds = turnSeconds
        let sleep = sleep
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await sleep(.seconds(1)) } catch { return }
                guard let self, !Task.isCancelled else { return }
                await self.tick()
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    /// The one haptic a turn gets: the strongest thing that happened in it.
    static func haptic(for events: [MatchEvent]) -> HapticEvent? {
        var best: HapticEvent?
        func rank(_ event: HapticEvent) -> Int {
            switch event {
            case .crumple: 4
            case .heavyHit: 3
            case .hit: 2
            case .support: 1
            default: 0
            }
        }
        for event in events {
            let haptic: HapticEvent? = switch event {
            case .crumpled: .crumple
            case let .hit(_, cause, healthLost, _): cause == .burst ? .heavyHit : .hit
            case .healed, .shielded, .buffed, .taunting: .support
            case .poisoned: .hit
            default: nil
            }
            if let haptic, rank(haptic) > best.map(rank) ?? -1 { best = haptic }
        }
        return best
    }
}

private extension MatchSide {
    func isRemote(in transport: any MatchTransport) -> Bool { !transport.localSides.contains(self) }
}
