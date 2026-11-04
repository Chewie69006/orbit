//
//  MemberPalette.swift
//  Orbit
//

import Foundation
import SwiftUI

/// Couleurs attribuées aux membres (autant que `OrbitStore.paletteSize`).
enum MemberPalette {
    static let colors: [Color] = [.blue, .orange, .green, .pink, .purple, .teal, .red, .indigo, .brown, .mint]

    static func color(for index: Int) -> Color {
        colors[((index % colors.count) + colors.count) % colors.count]
    }
}

extension Member {
    var color: Color { MemberPalette.color(for: colorIndex) }
}

/// Pastille ronde avec les initiales du membre.
struct MemberAvatar: View {
    let member: Member
    var size: CGFloat = 28

    var body: some View {
        Text(member.initials)
            .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(member.color.gradient, in: Circle())
            .accessibilityHidden(true)
    }
}

/// Coefficient de pondération sous forme de badge (orange : sous-estime, bleu : surestime).
struct FactorBadge: View {
    let calibration: Calibration

    var body: some View {
        Text(OrbitFormat.factor(calibration.factor))
            .monospacedDigit()
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(tint.opacity(0.15), in: Capsule())
            .foregroundStyle(tint)
            .help(OrbitFormat.biasDescription(calibration))
    }

    private var tint: Color {
        if calibration.sampleCount == 0 || abs(calibration.bias) < 0.03 { return .green }
        return calibration.bias > 0 ? .orange : .blue
    }
}

/// Chiffrage retenu, suivi de la durée planifiée quand la pondération la modifie.
struct EstimateLabel: View {
    let estimate: ManDays
    var planned: ManDays?

    var body: some View {
        HStack(spacing: 4) {
            Text(estimate.description)
                .fontWeight(.semibold)
            if let planned, planned != estimate {
                Image(systemName: "arrow.right")
                    .imageScale(.small)
                    .foregroundStyle(.secondary)
                Text(planned.description)
                    .foregroundStyle(.secondary)
            }
        }
        .monospacedDigit()
        .help(helpText)
    }

    private var helpText: String {
        guard let planned, planned != estimate else { return "Chiffrage : \(estimate.description)" }
        return "Chiffrage : \(estimate.description) · durée planifiée après pondération : \(planned.description)"
    }
}
