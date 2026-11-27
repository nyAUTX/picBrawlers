import Foundation
import Testing
@testable import picBrawlers

@Suite("Match setup")
struct MatchSetupTests {
    @Test func startsWithFullHealthOnTurnOneWithTheChosenSide() throws {
        let fixture = FightFixture()
        let state = try fixture.start(first: .guest)

        #expect(state.turn == 1)
        #expect(state.activeSide == .guest)
        #expect(state.outcome == nil)
        #expect(state.health(host(fixture.hostTank)) == 150)
        #expect(state.health(guest(fixture.guestDealer)) == 80)
        #expect(state[.host].fighters.count == 3)
    }

    @Test func rejectsATeamWithoutThreeCards() {
        var fixture = FightFixture()
        fixture.hostCards.removeLast()
        #expect(throws: MatchSetupError.wrongTeamSize(.host)) { try fixture.start() }
    }

    @Test func rejectsAStakeThatIsNotInTheTeam() {
        let fixture = FightFixture()
        #expect(throws: MatchSetupError.stakeNotInTeam(.guest)) {
            try MatchState.start(
                host: TeamSetup(playerID: "host", cards: fixture.hostCards, stakeID: fixture.hostTank),
                guest: TeamSetup(playerID: "guest", cards: fixture.guestCards, stakeID: fixture.hostTank),
                firstSide: .host
            )
        }
    }

    @Test func rejectsStatsOutsideTheCategoryRange() {
        var fixture = FightFixture()
        fixture.guestCards[1] = fightCard(.damageDealer, health: 300)
        #expect(throws: MatchSetupError.invalidCard(fixture.guestCards[1].id)) { try fixture.start() }
    }

    @Test func rejectsAnEffectTheCategoryMayNotHave() {
        var fixture = FightFixture()
        fixture.hostCards[0] = fightCard(.tank, effect: .heal)
        #expect(throws: MatchSetupError.invalidCard(fixture.hostCards[0].id)) { try fixture.start() }
    }

    @Test func rejectsTheSameCardTwice() {
        var fixture = FightFixture()
        fixture.guestCards[2] = fixture.hostCards[2]
        #expect(throws: MatchSetupError.duplicateCard(fixture.hostCards[2].id)) { try fixture.start() }
    }
}

@Suite("Turns")
struct TurnTests {
    @Test func anAttackDealsTheCardsDamageAndPassesTheTurn() throws {
        let fixture = FightFixture()
        let state = try fixture.start().playing(
            attack(fixture.hostDealer, guest(fixture.guestSupport)),
            attack(fixture.hostTank, guest(fixture.guestSupport))
        )

        #expect(state.health(guest(fixture.guestSupport)) == 100 - 40 - 15)
        #expect(state.activeSide == .guest)
        #expect(state.turn == 2)
    }

