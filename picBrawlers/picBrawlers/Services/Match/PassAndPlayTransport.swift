#if DEBUG
import Foundation

/// Both players on one phone, handing it over between turns. For development and playtesting only:
/// it is compiled into debug builds and never ships.
@MainActor
final class PassAndPlayTransport: MatchTransport {
    let localSides: Set<MatchSide> = [.host, .guest]
    /// Nothing comes from outside: both sides are played here.
    let incoming = AsyncStream<MatchMessage> { $0.finish() }
    /// Every message the fight sent, for checking the protocol while playtesting.
    private(set) var sent: [MatchMessage] = []

    func send(_ message: MatchMessage) async throws {
        sent.append(message)
    }
}
#endif
