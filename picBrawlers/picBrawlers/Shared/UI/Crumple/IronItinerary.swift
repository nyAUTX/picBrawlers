import CoreGraphics
import Foundation

/// Where the iron is at a moment of the ironing.
nonisolated struct IronPose: Equatable, Sendable {
    let position: CGPoint
    /// Direction of travel in radians: 0 points right, π points left.
    let angle: Double
    let isLifted: Bool
    /// The card being pressed, if any.
    let card: Int?
}

/// One footprint of the soleplate, in the card's own coordinates.
nonisolated struct IronStamp: Equatable, Sendable {
    let point: CGPoint
    let angle: Double
}

/// The iron's path over a lineup after a fight: it glides to each crumpled card in turn, works it in
/// five back-and-forth strokes from top to bottom, then glides on and leaves. Everything is a pure
/// function of time, so views can draw any frame and tests can check any moment.
nonisolated struct IronItinerary: Equatable, Sendable {
    enum Kind: Equatable, Sendable { case glide, press }

    struct Segment: Equatable, Sendable {
        let from: CGPoint
        let to: CGPoint
        let kind: Kind
        let card: Int?
        let start: Double
        let duration: Double

        var end: Double { start + duration }
        var length: Double { hypot(to.x - from.x, to.y - from.y) }
        var angle: Double { atan2(to.y - from.y, to.x - from.x) }
    }

    /// Stroke rows, relative to the card height: band, photo, photo, stats, attack.
    static let strokeRows: [Double] = [0.10, 0.30, 0.50, 0.70, 0.90]
    /// Where a stroke turns, relative to the card width.
    static let turnInset = 0.16
    /// Points per second while pressing a stroke, on a card `referenceCardWidth` wide.
    static let pressSpeed = 560.0
    /// Points per second while gliding, lifted, between cards, on a card `referenceCardWidth` wide.
    static let glideSpeed = 900.0
    /// Bigger cards get a proportionally faster iron, so a card always takes about the same time.
    static let referenceCardWidth = 110.0
    static let minimumGlide = 0.15
    /// How long the iron takes to turn into a new direction.
    static let turnDuration = 0.08
    /// Distance between two footprints on the trail.
    static let stampSpacing = 4.0

    let segments: [Segment]
    let ironedCards: [Int]
    let duration: Double
    private let frames: [Int: CGRect]

    init(cardFrames: [CGRect], ironing: [Int], start: CGPoint, exit: CGPoint) {
        let cards = ironing.filter { cardFrames.indices.contains($0) }
        let averageWidth = cards.isEmpty ? Self.referenceCardWidth
            : cards.map { Double(cardFrames[$0].width) }.reduce(0, +) / Double(cards.count)
        let speedScale = max(1, averageWidth / Self.referenceCardWidth)

        var segments: [Segment] = []
        var time = 0.0
        var here = start
        func add(_ to: CGPoint, _ kind: Kind, card: Int?) {
            let length = hypot(to.x - here.x, to.y - here.y)
            let duration = kind == .press
                ? length / (Self.pressSpeed * speedScale)
                : max(Self.minimumGlide, length / (Self.glideSpeed * speedScale))
            segments.append(Segment(from: here, to: to, kind: kind, card: card, start: time, duration: duration))
            time += duration
            here = to
        }

        var frames: [Int: CGRect] = [:]
        for card in cards {
            let frame = cardFrames[card]
            frames[card] = frame
            var points: [CGPoint] = []
            for (row, height) in Self.strokeRows.enumerated() {
                let left = Self.turnInset, right = 1 - Self.turnInset
                let (from, to) = row.isMultiple(of: 2) ? (left, right) : (right, left)
                let y = frame.minY + height * frame.height
                points.append(CGPoint(x: frame.minX + from * frame.width, y: y))
                points.append(CGPoint(x: frame.minX + to * frame.width, y: y))
            }
            add(points[0], .glide, card: nil)
            for point in points.dropFirst() { add(point, .press, card: card) }
        }
        add(exit, .glide, card: nil)

        self.segments = segments
        self.ironedCards = cards
        self.duration = time
        self.frames = frames
    }

    func frame(ofCard card: Int) -> CGRect? { frames[card] }

    func landingTime(ofCard card: Int) -> Double? {
        segments.first { $0.card == card }?.start
    }

    func finishTime(ofCard card: Int) -> Double? {
        segments.last { $0.card == card }?.end
    }

    func pose(at time: Double) -> IronPose {
        let time = min(max(time, 0), duration)
        let index = segments.lastIndex { $0.start <= time } ?? 0
        let segment = segments[index]
        var progress = segment.duration > 0 ? min(1, (time - segment.start) / segment.duration) : 1
        if segment.kind == .glide { progress = progress * progress * (3 - 2 * progress) }
        let position = CGPoint(
            x: segment.from.x + (segment.to.x - segment.from.x) * progress,
            y: segment.from.y + (segment.to.y - segment.from.y) * progress
        )
        let previous = index > 0 ? segments[index - 1].angle : segment.angle
        let turn = min(1, (time - segment.start) / Self.turnDuration)
        let angle = Self.normalized(previous + Self.normalized(segment.angle - previous) * turn)
        return IronPose(position: position, angle: angle, isLifted: segment.kind == .glide, card: segment.kind == .press ? segment.card : nil)
    }

    /// Every footprint the soleplate has left on a card up to `time`, in the card's coordinates.
    func footprints(ofCard card: Int, at time: Double) -> [IronStamp] {
        guard let frame = frames[card] else { return [] }
        var stamps: [IronStamp] = []
        for segment in segments where segment.card == card && segment.start < time {
            let progress = segment.duration > 0 ? min(1, (time - segment.start) / segment.duration) : 1
            let travelled = segment.length * progress
            let dx = segment.length > 0 ? (segment.to.x - segment.from.x) / segment.length : 0
            let dy = segment.length > 0 ? (segment.to.y - segment.from.y) / segment.length : 0
            var distance = 0.0
            while distance <= travelled {
                stamps.append(IronStamp(
                    point: CGPoint(x: segment.from.x + dx * distance - frame.minX, y: segment.from.y + dy * distance - frame.minY),
                    angle: segment.angle
                ))
                distance += Self.stampSpacing
            }
        }
        return stamps
    }

    private static func normalized(_ angle: Double) -> Double {
        var angle = angle
        while angle > .pi { angle -= 2 * .pi }
        while angle <= -.pi { angle += 2 * .pi }
        return angle
    }
}
