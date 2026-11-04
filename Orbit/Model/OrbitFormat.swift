//
//  OrbitFormat.swift
//  Orbit
//

import Foundation

/// Textes d'affichage partagés par les vues.
enum OrbitFormat {
    /// « ×1,18 »
    static func factor(_ value: Double) -> String {
        "×" + value.formatted(.number.precision(.fractionLength(2)))
    }

    /// « 18 % »
    static func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0)))
    }

    /// Écart d'une tâche : « +25 % », « −10 % » ou « pile ».
    static func deviation(ratio: Double) -> String {
        let delta = ratio - 1
        if abs(delta) < 0.005 { return "pile" }
        return (delta > 0 ? "+" : "−") + percent(abs(delta))
    }

    /// Lecture du coefficient pour un humain.
    static func biasDescription(_ calibration: Calibration) -> String {
        guard calibration.sampleCount > 0 else { return "Pas encore d'historique" }
        let bias = calibration.bias
        if abs(bias) < 0.03 { return "Chiffrages fiables" }
        let amount = percent(abs(bias))
        return bias > 0 ? "Prend \(amount) de temps en plus" : "Prend \(amount) de temps en moins"
    }

    /// « 1 membre », « 3 membres »
    static func count(_ value: Int, _ singular: String, _ plural: String) -> String {
        "\(value) \(value > 1 ? plural : singular)"
    }
}
