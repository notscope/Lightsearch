//
// ConversionUnits+Volume.swift
// Lightsearch
//

import Foundation

extension ConversionUnitCatalog {
    static let volume: [ConversionUnitDefinition] = [
        // MARK: - Volume
        linearUnit(
            "volume.liter", .volume, "Liters", "L",
            ["l", "L", "liter", "liters", "litre", "litres"], 0.001,
            defaultTargetID: "volume.usGallon"
        ),
        linearUnit(
            "volume.milliliter", .volume, "Milliliters", "mL",
            ["ml", "mL", "milliliter", "milliliters", "millilitre", "millilitres"], 0.000001,
            defaultTargetID: "volume.usFluidOunce"
        ),
        linearUnit(
            "volume.cubicMeter", .volume, "Cubic Meters", "m³",
            ["m3", "m³", "cubic meter", "cubic meters", "cubic metre", "cubic metres"], 1,
            defaultTargetID: "volume.usGallon"
        ),
        linearUnit(
            "volume.cubicCentimeter", .volume, "Cubic Centimeters", "cm³",
            ["cc", "cm3", "cm³", "cubic centimeter", "cubic centimeters", "cubic centimetre", "cubic centimetres"], 0.000001,
            defaultTargetID: "volume.milliliter"
        ),
        linearUnit(
            "volume.cubicMillimeter", .volume, "Cubic Millimeters", "mm³",
            ["mm3", "mm³", "cubic millimeter", "cubic millimeters", "cubic millimetre", "cubic millimetres"], 1e-9,
            defaultTargetID: "volume.milliliter"
        ),
        linearUnit(
            "volume.cubicInch", .volume, "Cubic Inches", "in³",
            ["in3", "in³", "cubic inch", "cubic inches"], 0.000016387064,
            defaultTargetID: "volume.milliliter"
        ),
        linearUnit(
            "volume.cubicFoot", .volume, "Cubic Feet", "ft³",
            ["ft3", "ft³", "cubic foot", "cubic feet"], 0.028316846592,
            defaultTargetID: "volume.cubicMeter"
        ),
        linearUnit(
            "volume.cubicYard", .volume, "Cubic Yards", "yd³",
            ["yd3", "yd³", "cubic yard", "cubic yards"], 0.764554857984,
            defaultTargetID: "volume.cubicMeter"
        ),
        linearUnit(
            "volume.usTeaspoon", .volume, "US Teaspoons", "tsp",
            ["tsp", "teaspoon", "teaspoons", "us teaspoon", "us teaspoons"], 4.92892159375e-6,
            defaultTargetID: "volume.milliliter"
        ),
        linearUnit(
            "volume.usTablespoon", .volume, "US Tablespoons", "tbsp",
            ["tbsp", "tbs", "tablespoon", "tablespoons", "us tablespoon", "us tablespoons"], 1.478676478125e-5,
            defaultTargetID: "volume.milliliter"
        ),
        linearUnit(
            "volume.usFluidOunce", .volume, "US Fluid Ounces", "fl oz",
            ["floz", "fl oz", "fluid ounce", "fluid ounces", "us fluid ounce", "us fluid ounces"], 2.95735295625e-5,
            defaultTargetID: "volume.milliliter"
        ),
        linearUnit(
            "volume.usCup", .volume, "US Cups", "cup",
            ["cup", "cups", "us cup", "us cups"], 0.0002365882365,
            defaultTargetID: "volume.milliliter"
        ),
        linearUnit(
            "volume.usPint", .volume, "US Pints", "pt",
            ["pt", "pint", "pints", "us pint", "us pints"], 0.000473176473,
            defaultTargetID: "volume.liter"
        ),
        linearUnit(
            "volume.usQuart", .volume, "US Quarts", "qt",
            ["qt", "quart", "quarts", "us quart", "us quarts"], 0.000946352946,
            defaultTargetID: "volume.liter"
        ),
        linearUnit(
            "volume.usGallon", .volume, "US Gallons", "gal",
            ["gal", "gallon", "gallons", "us gallon", "us gallons"], 0.003785411784,
            defaultTargetID: "volume.liter"
        ),
        linearUnit(
            "volume.imperialTeaspoon", .volume, "Imperial Teaspoons", "imp tsp",
            ["imp tsp", "imperial teaspoon", "imperial teaspoons"], 5.91938802e-6,
            defaultTargetID: "volume.milliliter"
        ),
        linearUnit(
            "volume.imperialTablespoon", .volume, "Imperial Tablespoons", "imp tbsp",
            ["imp tbsp", "imperial tablespoon", "imperial tablespoons"], 1.775816405e-5,
            defaultTargetID: "volume.milliliter"
        ),
        linearUnit(
            "volume.imperialFluidOunce", .volume, "Imperial Fluid Ounces", "imp fl oz",
            ["imp floz", "imp fl oz", "imperial fluid ounce", "imperial fluid ounces"], 2.84130625e-5,
            defaultTargetID: "volume.milliliter"
        ),
        linearUnit(
            "volume.imperialPint", .volume, "Imperial Pints", "imp pt",
            ["imp pt", "imperial pint", "imperial pints"], 0.00056826125,
            defaultTargetID: "volume.liter"
        ),
        linearUnit(
            "volume.imperialQuart", .volume, "Imperial Quarts", "imp qt",
            ["imp qt", "imperial quart", "imperial quarts"], 0.0011365225,
            defaultTargetID: "volume.liter"
        ),
        linearUnit(
            "volume.imperialGallon", .volume, "Imperial Gallons", "imp gal",
            ["imp gal", "imperial gallon", "imperial gallons"], 0.00454609,
            defaultTargetID: "volume.liter"
        ),
        linearUnit(
            "volume.metricCup", .volume, "Metric Cups", "metric cup",
            ["metric cup", "metric cups"], 0.00025,
            defaultTargetID: "volume.milliliter"
        ),
        linearUnit(
            "volume.bushel", .volume, "Bushels", "bu",
            ["bu", "bushel", "bushels"], 0.03523907016688,
            defaultTargetID: "volume.liter"
        ),
        linearUnit(
            "volume.barrel", .volume, "Oil Barrels", "bbl",
            ["bbl", "barrel", "barrels", "oil barrel", "oil barrels"], 0.158987294928,
            defaultTargetID: "volume.liter"
        ),
        linearUnit(
            "volume.drop", .volume, "Drops", "drop",
            ["drop", "drops"], 5e-8,
            defaultTargetID: "volume.milliliter"
        ),

    ]
}
