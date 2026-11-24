import CoreGraphics
import Testing
@testable import picBrawlers

@Suite("Iron itinerary")
struct IronItineraryTests {
    /// Three compact cards side by side, as on an iPhone.
    private let frames = [
        CGRect(x: 0, y: 0, width: 110, height: 300),
        CGRect(x: 134, y: 0, width: 110, height: 300),
        CGRect(x: 268, y: 0, width: 110, height: 300),
    ]
    private let start = CGPoint(x: -100, y: 150)
    private let exit = CGPoint(x: 500, y: 150)

    private func itinerary(ironing: [Int] = [0, 2]) -> IronItinerary {
        IronItinerary(cardFrames: frames, ironing: ironing, start: start, exit: exit)
    }

    @Test func onlyCrumpledCardsAreIroned() {
        let plan = itinerary()
        #expect(plan.ironedCards == [0, 2])
        #expect(!plan.segments.contains { $0.card == 1 && $0.kind == .press })
    }

    @Test func eachCardGetsFiveBackAndForthStrokes() {
        let plan = itinerary()
        for card in [0, 2] {
            let strokes = plan.segments.filter { $0.card == card && $0.kind == .press && $0.from.y == $0.to.y }
            #expect(strokes.count == 5)
            let directions = strokes.map { $0.to.x > $0.from.x }
            #expect(directions == [true, false, true, false, true])
        }
    }

    @Test func strokesWorkTheCardFromTopToBottom() {
        let rows = itinerary().segments
            .filter { $0.card == 0 && $0.kind == .press && $0.from.y == $0.to.y }
            .map(\.from.y)
        #expect(rows == rows.sorted())
        #expect(rows.first! < 60 && rows.last! > 240)
    }

    @Test func ironStartsLiftedAndEndsAtTheExit() {
        let plan = itinerary()
        let first = plan.pose(at: 0)
        #expect(first.position == start)
        #expect(first.isLifted)
        let last = plan.pose(at: plan.duration)
        #expect(abs(last.position.x - exit.x) < 0.001 && abs(last.position.y - exit.y) < 0.001)
        #expect(last.isLifted)
    }

    @Test func ironIsLiftedBetweenCardsAndPressedOnThem() {
        let plan = itinerary()
        let landing = plan.landingTime(ofCard: 0)!
        let finish = plan.finishTime(ofCard: 0)!
        let pressed = plan.pose(at: (landing + finish) / 2)
        #expect(!pressed.isLifted)
        #expect(pressed.card == 0)
        let gliding = plan.pose(at: (finish + plan.landingTime(ofCard: 2)!) / 2)
        #expect(gliding.isLifted)
        #expect(gliding.card == nil)
    }

    @Test func cardsAreIronedOneAfterAnother() {
        let plan = itinerary()
        #expect(plan.finishTime(ofCard: 0)! < plan.landingTime(ofCard: 2)!)
        #expect(plan.landingTime(ofCard: 1) == nil)
    }

    @Test func aCardTakesAboutASecondAndAHalf() {
        let plan = itinerary(ironing: [0])
        let perCard = plan.finishTime(ofCard: 0)! - plan.landingTime(ofCard: 0)!
        #expect(perCard > 0.8 && perCard < 2.0)
    }

    @Test func aFullWidthCardTakesAboutAsLongAsASmallOne() {
        // One card per row on an iPhone: 370 pt wide at the 63:88 ratio.
        let big = IronItinerary(
            cardFrames: [CGRect(x: 0, y: 0, width: 370, height: 517)],
            ironing: [0],
            start: CGPoint(x: -100, y: 258),
            exit: CGPoint(x: 500, y: 258)
        )
        let perCard = big.finishTime(ofCard: 0)! - big.landingTime(ofCard: 0)!
        let small = itinerary(ironing: [0])
        let smallPerCard = small.finishTime(ofCard: 0)! - small.landingTime(ofCard: 0)!
        #expect(perCard > 0.8 && perCard < 2.0)
        #expect(abs(perCard - smallPerCard) < 0.3)
    }

    @Test func ironFacesTheWayItMoves() {
        let plan = itinerary(ironing: [0])
        let strokes = plan.segments.filter { $0.card == 0 && $0.kind == .press && $0.from.y == $0.to.y }
        let rightward = plan.pose(at: strokes[0].start + strokes[0].duration * 0.8)
        let leftward = plan.pose(at: strokes[1].start + strokes[1].duration * 0.8)
        #expect(abs(rightward.angle) < 0.01)
        #expect(abs(abs(leftward.angle) - .pi) < 0.01)
    }

    @Test func noFootprintsBeforeTheIronLands() {
        let plan = itinerary()
        #expect(plan.footprints(ofCard: 2, at: plan.landingTime(ofCard: 2)! - 0.01).isEmpty)
    }

    @Test func footprintsFollowTheStrokesInCardCoordinates() {
        let plan = itinerary()
        let prints = plan.footprints(ofCard: 2, at: plan.finishTime(ofCard: 2)!)
        #expect(prints.count > 100)
        for stamp in prints {
            #expect((0...110).contains(stamp.point.x))
            #expect((0...300).contains(stamp.point.y))
        }
        let halfway = plan.footprints(ofCard: 2, at: (plan.landingTime(ofCard: 2)! + plan.finishTime(ofCard: 2)!) / 2)
        #expect(halfway.count < prints.count)
        #expect(halfway.count > 0)
    }

    @Test func nothingToIronMeansNoPressing() {
        let plan = itinerary(ironing: [])
        #expect(plan.ironedCards.isEmpty)
        #expect(!plan.segments.contains { $0.kind == .press })
    }
}
