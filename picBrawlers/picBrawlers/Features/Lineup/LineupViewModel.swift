import CoreGraphics
import Foundation
import Observation

/// Waits for a duration. Injected so tests don't actually wait.
typealias Sleeper = @Sendable (Duration) async throws -> Void

/// A player's three cards: crumpling them one by one and ironing them all flat after the fight.
@Observable
final class LineupViewModel {
    struct Card: Identifiable, Equatable {
        let content: FighterCard
        var isCrumpled = false
        let crumpleSeed: Float
        var id: UUID { content.id }
    }

    /// A running ironing pass. Views derive every frame from `itinerary` and the time since `startDate`.
    struct IroningSession: Equatable {
        let itinerary: IronItinerary
        let cardIDs: [UUID]
        let startDate: Date
    }

    /// Delay between two cards crumpled in the same turn.
    static let staggerDelay: Duration = .milliseconds(120)
    /// How far outside the lineup the iron starts and leaves.
    static let ironMargin = 120.0

    private(set) var cards: [Card]
    private(set) var ironing: IroningSession?
    private(set) var ironTask: Task<Void, Never>?
    var isIroning: Bool { ironing != nil }

    private var frames: [UUID: CGRect] = [:]
    private var bounds: CGRect = .zero
    private let announcer: any AccessibilityAnnouncing
    private let sleep: Sleeper
    private let now: () -> Date

    init(
        cards: [FighterCard] = FighterCard.demoLineup,
        announcer: any AccessibilityAnnouncing = SystemAccessibilityAnnouncer(),
        sleep: @escaping Sleeper = { try await Task.sleep(for: $0) },
        now: @escaping () -> Date = Date.init
    ) {
        self.cards = cards.map { Card(content: $0, crumpleSeed: CrumpleSeed.seed(for: $0.id)) }
        self.announcer = announcer
        self.sleep = sleep
        self.now = now
    }

    // MARK: Layout

    func updateFrame(_ frame: CGRect, for id: UUID) { frames[id] = frame }
    func updateLineupBounds(_ rect: CGRect) { bounds = rect }

    // MARK: Crumpling

    /// A hit that knocks out the next card that is still flat.
    func crumpleNext() {
        guard let index = cards.firstIndex(where: { !$0.isCrumpled }) else { return }
        cards[index].isCrumpled = true
        announcer.announce(String(localized: "\(cards[index].content.name) ist zerknittert"))
    }

    /// Two cards knocked out in the same turn, staggered so each gets its own beat and haptic.
    func crumpleTwo() async {
        crumpleNext()
        try? await sleep(Self.staggerDelay)
        crumpleNext()
    }

    // MARK: Ironing

    func startIroning(reduceMotion: Bool) {
        guard !isIroning else { return }
        let queue = cards.indices.filter { cards[$0].isCrumpled }
        guard !queue.isEmpty else { return }
        let ids = queue.map { cards[$0].id }

        let isLaidOut = bounds.width > 0 && ids.allSatisfy { frames[$0] != nil }
        guard !reduceMotion, isLaidOut else {
            flatten(ids)
            announceFlat()
            return
        }

        let itinerary = IronItinerary(
            cardFrames: cards.map { frames[$0.id] ?? .zero },
            ironing: queue,
            start: CGPoint(x: bounds.minX - Self.ironMargin, y: bounds.midY),
            exit: CGPoint(x: bounds.maxX + Self.ironMargin, y: bounds.midY)
        )
        ironing = IroningSession(itinerary: itinerary, cardIDs: ids, startDate: now())
        ironTask = Task { [weak self] in await self?.runIroning(itinerary, queue: queue, ids: ids) }
    }

    /// Ends the ironing at once: every card in this pass is flat immediately.
    func skipIroning() {
        guard let session = ironing else { return }
        ironTask?.cancel()
        flatten(session.cardIDs)
        ironing = nil
        announceFlat()
    }

    private func runIroning(_ itinerary: IronItinerary, queue: [Int], ids: [UUID]) async {
        var elapsed = 0.0
        for (card, id) in zip(queue, ids) {
            guard let finish = itinerary.finishTime(ofCard: card) else { continue }
            do { try await sleep(.seconds(finish - elapsed)) } catch { return }
            guard !Task.isCancelled else { return }
            elapsed = finish
            flatten([id])
        }
        do { try await sleep(.seconds(itinerary.duration - elapsed)) } catch { return }
        guard !Task.isCancelled, ironing != nil else { return }
        ironing = nil
        announceFlat()
    }

    private func flatten(_ ids: [UUID]) {
        for index in cards.indices where ids.contains(cards[index].id) {
            cards[index].isCrumpled = false
        }
    }

    private func announceFlat() {
        announcer.announce(String(localized: "Alle Karten sind wieder glatt"))
    }
}
