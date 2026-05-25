//
//  MasteryLegend.swift
//  London System Chess
//
//  The shared key for the Lines tab's visual language, floated over either
//  renderer so the colors and fills are never a guess: reliability is the hue
//  (weak → solid), coverage is the fill strength (faint → solid), never-studied
//  spots are a dashed grey "frontier", and the focus accent marks the one spot
//  to work on next. A small glass capsule — informative without crowding the map.
//

import SwiftUI

struct MasteryLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Reliability ramp — the hue axis.
            HStack(spacing: 6) {
                Text("Weak")
                RoundedRectangle(cornerRadius: 3)
                    .fill(MasteryStyle.reliabilityGradient)
                    .frame(width: 64, height: 8)
                Text("Solid")
            }

            // The two qualitative states that sit outside the ramp.
            HStack(spacing: 14) {
                swatch(
                    fill: .gray.opacity(0.35),
                    stroke: .secondary,
                    dashed: true,
                    label: "New"
                )
                swatch(
                    fill: .clear,
                    stroke: MasteryStyle.focusAccent,
                    dashed: false,
                    strokeWidth: 2,
                    label: "Focus"
                )
                Text("fill = coverage")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption2)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .accessibilityIdentifier("mastery-legend")
    }

    private func swatch(
        fill: Color,
        stroke: Color,
        dashed: Bool,
        strokeWidth: CGFloat = 1,
        label: String
    ) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(fill)
                .frame(width: 11, height: 11)
                .overlay(
                    Circle().stroke(
                        stroke,
                        style: StrokeStyle(lineWidth: strokeWidth, dash: dashed ? [2.5, 2.5] : [])
                    )
                )
            Text(label)
        }
    }
}

#Preview {
    ZStack {
        Color(.systemGroupedBackground)
        MasteryLegend()
    }
}