    @Test func twoCardsMustActEachTurn() throws {
        let fixture = FightFixture()
        let state = try fixture.start()
        #expect(state.requiredActionCount == 2)
        #expect(throws: RuleViolation.wrongActionCount(expected: 2, got: 1)) {
            try FightEngine.play([attack(fixture.hostDealer, guest(fixture.guestTank))], in: state)
        }
    }

    @Test func withOneCardLeftOneActionIsEnough() throws {
        let fixture = FightFixture()
        var state = try fixture.start()
        state.setHealth(0, of: host(fixture.hostTank))
        state.setHealth(0, of: host(fixture.hostSupport))

        #expect(state.requiredActionCount == 1)
        let next = try state.playing(attack(fixture.hostDealer, guest(fixture.guestTank)))
        #expect(next.activeSide == .guest)
    }

    @Test func aCardCannotActTwiceInOneTurn() throws {
        let fixture = FightFixture()
        let state = try fixture.start()
        #expect(throws: RuleViolation.actedTwice(fixture.hostDealer)) {
            try state.playing(
                attack(fixture.hostDealer, guest(fixture.guestTank)),
                attack(fixture.hostDealer, guest(fixture.guestTank))
            )
        }
    }

    @Test func onlyTheActiveSideMayAct() throws {
        let fixture = FightFixture()
        let state = try fixture.start()
        #expect(throws: RuleViolation.notYourCard(fixture.guestDealer)) {
            try state.playing(
                attack(fixture.guestDealer, host(fixture.hostTank)),
                attack(fixture.hostDealer, guest(fixture.guestTank))
            )
        }
    }

    @Test func aCrumpledCardCannotAct() throws {
        let fixture = FightFixture()
        var state = try fixture.start()
        state.setHealth(0, of: host(fixture.hostDealer))
        #expect(throws: RuleViolation.crumpled(fixture.hostDealer)) {
            try state.playing(
                attack(fixture.hostDealer, guest(fixture.guestTank)),
                attack(fixture.hostTank, guest(fixture.guestTank))
            )
        }
    }

    @Test func attacksMustTargetAStandingEnemy() throws {
        let fixture = FightFixture()
        var state = try fixture.start()
        #expect(throws: RuleViolation.invalidTarget(host(fixture.hostSupport))) {
            try state.playing(
                attack(fixture.hostDealer, host(fixture.hostSupport)),
                attack(fixture.hostTank, guest(fixture.guestTank))
            )
        }

        state.setHealth(0, of: guest(fixture.guestSupport))
        #expect(throws: RuleViolation.invalidTarget(guest(fixture.guestSupport))) {
            try state.playing(
                attack(fixture.hostDealer, guest(fixture.guestSupport)),
                attack(fixture.hostTank, guest(fixture.guestTank))
            )
        }
    }

    @Test func aCardAtZeroHealthIsCrumpledAndHealthNeverGoesNegative() throws {
        let fixture = FightFixture()
        var state = try fixture.start()
        state.setHealth(10, of: guest(fixture.guestSupport))

        let result = try FightEngine.play([
            attack(fixture.hostDealer, guest(fixture.guestSupport)),
            attack(fixture.hostTank, guest(fixture.guestTank)),
        ], in: state)

        #expect(result.state.health(guest(fixture.guestSupport)) == 0)
        #expect(result.state.fighter(guest(fixture.guestSupport))?.isCrumpled == true)
        #expect(result.events.contains(.crumpled(guest(fixture.guestSupport))))
    }

    @Test func crumplingTheLastCardWinsAndEndsTheTurnEarly() throws {
        let fixture = FightFixture()
        var state = try fixture.start()
        state.setHealth(0, of: guest(fixture.guestTank))
        state.setHealth(0, of: guest(fixture.guestSupport))
        state.setHealth(30, of: guest(fixture.guestDealer))

        let result = try FightEngine.play([attack(fixture.hostDealer, guest(fixture.guestDealer))], in: state)

        #expect(result.state.outcome == MatchOutcome(winner: .host, reason: .knockout))
        #expect(result.events.last == .matchEnded(MatchOutcome(winner: .host, reason: .knockout)))
    }

    @Test func noActionsAreAcceptedAfterTheMatchIsWon() throws {
        let fixture = FightFixture()
        var state = try fixture.start()
        state.setHealth(0, of: guest(fixture.guestTank))
        state.setHealth(0, of: guest(fixture.guestSupport))
        state.setHealth(30, of: guest(fixture.guestDealer))

        #expect(throws: RuleViolation.matchIsOver) {
            try state.playing(
                attack(fixture.hostDealer, guest(fixture.guestDealer)),
                attack(fixture.hostTank, guest(fixture.guestDealer))
            )
        }
    }

    @Test func aTimedOutTurnIsSkipped() throws {
        let fixture = FightFixture()
        let result = try FightEngine.skipTurn(in: fixture.start())

        #expect(result.state.activeSide == .guest)
        #expect(result.state.turn == 2)
        #expect(result.state[.host].skippedTurns == 1)
        #expect(result.events.first == .turnSkipped(.host))
    }

    @Test func threeSkippedTurnsInARowLose() throws {
        let fixture = FightFixture()
        var state = try fixture.start()
        for _ in 1...5 { state = try FightEngine.skipTurn(in: state).state }
        #expect(state.outcome == MatchOutcome(winner: .guest, reason: .timeouts))
    }

    @Test func playingATurnResetsTheSkipCount() throws {
        let fixture = FightFixture()
        var state = try fixture.start()
        state = try FightEngine.skipTurn(in: state).state // host skips
        state = try FightEngine.skipTurn(in: state).state // guest skips
        state = try state.playing(
            attack(fixture.hostDealer, guest(fixture.guestTank)),
            attack(fixture.hostTank, guest(fixture.guestTank))
        )
        #expect(state[.host].skippedTurns == 0)
        #expect(state[.guest].skippedTurns == 1)
    }

    @Test(arguments: [MatchSide.host, .guest])
    func resigningLosesAtAnyTime(side: MatchSide) throws {
        let state = try FightEngine.resign(side, in: FightFixture().start()).state
        #expect(state.outcome == MatchOutcome(winner: side.opponent, reason: .resignation))
    }
}

