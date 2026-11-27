import SwiftUI
import UIKit

/// Lets single screens limit the orientations the app may turn to. The app delegate asks it on every rotation.
enum OrientationLock {
    static let defaultMask: UIInterfaceOrientationMask = .allButUpsideDown
    private(set) static var mask = defaultMask

    static func set(_ newMask: UIInterfaceOrientationMask) {
        mask = newMask
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: newMask))
            for window in scene.windows {
                window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        OrientationLock.mask
    }
}

extension View {
    /// Keeps the app upright while this view is on screen, e.g. the fight board with its three-card rows.
    func portraitOnly() -> some View {
        onAppear { OrientationLock.set(.portrait) }
            .onDisappear { OrientationLock.set(OrientationLock.defaultMask) }
    }
}
