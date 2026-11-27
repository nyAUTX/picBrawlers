import Foundation
import Testing
@testable import picBrawlers

@Suite("Crumple seed")
struct CrumpleSeedTests {
    private let oma = UUID(uuidString: "6F1C2B4A-0001-4000-8000-000000000001")!
    private let kevin = UUID(uuidString: "6F1C2B4A-0002-4000-8000-000000000002")!

    @Test func sameCardAlwaysCrumplesTheSameWay() {
        #expect(CrumpleSeed.seed(for: oma) == CrumpleSeed.seed(for: oma))
    }

    @Test func differentCardsCrumpleDifferently() {
        #expect(CrumpleSeed.seed(for: oma) != CrumpleSeed.seed(for: kevin))
    }

    @Test func seedStaysInAShaderFriendlyRange() {
        for _ in 0..<50 {
            let seed = CrumpleSeed.seed(for: UUID())
            #expect(seed >= 0 && seed < 1000)
        }
    }
}

@Suite("Crease pattern")
struct CreasePatternTests {
    @Test func sameSeedGivesTheSamePattern() {
        #expect(CreasePattern(seed: 42) == CreasePattern(seed: 42))
    }

    @Test func differentSeedsGiveDifferentPatterns() {
        #expect(CreasePattern(seed: 42) != CreasePattern(seed: 43))
    }

    @Test func gridOfFourByFiveCellsGivesFortyFacets() {
        #expect(CreasePattern(seed: 7).facets.count == 40)
    }

    @Test func facetsAreSubtleShading() {
        for facet in CreasePattern(seed: 7).facets {
            #expect(facet.opacity >= 0.08 && facet.opacity <= 0.30)
        }
    }

    @Test func pointsStayInsideTheCardAndEdgesStayOnTheEdges() {
        let pattern = CreasePattern(seed: 99)
        for facet in pattern.facets {
            for point in facet.points {
                #expect((0...1).contains(point.x) && (0...1).contains(point.y))
            }
        }
        // The outer frame of the grid is not jittered, so the card outline stays a rectangle.
        let corners = pattern.facets.flatMap(\.points).filter { ($0.x == 0 || $0.x == 1) && ($0.y == 0 || $0.y == 1) }
        #expect(Set(corners.map { "\($0.x),\($0.y)" }).count == 4)
    }

    @Test func hasRidgesAndValleysBetweenTheFacets() {
        let pattern = CreasePattern(seed: 7)
        #expect(pattern.valleys.count == 4)
        #expect(pattern.ridges.count == 3)
    }
}

@Suite("Crumple warp")
struct CrumpleWarpTests {
    @Test func smallCardsWarpByAShareOfTheirWidth() {
        #expect(abs(CrumpleWarp.strength(forCardWidth: 110) - 6.05) < 0.001)
    }

    @Test func fullWidthCardsStayLegible() {
        // One card per row on an iPhone is 370 pt wide; 5.5 % would be over 20 pt and garble the text.
        #expect(CrumpleWarp.strength(forCardWidth: 370) == CrumpleWarp.maximumStrength)
        #expect(CrumpleWarp.maximumStrength == 10)
    }

    @Test func aFlatCardDoesNotWarp() {
        #expect(CrumpleWarp.strength(forCardWidth: 0) == 0)
    }
}
