import SwiftUI

/// Crushes a card like paper and lets the iron flatten it again.
///
/// Two layers: a flat copy underneath, and the crumpled card on top (warped by the `crumple` shader,
/// creased, grayed). While the iron works the card, the top layer is masked by the iron's trail, so the
/// card is flat wherever the soleplate has pressed. See the design system's CrumpleEffect guidelines.
struct CrumpleEffect: ViewModifier, Animatable {
    /// 0 flat … 1 crumpled. Animate it with `Motion.standard`.
    var amount: Double
    /// 0 … 1: the iron has landed on the card and pins it down, so tilt and scale relax.
    var landed: Double = 0
    /// Soleplate footprints so far, in the card's coordinates.
    var trail: [IronStamp] = []
    var ironWidth: CGFloat = 0
    let seed: Float

    private nonisolated static let warpRoom: CGFloat = 16

    var animatableData: Double {
        get { amount }
        set { amount = newValue }
    }

    func body(content: Content) -> some View {
        let settle = amount * (1 - landed)
        let amount = amount, seed = seed
        ZStack {
            content
                .opacity(landed > 0 ? 1 : 0)
                .accessibilityHidden(true)
            content
                .overlay { CreaseOverlay(pattern: CreasePattern(seed: seed), amount: amount) }
                // Room around the card so the buckled outline and the shadow aren't cut off by the layer bounds.
                .padding(Self.warpRoom)
                .visualEffect { view, proxy in
                    view.distortionEffect(
                        ShaderLibrary.crumple(.float(seed), .float(Float(amount)), .float(Float((proxy.size.width - 2 * Self.warpRoom) * 0.055))),
                        maxSampleOffset: CGSize(width: 14, height: 14),
                        isEnabled: amount > 0.001
                    )
                }
                .grayscale(0.9 * amount)
                .mask {
                    if trail.isEmpty {
                        Rectangle()
                    } else {
                        IronTrailMask(trail: trail, ironWidth: ironWidth, origin: CGPoint(x: Self.warpRoom, y: Self.warpRoom))
                    }
                }
                .padding(-Self.warpRoom)
        }
        .scaleEffect(1 - 0.1 * settle)
        .rotationEffect(.degrees(-6 * settle))
    }
}

/// The red ZERKNITTERT stamp on a crumpled card. Drawn outside the warp so it stays sharp.
struct CrumpleStamp: View {
    var body: some View {
        Text("ZERKNITTERT")
            .font(.footnote.weight(.black))
            .fixedSize()
            .foregroundStyle(Color.dangerText)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.paperRaised)
            .overlay(Rectangle().strokeBorder(Color.dangerText, lineWidth: 3))
            .rotationEffect(.degrees(-12))
            .accessibilityHidden(true)
    }
}
