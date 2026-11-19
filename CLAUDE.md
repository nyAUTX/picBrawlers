# PicBrawlers – Working Conventions

iPhone trading card game built with SwiftUI and SwiftData. [README.md](README.md) describes the game, and [PLAN.md](PLAN.md) holds decisions and the roadmap. Code, identifiers and comments are in English; everything the player sees is in German.

These rules apply to every change.

## Architecture: MVVM

- Each feature lives in `Features/<Feature>/` with `<Name>View.swift` and `<Name>ViewModel.swift`.
- **Views** only lay out and bind. They contain no business logic, networking or persistence calls.
- **ViewModels** are `@Observable` and `@MainActor` classes. They hold screen state (`ViewState`, see below) and expose intent methods such as `createCard()` and `attack(with:target:)`.
- **Dependencies** are injected through protocols (`CardRepository`, `CardGenerationService`, `HapticsService`, …) so tests can swap them for fakes. Production implementations live in `Services/`.
- **SwiftData** stays behind repositories. ViewModels don't touch `ModelContext`, and views don't use `@Query`.
- **Game rules** live in `GameEngine/`, which is pure Swift with no SwiftUI, SwiftData or networking. ViewModels call the engine; the engine never knows about the UI.

## Test-driven development

- Write the failing test first, then the code that makes it pass, then refactor.
- **Unit tests** use Swift Testing (`import Testing`, `@Test`, `#expect`). This covers every `GameEngine` rule, every ViewModel state transition, and the error mapping.
- **UI tests** use XCTest/XCUITest for the main flows: create a card, fight, trade. Each UI test also runs `XCUIApplication().performAccessibilityAudit()`.
- Tests use fakes, never the real backend or AI. Stat rolls take an injectable random number generator so results are deterministic.
- A bug fix starts with a test that reproduces the bug.

## Screen states: empty, loading, error

Every screen that loads data models its state explicitly:

```swift
enum ViewState<Value> {
    case loading
    case empty
    case loaded(Value)
    case failed(AppError)
}
```

- **Empty:** use `ContentUnavailableView` with a German title, one sentence of explanation and a button for the next step. Example: no cards yet → "Erstelle deine erste Karte". This applies to the collection, friends, fights, trades and search with no results.
- **Loading:**
  - Show placeholders in the final layout (`.redacted(reason: .placeholder)`) instead of a bare spinner.
  - Long tasks such as card generation show named stages ("Foto wird analysiert …", "Angriff wird erfunden …") and can be cancelled.
  - Loading never blocks unrelated input.
- **Error:** see the next section.

## Errors

- All errors the user can see are an `AppError` (`Shared/Errors/AppError.swift`), a `LocalizedError` with three German texts:
  - `errorDescription`: what happened. This is the `title` the caller passes, e.g. `AppError(title: String(localized: "Karte konnte nicht erstellt werden"), error: error)`.
  - `failureReason`: why ("Keine Internetverbindung."), derived from the `Cause`.
  - `recoverySuggestion`: what to do ("Prüfe deine Verbindung und versuch es noch einmal."), also derived from the `Cause`.
- `AppError(title:error:)` maps thrown errors (e.g. `URLError`) to a `Cause`. New causes need a German reason and suggestion, plus tests.
- Errors offer an action wherever one exists (retry, open Settings, choose another photo).
- Show errors where they happened: inline for form fields, in the screen's `failed` state for loading. Use an alert only when there's no better place.
- Never show raw error messages, status codes or stack traces to the player. Log the underlying error with `Logger` (OSLog).
- Validate inline while the player types (for example the card name), not only on submit.

## Haptics

- Use SwiftUI's `.sensoryFeedback(_:trigger:)`, wrapped by `HapticsService` for anything not driven by a view.
- Haptics fire **on the same frame** as the animation and sound they belong to, and they must match what caused them.
- Keep them for meaningful moments, otherwise players start ignoring them:

