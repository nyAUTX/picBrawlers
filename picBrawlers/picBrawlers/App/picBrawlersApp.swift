import AppIntents
import SwiftUI

@main
struct picBrawlersApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var environment: AppEnvironment

    init() {
        let environment = AppEnvironment.launch()
        AppDependencyManager.shared.add(dependency: environment)
        _environment = State(initialValue: environment)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
                // Set explicitly: the global accent from the asset catalog wasn't picked up (buttons showed system blue).
                .tint(Color("AccentColor"))
        }
    }
}
