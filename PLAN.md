# PicBrawlers – Project Plan

Based on [README.md](README.md). PicBrawlers is a TCG-style game: players turn photos from their gallery into fighter cards, fight 3-vs-3 battles against friends and trade cards with each other.

**Current state:** Phases 0 and 1 are done. Players can turn a photo into a card, browse their collection, open and delete cards, and reach all of it from Siri, Shortcuts and Spotlight. Card texts still come from curated lists, and there are no fights yet.

---

## 0. Decisions

| Topic | Decision |
|---|---|
| Card at stake | **The winner takes the original.** The loser's staked card moves to the winner's phone for good |
| Turn structure | **2 cards act per turn**: each turn, 2 of your cards each perform one action |
| "Klassen vorerst nicht" | **Elements/types** (fire/water-style strengths and weaknesses) are postponed |
| Opponents | Remotely: **Game Center friends**. In person: **anyone nearby** who accepts the invite. No random matchmaking and no bot mode |
| Backend | **No server of our own.** Cards live on the phone. Remote fights use **Game Center live (real-time) matches**; in-person fights use **nearby play** (MultipeerConnectivity). iCloud backs up a player's own cards |
| Starting a fight | Remotely: Game Center invite. In person: the "Kampf in der Nähe" list, a QR code, or a challenge sent by AirDrop |
| Turn time | **30 seconds** per turn, so fights are live: both players have the app open |
| AI generation | **On-device:** the Vision framework plus Apple's on-device language model. Devices without Apple Intelligence fall back to the curated attack lists |
| Card creation | **Daily limit** on new cards per player, checked on the device |
| Platforms | **iPhone only** for now |
| Language | **German only.** UI and AI-generated texts are in German; code and identifiers are in English |
| App architecture | **MVVM**, developed **test-first** |
| Quality bar | Every screen has empty, loading and error states. Errors explain what happened, why, and what to do. Haptics for meaningful moments, App Intents for the main actions, full accessibility support. Design follows the apple-design skill. Details in [CLAUDE.md](CLAUDE.md) |

---

## 1. Core concepts

### Card
| Field | Source | Notes |
|---|---|---|
| ID | Device | A UUID that stays the same when the card changes phones |
| Image | User, from the gallery | Picked with `PhotosPicker`, which needs no full photo-library permission |
| Name | User | Free text, length-limited, moderated |
| Category | User | `Tank`, `Damage Dealer` or `Support` |
| Health / Damage | Generated | Rolled randomly inside the category's range (see below) |
| Attack | AI | Name and flavor text based on the image, e.g. *Gulaschkanone*, *Schnitzelklopfer*, *Fußball ins Gesicht* |
| Special ability | AI | Name and flavor text; the **mechanical effect comes from a fixed list** |
| Weaknesses | AI | Flavor only (fun fact), with no game effect, e.g. *Spritpreis*, *Schlagloch*, *Deutsche Wanderer (Flipflops)* |
| Photo description | AI | Short text for VoiceOver |
| Condition | Game | `fresh` or `crumpled` (knocked out). After the fight every card is "ironed" back to fresh |
| Creator / owner | Device | Player IDs. The owner changes on trade or a lost stake; the creator stays the same and travels with the card |

### Category stat ranges (first draft, to be balanced in playtests)
| Category | Health | Damage | Special effects allowed |
|---|---|---|---|
| Tank | 130–170 | 10–20 | Taunt/shield self, damage reduction |
| Damage Dealer | 60–90 | 30–45 | Burst damage, damage over time |
| Support | 90–110 | 12–22 | **Protect / heal / buff other cards** |

### Key design rule: the AI writes the flavor, the engine owns the numbers
The AI chooses an attack/special *name and description* (in German) plus an `effectType` from a closed list (`heal`, `shield`, `buff`, `burst`, `dot`, `taunt`). The engine sets the actual values from the category and card stats. This keeps the game balanced no matter what the AI returns, and it lets the receiving phone check every card it gets from an opponent.

