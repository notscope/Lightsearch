//
// ConversionUnits+Area.swift
// Lightsearch
//

import Foundation

extension ConversionUnitCatalog {
    static let area: [ConversionUnitDefinition] = [
        // MARK: - Area
        linearUnit(
            "area.squareMeter", .area, "Square Meters", "m²",
            ["m2", "m²", "square meter", "square meters", "square metre", "square metres"], 1,
            defaultTargetID: "area.squareFoot"
        ),
        linearUnit(
            "area.squareKilometer", .area, "Square Kilometers", "km²",
            ["km2", "km²", "square kilometer", "square kilometers", "square kilometre", "square kilometres"], 1_000_000,
            defaultTargetID: "area.squareMile"
        ),
        linearUnit(
            "area.squareCentimeter", .area, "Square Centimeters", "cm²",
            ["cm2", "cm²", "square centimeter", "square centimeters", "square centimetre", "square centimetres"], 0.0001,
            defaultTargetID: "area.squareInch"
        ),
        linearUnit(
            "area.squareMillimeter", .area, "Square Millimeters", "mm²",
            ["mm2", "mm²", "square millimeter", "square millimeters", "square millimetre", "square millimetres"], 0.000001,
            defaultTargetID: "area.squareInch"
        ),
        linearUnit(
            "area.squareInch", .area, "Square Inches", "in²",
            ["in2", "in²", "square inch", "square inches"], 0.00064516,
            defaultTargetID: "area.squareCentimeter"
        ),
        linearUnit(
            "area.squareFoot", .area, "Square Feet", "ft²",
            ["ft2", "ft²", "square foot", "square feet"], 0.09290304,
            defaultTargetID: "area.squareMeter"
        ),
        linearUnit(
            "area.squareYard", .area, "Square Yards", "yd²",
            ["yd2", "yd²", "square yard", "square yards"], 0.83612736,
            defaultTargetID: "area.squareMeter"
        ),
        linearUnit(
            "area.squareMile", .area, "Square Miles", "mi²",
            ["mi2", "mi²", "square mile", "square miles"], 2_589_988.110336,
            defaultTargetID: "area.squareKilometer"
        ),
        linearUnit(
            "area.acre", .area, "Acres", "ac",
            ["ac", "acre", "acres"], 4_046.8564224,
            defaultTargetID: "area.squareMeter"
        ),
        linearUnit(
            "area.are", .area, "Ares", "a",
            ["are", "ares"], 100,
            defaultTargetID: "area.squareMeter"
        ),
        linearUnit(
            "area.hectare", .area, "Hectares", "ha",
            ["ha", "hectare", "hectares"], 10_000,
            defaultTargetID: "area.squareMeter"
        ),
        linearUnit(
            "area.barn", .area, "Barns", "b",
            ["b", "barn", "barns"], 1e-28,
            defaultTargetID: "area.squareMeter"
        ),

    ]
}
