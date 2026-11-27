import SwiftUI

/// A small card on the fight board: name and category, health, effects, and whether it is the stake.
/// Crumpled cards are crushed with the same effect as in the collection.
struct FighterTile: View {
    enum Highlight {
        case none
        /// The card picked to act.
        case selected
        /// A legal target for the chosen move.
        case target
    }

    let card: FighterCard
    let fighter: Fighter
    let isStake: Bool
    /// The card already has an action this turn.
    let hasActed: Bool
    let highlight: Highlight

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let shape = RoundedRectangle(cornerRadius: 8)

    var body: some View {
        Group {
            // The crumple effect only wraps crumpled cards: it draws the card twice through a shader,
            // which standing cards don't need.
            if fighter.isCrumpled {
                CrumplingFace(seed: CrumpleSeed.seed(for: card.id), reduceMotion: reduceMotion) { face }
                    .transition(.identity)
            } else {
                face
            }
        }
        .overlay { highlightFrame }
    }

    private var face: some View {
        VStack(alignment: .leading, spacing: 4) {
            band
            VStack(alignment: .leading, spacing: 4) {
                if fighter.isCrumpled {
                    Text("zerknittert")
                        .font(.caption.bold())
                        .foregroundStyle(Color.dangerText)
                } else {
                    HealthBar(health: fighter.health, maxHealth: fighter.maxHealth)
                    Text("\(fighter.health)/\(fighter.maxHealth)")
                        .font(.caption.monospacedDigit().bold())
                    statusIcons
                }
                if isStake {
                    Text("Einsatz")
                        .font(.caption.bold())
                        .padding(.horizontal, 4)
                        .background(Color.volt, in: RoundedRectangle(cornerRadius: 3))
                        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color.ink, lineWidth: 1.5))
                }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 6)
        }
        .foregroundStyle(Color.ink)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.paperRaised, in: shape)
        .overlay(shape.strokeBorder(Color.ink, lineWidth: 2.5))
        .background(shape.fill(Color.shadowInk).offset(x: 3, y: 3))
        // Not dimmed: a gray card would read as crumpled. A check mark says it has its action.
        .overlay(alignment: .topTrailing) {
            if hasActed {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.ink, Color.volt)
                    .offset(x: 6, y: -8)
            }
        }
    }

    private var band: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Wraps instead of shrinking, so it grows with Dynamic Type; the row takes the tallest tile's height.
            Text(card.name)
                .font(.subheadline.weight(.heavy))
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Image(systemName: fighter.category.systemImage)
                Text(fighter.category.title)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.caption.bold())
        }
        .foregroundStyle(Color.onFill)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(fighter.category.fill, in: UnevenRoundedRectangle(topLeadingRadius: 8, topTrailingRadius: 8))
    }

    private var statusIcons: some View {
        HStack(spacing: 4) {
            if fighter.shield > 0 { Image(systemName: SpecialEffect.shield.systemImage) }
            if fighter.isTaunting { Image(systemName: SpecialEffect.taunt.systemImage) }
            if fighter.buff > 0 { Image(systemName: SpecialEffect.buff.systemImage) }
            if !fighter.damageOverTime.isEmpty { Image(systemName: SpecialEffect.dot.systemImage) }
            if !fighter.canUseSpecial { Image(systemName: "hourglass") }
        }
        .font(.caption)
        .frame(minHeight: 16)
    }

    @ViewBuilder private var highlightFrame: some View {
        switch highlight {
        case .none:
            EmptyView()
        case .selected:
            shape.strokeBorder(Color.brawl, lineWidth: 4).padding(-4)
        case .target:
            shape.strokeBorder(Color.brawl, style: StrokeStyle(lineWidth: 3, dash: [6, 4])).padding(-4)
        }
    }
}

/// Crushes the card as soon as it appears, so the knockout plays as an animation.
/// With Reduce Motion it fades to a crushed, dimmed card instead.
private struct CrumplingFace<Content: View>: View {
    let seed: Float
    let reduceMotion: Bool
    @ViewBuilder let content: Content
    @State private var amount = 0.0

    var body: some View {
        content
            .modifier(CrumpleEffect(amount: reduceMotion ? 1 : amount, seed: seed))
            .opacity(reduceMotion ? amount * 0.5 + 0.5 : 1)
            .onAppear {
                withAnimation(Motion.animation(Motion.standard, reduceMotion: reduceMotion)) { amount = 1 }
            }
    }
}

/// Health as a bar on the dark track. The number next to it carries the information; the bar never does alone.
private struct HealthBar: View {
    let health: Int
    let maxHealth: Int

    var body: some View {
        GeometryReader { proxy in
            Capsule()
                .fill(Color.hpTrack)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(Color.support)
                        .frame(width: proxy.size.width * CGFloat(health) / CGFloat(max(1, maxHealth)))
                }
        }
        .frame(height: 6)
        .animation(Motion.standard, value: health)
        .accessibilityHidden(true)
    }
}
