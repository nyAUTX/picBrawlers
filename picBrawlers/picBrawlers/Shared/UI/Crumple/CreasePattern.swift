import CoreGraphics

/// The crease facets of a crumpled card: a jittered 4 × 5 grid cut into light and dark triangles,
/// with valleys along the rows and ridges along the columns. Coordinates are in the unit square.
nonisolated struct CreasePattern: Equatable, Sendable {
    struct Facet: Equatable, Sendable {
        let points: [CGPoint]
        let isLight: Bool
        let opacity: Double
    }

    static let columns = 4
    static let rows = 5

    let facets: [Facet]
    let valleys: [[CGPoint]]
    let ridges: [[CGPoint]]

    init(seed: Float) {
        var random = SeededRandom(seed: UInt32(seed * 7919))
        let columns = Self.columns, rows = Self.rows
        var grid: [CGPoint] = []
        for row in 0...rows {
            for column in 0...columns {
                var x = Double(column) / Double(columns)
                var y = Double(row) / Double(rows)
                if column > 0 && column < columns { x += (random.next() - 0.5) * 0.18 }
                if row > 0 && row < rows { y += (random.next() - 0.5) * 0.14 }
                grid.append(CGPoint(x: x, y: y))
            }
        }
        func at(_ column: Int, _ row: Int) -> CGPoint { grid[row * (columns + 1) + column] }

        var facets: [Facet] = []
        func facet(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> Facet {
            let isLight = random.next() < 0.5
            return Facet(points: [a, b, c], isLight: isLight, opacity: 0.08 + random.next() * 0.22)
        }
        for row in 0..<rows {
            for column in 0..<columns {
                let a = at(column, row), b = at(column + 1, row), c = at(column + 1, row + 1), d = at(column, row + 1)
                if random.next() < 0.5 {
                    facets.append(facet(a, b, c)); facets.append(facet(a, c, d))
                } else {
                    facets.append(facet(a, b, d)); facets.append(facet(b, c, d))
                }
            }
        }
        self.facets = facets
        valleys = (1..<rows).map { row in (0...columns).map { at($0, row) } }
        ridges = (1..<columns).map { column in (0...rows).map { at(column, $0) } }
    }
}

/// A tiny deterministic generator (LCG), the same one the design system's web preview uses.
nonisolated struct SeededRandom {
    private var state: UInt32
    init(seed: UInt32) { state = seed }

    /// The next value in 0 ..< 1.
    mutating func next() -> Double {
        state = state &* 1_664_525 &+ 1_013_904_223
        return Double(state) / 4_294_967_296
    }
}
