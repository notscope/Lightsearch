//
// ConversionUnits+Frequency.swift
// Lightsearch
//

import Foundation

extension ConversionUnitCatalog {
    static let frequency: [ConversionUnitDefinition] = [
        // MARK: - Frequency
        linearUnit(
            "frequency.hertz", .frequency, "Hertz", "Hz",
            ["hz", "hertz"], 1,
            defaultTargetID: "frequency.kilohertz"
        ),
        linearUnit(
            "frequency.kilohertz", .frequency, "Kilohertz", "kHz",
            ["khz", "kilohertz"], 1_000,
            defaultTargetID: "frequency.hertz"
        ),
        linearUnit(
            "frequency.megahertz", .frequency, "Megahertz", "MHz",
            ["mhz", "megahertz"], 1_000_000,
            defaultTargetID: "frequency.kilohertz"
        ),
        linearUnit(
            "frequency.gigahertz", .frequency, "Gigahertz", "GHz",
            ["ghz", "gigahertz"], 1_000_000_000,
            defaultTargetID: "frequency.megahertz"
        ),
        linearUnit(
            "frequency.rpm", .frequency, "Revolutions per Minute", "rpm",
            ["rpm", "revolution per minute", "revolutions per minute"], 1.0 / 60.0,
            defaultTargetID: "frequency.hertz"
        ),
        linearUnit(
            "frequency.beatsPerMinute", .frequency, "Beats per Minute", "BPM",
            ["bpm", "beat per minute", "beats per minute"], 1.0 / 60.0,
            defaultTargetID: "frequency.hertz"
        ),

    ]
}
