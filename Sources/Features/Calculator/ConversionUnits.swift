//
// ConversionUnits.swift
// Lightsearch
//

import Foundation

enum ConversionCategory: String {
    case length = "Length"
    case area = "Area"
    case volume = "Volume"
    case mass = "Mass"
    case temperature = "Temperature"
    case speed = "Speed"
    case duration = "Time"
    case angle = "Angle"
    case pressure = "Pressure"
    case energy = "Energy"
    case power = "Power"
    case frequency = "Frequency"
    case data = "Data"
}
struct ConversionUnitDefinition {
    let id: String
    let category: ConversionCategory
    let name: String
    let symbol: String
    let aliases: [String]
    let coefficient: Double
    let offset: Double
    let defaultTargetID: String

    func toBase(_ value: Double) -> Double {
        value * coefficient + offset
    }

    func fromBase(_ value: Double) -> Double {
        (value - offset) / coefficient
    }
}

enum ConversionUnitCatalog {
    // Keep this list in the same order as the grouped definition files.
    static let all: [ConversionUnitDefinition] =
        length + area + volume + mass + temperature + speed + duration
            + angle + pressure + energy + power + frequency + data

    static func linearUnit(
        _ id: String,
        _ category: ConversionCategory,
        _ name: String,
        _ symbol: String,
        _ aliases: [String],
        _ coefficient: Double,
        offset: Double = 0,
        defaultTargetID: String,
        includeSymbol: Bool = true
    ) -> ConversionUnitDefinition {
        ConversionUnitDefinition(
            id: id,
            category: category,
            name: name,
            symbol: symbol,
            aliases: aliases + (includeSymbol ? [symbol] : []) + [name],
            coefficient: coefficient,
            offset: offset,
            defaultTargetID: defaultTargetID
        )
    }
}
