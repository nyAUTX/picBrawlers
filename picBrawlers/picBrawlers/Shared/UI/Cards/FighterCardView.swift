import SwiftUI
import UIKit

/// A fighter card in the shape of a real playing card (63 × 88 mm).
///
/// Like a printed card, it is laid out once at `referenceSize` and scaled as a whole to the width it
/// gets, so its proportions never change. Its text is pinned to the default size; larger text sizes are
/// served by showing the card big (one card per row on a phone) and by the VoiceOver label.
/// The caller makes it one accessibility element with `FighterCard.accessibilityLabel(isCrumpled:)`.
struct FighterCardView: View {
    let content: FighterCard

    /// Width : height of a standard playing card, 63 × 88 mm.
    static let aspectRatio: CGFloat = 63.0 / 88.0
    static let referenceSize = CGSize(width: 160, height: 160 / aspectRatio)

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
    let content: FighterCard

    private let shape = RoundedRectangle(cornerRadius: 12)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            band
            // The photo takes whatever height the fixed rows leave, so the face always fits exactly.
            photo.padding(.horizontal, 8)
            stats.padding(.horizontal, 8)
            VStack(alignment: .leading, spacing: 2) {
                move(systemImage: "figure.boxing", name: content.attack.name)
                move(systemImage: content.special.effect.systemImage, name: content.special.name)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
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
        .background(content.category.fill, in: UnevenRoundedRectangle(topLeadingRadius: 12, topTrailingRadius: 12))
        .overlay(alignment: .bottom) { Rectangle().fill(Color.ink).frame(height: 3) }
    }

    private var photo: some View {
        Color.paperSunken
            .overlay {
                if let image = CardPhotoCache.image(for: content) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "person.fill")
                        .resizable()
                        .scaledToFit()
                        .padding(.top, 12)
                        .foregroundStyle(Color.ink.opacity(0.8))
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .overlay(Rectangle().strokeBorder(Color.ink, lineWidth: 3))
            .accessibilityIgnoresInvertColors()
    }

    private var stats: some View {
        HStack(spacing: 0) {
            stat(systemImage: "heart.fill", value: content.stats.health)
            Rectangle().fill(Color.ink).frame(width: 2)
            stat(systemImage: "bolt.fill", value: content.stats.damage)
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

    private func move(systemImage: String, name: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.inkMuted)
                .frame(width: 16)
            Text(name)
                .font(.subheadline.bold())
                .foregroundStyle(Color.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }
}

/// Decoded card photos, so a card isn't decoded again every time its view is drawn. A card's photo
/// never changes after it's created, so the card's ID is a safe key.
enum CardPhotoCache {
    private static let cache = NSCache<NSUUID, UIImage>()

    static func image(for card: FighterCard) -> UIImage? {
        guard let data = card.imageData else { return nil }
        if let cached = cache.object(forKey: card.id as NSUUID) { return cached }
        guard let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: card.id as NSUUID)
        return image
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 24) {
            ForEach(FighterCard.demoLineup) { FighterCardView(content: $0).frame(maxWidth: 360) }
        }
        .padding()
    }
    .background(Color.paper)
}
