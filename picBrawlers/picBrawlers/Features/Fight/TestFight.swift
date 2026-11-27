#if DEBUG
import Foundation
import UIKit

/// Pass-and-play test fights with two fixed teams, for development and playtesting.
/// Debug builds only: none of this ships.
extension FighterCard {
    /// The second test team, facing `demoLineup`.
    nonisolated static let testOpponentLineup: [FighterCard] = [
        FighterCard(
            id: UUID(uuidString: "6F1C2B4A-0004-4000-8000-000000000004")!,
            name: "Linienbus", category: .tank,
            stats: CardStats(health: 160, damage: 14),
            attack: Move(name: "Vollbremsung", description: "Alle Fahrgäste fliegen nach vorn."),
            special: Special(name: "Hupkonzert", description: "So laut, dass alle nur noch ihn ansehen.", effect: .taunt),
            weaknesses: ["Rettungsgasse"],
            photoDescription: "", imageData: nil,
            creatorID: "demo", ownerID: "demo", createdAt: Date(timeIntervalSince1970: 0)
        ),
        FighterCard(
            id: UUID(uuidString: "6F1C2B4A-0005-4000-8000-000000000005")!,
            name: "Toaster", category: .damageDealer,
            stats: CardStats(health: 70, damage: 38),
            attack: Move(name: "Toastschuss", description: "Zwei Scheiben, glühend heiß."),
            special: Special(name: "Krümelfalle", description: "Brennt noch lange nach.", effect: .dot),
            weaknesses: ["Badewanne"],
            photoDescription: "", imageData: nil,
            creatorID: "demo", ownerID: "demo", createdAt: Date(timeIntervalSince1970: 0)
        ),
        FighterCard(
            id: UUID(uuidString: "6F1C2B4A-0006-4000-8000-000000000006")!,
            name: "Kaktus", category: .support,
            stats: CardStats(health: 100, damage: 18),
            attack: Move(name: "Stachelgruß", description: "Eine Umarmung, die man nicht vergisst."),
            special: Special(name: "Wüstenwasser", description: "Ein Schluck aus dem Vorrat.", effect: .heal),
            weaknesses: ["Gießkanne"],
            photoDescription: "", imageData: nil,
            creatorID: "demo", ownerID: "demo", createdAt: Date(timeIntervalSince1970: 0)
        ),
    ]
}

extension AppEnvironment {
    /// A fresh pass-and-play fight: `demoLineup` against `testOpponentLineup`, each staking its damage dealer.
    func makeTestFightViewModel() -> FightViewModel {
        let host = FighterCard.demoLineup
        let guest = FighterCard.testOpponentLineup
        // The test teams are fixed and valid, so the setup can't fail.
        let state = try! MatchState.start(
            host: TeamSetup(playerID: "test-host", cards: host, stakeID: host[1].id),
            guest: TeamSetup(playerID: "test-guest", cards: guest, stakeID: guest[1].id),
            firstSide: .host
        )
        let assisted = UIAccessibility.isVoiceOverRunning || UIAccessibility.isSwitchControlRunning
        // UI tests take longer than 30 seconds to tap through a turn.
        let isUITesting = ProcessInfo.processInfo.arguments.contains("-ui-testing")
        return FightViewModel(
            state: state,
            cards: host + guest,
            playerNames: [.host: String(localized: "Spieler 1"), .guest: String(localized: "Spieler 2")],
            transport: PassAndPlayTransport(),
            haptics: SystemHapticsService(),
            announcer: SystemAccessibilityAnnouncer(),
            turnSeconds: isUITesting ? 600 : FightViewModel.turnSeconds(usesAssistiveTechnology: assisted)
        )
    }
}
#endif
