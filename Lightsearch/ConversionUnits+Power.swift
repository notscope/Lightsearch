//
// ConversionUnits+Power.swift
// Lightsearch
//

import Foundation

extension ConversionUnitCatalog {
    static let power: [ConversionUnitDefinition] = [
        // MARK: - Power
        linearUnit(
            "power.watt", .power, "Watts", "W",
            ["w", "watt", "watts"], 1,
            defaultTargetID: "power.kilowatt"
        ),
        linearUnit(
            "power.kilowatt", .power, "Kilowatts", "kW",
            ["kw", "kilowatt", "kilowatts"], 1_000,
            defaultTargetID: "power.horsepower"
        ),
        linearUnit(
            "power.megawatt", .power, "Megawatts", "MW",
            ["mw", "megawatt", "megawatts"], 1_000_000,
            defaultTargetID: "power.kilowatt"
        ),
        linearUnit(
            "power.horsepower", .power, "Horsepower", "hp",
            ["hp", "horsepower", "mechanical horsepower"], 745.6998715822702,
            defaultTargetID: "power.kilowatt"
        ),
        linearUnit(
            "power.metricHorsepower", .power, "Metric Horsepower", "PS",
            ["ps", "metric horsepower", "metric hp"], 735.49875,
            defaultTargetID: "power.kilowatt"
        ),
        linearUnit(
            "power.btuPerHour", .power, "BTU per Hour", "BTU/h",
            ["btu/h", "btuh", "btu per hour", "british thermal unit per hour"], 0.2930710701722222,
            defaultTargetID: "power.watt"
        ),

    ]
}