@Suite("Special effects")
struct FightSpecialEffectTests {
    @Test func healRestoresTwiceTheDamageCappedAtMaxHealth() throws {
        let fixture = FightFixture()
        var state = try fixture.start()
        state.setHealth(30, of: host(fixture.hostDealer))
        state.setHealth(140, of: host(fixture.hostTank))

        state = try state.playing(
            special(fixture.hostSupport, host(fixture.hostDealer)),
            attack(fixture.hostTank, guest(fixture.guestTank))
        )
        #expect(state.health(host(fixture.hostDealer)) == 30 + 40)

        var capped = try fixture.start()
        capped.setHealth(140, of: host(fixture.hostTank))
        capped = try capped.playing(
            special(fixture.hostSupport, host(fixture.hostTank)),
            attack(fixture.hostDealer, guest(fixture.guestTank))
        )
        #expect(capped.health(host(fixture.hostTank)) == 150)
    }

    @Test func healOnlyReachesStandingTeammates() throws {
        let fixture = FightFixture()
        var state = try fixture.start()
        state.setHealth(0, of: host(fixture.hostDealer))

        #expect(throws: RuleViolation.invalidTarget(host(fixture.hostDealer))) {
            try state.playing(
                special(fixture.hostSupport, host(fixture.hostDealer)),
                attack(fixture.hostTank, guest(fixture.guestTank))
            )
        }
        #expect(throws: RuleViolation.invalidTarget(guest(fixture.guestTank))) {
            try state.playing(
                special(fixture.hostSupport, guest(fixture.guestTank)),
                attack(fixture.hostTank, guest(fixture.guestTank))
            )
        }
    }

    @Test func aShieldAbsorbsDamageUntilItsOwnersNextTurn() throws {
        let fixture = FightFixture(hostSupport: .shield)
        var state = try fixture.start()
        state = try state.playing(
            special(fixture.hostSupport, host(fixture.hostDealer)), // 40 shield
            attack(fixture.hostTank, guest(fixture.guestTank))
        )
        #expect(state.fighter(host(fixture.hostDealer))?.shield == 40)

        let result = try FightEngine.play([
            attack(fixture.guestTank, host(fixture.hostDealer)), // 15 into the shield
            attack(fixture.guestDealer, host(fixture.hostDealer)), // 25 shield, 15 health
        ], in: state)
        #expect(result.state.health(host(fixture.hostDealer)) == 80 - 15)
        #expect(result.events.contains(.hit(host(fixture.hostDealer), cause: .attack, healthLost: 0, absorbed: 15)))
        #expect(result.state.fighter(host(fixture.hostDealer))?.shield == 0)

        var unused = state
        unused = try unused.playing(
            attack(fixture.guestTank, host(fixture.hostTank)),
            attack(fixture.guestSupport, host(fixture.hostTank))
        )
        #expect(unused.fighter(host(fixture.hostDealer))?.shield == 0)
    }

    @Test func aTanksShieldOnlyCoversItself() throws {
        let fixture = FightFixture(hostTank: .shield)
        let state = try fixture.start()
        #expect(throws: RuleViolation.invalidTarget(host(fixture.hostDealer))) {
            try state.playing(
                special(fixture.hostTank, host(fixture.hostDealer)),
                attack(fixture.hostDealer, guest(fixture.guestTank))
            )
        }
        let shielded = try state.playing(
            special(fixture.hostTank, host(fixture.hostTank)),
            attack(fixture.hostDealer, guest(fixture.guestTank))
        )
        #expect(shielded.fighter(host(fixture.hostTank))?.shield == 30)
    }

    @Test func aBuffAddsTheSupportersDamageToTheNextAttackOnce() throws {
        let fixture = FightFixture(hostSupport: .buff)
        var state = try fixture.start()
        state = try state.playing(
            special(fixture.hostSupport, host(fixture.hostTank)), // +20
            attack(fixture.hostTank, guest(fixture.guestTank)) // 15 + 20
        )
        #expect(state.health(guest(fixture.guestTank)) == 150 - 35)
        #expect(state.fighter(host(fixture.hostTank))?.buff == 0)
    }

    @Test func burstDealsTwiceTheDamage() throws {
        let fixture = FightFixture()
        let state = try fixture.start().playing(
            special(fixture.hostDealer, guest(fixture.guestTank)),
            attack(fixture.hostTank, guest(fixture.guestSupport))
        )
        #expect(state.health(guest(fixture.guestTank)) == 150 - 80)
    }

    @Test func damageOverTimeTicksAtTheStartOfTheVictimsNextThreeTurns() throws {
        let fixture = FightFixture(hostDealer: .dot)
        var state = try fixture.start()
        let afterApply = try FightEngine.play([
            special(fixture.hostDealer, guest(fixture.guestTank)),
            attack(fixture.hostSupport, guest(fixture.guestSupport)),
        ], in: state)
        state = afterApply.state

        #expect(state.health(guest(fixture.guestTank)) == 150 - 20) // first tick at the start of the guest's turn
        #expect(afterApply.events.contains(.hit(guest(fixture.guestTank), cause: .damageOverTime, healthLost: 20, absorbed: 0)))

        for _ in 1...4 { state = try FightEngine.skipTurnResettingTimeouts(in: state) }
        #expect(state.health(guest(fixture.guestTank)) == 150 - 60)

        for _ in 1...2 { state = try FightEngine.skipTurnResettingTimeouts(in: state) }
        #expect(state.health(guest(fixture.guestTank)) == 150 - 60)
    }

    @Test func damageOverTimeCanWinTheMatchAtTheStartOfATurn() throws {
        let fixture = FightFixture(hostDealer: .dot)
        var state = try fixture.start()
        state.setHealth(0, of: guest(fixture.guestTank))
        state.setHealth(0, of: guest(fixture.guestSupport))
        state.setHealth(10, of: guest(fixture.guestDealer))
        state.setHealth(0, of: host(fixture.hostTank))
        state.setHealth(0, of: host(fixture.hostSupport))

        state = try state.playing(special(fixture.hostDealer, guest(fixture.guestDealer)))
        #expect(state.health(guest(fixture.guestDealer)) == 0)
        #expect(state.outcome == MatchOutcome(winner: .host, reason: .knockout))
    }

    @Test func tauntForcesAttacksOntoTheTankAndSoftensThem() throws {
        let fixture = FightFixture()
        var state = try fixture.start()
        state = try state.playing(
            special(fixture.hostTank, host(fixture.hostTank)),
            attack(fixture.hostDealer, guest(fixture.guestTank))
        )
        #expect(state.fighter(host(fixture.hostTank))?.isTaunting == true)
        #expect(throws: RuleViolation.mustTargetTaunter) {
            try state.playing(
                attack(fixture.guestDealer, host(fixture.hostSupport)),
                attack(fixture.guestTank, host(fixture.hostTank))
            )
        }

        state = try state.playing(
            attack(fixture.guestDealer, host(fixture.hostTank)), // 40 → 28
            attack(fixture.guestSupport, host(fixture.hostTank)) // 20 → 14
        )
        #expect(state.health(host(fixture.hostTank)) == 150 - 28 - 14)
        #expect(state.fighter(host(fixture.hostTank))?.isTaunting == false) // ends with the host's new turn
    }

    @Test func aSpecialNeedsOneOwnTurnToRecharge() throws {
        let fixture = FightFixture()
        var state = try fixture.start()
        state = try state.playing(
            special(fixture.hostDealer, guest(fixture.guestTank)),
            attack(fixture.hostTank, guest(fixture.guestTank))
        )
        state = try FightEngine.skipTurnResettingTimeouts(in: state)

        #expect(state.fighter(host(fixture.hostDealer))?.canUseSpecial == false)
        #expect(throws: RuleViolation.specialNotReady(fixture.hostDealer)) {
            try state.playing(
                special(fixture.hostDealer, guest(fixture.guestTank)),
                attack(fixture.hostTank, guest(fixture.guestTank))
            )
        }

        state = try FightEngine.skipTurnResettingTimeouts(in: state)
        state = try FightEngine.skipTurnResettingTimeouts(in: state)
        #expect(state.fighter(host(fixture.hostDealer))?.canUseSpecial == true)
    }

    @Test func legalTargetsFollowTheRules() throws {
        let fixture = FightFixture()
        let state = try fixture.start()
        #expect(Set(FightEngine.legalTargets(for: fixture.hostDealer, move: .attack, in: state))
            == [guest(fixture.guestTank), guest(fixture.guestDealer), guest(fixture.guestSupport)])
        #expect(FightEngine.legalTargets(for: fixture.hostTank, move: .special, in: state) == [host(fixture.hostTank)])
        #expect(Set(FightEngine.legalTargets(for: fixture.hostSupport, move: .special, in: state))
            == [host(fixture.hostTank), host(fixture.hostDealer), host(fixture.hostSupport)])
        #expect(FightEngine.legalTargets(for: fixture.guestDealer, move: .attack, in: state).isEmpty)
    }
}

