import Foundation

/// Picks attacks, specials and weaknesses from curated lists. It can't see the photo yet, so it
/// doesn't describe it. Stays as the fallback for iPhones without Apple Intelligence.
final class StubCardGenerationService: CardGenerationService {
    private var random: AnyRandomNumberGenerator

    init(random: any RandomNumberGenerator = SystemRandomNumberGenerator()) {
        self.random = AnyRandomNumberGenerator(random)
    }

    func analyze(photo: Data) async throws -> PhotoAnalysis {
        PhotoAnalysis(labels: [], description: "")
    }

    func inventText(for request: CardGenerationRequest) async throws -> CardText {
        let effect = request.category.allowedEffects.randomElement(using: &random)!
        let special = Self.specials[effect]!.randomElement(using: &random)!
        let count = Int.random(in: 1...CardFactory.maxWeaknesses, using: &random)
        return CardText(
            attack: Self.attacks.randomElement(using: &random)!,
            special: FighterCard.Special(name: special.name, description: special.description, effect: effect),
            weaknesses: Array(Self.weaknesses.shuffled(using: &random).prefix(count)),
            photoDescription: ""
        )
    }

    static let attacks: [FighterCard.Move] = [
        .init(name: "Gulaschkanone", description: "Feuert einen Schöpfer heißen Gulasch quer über den Tisch."),
        .init(name: "Schnitzelklopfer", description: "Klopft den Gegner so flach wie ein Wiener Schnitzel."),
        .init(name: "Fußball ins Gesicht", description: "Ein Volley aus kurzer Distanz, direkt auf die Nase."),
        .init(name: "Hackerangriff", description: "Stellt dem Gegner heimlich die Autokorrektur auf Klingonisch."),
        .init(name: "Kampfhund", description: "Bellt viel lauter, als er beißt."),
        .init(name: "Ellbogencheck", description: "Der Klassiker an der Supermarktkasse."),
        .init(name: "Sockenschleuder", description: "Wirft ein Paar Socken, die seit Tagen getragen wurden."),
        .init(name: "Formularflut", description: "Begräbt den Gegner unter Anträgen in dreifacher Ausfertigung."),
    ]

    static let specials: [SpecialEffect: [FighterCard.Move]] = [
        .heal: [
            .init(name: "Hühnersuppe", description: "Ein Teller wie bei Oma, und alles ist halb so schlimm."),
            .init(name: "Pflaster drauf", description: "Hilft nicht immer, beruhigt aber sofort."),
        ],
        .shield: [
            .init(name: "Regenschirm", description: "Spannt den Schirm auf, egal ob es regnet."),
            .init(name: "Kittelschürze", description: "Hält Flecken und Treffer ab."),
        ],
        .buff: [
            .init(name: "Stoßlüften", description: "Fenster auf, frische Luft, alle sind wieder wach."),
            .init(name: "Kabinenansprache", description: "Drei Sätze aus dem Kalender, und das Team glaubt wieder an sich."),
        ],
        .burst: [
            .init(name: "Blutgrätsche", description: "Rutscht mit Anlauf in den Gegner."),
            .init(name: "Turboniesen", description: "Kommt ohne Vorwarnung und mit voller Wucht."),
        ],
        .dot: [
            .init(name: "Mückenschwarm", description: "Sticht und juckt noch Runden später."),
            .init(name: "Ohrwurm", description: "Ein Schlager, der nicht mehr aus dem Kopf geht."),
        ],
        .taunt: [
            .init(name: "Große Klappe", description: "Redet so laut, dass alle nur noch auf ihn zielen."),
            .init(name: "Breitbeinig", description: "Steht so im Weg, dass niemand vorbeikommt."),
        ],
    ]

    static let weaknesses = [
        "Spritpreis", "Schlagloch", "Radfahrer", "Lügendetektor", "Deutsche Wanderer in Flipflops",
        "Montagmorgen", "Funkloch", "Leere Kaffeemaschine", "Rückwärts einparken",
    ]
}
