import SwiftUI

/// A top-down clothes iron, nose pointing right (angle 0). Drawn in a 158 × 76 design box whose
/// soleplate centre sits at `IronView.pivot`; rotate and position it around that point.
struct IronView: View {
    /// Width in points. The iron is about as wide as the card it irons.
    let width: CGFloat
    var isLifted = false

    /// The design box is x −34…124, y 0…76; the soleplate centre is at (60, 36).
    static let designSize = CGSize(width: 158, height: 76)
    static let pivot = UnitPoint(x: 94 / 158, y: 36 / 76)

    var height: CGFloat { width * Self.designSize.height / Self.designSize.width }

    /// The iron is three quarters as wide as the card it irons.
    static func width(forCardWidth cardWidth: CGFloat) -> CGFloat { cardWidth * 0.75 }

    /// The soleplate's footprint at this width, for the ironed-trail mask.
    static func footprint(forWidth width: CGFloat) -> CGSize {
        let scale = width / designSize.width
        return CGSize(width: 112 * scale, height: 56 * scale)
    }

    var body: some View {
        Canvas { context, size in
            let scale = size.width / Self.designSize.width
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: 34, y: 0)
            let line = 2.5 / scale

            var cord = Path()
            cord.move(to: CGPoint(x: 6, y: 38))
            cord.addCurve(to: CGPoint(x: -32, y: 52), control1: CGPoint(x: -6, y: 38), control2: CGPoint(x: -10, y: 54))
            context.stroke(cord, with: .color(.ink), style: StrokeStyle(lineWidth: line, lineCap: .round))

            let shadowOffset: CGFloat = isLifted ? 9 : 4
            context.fill(Self.soleplate.offsetBy(dx: shadowOffset, dy: shadowOffset), with: .color(.shadowInk))
            context.fill(Self.soleplate, with: .color(.chrome))
            context.stroke(Self.soleplate, with: .color(.ink), lineWidth: line)
            context.fill(Self.body, with: .color(.brawl))
            context.stroke(Self.body, with: .color(.ink), lineWidth: line)
            let handle = Path(roundedRect: CGRect(x: 22, y: 28, width: 52, height: 16), cornerRadius: 8)
            context.fill(handle, with: .color(.volt))
            context.stroke(handle, with: .color(.ink), lineWidth: line)
            let dial = Path(ellipseIn: CGRect(x: 82, y: 30, width: 12, height: 12))
            context.fill(dial, with: .color(.paperRaised))
            context.stroke(dial, with: .color(.ink), lineWidth: line * 0.8)
        }
        .frame(width: width, height: height)
        .scaleEffect(isLifted ? 1.08 : 1, anchor: Self.pivot)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// The soleplate outline, also used for the footprint.
    static let soleplate: Path = {
        var path = Path()
        path.move(to: CGPoint(x: 8, y: 8))
        path.addLine(to: CGPoint(x: 78, y: 8))
        path.addQuadCurve(to: CGPoint(x: 116, y: 36), control: CGPoint(x: 114, y: 14))
        path.addQuadCurve(to: CGPoint(x: 78, y: 64), control: CGPoint(x: 114, y: 58))
        path.addLine(to: CGPoint(x: 8, y: 64))
        path.addQuadCurve(to: CGPoint(x: 4, y: 60), control: CGPoint(x: 4, y: 64))
        path.addLine(to: CGPoint(x: 4, y: 12))
        path.addQuadCurve(to: CGPoint(x: 8, y: 8), control: CGPoint(x: 4, y: 8))
        path.closeSubpath()
        return path
    }()

    private static let body: Path = {
        var path = Path()
        path.move(to: CGPoint(x: 16, y: 16))
        path.addLine(to: CGPoint(x: 76, y: 16))
        path.addQuadCurve(to: CGPoint(x: 104, y: 36), control: CGPoint(x: 102, y: 20))
        path.addQuadCurve(to: CGPoint(x: 76, y: 56), control: CGPoint(x: 102, y: 52))
        path.addLine(to: CGPoint(x: 16, y: 56))
        path.closeSubpath()
        return path
    }()
}

/// Everything except the iron's trail: the crumpled layer stays visible where the soleplate hasn't pressed.
struct IronTrailMask: View {
    let trail: [IronStamp]
    let ironWidth: CGFloat
    /// Where the card's top-left corner sits inside the mask.
    var origin: CGPoint = .zero

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
            context.blendMode = .destinationOut
            let scale = ironWidth / IronView.designSize.width
            for stamp in trail {
                let transform = CGAffineTransform(translationX: origin.x + stamp.point.x, y: origin.y + stamp.point.y)
                    .rotated(by: stamp.angle)
                    .scaledBy(x: scale, y: scale)
                    .translatedBy(x: -60, y: -36)
                context.fill(IronView.soleplate.applying(transform), with: .color(.black))
            }
        }
    }
}
