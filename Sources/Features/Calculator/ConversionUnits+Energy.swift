//
// ConversionUnits+Energy.swift
// Lightsearch
//

import Foundation

extension ConversionUnitCatalog {
    static let energy: [ConversionUnitDefinition] = [
        // MARK: - Energy
        linearUnit(
            "energy.joule", .energy, "Joules", "J",
            ["j", "joule", "joules"], 1,
            defaultTargetID: "energy.calorie"
        ),
        linearUnit(
            "energy.kilojoule", .energy, "Kilojoules", "kJ",
            ["kj", "kilojoule", "kilojoules"], 1_000,
            defaultTargetID: "energy.kilocalorie"
        ),
        linearUnit(
            "energy.calorie", .energy, "Calories", "cal",
            ["cal", "calorie", "calories", "gram calorie"], 4.184,
            defaultTargetID: "energy.joule"
        ),
        linearUnit(
            "energy.kilocalorie", .energy, "Kilocalories", "kcal",
            ["kcal", "kilocalorie", "kilocalories", "food calorie", "food calories"], 4_184,
            defaultTargetID: "energy.kilojoule"
        ),
        linearUnit(
            "energy.wattHour", .energy, "Watt-Hours", "Wh",
            ["wh", "watt hour", "watt hours", "watt-hour", "watt-hours"], 3_600,
            defaultTargetID: "energy.joule"
        ),
        linearUnit(
            "energy.kilowattHour", .energy, "Kilowatt-Hours", "kWh",
            ["kwh", "kilowatt hour", "kilowatt hours", "kilowatt-hour", "kilowatt-hours"], 3_600_000,
            defaultTargetID: "energy.joule"
        ),
        linearUnit(
            "energy.electronvolt", .energy, "Electronvolts", "eV",
            ["ev", "electronvolt", "electronvolts"], 1.602176634e-19,
            defaultTargetID: "energy.joule"
        ),
        linearUnit(
            "energy.btu", .energy, "British Thermal Units", "BTU",
            ["btu", "british thermal unit", "british thermal units"], 1_055.05585262,
            defaultTargetID: "energy.joule"
        ),
        linearUnit(
            "energy.therm", .energy, "Therms", "therm",
            ["therm", "therms"], 105_480_400,
            defaultTargetID: "energy.kilowattHour"
        ),
        linearUnit(
            "energy.footPound", .energy, "Foot-Pounds", "ft⋅lb",
            ["ftlb", "ft-lb", "foot pound", "foot pounds", "foot-pound", "foot-pounds"], 1.3558179483314004,
            defaultTargetID: "energy.joule"
        ),
        linearUnit(
            "energy.erg", .energy, "Ergs", "erg",
            ["erg", "ergs"], 1e-7,
            defaultTargetID: "energy.joule"
        ),

    ]
}
