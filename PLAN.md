# PicBrawlers – Project Plan

Based on [README.md](README.md). PicBrawlers is a TCG-style game: players turn photos from their gallery into fighter cards, fight 3-vs-3 battles against friends and trade cards with each other.

**Current state:** the Xcode template, using SwiftUI and SwiftData with the placeholder `Item` model. It currently targets iOS/iPadOS/visionOS 27.2. No game code exists yet.

---

## 0. Decisions

| Topic | Decision |
|---|---|
| Card at stake | **The winner takes the original.** The loser's staked card changes owner for good |
| Turn structure | **2 cards act per turn**: each turn, 2 of your cards each perform one action |
| "Klassen vorerst nicht" | **Elements/types** (fire/water-style strengths and weaknesses) are postponed |
| Opponents | **Friends only**, invited by friend code or link. No random matchmaking and no bot mode for players |
| Card creation | **Daily limit** on new cards per player, enforced by the server |
| Platforms | **iPhone only** for now |
| Backend | **Supabase** in the EU region |
| Language | **German only.** UI and AI-generated texts are in German; code and identifiers are in English |
| App architecture | **MVVM**, developed **test-first** |
| Quality bar | Every screen has empty, loading and error states. Errors explain what happened, why, and what to do. Haptics for meaningful moments, App Intents for the main actions, full accessibility support. Design follows the apple-design skill. Details in [CLAUDE.md](CLAUDE.md) |

---

## 1. Core concepts

### Card
| Field | Source | Notes |
|---|---|---|
| Image | User, from the gallery | Picked with `PhotosPicker`, which needs no full photo-library permission |
| Name | User | Free text, length-limited, moderated |
| Category | User | `Tank`, `Damage Dealer` or `Support` |
| Health / Damage | Generated | Rolled randomly inside the category's range (see below) |
| Attack | AI | Name and flavor text based on the image, e.g. *Gulaschkanone*, *Schnitzelklopfer*, *Fußball ins Gesicht* |
| Special ability | AI | Name and flavor text; the **mechanical effect comes from a fixed list** |
| Weaknesses | AI | Flavor only (fun fact), with no game effect, e.g. *Spritpreis*, *Schlagloch*, *Deutsche Wanderer (Flipflops)* |
| Condition | Game | `fresh` or `crumpled` (knocked out). After the fight every card is "ironed" back to fresh |
| Owner / creator | Server | The owner changes on trade or a lost stake; the creator stays the same |

### Category stat ranges (first draft, to be balanced in playtests)
| Category | Health | Damage | Special effects allowed |
|---|---|---|---|
| Tank | 130–170 | 10–20 | Taunt/shield self, damage reduction |
| Damage Dealer | 60–90 | 30–45 | Burst damage, damage over time |
| Support | 90–110 | 12–22 | **Protect / heal / buff other cards** |

### Key design rule: the AI writes the flavor, the engine owns the numbers
The AI chooses an attack/special *name and description* (in German) plus an `effectType` from a closed list (`heal`, `shield`, `buff`, `burst`, `dot`, `taunt`). The engine sets the actual values from the category and card stats. This keeps the game balanced and cheat-resistant no matter what the AI returns.

### Fight rules (draft)
1. **Invite:** a player challenges a friend. Each player brings **3 cards**.
2. **Stake:** each player picks **one of their 3 cards to put at stake**. Both players see both stakes and must confirm before the fight starts.
3. **Turns:** players alternate turns. On a turn you choose **2 of your non-crumpled cards**, and each does one action: its attack or its special. With only 1 card left, you get 1 action.
4. **Knockout:** a card at 0 HP is **crumpled** and out for the rest of the fight.
5. **Win:** you win when all 3 of the opponent's cards are crumpled.
6. **Afterwards:** all cards are **ironed** (fully restored), and **the winner receives the loser's staked card**.

### Trading
- Friends offer cards in exchange for other cards. Both sides confirm, then ownership moves atomically on the server.
- A card that is in an open trade offer or staked in a running fight is locked.

---

## 2. Architecture

```
iOS app (SwiftUI + SwiftData, iPhone, MVVM)
 ├─ Features/<Feature>/: View + @Observable ViewModel
 │    Collection · Card Creator · Friends · Fight · Trade · Profile
 ├─ Intents/: AppEntities, App Intents, App Shortcuts (Siri, Shortcuts, Spotlight)
 ├─ Shared/UI: button style, card view, empty/loading/error views
 ├─ Services/ (behind protocols, faked in tests):
 │    repositories (SwiftData), API client (supabase-swift),
 │    card generation, haptics
 ├─ GameEngine (pure Swift package, no UI, fully unit-tested)
 └─ Local store (SwiftData): cached cards, images, in-progress fights
          │  HTTPS
Supabase (EU region)
 ├─ Auth: Sign in with Apple
 ├─ Postgres: users, friendships, cards, decks, matches, trades (row-level security)
 ├─ Storage: card images
 ├─ Edge functions: generate-card (daily limit + moderation + AI + stat roll),
 │                  resolve-turn, finish-match (stake transfer), trade
 ├─ Realtime: match updates, trade offers
 └─ AI: vision LLM called only from the edge function (the API key never ships in the app)
```

**AI generation:** a Claude vision model behind the `generate-card` function (start with `claude-haiku-5-5` for cost, move to `claude-sonnet-5-5` if quality is lacking). The function returns structured JSON (`attack`, `special` + `effectType`, `weaknesses[]`), written in German. The prompt includes the README's attack/weakness lists as style examples, and the model can invent new ones in the same tone.

**Authority:** stats are rolled, turns are resolved and ownership is transferred **on the server**. Until Phase 3 the same rules run locally in `GameEngine`. Edge functions run TypeScript, so the server-side rules will be a TypeScript port of the engine. Both versions are checked against the same JSON test cases so they can't drift apart.