### Fight rules (draft)
1. **Invite:** a player challenges someone (see "Starting a fight" below). Each player brings **3 cards**.
2. **Stake:** each player picks **one of their 3 cards to put at stake**. Both players see both stakes and must confirm before the fight starts.
3. **Turns:** players alternate turns, and each turn has a **30-second timer**. On a turn you choose **2 of your non-crumpled cards**, and each does one action: its attack or its special. With only 1 card left, you get 1 action.
4. **Knockout:** a card at 0 HP is **crumpled** and out for the rest of the fight.
5. **Win:** you win when all 3 of the opponent's cards are crumpled.
6. **Afterwards:** all cards are **ironed** (fully restored), and **the winner receives the loser's staked card**.

### Trading
- Players offer cards in exchange for other cards, over the same connections as fights (Game Center or nearby).
- Both sides confirm, then each phone hands over its card and stores the one it receives.
- A card that is in an open trade offer or staked in a running fight is locked.

---

## 2. Architecture

```
iOS app (SwiftUI + SwiftData, iPhone, MVVM)
 ├─ Features/<Feature>/: View + @Observable ViewModel
 │    Collection · Card Creator · Fight · Nearby · Trade · Profile
 ├─ Intents/: AppEntities, App Intents, App Shortcuts (Siri, Shortcuts, Spotlight)
 ├─ Shared/UI: button style, card view, empty/loading/error views
 ├─ Match/:
 │    MatchMessage (Codable protocol between two phones)
 │    MatchCoordinator (applies messages through GameEngine, checks state hashes,
 │                      validates everything received)
 ├─ Services/ (behind protocols, faked in tests):
 │    repositories (SwiftData), card generation (AI), haptics,
 │    MatchTransport: GameCenterTransport · NearbyTransport · PassAndPlayTransport
 ├─ GameEngine (pure Swift, no UI, fully unit-tested)
 └─ Local store (SwiftData): own cards, images, in-progress fights,
                             synced to the player's private iCloud as a backup

Apple services (no server of our own)
 ├─ Game Center: player identity, friends, invites, live matches
 ├─ MultipeerConnectivity: nearby discovery and a direct, encrypted connection
 │                         over peer-to-peer Wi-Fi or Bluetooth, no internet needed
 ├─ AirDrop / QR code: deliver a challenge to a phone nearby
 └─ iCloud (CloudKit private database via SwiftData): backup of the player's own cards
```

**One engine, many transports.** The fight screen and `MatchCoordinator` don't know how the other phone is connected. `MatchTransport` sends and receives `MatchMessage`s. Game Center, nearby play and pass-and-play are interchangeable implementations, and tests use a fake one.

**AI generation runs on the device.** The Vision framework detects what's in the photo (dog, bottle, football, face …). Apple's on-device language model (Foundation Models framework) then writes the attack, special, weaknesses and photo description from those labels, as structured German output. This costs nothing per card, needs no internet, and no photo leaves the phone for generation. It only runs on devices that support Apple Intelligence; other phones pick from the curated attack lists instead.

### Match protocol
Both phones run the same `GameEngine`. **Only actions are sent, never the whole game state.**

| Message | Content |
|---|---|
| `hello` | Protocol and app version, player name and ID |
| `deck` | The player's 3 cards: stats, texts and a small thumbnail (about 200 px, HEIC) |
| `stake` / `confirmStake` | The card put at stake, then both players' confirmation |
| `turn` | Turn number, the 2 actions, and a hash of the resulting game state |
| `resign` | Giving up |
| `stakedCard` | The full staked card, including the full-size image, sent to the winner at the end |

- **Sync check:** the receiving phone applies the actions with its own engine and compares state hashes. If they differ, the fight stops with a clear error, because the apps are out of sync or one was tampered with.
- **Randomness** (only if fights ever get random elements, such as critical hits): both players contribute half of a shared seed, so neither can rig the dice.
- **Validation:** everything received is untrusted. Message size, format, stats within the category ranges, `effectType` from the closed list and image size are all checked before use.
- **Turn timer:** both phones run the 30-second timer. A `turn` message must arrive within the time (plus a short grace period for network delay), otherwise both phones apply the timeout rule.
- **Size:** Game Center limits the size of a single message. Thumbnails keep the `deck` message small; the full-size image of the staked card is sent in chunks. Check the exact limit early in Phase 4.

