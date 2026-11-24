import SwiftUI

nonisolated extension CardCategory {
    /// The category's name as the player sees it. Always shown next to its icon, never as color alone.
    var title: String {
        switch self {
        case .tank: String(localized: "Tank")
        case .damageDealer: String(localized: "Damage Dealer")
        case .support: String(localized: "Support")
        }
    }

    var systemImage: String {
        switch self {
        case .tank: "shield.fill"
        case .damageDealer: "flame.fill"
        case .support: "cross.fill"
        }
    }
}

extension CardCategory {
    /// The category fill. Text and icons on it use `Color.onFill`.
    var fill: Color {
        switch self {
        case .tank: .tank
        case .damageDealer: .damage
        case .support: .support
        }
    }
}
