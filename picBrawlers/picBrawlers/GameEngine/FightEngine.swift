import Foundation

/// One card's action in a turn. This is what travels between the phones.
nonisolated struct FightAction: Hashable, Codable, Sendable {
    enum Move: String, Codable, Sendable {
        case attack
        case special
    }

    var actor: UUID
    var move: Move
    /// For self-only specials (taunt, a tank's shield) this is the actor itself.
    var target: FighterRef
}

/// A rule an action broke. The UI only offers legal actions, so this mostly catches bad messages from the other phone.
nonisolated enum RuleViolation: Error, Equatable, Sendable {
    case matchIsOver
    case wrongActionCount(expected: Int, got: Int)
    case notYourCard(UUID)
    case crumpled(UUID)
    case actedTwice(UUID)
    case specialNotReady(UUID)
    case invalidTarget(FighterRef)
    case mustTargetTaunter
}

/// Something that happened, in order, so the UI can animate it and fire the matching haptic.
nonisolated enum MatchEvent: Hashable, Sendable {
    enum HitCause: Hashable, Sendable {
        case attack
        case burst
        case damageOverTime
    }

    case hit(FighterRef, cause: HitCause, healthLost: Int, absorbed: Int)
    case healed(FighterRef, amount: Int)
    case shielded(FighterRef, amount: Int)
    case buffed(FighterRef, bonus: Int)
    case taunting(FighterRef)
    case poisoned(FighterRef, damagePerTurn: Int, turns: Int)
    case crumpled(FighterRef)
    case turnSkipped(MatchSide)
    case turnStarted(MatchSide, turn: Int)
    case matchEnded(MatchOutcome)
}

nonisolated struct TurnResult: Sendable {
    var state: MatchState
    var events: [MatchEvent]
}