@Suite("State hash")
struct StateHashTests {
    @Test func theSameTurnsGiveTheSameHash() throws {
        let fixture = FightFixture()
        let turn = [attack(fixture.hostDealer, guest(fixture.guestTank)), attack(fixture.hostTank, guest(fixture.guestTank))]
        let first = try FightEngine.play(turn, in: fixture.start()).state
        let second = try FightEngine.play(turn, in: fixture.start()).state
        #expect(first.stateHash == second.stateHash)
        #expect(first.stateHash.count == 64)
    }

    @Test func differentTurnsGiveDifferentHashes() throws {
        let fixture = FightFixture()
        let first = try fixture.start().playing(
            attack(fixture.hostDealer, guest(fixture.guestTank)), attack(fixture.hostTank, guest(fixture.guestTank))
        )
        let second = try fixture.start().playing(
            attack(fixture.hostDealer, guest(fixture.guestSupport)), attack(fixture.hostTank, guest(fixture.guestTank))
        )
        #expect(first.stateHash != second.stateHash)
    }

    @Test func theHashSurvivesACodableRoundTrip() throws {
        let state = try FightFixture().start()
        let decoded = try JSONDecoder().decode(MatchState.self, from: JSONEncoder().encode(state))
        #expect(decoded == state)
        #expect(decoded.stateHash == state.stateHash)
    }