| Moment | Feedback |
|---|---|
| Selecting a card / target | `.selection` |
| Attack hits | `.impact(weight: .medium)`; `.heavy` for big hits |
| Card is crumpled | `.impact(weight: .heavy)` |
| Heal / shield / buff | `.impact(flexibility: .soft)` |
| Card created, fight won, trade accepted | `.success` |
| Fight lost | `.error` |
| Invalid action (e.g. a crumpled card can't act) | `.warning` |

## App Intents

Expose the main actions to Siri, Shortcuts, Spotlight and widgets:

- `CardEntity: AppEntity` (and `IndexedEntity` for Spotlight) plus `CardQuery`
- `OpenCardIntent`, `ShowCollectionIntent`
- `CreateCardIntent`, which takes a photo as input and opens the creator
- `ChallengeFriendIntent` (once multiplayer exists)
- An `AppShortcutsProvider` with German phrases, e.g. "Neue Karte in \(.applicationName)"

Intents call the same ViewModels/services as the UI; they never duplicate logic. Every intent gets unit tests.

## Accessibility

- **VoiceOver:**
  - Each card reads as one element (`.accessibilityElement(children: .combine)`), e.g. "Oma Gerti, Tank, 150 Leben, 15 Schaden, Angriff: Gulaschkanone".
  - Fight actions are available as `.accessibilityAction`s.
  - Card photos get a short description, generated by the AI together with the attack.
- **Dynamic Type:**
  - Use system text styles only (no fixed font sizes).
  - Layouts must work up to accessibility sizes; switch to vertical layouts with `ViewThatFits` or `dynamicTypeSize` where needed.
- **Color:** never carry information by color alone. Categories always show an icon and a label as well.
- **Settings:** respect Reduce Motion (crumple/iron become cross-fades), Reduce Transparency (solid backgrounds instead of materials) and Increase Contrast.
- **Hit targets:** at least 44×44 pt.
- **Full-screen states:** wrap them in `.scrollableWhenTooTall()` so they scroll instead of clipping at large text sizes (`EmptyStateView` and `ErrorView` already do).
- **Long German words:** compound words can't wrap. Keep titles short; the accessibility audit flags long ones (e.g. "Tauschangebote") as clipped.
- **Checks:** check every new screen with Accessibility Inspector, in addition to the automated audit in the UI tests.

## Design & motion

Based on the [apple-design skill](https://github.com/emilkowalski/skills/blob/main/skills/apple-design/SKILL.md). That skill is written for the web; these are the SwiftUI equivalents:

- **Respond on touch-down.** Buttons and cards react as soon as they're pressed (a custom `ButtonStyle` scaling to about 0.97). Never add artificial delays.
- **Springs:**
  - Default to `.spring(duration: 0.4, bounce: 0)`.
  - Use `bounce: 0.2` only after a gesture with momentum, such as flinging a card.
  - Sheets and drawers: about `.spring(duration: 0.3, bounce: 0.2)`.
- **Interruptible:** never lock input during an animation. New animations start from where the view is right now.
- **Direct manipulation:**
  - Dragged cards follow the finger 1:1 and keep the grab offset.
  - On release, carry the gesture's velocity into the spring so there's no visible seam between drag and animation.
- **Spatial consistency:**
  - Things leave the way they came in.
  - Detail views open from their card (`.navigationTransition(.zoom)` / `matchedTransitionSource`).
- **Materials:**
  - Use system materials and glass for floating UI.
  - Don't stack translucent layers on each other.
  - Use a dimming background only for modal tasks.
- **Typography:** system font, hierarchy built from weight and size together, Dynamic Type everywhere.
- **Undo and confirmation:** offer undo for small slips. Ask for confirmation only for destructive or irreversible actions: deleting a card, confirming a stake, accepting a trade.
- **Wayfinding and labels:**
  - Every screen shows where you are and how to get back.
  - Use specific tab and button labels ("Sammlung", "Kämpfe", "Tauschen") instead of vague ones ("Home").
- **Multimodal feedback:** visual, haptic and sound for one event fire together (see Haptics).
