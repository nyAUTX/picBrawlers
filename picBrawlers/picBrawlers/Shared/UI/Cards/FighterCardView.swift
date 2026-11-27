import SwiftUI

/// A fighter card in the shape of a real playing card (63 × 88 mm).
///
/// Like a printed card, it is laid out once at `referenceSize` and scaled as a whole to the width it
/// gets, so its proportions never change. Its text is pinned to the default size; larger text sizes are
/// served by showing the card big (one card per row on a phone) and by the VoiceOver label.
/// The caller makes it one accessibility element with `FighterCardContent.accessibilityLabel(isCrumpled:)`.
struct FighterCardView: View {
    let content: FighterCardContent

    /// Width : height of a standard playing card, 63 × 88 mm.
    static let aspectRatio: CGFloat = 63.0 / 88.0
    static let referenceSize = CGSize(width: 140, height: 140 / aspectRatio)

    var body: some View {
        Color.clear
            .aspectRatio(Self.aspectRatio, contentMode: .fit)
            .overlay(alignment: .topLeading) {
                GeometryReader { proxy in
                    FighterCardFace(content: content)
                        .frame(width: Self.referenceSize.width, height: Self.referenceSize.height)
                        .scaleEffect(proxy.size.width / Self.referenceSize.width, anchor: .topLeading)
                }
            }
    }
}

/// The printed face of the card at its reference size.
private struct FighterCardFace: View {
    let content: FighterCardContent

    private let shape = RoundedRectangle(cornerRadius: 10)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            band
            photo.padding(.horizontal, 8)
            stats.padding(.horizontal, 8)
            move.padding(.horizontal, 8)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.paperRaised, in: shape)
        .overlay(shape.strokeBorder(Color.ink, lineWidth: 3))
        .background(shape.fill(Color.shadowInk).offset(x: 4, y: 4))
        .dynamicTypeSize(.large)
    }

    private var band: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(content.name)
                .font(.headline.weight(.heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Label(content.category.title, systemImage: content.category.systemImage)
                .font(.caption2.bold())
                .textCase(.uppercase)
                .lineLimit(1)
        }
        .foregroundStyle(Color.onFill)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(content.category.fill, in: UnevenRoundedRectangle(topLeadingRadius: 10, topTrailingRadius: 10))
        .overlay(alignment: .bottom) { Rectangle().fill(Color.ink).frame(height: 3) }
    }

    private var photo: some View {
        ZStack(alignment: .bottom) {
            Color.paperSunken
            Image(systemName: "person.fill")
                .resizable()
                .scaledToFit()
                .padding(.top, 12)
                .foregroundStyle(Color.ink.opacity(0.8))
        }
        // The card layout is fixed, so the photo window has an exact 16:10 size inside the 8 pt margins.
        .frame(width: FighterCardView.referenceSize.width - 16, height: (FighterCardView.referenceSize.width - 16) * 10 / 16)
        .clipped()
        .overlay(Rectangle().strokeBorder(Color.ink, lineWidth: 3))
        .accessibilityIgnoresInvertColors()
    }

    private var stats: some View {
        HStack(spacing: 0) {
            stat(systemImage: "heart.fill", value: content.health)
            Rectangle().fill(Color.ink).frame(width: 2)
            stat(systemImage: "bolt.fill", value: content.damage)
        }
        .fixedSize(horizontal: false, vertical: true)
        .overlay(Rectangle().strokeBorder(Color.ink, lineWidth: 2))
    }

    private func stat(systemImage: String, value: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.inkMuted)
            Text(value, format: .number)
                .font(.system(.headline, design: .monospaced).weight(.heavy))
                .foregroundStyle(Color.ink)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 3)
    }

    private var move: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(content.moveKind.title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.inkMuted)
            Text(content.moveName)
                .font(.subheadline.bold())
                .foregroundStyle(Color.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }
}

#Preview {
    HStack(alignment: .top, spacing: 12) {
        ForEach(FighterCardContent.demoLineup) { FighterCardView(content: $0) }
    }
    .padding()
    .background(Color.paper)
}
