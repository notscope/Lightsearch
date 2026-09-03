//
// ConversionUnits+Mass.swift
// Lightsearch
//

import Foundation

extension ConversionUnitCatalog {
    static let mass: [ConversionUnitDefinition] = [
        // MARK: - Mass
        linearUnit(
            "mass.gram", .mass, "Grams", "g",
            ["g", "gram", "grams"], 0.001,
            defaultTargetID: "mass.ounce"
        ),
        linearUnit(
            "mass.kilogram", .mass, "Kilograms", "kg",
            ["kg", "kilogram", "kilograms", "kilo", "kilos"], 1,
            defaultTargetID: "mass.pound"
        ),
        linearUnit(
            "mass.milligram", .mass, "Milligrams", "mg",
            ["mg", "milligram", "milligrams"], 0.000001,
            defaultTargetID: "mass.gram"
        ),
        linearUnit(
            "mass.microgram", .mass, "Micrograms", "µg",
            ["ug", "µg", "microgram", "micrograms"], 1e-9,
            defaultTargetID: "mass.milligram"
        ),
        linearUnit(
            "mass.nanogram", .mass, "Nanograms", "ng",
            ["ng", "nanogram", "nanograms"], 1e-12,
            defaultTargetID: "mass.microgram"
        ),
        linearUnit(
            "mass.ounce", .mass, "Ounces", "oz",
            ["oz", "ounce", "ounces", "avoirdupois ounce"], 0.028349523125,
            defaultTargetID: "mass.gram"
        ),
        linearUnit(
            "mass.pound", .mass, "Pounds", "lb",
            ["lb", "lbs", "pound", "pounds"], 0.45359237,
            defaultTargetID: "mass.kilogram"
        ),
        linearUnit(
            "mass.stone", .mass, "Stones", "st",
            ["st", "stone", "stones"], 6.35029318,
            defaultTargetID: "mass.kilogram"
        ),
        linearUnit(
            "mass.metricTon", .mass, "Metric Tons", "t",
            ["t", "tonne", "tonnes", "metric ton", "metric tons"], 1_000,
            defaultTargetID: "mass.kilogram"
        ),
        linearUnit(
            "mass.shortTon", .mass, "Short Tons", "short ton",
            ["short ton", "short tons", "us ton", "us tons"], 907.18474,
            defaultTargetID: "mass.kilogram"
        ),
        linearUnit(
            "mass.longTon", .mass, "Long Tons", "long ton",
            ["long ton", "long tons", "imperial ton", "imperial tons"], 1_016.0469088,
            defaultTargetID: "mass.kilogram"
        ),
        linearUnit(
            "mass.troyOunce", .mass, "Troy Ounces", "ozt",
            ["ozt", "troy ounce", "troy ounces"], 0.0311034768,
            defaultTargetID: "mass.gram"
        ),
        linearUnit(
            "mass.carat", .mass, "Carats", "ct",
            ["ct", "carat", "carats"], 0.0002,
            defaultTargetID: "mass.gram"
        ),
        linearUnit(
            "mass.grain", .mass, "Grains", "gr",
            ["gr", "grain", "grains"], 0.00006479891,
            defaultTargetID: "mass.milligram"
        ),
        linearUnit(
            "mass.dram", .mass, "Drams", "dr",
            ["dr", "dram", "drams"], 0.0017718451953125,
            defaultTargetID: "mass.gram"
        ),
        linearUnit(
            "mass.pennyweight", .mass, "Pennyweights", "dwt",
            ["dwt", "pennyweight", "pennyweights"], 0.00155517384,
            defaultTargetID: "mass.gram"
        ),
        linearUnit(
            "mass.slug", .mass, "Slugs", "slug",
            ["slug", "slugs"], 14.59390294,
            defaultTargetID: "mass.kilogram"
        ),
        linearUnit(
            "mass.atomicMassUnit", .mass, "Atomic Mass Units", "u",
            ["u", "amu", "da", "dalton", "daltons", "atomic mass unit", "atomic mass units"], 1.6605390666e-27,
            defaultTargetID: "mass.gram"
        ),
        linearUnit(
            "mass.solarMass", .mass, "Solar Masses", "M☉",
            ["msun", "m sun", "solar mass", "solar masses"], 1.98847e30,
            defaultTargetID: "mass.kilogram"
        ),

    ]
}
