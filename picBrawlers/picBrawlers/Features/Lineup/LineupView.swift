import SwiftUI

/// Three cards that can be crumpled by hits and ironed flat again, card by card. The fight screen
/// will reuse this lineup; for now it's reachable from the Kämpfe tab in debug builds.
struct LineupView: View {
    @State private var viewModel: LineupViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private nonisolated static let space = "lineup"
    /// Keeps cards a hand-held size on larger phones.
    private static let maxCardWidth: CGFloat = 360

    init(viewModel: LineupViewModel = LineupViewModel()) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                controls
                lineup
            }
            .padding(16)
        }
        .background(Color.paper)
        .navigationTitle("Effekte")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Controls

    private var controls: some View {
        // The iron button has its own row: when "Bügeln" becomes the wider "Überspringen",
        // nothing reflows and the cards don't move while the iron is on them.
        VStack(alignment: .leading, spacing: 12) {
            let row = dynamicTypeSize >= .xLarge
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                : AnyLayout(HStackLayout(spacing: 12))
            row { hitButtons }
            if viewModel.isIroning {
                Button("Überspringen") { viewModel.skipIroning() }
                    .buttonStyle(.brawl())
            } else {
                Button("Bügeln") { viewModel.startIroning(reduceMotion: reduceMotion) }
                    .buttonStyle(.brawl())
            }
        }
    }

    @ViewBuilder private var hitButtons: some View {
        Button("Treffer") { viewModel.crumpleNext() }
            .buttonStyle(.brawl(.primary))
        Button("Zwei auf einmal") { Task { await viewModel.crumpleTwo() } }
            .buttonStyle(.brawl(.volt))
    }

    // MARK: Lineup

    private var lineup: some View {
        // On a phone, one card per row: each card gets the full width, like a real card in your hand.
        TimelineView(.animation(paused: !viewModel.isIroning)) { timeline in
            let elapsed = viewModel.ironing.map { timeline.date.timeIntervalSince($0.startDate) } ?? 0
            LazyVStack(spacing: 28) {
                ForEach(Array(viewModel.cards.enumerated()), id: \.element.id) { index, card in
                    cell(card, index: index, elapsed: elapsed)
                        .frame(maxWidth: Self.maxCardWidth)
                }
            }
            .frame(maxWidth: .infinity)
            .overlay(alignment: .topLeading) { ironLayer(elapsed: elapsed) }
            .coordinateSpace(.named(Self.space))
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
                viewModel.updateLineupBounds(CGRect(origin: .zero, size: size))
            }
        }
    }

    private func cell(_ card: LineupViewModel.Card, index: Int, elapsed: Double) -> some View {
        let iron = ironState(for: card, index: index, elapsed: elapsed)
        return Group {
            if reduceMotion {
                // Reduce Motion: no warp animation, just a cross-fade to the crumpled card.
                ZStack {
                    FighterCardView(content: card.content)
                    if card.isCrumpled {
                        FighterCardView(content: card.content)
                            .modifier(CrumpleEffect(amount: 1, seed: card.crumpleSeed))
                            .transition(.opacity)
                    }
                }
                .animation(Motion.reducedMotionFallback, value: card.isCrumpled)
            } else {
                FighterCardView(content: card.content)
                    .modifier(CrumpleEffect(
                        amount: card.isCrumpled ? 1 : 0,
                        landed: iron.landed,
                        trail: iron.trail,
                        ironWidth: iron.width,
                        seed: card.crumpleSeed
                    ))
                    .animation(Motion.standard, value: card.isCrumpled)
            }
        }
        .overlay {
            if card.isCrumpled && iron.landed == 0 {
                CrumpleStamp()
                    .transition(reduceMotion ? .opacity : .scale(scale: 1.6).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? Motion.reducedMotionFallback : Motion.standard.delay(0.25), value: card.isCrumpled)
        .sensoryFeedback(trigger: card.isCrumpled) { _, isCrumpled in
            isCrumpled ? HapticEvent.crumple.feedback : nil
        }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { frame in
            viewModel.updateFrame(frame, for: card.id)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(card.content.accessibilityLabel(isCrumpled: card.isCrumpled))
    }

    // MARK: Iron

    private struct CardIronState {
        var landed = 0.0
        var trail: [IronStamp] = []
        var width: CGFloat = 0
    }

    /// How far the iron has got on this card at `elapsed`, derived from the itinerary.
    private func ironState(for card: LineupViewModel.Card, index: Int, elapsed: Double) -> CardIronState {
        guard let session = viewModel.ironing,
              session.cardIDs.contains(card.id),
              let landing = session.itinerary.landingTime(ofCard: index),
              let finish = session.itinerary.finishTime(ofCard: index),
              let frame = session.itinerary.frame(ofCard: index),
              elapsed >= landing,
              // A card crumpled again after the iron finished it is a new crumple, not part of this pass.
              !(card.isCrumpled && elapsed > finish + 0.3)
        else { return CardIronState() }
        let progress = min(1, (elapsed - landing) / 0.4)
        return CardIronState(
            landed: max(0.001, progress * progress * (3 - 2 * progress)),
            trail: session.itinerary.footprints(ofCard: index, at: elapsed),
            width: IronView.width(forCardWidth: frame.width)
        )
    }

    @ViewBuilder
    private func ironLayer(elapsed: Double) -> some View {
        if let session = viewModel.ironing, !reduceMotion,
           let first = session.itinerary.ironedCards.first,
           let frame = session.itinerary.frame(ofCard: first) {
            let pose = session.itinerary.pose(at: elapsed)
            let ironWidth = IronView.width(forCardWidth: frame.width)
            let iron = IronView(width: ironWidth, isLifted: pose.isLifted)
            ZStack(alignment: .topLeading) {
                SteamPuffs(itinerary: session.itinerary, elapsed: elapsed, ironWidth: ironWidth)
                iron
                    .rotationEffect(.radians(pose.angle), anchor: IronView.pivot)
                    .offset(
                        x: pose.position.x - IronView.pivot.x * iron.width,
                        y: pose.position.y - IronView.pivot.y * iron.height
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

/// Steam rising behind the iron while it presses. Each puff stays where it was released and rises.
private struct SteamPuffs: View {
    let itinerary: IronItinerary
    let elapsed: Double
    let ironWidth: CGFloat

    private static let interval = 0.08
    private static let lifetime = 0.8

    var body: some View {
        Canvas { context, _ in
            let newest = (elapsed / Self.interval).rounded(.down) * Self.interval
            var released = newest
            while released > 0 && elapsed - released < Self.lifetime {
                let age = elapsed - released
                let pose = itinerary.pose(at: released)
                if !pose.isLifted {
                    let back = ironWidth * 0.45
                    let radius = 5 + age * 10
                    let center = CGPoint(
                        x: pose.position.x - cos(pose.angle) * back - age * 12,
                        y: pose.position.y - sin(pose.angle) * back - age * 45
                    )
                    let puff = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
                    let opacity = max(0, 0.9 * (1 - age / Self.lifetime))
                    context.fill(puff, with: .color(Color.paperRaised.opacity(opacity)))
                    context.stroke(puff, with: .color(Color.ink.opacity(opacity)), lineWidth: 2)
                }
                released -= Self.interval
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    NavigationStack { LineupView() }
}
