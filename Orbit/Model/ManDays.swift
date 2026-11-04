//
//  ManDays.swift
//  Orbit
//

import Foundation

/// Une durée exprimée en jours-hommes, avec une granularité de 1/8 de journée.
///
/// La valeur est stockée en huitièmes de jour (entier) pour éviter toute erreur d'arrondi.
struct ManDays: Hashable, Comparable {
    static let eighthsPerDay = 8

    /// Nombre de huitièmes de journée (toujours positif ou nul).
    private(set) var eighths: Int

    init(eighths: Int) {
        self.eighths = max(0, eighths)
    }

    /// Arrondit au huitième de journée le plus proche.
    init(days: Double) {
        guard days.isFinite else {
            self.init(eighths: 0)
            return
        }
        self.init(eighths: Int((days * Double(Self.eighthsPerDay)).rounded()))
    }

    static let zero = ManDays(eighths: 0)
    static let eighth = ManDays(eighths: 1)
    static let halfDay = ManDays(eighths: 4)
    static let day = ManDays(eighths: 8)

    var days: Double { Double(eighths) / Double(Self.eighthsPerDay) }
    var isZero: Bool { eighths == 0 }

    static func < (lhs: ManDays, rhs: ManDays) -> Bool { lhs.eighths < rhs.eighths }
    static func + (lhs: ManDays, rhs: ManDays) -> ManDays { ManDays(eighths: lhs.eighths + rhs.eighths) }
    static func += (lhs: inout ManDays, rhs: ManDays) { lhs = lhs + rhs }

    /// Applique un coefficient (pondération) en arrondissant au huitième le plus proche.
    /// Une durée non nulle ne descend jamais sous 1/8 de journée.
    func scaled(by factor: Double) -> ManDays {
        guard eighths > 0 else { return .zero }
        guard factor.isFinite, factor > 0 else { return self }
        let scaled = Int((Double(eighths) * factor).rounded())
        return ManDays(eighths: max(1, scaled))
    }
}

extension Sequence where Element == ManDays {
    func sum() -> ManDays { reduce(.zero, +) }
}

// MARK: - Codable (stocké comme un entier de huitièmes)

extension ManDays: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(eighths: try container.decode(Int.self))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(eighths)
    }
}

// MARK: - Affichage

extension ManDays: CustomStringConvertible {
    private static let fractionGlyphs = ["", "⅛", "¼", "⅜", "½", "⅝", "¾", "⅞"]

    /// Représentation compacte : « 0 j », « ⅜ j », « 2 j », « 2⅜ j ».
    var description: String {
        let whole = eighths / Self.eighthsPerDay
        let remainder = eighths % Self.eighthsPerDay
        let glyph = Self.fractionGlyphs[remainder]
        if remainder == 0 { return "\(whole) j" }
        return whole == 0 ? "\(glyph) j" : "\(whole)\(glyph) j"
    }
}

// MARK: - Saisie

extension ManDays {
    private static let glyphValues: [Character: String] = [
        "⅛": " 1/8", "¼": " 1/4", "⅜": " 3/8", "½": " 1/2",
        "⅝": " 5/8", "¾": " 3/4", "⅞": " 7/8",
    ]
    private static let dayUnits: Set<String> = ["", "j", "jh", "jour", "jours", "d", "day", "days"]
    private static let hourUnits: Set<String> = ["h", "heure", "heures", "hour", "hours"]

    /// Interprète une saisie libre. Exemples acceptés :
    /// `2`, `1,5`, `1.5 j`, `1 3/8`, `3/8`, `2⅜ j`, `6h` (1 h = 1/8 de jour).
    /// Le résultat est arrondi au huitième de journée le plus proche.
    static func parse(_ input: String) -> ManDays? {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !text.isEmpty else { return nil }

        // Unité éventuelle en suffixe (lettres finales).
        var unit = ""
        while let last = text.last, last.isLetter {
            unit.insert(last, at: unit.startIndex)
            text.removeLast()
        }
        let eighthsPerUnit: Double
        if dayUnits.contains(unit) {
            eighthsPerUnit = Double(eighthsPerDay)
        } else if hourUnits.contains(unit) {
            eighthsPerUnit = 1
        } else {
            return nil
        }

        // Fractions Unicode → « a/b », virgule décimale → point.
        var normalized = ""
        for character in text {
            if let replacement = glyphValues[character] {
                normalized += replacement
            } else if character == "," {
                normalized.append(".")
            } else {
                normalized.append(character)
            }
        }

        let parts = normalized.split(whereSeparator: { $0.isWhitespace })
        guard (1...2).contains(parts.count) else { return nil }
        var value = 0.0
        for part in parts {
            guard let partValue = parseNumber(String(part)) else { return nil }
            value += partValue
        }
        guard value.isFinite, value >= 0 else { return nil }
        return ManDays(eighths: Int((value * eighthsPerUnit).rounded()))
    }

    private static func parseNumber(_ text: String) -> Double? {
        let pieces = text.split(separator: "/", omittingEmptySubsequences: false)
        switch pieces.count {
        case 1:
            return Double(text)
        case 2:
            guard let numerator = Double(pieces[0]), let denominator = Double(pieces[1]), denominator != 0 else {
                return nil
            }
            return numerator / denominator
        default:
            return nil
        }
    }
}
