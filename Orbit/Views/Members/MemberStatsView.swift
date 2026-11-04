//
//  MemberStatsView.swift
//  Orbit
//

import Charts
import Foundation
import SwiftUI

/// Historique de chiffrage d'un membre : rapport temps passé / chiffrage de chaque tâche
/// et évolution du coefficient (moyenne mobile exponentielle).
struct MemberStatsView: View {
    let member: Member

    @Environment(OrbitStore.self) private var store

    private static let ratioSeries = "Temps passé / chiffrage"
    private static let factorSeries = "Coefficient (EMA)"

    var body: some View {
        let calibration = store.calibration(for: member.id)

        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                MemberAvatar(member: member, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(member.name)
                        .font(.headline)
                    if !member.role.isEmpty {
                        Text(member.role)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(OrbitFormat.factor(calibration.factor))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                VStack(alignment: .leading, spacing: 2) {
                    Text(OrbitFormat.biasDescription(calibration))
                    Text(OrbitFormat.count(calibration.sampleCount, "tâche prise en compte", "tâches prises en compte"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if calibration.points.isEmpty {
                Text("Aucune tâche terminée avec un temps passé : le coefficient reste neutre (×1).")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                chart(calibration)
                    .frame(height: 170)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Dernières tâches")
                        .font(.subheadline.weight(.semibold))
                    ForEach(Array(calibration.points.suffix(5).reversed())) { point in
                        HStack {
                            Text(point.title)
                                .lineLimit(1)
                            Spacer()
                            Text("\(point.estimate.description) → \(point.actual.description)")
                                .foregroundStyle(.secondary)
                            Text(OrbitFormat.deviation(ratio: point.ratio))
                                .frame(width: 48, alignment: .trailing)
                        }
                        .font(.callout)
                        .monospacedDigit()
                    }
                }
            }

            Text(explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(width: 380)
    }

    private func chart(_ calibration: Calibration) -> some View {
        Chart {
            RuleMark(y: .value("Chiffrage exact", 1.0))
                .foregroundStyle(Color.secondary.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
            ForEach(calibration.points) { point in
                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Valeur", point.ratio)
                )
                .foregroundStyle(by: .value("Série", Self.ratioSeries))
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Valeur", point.factor)
                )
                .foregroundStyle(by: .value("Série", Self.factorSeries))
                .interpolationMethod(.monotone)
            }
        }
        .chartForegroundStyleScale([
            Self.ratioSeries: Color.gray,
            Self.factorSeries: member.color,
        ])
        .chartLegend(position: .bottom)
    }

    private var explanation: String {
        let alpha = store.settings.smoothing.formatted(.number.precision(.fractionLength(2)))
        let applied = store.settings.applyCalibration
            ? "Ce coefficient multiplie ses chiffrages dans le planning."
            : "La pondération du planning est désactivée dans les réglages."
        return "Moyenne mobile exponentielle (α = \(alpha)) : chaque nouvelle tâche terminée pèse plus que les précédentes. \(applied)"
    }
}
