//
//  MasteryStyle.swift
//  London System Chess
//
//  The shared visual language for Mastery, used by both renderers and the board
//  card so progress reads the same everywhere. The two axes map to two channels:
//  reliability → color (grey "unknown" → red "weak" → green "solid"), and
//  coverage → fill strength (faint "barely seen" → solid "drilled"). See CONTEXT.md.
//
//  This is the prototype's first cut; the styling polish (step 5) refines it.
//

import SwiftUI

enum MasteryStyle {
    /// Color for a reliability value. `nil` (unknown — never studied) is a neutral
    /// grey, deliberately *outside* the red→green ramp so "new" never reads as "bad".
    static func reliabilityColor(_ reliability: Double?) -> Color {
        guard let r = reliability else { return .gray }
        // red (0) → amber (0.5) → green (1)
        if r < 0.5 {
            return Color(hue: lerp(0.0, 0.13, r / 0.5), saturation: 0.85, brightness: 0.85)
        } else {
            return Color(hue: lerp(0.13, 0.33, (r - 0.5) / 0.5), saturation: 0.85, brightness: 0.78)
        }
    }

    /// How strongly a node's fill reads, from coverage. Floored so even barely-seen
    /// spots stay visible against the canvas.
    static func coverageOpacity(_ coverage: Double) -> Double {
        coverage <= 0 ? 0.12 : lerp(0.30, 1.0, coverage)
    }

    /// The combined tint for a node/chip: reliability hue at coverage strength.
    static func tint(for mastery: Mastery) -> Color {
        reliabilityColor(mastery.reliability).opacity(coverageOpacity(mastery.coverage))
    }

    /// The reliability ramp as a gradient, for the legend's "weak → solid" swatch.
    static var reliabilityGradient: LinearGradient {
        LinearGradient(
            colors: [reliabilityColor(0), reliabilityColor(0.5), reliabilityColor(1)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    /// The accent used for the active-focus affordance (the "work on this next" spot),
    /// kept here so the map ring, the column pulse, and the legend agree.
    static let focusAccent: Color = .orange

    /// Short human label for a mastery state, for the board card / accessibility.
    static func summary(for mastery: Mastery) -> String {
        guard let r = mastery.reliability else { return "Not yet studied" }
        let reliability: String = switch r {
        case ..<0.4: "Error-prone"
        case ..<0.7: "Shaky"
        default: "Solid"
        }
        let coverage = Int((mastery.coverage * 100).rounded())
        return "\(reliability) · \(coverage)% covered"
    }

    private static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * min(max(t, 0), 1)
    }
}
