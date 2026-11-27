import SwiftUI

/// Light and dark crease facets, ridge and valley lines and a dog-ear, drawn over a crumpled card.
struct CreaseOverlay: View {
    let pattern: CreasePattern
    /// 0 flat … 1 crumpled.
    var amount: Double
    var cornerRadius: CGFloat = 12

    var body: some View {
        Canvas { context, size in
            func scaled(_ point: CGPoint) -> CGPoint { CGPoint(x: point.x * size.width, y: point.y * size.height) }
            func line(_ points: [CGPoint]) -> Path {
                var path = Path()
                path.addLines(points.map(scaled))
                return path
            }

            for facet in pattern.facets {
                var path = Path()
                path.addLines(facet.points.map(scaled))
                path.closeSubpath()
                let shade: Color = facet.isLight ? .white : .black
                context.fill(path, with: .color(shade.opacity(facet.opacity * amount)))
            }
            for valley in pattern.valleys {
                context.stroke(line(valley), with: .color(.black.opacity(0.5 * amount)), lineWidth: 1.5)
            }
            for ridge in pattern.ridges {
                context.stroke(line(ridge), with: .color(.white.opacity(0.75 * amount)), lineWidth: 1.5)
            }
        }
        .overlay(alignment: .bottomTrailing) { DogEar().opacity(max(0, (amount - 0.5) * 2)) }
        .clipShape(.rect(cornerRadius: cornerRadius))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The folded-over bottom-right corner of a crumpled card.
private struct DogEar: View {
    var body: some View {
        ZStack {
            FoldTriangle(isUnderside: false).fill(Color.paper)
            FoldTriangle(isUnderside: true).fill(Color.paperSunken)
            FoldTriangle(isUnderside: true).stroke(Color.ink, lineWidth: 3)
        }
        .frame(width: 30, height: 30)
    }
}

private nonisolated struct FoldTriangle: Shape {
    let isUnderside: Bool
    func path(in rect: CGRect) -> Path {
        var path = Path()
        if isUnderside {
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        } else {
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        }
        path.closeSubpath()
        return path
    }
}