---

## 3. Roadmap

### Phase 0 – Foundations ✅
- [x] Fix the repo layout: `picBrawlers/` contains its **own nested `.git`** (Xcode's template commit). Keep one repository, most likely the root one.
- [x] Add `.DS_Store` to `.gitignore`.
- [x] Limit the target to iPhone (`TARGETED_DEVICE_FAMILY = 1`, removing iPad and visionOS).
- [x] Remove the template `Item` model and list UI.
- [x] Set up the MVVM folder structure (`App/`, `Features/`, `Resources/`, `Services/`, `Shared/`) and a German String Catalog. `GameEngine/`, `Intents/` and `Models/` are added with their first code in Phase 1/2.
- [x] Switch both test targets to the TDD setup: Swift Testing for unit tests, XCUITest with `performAccessibilityAudit()` for UI tests.
- [x] Shared building blocks, each test-first:
  - `ViewState<Value>` with empty/loading/loaded/failed
  - `AppError: LocalizedError` with German description, reason and suggestion
  - empty, loading and error views
  - `HapticsService`
  - a press-down `ButtonStyle` and spring presets

### Phase 1 – Card creation, offline MVP
- [ ] `Card` SwiftData model + `Category` enum + `SpecialEffect` enum
- [ ] Card creator flow: pick photo → crop → enter name → choose category → "generieren"
- [ ] Local stat roll per category range
- [ ] **Stub AI** that picks a random attack/special/weakness from the README lists
- [ ] Card view (front design: image, name, category badge, HP/DMG, attack, special, weaknesses), readable as one VoiceOver element and working at large Dynamic Type sizes
- [ ] Collection screen (grid, detail opening from its card, delete with confirmation)
- [ ] Empty collection state, staged loading while generating, clear errors (photo can't be loaded, generation failed)
- [ ] App Intents: `CardEntity` + Spotlight indexing, `OpenCardIntent`, `ShowCollectionIntent`, `CreateCardIntent`, App Shortcuts with German phrases

### Phase 2 – Fight engine, local
- [ ] `GameEngine` package: state, the "2 cards act per turn" rule, turn resolution, win check, crumple/iron, stake result
- [ ] Support effects (heal / shield / buff), Tank taunt, DD burst/DoT
- [ ] Unit tests for every rule (Swift Testing)
- [ ] Fight UI in **pass-and-play mode** on one phone (only for development and playtesting, since there is no bot mode)
- [ ] Crumple / iron animations, with cross-fade variants for Reduce Motion
- [ ] Haptics for selection, hits, crumpling, healing, win and loss, on the same frame as the animation
- [ ] VoiceOver: fight actions as accessibility actions, with announcements for damage and knockouts

### Phase 3 – Supabase + real AI
- [ ] Supabase project (EU region), Sign in with Apple, user profile
- [ ] Image upload + card sync (offline cache stays in SwiftData)
- [ ] `generate-card` function: daily limit check → moderation → vision LLM → validated JSON → server-side stat roll
- [ ] Show remaining daily creations in the creator

### Phase 4 – Friends & multiplayer fights
- [ ] Friends list: add by friend code or invite link (universal link), accept/remove
- [ ] Challenge a friend → stake selection and confirmation by both players
- [ ] Server-validated turns (async turn-based first, real-time later)
- [ ] `finish-match`: atomic transfer of the staked card to the winner
- [ ] Push notifications ("Du bist dran", "Neue Herausforderung")
- [ ] `ChallengeFriendIntent`; empty states for no friends and no fights

### Phase 5 – Trading
- [ ] Trade offers between friends, accept/decline, atomic ownership transfer
- [ ] Locking of cards that are in a trade offer or a running fight
- [ ] Trade and fight history

### Phase 6 – Polish & release
- [ ] Sounds (fired together with haptics), onboarding/tutorial (in German)
- [ ] Widgets (e.g. "Karte des Tages", open challenges) built on the existing App Intents
- [ ] Full accessibility pass: VoiceOver, Dynamic Type, Reduce Motion/Transparency, Increase Contrast
- [ ] Balance pass based on playtest data
- [ ] App Store compliance (see risks), privacy policy, TestFlight

### Later
- Elements/types with strengths and weaknesses against each other
- iPad (and maybe visionOS)

---

## 4. Risks & things to get right early

- **Photos of real people + roast-style attacks.** Attacks like *Bierflasche (Person sieht alkoholisiert aus)* make claims about real people. Because the winner takes the original card, a photo can end up with someone the person in it never agreed to. Friends-only play limits this, but plan for:
  - consent wording in the creator flow
  - AI guardrails: playful rather than insulting, no sensitive traits
  - image moderation (nudity, violence, minors)
  - report/block features, which App Store Guideline 1.2 requires for user-generated content
  - a way for the creator, or the person shown, to have a card removed even after it changed owner
- **Losing cards for good.** Losing a favorite card can drive players away. Both players confirming the stakes before the fight helps, and the history screen makes losses traceable.
- **Privacy (GDPR).** Photos are sent to Supabase and to an AI provider. This needs a privacy policy, account and data deletion, the EU region and minimal retention.
- **Two copies of the rules.** Swift (client) and TypeScript (server) versions of the engine can drift apart. Shared JSON test cases guard against that.
- **Balance.** AI output must never set numbers directly (see the design rule above).
- **AI cost.** The daily limit caps it, and each card is generated once and cached.

---

## 5. Remaining open questions

1. How many cards can a player create per day (e.g. 3)? Does the limit reset at midnight local time?
2. Can the new owner of a won card trade it on or stake it again?
3. Can the person shown in a photo (rather than the card's creator) request removal, and how would they prove it's them?
