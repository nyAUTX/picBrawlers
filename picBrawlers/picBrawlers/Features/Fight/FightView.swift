import SwiftUI

/// The fight board, portrait only: the opponent's cards on top, the player's own cards by the thumb,
/// and between them what the turn needs next. Both actions are picked first, then play out together.
struct FightView: View {
    @State private var viewModel: FightViewModel
    @State private var confirmsResign = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(viewModel: FightViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            content
                .background(Color.paper)
                .navigationTitle("Kampf")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbar }
                .confirmationDialog("Kampf aufgeben?", isPresented: $confirmsResign, titleVisibility: .visible) {
                    Button("Aufgeben", role: .destructive) { Task { await viewModel.resign() } }
                } message: {
                    Text("Du verlierst den Kampf und deine Einsatzkarte.")
                }
        }
        .portraitOnly()
        .task { await viewModel.run() }
    }

    @ViewBuilder private var content: some View {
        switch viewModel.phase {
        case .handover(let side):
            HandoverView(name: viewModel.name(of: side)) { viewModel.beginTurn() }
        case .failed(let error):
            ErrorView(error: error)
        default:
            board
        }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        if case .finished = viewModel.phase {
            ToolbarItem(placement: .confirmationAction) {
                // Icon only, like the other screens: text buttons in bars stop growing at large text sizes.
                Button("Fertig", systemImage: "checkmark") { dismiss() }
            }
        } else if case .failed = viewModel.phase {
            ToolbarItem(placement: .cancellationAction) {
                Button("Schließen", systemImage: "xmark") { dismiss() }
            }
        } else if canResign {
            ToolbarItem(placement: .cancellationAction) {
                Button("Aufgeben", systemImage: "flag.fill") { confirmsResign = true }
            }
        }
    }

    /// Not on the handover screen: nobody holds the phone yet, so nobody can give up.
    private var canResign: Bool {
        if case .handover = viewModel.phase { return false }
        return true
    }

    // MARK: Board

    private var board: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                team(viewModel.perspective.opponent)
                turnPanel
                team(viewModel.perspective)
                actionPanel
            }
            .padding(16)
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Zug \(viewModel.state.turn)")
                    .font(.headline.weight(.heavy))
                Text(headerSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.inkMuted)
            }
            Spacer()
            if viewModel.phase == .choosing {
                TurnTimer(remaining: viewModel.remainingSeconds, total: viewModel.turnSeconds)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var headerSubtitle: String {
        if case .finished = viewModel.phase { return String(localized: "Kampf vorbei") }
        return String(localized: "\(viewModel.name(of: viewModel.state.activeSide)) ist dran")
    }

    private func team(_ side: MatchSide) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.name(of: side))
                .font(.caption.bold())
                .foregroundStyle(Color.inkMuted)
                .accessibilityAddTraits(.isHeader)
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 10))
                : AnyLayout(HStackLayout(alignment: .top, spacing: 8))
            layout {
                ForEach(viewModel.state[side].fighters) { fighter in
                    tile(fighter, side: side)
                }
            }
            // Tiles in a row share the tallest one's height.
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func tile(_ fighter: Fighter, side: MatchSide) -> some View {
        let ref = FighterRef(side: side, cardID: fighter.id)
        let card = viewModel.cards[fighter.id]
        let isTarget = viewModel.legalTargets.contains(ref)
        let highlight: FighterTile.Highlight = viewModel.selectedActor == fighter.id ? .selected : isTarget ? .target : .none
        let isStake = viewModel.state[side].stakeID == fighter.id
        let hasActed = viewModel.pending.contains { $0.actor == fighter.id }
        return Button {
            viewModel.tap(ref)
        } label: {
            if let card {
                FighterTile(
                    card: card,
                    fighter: fighter,
                    isStake: isStake,
                    hasActed: hasActed,
                    highlight: highlight
                )
                // The label goes on the button's content: set on the button itself, it is ignored.
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(fighter.accessibilityLabel(card: card, isStake: isStake, hasActed: hasActed))
            }
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(highlight == .selected ? .isSelected : [])
        .accessibilityHint(isTarget ? Text("Als Ziel wählen") : Text(""))
        .modifier(MoveActions(viewModel: viewModel, fighter: fighter, card: card))
    }

    // MARK: Turn panel

    @ViewBuilder private var turnPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch viewModel.phase {
            case .choosing:
                choosingSummary
            case .waiting:
                Label("Warte auf \(viewModel.name(of: viewModel.state.activeSide)) …", systemImage: "hourglass")
            case .reviewing:
                turnLog
                Button("Weiter") { viewModel.continueAfterReview() }
                    .buttonStyle(.brawl(.primary))
            case .finished(let result):
                resultPanel(result)
            case .handover, .failed:
                EmptyView()
            }
        }
        .font(.subheadline)
        .inkPanel()
    }

    @ViewBuilder private var choosingSummary: some View {
        let required = viewModel.state.requiredActionCount
        Text("Aktion \(min(viewModel.pending.count + 1, required)) von \(required)")
            .font(.subheadline.bold())
        ForEach(Array(viewModel.pending.enumerated()), id: \.offset) { index, action in
            HStack {
                Text(description(of: action))
                Spacer()
                Button {
                    viewModel.removeAction(at: index)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Aktion entfernen")
                .tint(Color.ink)
            }
        }
        // Always one hint line, so the cards below never jump when the step changes.
        Text(choosingHint)
            .foregroundStyle(Color.inkMuted)
    }

    private var choosingHint: String {
        if viewModel.selectedMove != nil { return String(localized: "Tippe auf ein Ziel.") }
        if viewModel.selectedActor != nil { return String(localized: "Wähle Angriff oder Spezial.") }
        if viewModel.canSubmit { return String(localized: "Bereit: Führe den Zug aus.") }
        return String(localized: "Tippe auf eine deiner Karten.")
    }

    private var turnLog: some View {
        VStack(alignment: .leading, spacing: 4) {
            if viewModel.log.isEmpty {
                Text("Nichts passiert.")
            }
            ForEach(Array(viewModel.log.enumerated()), id: \.offset) { _, line in
                Text(line)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func resultPanel(_ result: MatchResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(viewModel.name(of: result.winner)) gewinnt")
                .font(.title3.weight(.heavy))
            if let staked = viewModel.cards[result.stakedCardID] {
                Text("\(staked.name) geht an \(viewModel.name(of: result.winner)).")
            }
            if viewModel.isPassAndPlay {
                Text("Testkampf: Es wechselt keine Karte den Besitzer.")
                    .foregroundStyle(Color.inkMuted)
            }
            if !viewModel.isIroned {
                Button("Bügeln") { withAnimation(Motion.standard) { viewModel.iron() } }
                    .buttonStyle(.brawl(.volt))
            }
        }
    }

    // MARK: Action panel

    @ViewBuilder private var actionPanel: some View {
        if viewModel.phase == .choosing {
            VStack(alignment: .leading, spacing: 12) {
                if let actorID = viewModel.selectedActor,
                   let ref = viewModel.state.ref(of: actorID),
                   let fighter = viewModel.state.fighter(ref),
                   let card = viewModel.cards[actorID] {
                    if viewModel.selectedMove == nil {
                        moveButtons(fighter: fighter, card: card)
                    }
                    Button("Abbrechen") { viewModel.cancelSelection() }
                        .buttonStyle(.brawl())
                } else if viewModel.canSubmit {
                    Button("Zug ausführen") { Task { await viewModel.submitTurn() } }
                        .buttonStyle(.brawl(.primary))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func moveButtons(fighter: Fighter, card: FighterCard) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                viewModel.choose(.attack)
            } label: {
                Label("Angriff: \(card.attack.name) · \(fighter.damage + fighter.buff)", systemImage: "figure.boxing")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.brawl())
            Button {
                viewModel.choose(.special)
            } label: {
                Label(specialTitle(fighter: fighter, card: card), systemImage: fighter.effect.systemImage)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.brawl())
        }
    }

    private func specialTitle(fighter: Fighter, card: FighterCard) -> String {
        guard fighter.canUseSpecial else { return String(localized: "Spezial: \(card.special.name) · lädt noch") }
        if let value = fighter.specialValue {
            return String(localized: "Spezial: \(card.special.name) · \(value)")
        }
        return String(localized: "Spezial: \(card.special.name)")
    }

    private func description(of action: FightAction) -> String {
        let actor = viewModel.cards[action.actor]
        let target = viewModel.cards[action.target.cardID]?.name ?? ""
        let move = action.move == .attack ? actor?.attack.name : actor?.special.name
        return String(localized: "\(actor?.name ?? ""): \(move ?? "") → \(target)")
    }
}

/// VoiceOver actions on the player's own cards: attack or special straight from the card.
private struct MoveActions: ViewModifier {
    let viewModel: FightViewModel
    let fighter: Fighter
    let card: FighterCard?

    func body(content: Content) -> some View {
        if let card, viewModel.canAct(fighter.id) {
            content
                .accessibilityAction(named: Text("Angriff: \(card.attack.name)")) { viewModel.choose(.attack, for: fighter.id) }
                .accessibilityAction(named: Text("Spezial: \(card.special.name)")) { viewModel.choose(.special, for: fighter.id) }
        } else {
            content
        }
    }
}

/// The turn's countdown as a ring. It turns `brawl` red for the last seconds, with the number always shown.
private struct TurnTimer: View {
    let remaining: Int
    let total: Int

    var body: some View {
        // The ring is sized by its number, so it grows with Dynamic Type and longer times instead of clipping.
        Text("\(remaining)")
            .font(.headline.monospacedDigit().bold())
            .fixedSize()
            .padding(12)
            .frame(minWidth: 48, minHeight: 48)
            .aspectRatio(1, contentMode: .fill)
            .background {
                ZStack {
                    Circle().stroke(Color.ink.opacity(0.15), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: CGFloat(remaining) / CGFloat(max(1, total)))
                        .stroke(remaining <= 5 ? Color.brawl : Color.ink, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: remaining)
                }
            }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Noch \(remaining) Sekunden")
    }
}

/// Pass-and-play: covers the board so the next player doesn't see the last one's choices.
private struct HandoverView: View {
    let name: String
    let start: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "iphone.and.arrow.forward")
                .font(.largeTitle)
                .accessibilityHidden(true)
            Text("Gib das Handy an \(name)")
                .font(.title2.weight(.heavy))
                .multilineTextAlignment(.center)
            Text("Der Timer startet erst, wenn \(name) bereit ist.")
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.inkMuted)
            Button("Los geht's") { start() }
                .buttonStyle(.brawl(.primary))
        }
        .foregroundStyle(Color.ink)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scrollableWhenTooTall()
    }
}
