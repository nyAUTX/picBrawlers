# PicBrawlers

[Deutsch](#deutsch) · [English](#english)

---

## Deutsch

PicBrawlers ist ein Sammelkartenspiel für das iPhone. Aus Fotos in deiner Galerie werden Kämpferkarten, mit denen du gegen Freunde antrittst und die du mit ihnen tauschst.

### Karten erstellen

1. Foto aus der Galerie wählen.
2. Namen für die Karte vergeben.
3. Kategorie wählen: Tank, Damage Dealer oder Support.
4. Die App würfelt Lebenspunkte und Schaden passend zur Kategorie aus. Eine KI sieht sich das Foto an und erfindet dazu einen Angriff, eine Spezialfähigkeit und ein paar Schwächen.

| Kategorie | Leben | Schaden | Spezialfähigkeit |
|---|---|---|---|
| Tank | hoch | niedrig | schützt sich selbst, zieht Angriffe auf sich |
| Damage Dealer | niedrig | hoch | hoher Einzelschaden, Schaden über Zeit |
| Support | mittel | mittel bis niedrig | schützt, heilt oder stärkt andere Karten |

Beispiele für Angriffe: Gulaschkanone, Schnitzelklopfer, Fußball ins Gesicht (wenn die Person wie ein Fußballer aussieht), Hackerangriff, Stoßlüften, Kampfhund (wenn ein Hund mit im Bild ist).

Schwächen sind nur Fun Facts und wirken sich nicht auf den Kampf aus, zum Beispiel Spritpreis, Schlagloch, Radfahrer, Lügendetektor oder deutsche Wanderer in Flipflops.

Den Namen und die Beschreibung schreibt die KI, die Zahlen legt das Spiel fest. So bleibt jede Karte im Gleichgewicht, egal was die KI erfindet.

### Kämpfen

- Du forderst einen Freund heraus. Jeder bringt 3 Karten mit.
- Jeder setzt eine seiner 3 Karten ein. Beide sehen die Einsätze und bestätigen sie, bevor es losgeht.
- Pro Zug handeln 2 deiner Karten, jede mit ihrem Angriff oder ihrer Spezialfähigkeit.
- Eine Karte ohne Lebenspunkte ist zerknittert und scheidet aus. Wer alle 3 gegnerischen Karten zerknittert hat, gewinnt.
- Nach dem Kampf werden alle Karten wieder gebügelt. Der Gewinner bekommt die eingesetzte Karte des Verlierers.

### Tauschen

Du kannst Karten mit Freunden tauschen. Ein Tausch gilt erst, wenn beide zustimmen.

### Stand

PicBrawlers ist am Anfang der Entwicklung. Im Projekt steckt bisher nur die Xcode-Vorlage, noch kein Spielcode. Der Fahrplan, die getroffenen Entscheidungen und die offenen Fragen stehen in [PLAN.md](PLAN.md).

### Technik

- iOS-App mit SwiftUI und SwiftData, zunächst nur für das iPhone
- Backend mit Supabase (geplant): Anmeldung mit Apple, Datenbank, Bildspeicher, Server-Funktionen
- KI-Generierung über ein Vision-Modell, das nur der Server aufruft
- App-Sprache: Deutsch

### Entwicklung

Voraussetzung ist Xcode mit dem SDK für iOS 27.2 oder neuer.

```bash
git clone https://github.com/nyAUTX/picBrawlers.git
```

```bash
open picBrawlers/picBrawlers/picBrawlers.xcodeproj
```

In Xcode das Schema `picBrawlers` und einen iPhone-Simulator wählen, dann mit ⌘R starten.

---

## English

PicBrawlers is a trading card game for the iPhone. Photos from your gallery become fighter cards that you battle and trade with your friends.

### Creating cards

1. Pick a photo from your gallery.
2. Give the card a name.
3. Choose a category: Tank, Damage Dealer or Support.
4. The app rolls health and damage to match the category. An AI looks at the photo and comes up with an attack, a special ability and a few weaknesses.

| Category | Health | Damage | Special ability |
|---|---|---|---|
| Tank | high | low | protects itself, draws attacks |
| Damage Dealer | low | high | big single hits, damage over time |
| Support | medium | medium to low | protects, heals or buffs other cards |

Example attacks (the game is in German, so the names are too): *Gulaschkanone* (goulash cannon), *Schnitzelklopfer* (meat tenderizer), *Fußball ins Gesicht* (football to the face, if the person looks like a footballer), *Hackerangriff* (hacker attack), *Stoßlüften* (the German habit of airing out a room), *Kampfhund* (attack dog, if there's a dog in the picture).

Weaknesses are fun facts only and have no effect in battle, for example fuel prices, potholes, cyclists, lie detectors or German hikers in flip-flops.

The AI writes the names and descriptions; the game sets the numbers. That keeps every card balanced, whatever the AI comes up with.

### Fighting

- You challenge a friend. Each player brings 3 cards.
- Each player puts one of their 3 cards at stake. Both see the stakes and confirm them before the fight starts.
- On each turn, 2 of your cards act, each using its attack or its special ability.
- A card with no health left is crumpled and out. Whoever crumples all 3 of the opponent's cards wins.
- After the fight all cards are ironed flat again. The winner gets the loser's staked card.

### Trading

You can trade cards with friends. A trade only goes through once both players accept it.

### Status

PicBrawlers is in early development. The project only contains the Xcode template so far, with no game code yet. The roadmap, the decisions made so far and the open questions are in [PLAN.md](PLAN.md).

### Tech

- iOS app built with SwiftUI and SwiftData, iPhone only at first
- Supabase backend (planned): Sign in with Apple, database, image storage, server functions
- AI generation through a vision model that only the server calls
- App language: German

### Development

You need Xcode with the iOS 27.2 SDK or newer.

```bash
git clone https://github.com/nyAUTX/picBrawlers.git
```

```bash
open picBrawlers/picBrawlers/picBrawlers.xcodeproj
```

In Xcode, select the `picBrawlers` scheme and an iPhone simulator, then press ⌘R.
