//
//  Calibration.swift
//  Orbit
//

import Foundation

/// Un point de l'historique de pondération : une tâche terminée et l'effet qu'elle a eu.
struct CalibrationPoint: Identifiable, Hashable {
    let taskID: UUID
    let title: String
    let date: Date
    let estimate: ManDays
    let actual: ManDays
    /// Temps passé / chiffrage (1 = chiffrage exact, 1,5 = 50 % de temps en plus).
    let ratio: Double
    /// Coefficient après la prise en compte de cette tâche.
    let factor: Double

    var id: UUID { taskID }
}

/// Pondération des chiffrages d'une personne, calculée par moyenne mobile exponentielle (EMA)
/// sur le rapport « temps passé / chiffrage » de ses tâches terminées.
///
///     coefficient₀ = 1 (neutre)
///     coefficientₙ = α × ratioₙ + (1 − α) × coefficientₙ₋₁
///
/// Les tâches sont prises dans l'ordre où elles ont été terminées : les plus récentes
/// pèsent davantage que les plus anciennes.
struct Calibration: Hashable {
    static let neutral = Calibration(factor: 1, points: [])

    /// Coefficient à appliquer aux chiffrages de la personne.
    let factor: Double
    /// Historique, de la plus ancienne à la plus récente tâche.
    let points: [CalibrationPoint]

    var sampleCount: Int { points.count }

    /// Écart relatif entre le temps passé et le chiffrage (0,18 = 18 % de temps en plus).
    var bias: Double { factor - 1 }

    func adjusted(_ estimate: ManDays) -> ManDays {
        estimate.scaled(by: factor)
    }

    /// Calcule la pondération à partir des tâches d'une personne.
    /// Seules les tâches terminées, chiffrées et dont le temps passé est connu sont prises en compte.
    static func compute(from tasks: [TaskItem], smoothing: Double) -> Calibration {
        let alpha = min(max(smoothing, 0.01), 1)

        let samples = tasks
            .compactMap { task -> (task: TaskItem, date: Date, actual: ManDays)? in
                guard task.status == .done,
                      let date = task.completedAt,
                      let actual = task.actualSpent,
                      !actual.isZero,
                      !task.effectiveEstimate.isZero
                else { return nil }
                return (task, date, actual)
            }
            .sorted { lhs, rhs in
                (lhs.date, lhs.task.createdAt) < (rhs.date, rhs.task.createdAt)
            }

        var factor = 1.0
        var points: [CalibrationPoint] = []
        points.reserveCapacity(samples.count)
        for sample in samples {
            let estimate = sample.task.effectiveEstimate
            let ratio = Double(sample.actual.eighths) / Double(estimate.eighths)
            factor = alpha * ratio + (1 - alpha) * factor
            points.append(
                CalibrationPoint(
                    taskID: sample.task.id,
                    title: sample.task.title,
                    date: sample.date,
                    estimate: estimate,
                    actual: sample.actual,
                    ratio: ratio,
                    factor: factor
                )
            )
        }
        return Calibration(factor: factor, points: points)
    }
}
