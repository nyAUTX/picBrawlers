import AppIntents
import UniformTypeIdentifiers

/// Opens one card in the collection.
struct OpenCardIntent: OpenIntent {
    static let title: LocalizedStringResource = "Karte öffnen"
    static let description = IntentDescription("Öffnet eine deiner Karten in der Sammlung.")

    @Parameter(title: "Karte")
    var target: CardEntity

    @Dependency private var environment: AppEnvironment

    init() {}

    init(target: CardEntity) {
        self.target = target
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        Self.open(target, with: environment.router)
        return .result()
    }

    @MainActor
    static func open(_ card: CardEntity, with router: AppRouter) {
        router.openCard(id: card.id)
    }
}

/// Shows the collection.
struct ShowCollectionIntent: AppIntent {
    static let title: LocalizedStringResource = "Sammlung zeigen"
    static let description = IntentDescription("Zeigt alle deine Karten.")
    static let supportedModes: IntentModes = .foreground

    @Dependency private var environment: AppEnvironment

    @MainActor
    func perform() async throws -> some IntentResult {
        Self.show(with: environment.router)
        return .result()
    }

    @MainActor
    static func show(with router: AppRouter) {
        router.showCollection()
    }
}

/// Opens the card creator, with a photo if one is passed in (e.g. shared from the Photos app via Shortcuts).
struct CreateCardIntent: AppIntent {
    static let title: LocalizedStringResource = "Karte erstellen"
    static let description = IntentDescription("Macht aus einem Foto eine neue Kämpferkarte.")
    static let supportedModes: IntentModes = .foreground

    @Parameter(title: "Foto", supportedContentTypes: [.image])
    var photo: IntentFile?

    @Dependency private var environment: AppEnvironment

    @MainActor
    func perform() async throws -> some IntentResult {
        Self.openCreator(photo: photo?.data, with: environment.router)
        return .result()
    }

    @MainActor
    static func openCreator(photo: Data?, with router: AppRouter) {
        router.openCreator(photo: photo)
    }
}

/// The phrases Siri and Spotlight offer without any setup.
struct PicBrawlersShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateCardIntent(),
            phrases: [
                "Neue Karte in \(.applicationName)",
                "Erstelle eine Karte in \(.applicationName)",
            ],
            shortTitle: "Neue Karte",
            systemImageName: "photo.badge.plus"
        )
        AppShortcut(
            intent: ShowCollectionIntent(),
            phrases: [
                "Zeig meine Sammlung in \(.applicationName)",
                "Öffne meine Karten in \(.applicationName)",
            ],
            shortTitle: "Sammlung",
            systemImageName: "rectangle.stack.fill"
        )
        AppShortcut(
            intent: OpenCardIntent(),
            phrases: [
                "Öffne \(\.$target) in \(.applicationName)",
                "Zeig \(\.$target) in \(.applicationName)",
            ],
            shortTitle: "Karte öffnen",
            systemImageName: "rectangle.portrait.fill"
        )
    }
}