### Starting a fight
| Where | How | Fight runs over |
|---|---|---|
| Remote | Invite a Game Center friend, who gets the invite as a notification and joins live | Game Center live match |
| Same room | "Kampf in der Nähe": nearby players running the app appear automatically; tap a name, the other player accepts | Nearby connection |
| Same room | Scan the opponent's QR code in the app | Nearby connection |
| Same room | "Herausfordern" → share sheet → AirDrop (or hold the iPhones together). The challenge file carries the challenger's cards and stake | Nearby connection |

Nearby play needs Wi-Fi and Bluetooth switched on, but no shared network and no internet. In every case both apps must stay open during the fight; a fight resumes if the connection comes back within a short reconnect window.

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

### Phase 1 – Card creation, offline MVP ✅
- [x] `CardRecord` SwiftData model behind `CardRepository`, plus `CardCategory` and `SpecialEffect`. Ready for iCloud sync: every property has a default, no unique constraints. The game works on the value type `FighterCard`. The `fresh`/`crumpled` condition is fight state and comes with the engine in Phase 2
- [x] Card creator flow: pick photo → enter name (checked while typing) → choose category → "Karte erstellen". The photo is shrunk to 1200 px and filled into the card window from the center; an interactive crop step is still open
- [x] Local stat roll per category range, with an injectable random number generator
- [x] **Stub AI** (`StubCardGenerationService`) that picks attack, special and weaknesses from curated lists; it stays as the fallback for iPhones without Apple Intelligence
- [x] Card view (front: photo, name, category band, HP/DMG, attack, special), readable as one VoiceOver element. Descriptions and weaknesses don't fit the printed face and are on the detail view
- [x] Collection screen: one card per row as the design system asks (instead of a grid), detail opening from its card with a zoom, delete with confirmation from the context menu, a VoiceOver action or the detail view
- [x] Empty collection state, named stages while generating (cancellable), clear errors (photo can't be loaded, generation or saving failed)
- [x] App Intents: `CardEntity` + Spotlight indexing, `OpenCardIntent`, `ShowCollectionIntent`, `CreateCardIntent` (takes a photo), App Shortcuts with German phrases

### Phase 2 – Fight engine, local
- [ ] `GameEngine` package: state, the "2 cards act per turn" rule, turn resolution, win check, crumple/iron, stake result
- [ ] Support effects (heal / shield / buff), Tank taunt, DD burst/DoT
- [ ] Deterministic state hash, so two phones can compare their game state
- [ ] Unit tests for every rule (Swift Testing)
- [ ] Fight UI in **pass-and-play mode** on one phone, built on `MatchTransport` from the start (only for development and playtesting, since there is no bot mode)
- [ ] 30-second turn timer with the timeout rule, a visible countdown, VoiceOver announcements as time runs out, and a haptic warning
- [ ] Crumple / iron animations, with cross-fade variants for Reduce Motion
- [ ] Haptics for selection, hits, crumpling, healing, win and loss, on the same frame as the animation
- [ ] VoiceOver: fight actions as accessibility actions, with announcements for damage and knockouts

### Phase 3 – Real AI & iCloud backup
- [ ] On-device card generation: Vision labels → Foundation Models with structured (guided) output in German, behind `CardGenerationService`. The curated lists stay as fallback for devices without Apple Intelligence
- [ ] On-device image checks before a card is created (nudity, violence)
- [ ] iCloud backup of the player's own cards (SwiftData + CloudKit private database)
- [ ] Daily creation limit on the device; show remaining creations in the creator

### Phase 4 – Fights with friends
- [ ] `MatchMessage` protocol and `MatchCoordinator`, test-first with a fake transport: message validation, sync check, stake confirmation, resign, stake transfer
- [ ] Game Center: sign-in, invite a friend, live matches, reconnect window after a dropped connection
- [ ] Nearby play: "Kampf in der Nähe" list open to anyone running the app, invitations showing both stakes, reconnect after a dropped connection, local block list
- [ ] Local-network permission prompt with a German explanation, plus an empty state with a Settings link when it's denied
- [ ] Challenge by QR code (in-app scanner) and by AirDrop (custom challenge file type via the share sheet), with validation of incoming files
- [ ] Stake selection and confirmation by both players; transfer of the staked card to the winner's phone
- [ ] `ChallengeFriendIntent`; empty states for no friends, no nearby players and no fights
- [ ] Test checklist on two real iPhones (the simulator is unreliable for nearby play)

### Phase 5 – Trading
- [ ] Trade offers over Game Center and nearby play, accept/decline, both phones confirm before cards move
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
- Slow fights with long turns (Game Center turn-based matches), for friends who can't play at the same time
- iPad (and maybe visionOS)

---

## 4. Risks & things to get right early

- **Photos of real people + roast-style attacks.** Attacks like *Bierflasche (Person sieht alkoholisiert aus)* make claims about real people. Because the winner takes the original card, a photo can end up with someone the person in it never agreed to, and nearby play is open to strangers. Plan for:
  - consent wording in the creator flow
  - AI guardrails: playful rather than insulting, no sensitive traits
  - on-device image checks (nudity, violence, minors)
  - report/block features, which App Store Guideline 1.2 requires for user-generated content. Without a server, this means a local block list plus a way to report a card (e.g. by email)
- **No server as referee.** A modified app could fake stats or results. With people you know, that's acceptable. The receiving phone validates every card and message, and state hashes catch tampered or out-of-sync fights.
- **The staked card.** The loser's phone has to give up the card itself, and a player could try to quit at the right moment. Mitigations: resigning or not coming back within the reconnect window counts as a loss, and the staked cards are already exchanged with the `deck`, only unlocked at the end.
- **Losing cards for good.** Losing a favorite card can drive players away. Both players confirming the stakes before the fight helps, and the history screen makes losses traceable.
- **Cards only exist on the phone.** Without the iCloud backup, a lost phone means lost cards. Cards also can't be removed from someone else's phone once traded or won.
- **Game Center account required for remote play.** Players without Game Center can still fight nearby.
- **Data size limits.** Game Center limits message size. Thumbnails keep messages small, and the full staked image is sent in chunks.
- **30-second turns and accessibility.** VoiceOver and Switch Control users need more time, and fixed time limits are an accessibility barrier. The timer needs to be longer for them (see open questions).
- **Strangers nearby.** Anyone in the room can send an invite. The invite shows both stakes before accepting, and blocked players no longer appear in the list.
- **Privacy (GDPR).** Card generation runs on the device, so photos only go to opponents (as thumbnails), to the winner of a staked card, and to the player's own iCloud. This still needs a privacy policy and in-app deletion of cards and data.
- **Balance.** AI output must never set numbers directly (see the design rule above).
- **Daily limit can be bypassed** by changing the phone's clock. Acceptable: on-device AI costs nothing, so the limit only keeps cards feeling valuable.
- **On-device AI quality and reach.** The on-device model is smaller than cloud models, so the jokes may be less sharp, and older iPhones only get the curated lists. Playtest early in Phase 3.

---

## 5. Remaining open questions

1. What happens when the 30 seconds run out? Recommendation: the turn is skipped, and 3 skipped turns in a row count as a loss.
2. Should VoiceOver and Switch Control users get more time? Recommendation: yes, 60 seconds.
3. How long is the reconnect window after a dropped connection? Recommendation: 30 seconds.
4. How many cards can a player create per day (e.g. 3)? Does the limit reset at midnight local time?
5. Can the new owner of a won card trade it on or stake it again?
6. Can the person shown in a photo (rather than the card's creator) request removal, and how would they prove it's them?