/// The fight rules. Pure functions from a state and the player's choice to the next state.
nonisolated enum FightEngine {
    // MARK: Turns

    /// Plays the active side's turn: each action in order, then the start of the opponent's turn.
    /// A turn may stop early when an action wins the match; no further actions are accepted then.
    static func play(_ actions: [FightAction], in state: MatchState) throws(RuleViolation) -> TurnResult {
        guard !state.isOver else { throw .matchIsOver }
        let required = state.requiredActionCount
        guard actions.count <= required else { throw .wrongActionCount(expected: required, got: actions.count) }

        var state = state
        var events: [MatchEvent] = []
        var acted = Set<UUID>()
        for action in actions {
            guard !state.isOver else { throw .matchIsOver }
            guard acted.insert(action.actor).inserted else { throw .actedTwice(action.actor) }
            try resolve(action, in: &state, events: &events)
        }
        guard state.isOver || actions.count == required else {
            throw .wrongActionCount(expected: required, got: actions.count)
        }

        state[state.activeSide].skippedTurns = 0
        if !state.isOver { advanceTurn(&state, events: &events) }
        return TurnResult(state: state, events: events)
    }

    /// The active side ran out of time. Too many timeouts in a row lose the match.
    static func skipTurn(in state: MatchState) throws(RuleViolation) -> TurnResult {
        guard !state.isOver else { throw .matchIsOver }
        var state = state
        let side = state.activeSide
        var events: [MatchEvent] = [.turnSkipped(side)]
        state[side].skippedTurns += 1
        if state[side].skippedTurns >= FightRules.maxSkippedTurnsInARow {
            end(&state, MatchOutcome(winner: side.opponent, reason: .timeouts), events: &events)
        } else {
            advanceTurn(&state, events: &events)
        }
        return TurnResult(state: state, events: events)
    }

    /// Either player may give up at any time, also during the opponent's turn.
    static func resign(_ side: MatchSide, in state: MatchState) throws(RuleViolation) -> TurnResult {
        guard !state.isOver else { throw .matchIsOver }
        var state = state
        var events: [MatchEvent] = []
        end(&state, MatchOutcome(winner: side.opponent, reason: .resignation), events: &events)
        return TurnResult(state: state, events: events)
    }

    // MARK: Targets

    /// The cards a move may target right now. Empty if the card can't make the move at all.
    static func legalTargets(for actorID: UUID, move: FightAction.Move, in state: MatchState) -> [FighterRef] {
        guard !state.isOver, let actorRef = state.ref(of: actorID), actorRef.side == state.activeSide,
              let actor = state.fighter(actorRef), !actor.isCrumpled
        else { return [] }
        if move == .special, !actor.canUseSpecial { return [] }

        switch targetKind(of: actor, move: move) {
        case .enemy:
            let enemies = state[actorRef.side.opponent].standing
            let taunters = enemies.filter(\.isTaunting)
            return (taunters.isEmpty ? enemies : taunters).map { FighterRef(side: actorRef.side.opponent, cardID: $0.id) }
        case .ally:
            return state[actorRef.side].standing.map { FighterRef(side: actorRef.side, cardID: $0.id) }
        case .actor:
            return [actorRef]
        }
    }

    private enum TargetKind { case enemy, ally, actor }

    private static func targetKind(of actor: Fighter, move: FightAction.Move) -> TargetKind {
        guard move == .special else { return .enemy }
        switch actor.effect {
        case .burst, .dot: return .enemy
        case .heal, .buff: return .ally
        case .shield: return actor.category == .support ? .ally : .actor
        case .taunt: return .actor
        }
    }

    // MARK: Resolving

    private static func resolve(_ action: FightAction, in state: inout MatchState, events: inout [MatchEvent]) throws(RuleViolation) {
        guard let actorRef = state.ref(of: action.actor), actorRef.side == state.activeSide,
              let actor = state.fighter(actorRef)
        else { throw .notYourCard(action.actor) }
        guard !actor.isCrumpled else { throw .crumpled(action.actor) }
        if action.move == .special, !actor.canUseSpecial { throw .specialNotReady(action.actor) }

        let legal = legalTargets(for: action.actor, move: action.move, in: state)
        guard legal.contains(action.target) else {
            let isStandingEnemy = action.target.side != actorRef.side && state.fighter(action.target)?.isCrumpled == false
            if targetKind(of: actor, move: action.move) == .enemy, isStandingEnemy { throw .mustTargetTaunter }
            throw .invalidTarget(action.target)
        }

        let target = action.target
        switch action.move {
        case .attack:
            dealDamage(actor.damage + consumeBuff(of: actorRef, in: &state), to: target, cause: .attack, in: &state, events: &events)
        case .special:
            state.update(actorRef) { $0.specialReadyIn = FightRules.specialCooldownTurns + 1 }
            applySpecial(of: actor, from: actorRef, to: target, in: &state, events: &events)
        }
    }

    private static func applySpecial(
        of actor: Fighter, from actorRef: FighterRef, to target: FighterRef,
        in state: inout MatchState, events: inout [MatchEvent]
    ) {
        switch actor.effect {
        case .burst:
            let amount = FightRules.burstDamage(damage: actor.damage) + consumeBuff(of: actorRef, in: &state)
            dealDamage(amount, to: target, cause: .burst, in: &state, events: &events)
        case .dot:
            let tick = DamageOverTime(
                sourceID: actor.id,
                damagePerTurn: FightRules.damageOverTimePerTurn(damage: actor.damage),
                turnsLeft: FightRules.damageOverTimeTurns
            )
            state.update(target) { fighter in
                fighter.damageOverTime.removeAll { $0.sourceID == actor.id }
                fighter.damageOverTime.append(tick)
            }
            events.append(.poisoned(target, damagePerTurn: tick.damagePerTurn, turns: tick.turnsLeft))
        case .heal:
            var healed = 0
            state.update(target) { fighter in
                healed = min(FightRules.healAmount(damage: actor.damage), fighter.maxHealth - fighter.health)
                fighter.health += healed
            }
            events.append(.healed(target, amount: healed))
        case .shield:
            let amount = FightRules.shieldAmount(damage: actor.damage)
            state.update(target) { $0.shield = max($0.shield, amount) }
            events.append(.shielded(target, amount: amount))
        case .buff:
            let bonus = FightRules.buffBonus(damage: actor.damage)
            state.update(target) { $0.buff = max($0.buff, bonus) }
            events.append(.buffed(target, bonus: bonus))
        case .taunt:
            state.update(target) { $0.isTaunting = true }
            events.append(.taunting(target))
        }
    }

    private static func consumeBuff(of ref: FighterRef, in state: inout MatchState) -> Int {
        var bonus = 0
        state.update(ref) { fighter in
            bonus = fighter.buff
            fighter.buff = 0
        }
        return bonus
    }

    /// Taunt softens the hit, the shield takes what it can, health takes the rest.
    private static func dealDamage(
        _ amount: Int, to target: FighterRef, cause: MatchEvent.HitCause,
        in state: inout MatchState, events: inout [MatchEvent]
    ) {
        guard let fighter = state.fighter(target), !fighter.isCrumpled else { return }
        let incoming = fighter.isTaunting ? FightRules.reducedByTaunt(amount) : amount
        let absorbed = min(fighter.shield, incoming)
        let healthLost = min(fighter.health, incoming - absorbed)
        state.update(target) { fighter in
            fighter.shield -= absorbed
            fighter.health -= healthLost
            if fighter.isCrumpled { fighter.clearEffects() }
        }
        events.append(.hit(target, cause: cause, healthLost: healthLost, absorbed: absorbed))

        guard state.fighter(target)?.isCrumpled == true else { return }
        events.append(.crumpled(target))
        if state[target.side].isDefeated {
            end(&state, MatchOutcome(winner: target.side.opponent, reason: .knockout), events: &events)
        }
    }

    /// Hands the turn over: the new side's shields and taunts run out, cooldowns tick down, damage over time hits.
    private static func advanceTurn(_ state: inout MatchState, events: inout [MatchEvent]) {
        let side = state.activeSide.opponent
        state.activeSide = side
        state.turn += 1
        events.append(.turnStarted(side, turn: state.turn))

        for fighter in state[side].fighters where !fighter.isCrumpled {
            let ref = FighterRef(side: side, cardID: fighter.id)
            state.update(ref) { fighter in
                fighter.shield = 0
                fighter.isTaunting = false
                fighter.specialReadyIn = max(0, fighter.specialReadyIn - 1)
            }
            for tick in fighter.damageOverTime {
                dealDamage(tick.damagePerTurn, to: ref, cause: .damageOverTime, in: &state, events: &events)
            }
            state.update(ref) { fighter in
                fighter.damageOverTime = fighter.damageOverTime
                    .map { DamageOverTime(sourceID: $0.sourceID, damagePerTurn: $0.damagePerTurn, turnsLeft: $0.turnsLeft - 1) }
                    .filter { $0.turnsLeft > 0 }
            }
            if state.isOver { return }
        }
    }

    private static func end(_ state: inout MatchState, _ outcome: MatchOutcome, events: inout [MatchEvent]) {
        guard !state.isOver else { return }
        state.outcome = outcome
        events.append(.matchEnded(outcome))
    }
}