    @Test func cardTextsAndPhotosDoNotChangeTheHash() throws {
        var fixture = FightFixture()
        let plain = try fixture.start()
        fixture.hostCards[0].name = "Oma Gerti"
        fixture.hostCards[0].imageData = Data([1, 2, 3])
        #expect(try fixture.start().stateHash == plain.stateHash)
    }
}

@Suite("Match result")
struct MatchResultTests {
    @Test func theWinnerTakesTheLosersStakedCard() throws {
        let fixture = FightFixture()
        let state = try FightEngine.resign(.guest, in: fixture.start()).state
        #expect(state.result == MatchResult(
            winner: .host, reason: .resignation,
            stakedCardID: fixture.guestDealer, fromPlayerID: "guest", toPlayerID: "host"
        ))
    }

    @Test func aRunningMatchHasNoResult() throws {
        #expect(try FightFixture().start().result == nil)
    }

    @Test func ironingRestoresEveryCard() throws {
        let fixture = FightFixture(hostSupport: .shield)
        var state = try fixture.start()
        state = try state.playing(
            special(fixture.hostSupport, host(fixture.hostDealer)),
            special(fixture.hostDealer, guest(fixture.guestTank))
        )
        state.setHealth(0, of: guest(fixture.guestSupport))

        let ironed = state.ironed()
        for side in MatchSide.allCases {
            for fighter in ironed[side].fighters {
                #expect(fighter.health == fighter.maxHealth)
                #expect(fighter.shield == 0)
                #expect(fighter.canUseSpecial)
                #expect(fighter.damageOverTime.isEmpty)
            }
        }
    }
}

private extension FightEngine {
    /// Skips a turn without counting toward the timeout loss, to fast-forward in tests.
    static func skipTurnResettingTimeouts(in state: MatchState) throws -> MatchState {
        var next = try skipTurn(in: state).state
        next.resetSkippedTurns()
        return next
    }
}
