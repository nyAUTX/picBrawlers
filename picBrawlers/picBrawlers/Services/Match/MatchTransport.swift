import Foundation

/// What one phone tells the other during a fight. Only choices travel, never the whole state;
/// the hash lets the receiver check that both phones still agree. The full protocol (hello, deck,
/// stake …) follows in Phase 4.
nonisolated enum MatchMessage: Hashable, Codable, Sendable {
    /// A played turn: its number, the actions and the hash of the state after it.
    case turn(number: Int, actions: [FightAction], stateHash: String)
    /// The turn timed out on the sender's phone.
    case timeout(number: Int, stateHash: String)
    case resign(MatchSide)
}

/// Carries `MatchMessage`s between the two phones. The fight screen doesn't know how they are connected:
/// Game Center, nearby play, or (in debug builds) both players on one phone.
@MainActor
protocol MatchTransport: AnyObject {
    /// The sides this phone plays. One for a real fight, both for pass-and-play.
    var localSides: Set<MatchSide> { get }
    /// Messages from the other phone, in the order they were sent.
    var incoming: AsyncStream<MatchMessage> { get }
    func send(_ message: MatchMessage) async throws
}
