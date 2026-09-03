//
// ConversionUnits+Temperature.swift
// Lightsearch
//

import Foundation

extension ConversionUnitCatalog {
    static let temperature: [ConversionUnitDefinition] = [
        // MARK: - Temperature
        // Offsets convert to Kelvin, which is the base value.
        linearUnit(
            "temperature.celsius", .temperature, "Celsius", "°C",
            ["c", "°c", "celsius", "degree celsius", "degrees celsius"], 1,
            offset: 273.15,
            defaultTargetID: "temperature.fahrenheit"
        ),
        linearUnit(
            "temperature.fahrenheit", .temperature, "Fahrenheit", "°F",
            ["f", "°f", "fahrenheit", "degree fahrenheit", "degrees fahrenheit"], 5.0 / 9.0,
            offset: 255.3722222222222,
            defaultTargetID: "temperature.celsius"
        ),
        linearUnit(
            "temperature.kelvin", .temperature, "Kelvin", "K",
            ["k", "kelvin", "kelvins"], 1,
            offset: 0,
            defaultTargetID: "temperature.celsius"
        ),
        linearUnit(
            "temperature.rankine", .temperature, "Rankine", "°R",
            ["r", "°r", "rankine", "degrees rankine"], 5.0 / 9.0,
            defaultTargetID: "temperature.celsius"
        ),
        linearUnit(
            "temperature.reaumur", .temperature, "Réaumur", "°Ré",
            ["re", "ré", "reaumur", "réaumur", "degree reaumur", "degrees reaumur"], 1.25,
            offset: 273.15,
            defaultTargetID: "temperature.celsius"
        ),
        linearUnit(
            "temperature.newton", .temperature, "Newton", "°N",
            ["n", "°n", "newton", "newtons", "degree newton", "degrees newton"], 100.0 / 33.0,
            offset: 273.15,
            defaultTargetID: "temperature.celsius"
        ),
        linearUnit(
            "temperature.romer", .temperature, "Rømer", "°Rø",
            ["ro", "rø", "romer", "rømer", "degree romer", "degrees romer"], 40.0 / 21.0,
            offset: 258.8642857142857,
            defaultTargetID: "temperature.celsius"
        ),
        linearUnit(
            "temperature.delisle", .temperature, "Delisle", "°De",
            ["de", "°de", "delisle", "degrees delisle"], -2.0 / 3.0,
            offset: 373.15,
            defaultTargetID: "temperature.celsius"
        ),

    ]
}
