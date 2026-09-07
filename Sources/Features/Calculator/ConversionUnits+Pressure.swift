import Foundation

extension ConversionUnitCatalog {
    static let pressure: [ConversionUnitDefinition] = [
        // MARK: - Pressure
        linearUnit(
            "pressure.pascal", .pressure, "Pascals", "Pa",
            ["pa", "pascal", "pascals"], 1,
            defaultTargetID: "pressure.kilopascal"
        ),
        linearUnit(
            "pressure.kilopascal", .pressure, "Kilopascals", "kPa",
            ["kpa", "kilopascal", "kilopascals"], 1_000,
            defaultTargetID: "pressure.psi"
        ),
        linearUnit(
            "pressure.megapascal", .pressure, "Megapascals", "MPa",
            ["mpa", "megapascal", "megapascals"], 1_000_000,
            defaultTargetID: "pressure.bar"
        ),
        linearUnit(
            "pressure.bar", .pressure, "Bars", "bar",
            ["bar", "bars"], 100_000,
            defaultTargetID: "pressure.psi"
        ),
        linearUnit(
            "pressure.millibar", .pressure, "Millibars", "mbar",
            ["mbar", "millibar", "millibars"], 100,
            defaultTargetID: "pressure.pascal"
        ),
        linearUnit(
            "pressure.atmosphere", .pressure, "Atmospheres", "atm",
            ["atm", "atmosphere", "atmospheres", "standard atmosphere"], 101_325,
            defaultTargetID: "pressure.psi"
        ),
        linearUnit(
            "pressure.psi", .pressure, "Pounds per Square Inch", "psi",
            ["psi", "pounds per square inch", "pound per square inch"], 6_894.757293168,
            defaultTargetID: "pressure.kilopascal"
        ),
        linearUnit(
            "pressure.torr", .pressure, "Torr", "Torr",
            ["torr"], 101_325 / 760,
            defaultTargetID: "pressure.pascal"
        ),
        linearUnit(
            "pressure.millimeterMercury", .pressure, "Millimeters of Mercury", "mmHg",
            ["mmhg", "mm hg", "millimeter mercury", "millimeters mercury"], 133.322387415,
            defaultTargetID: "pressure.pascal"
        ),
        linearUnit(
            "pressure.inchMercury", .pressure, "Inches of Mercury", "inHg",
            ["inhg", "in hg", "inch mercury", "inches mercury"], 3_386.389,
            defaultTargetID: "pressure.psi"
        ),
        linearUnit(
            "pressure.barye", .pressure, "Baryes", "Ba",
            ["ba", "barye", "baryes"], 0.1,
            defaultTargetID: "pressure.pascal"
        ),

    ]
}
