//
// ConversionUnits+Speed.swift
// Lightsearch
//

import Foundation

extension ConversionUnitCatalog {
    static let speed: [ConversionUnitDefinition] = [
        // MARK: - Speed
        linearUnit(
            "speed.metersPerSecond", .speed, "Meters per Second", "m/s",
            ["m/s", "mps", "meter per second", "meters per second", "metre per second", "metres per second"], 1,
            defaultTargetID: "speed.kilometersPerHour"
        ),
        linearUnit(
            "speed.kilometersPerHour", .speed, "Kilometers per Hour", "km/h",
            ["km/h", "kmh", "kph", "kilometer per hour", "kilometers per hour", "kilometre per hour", "kilometres per hour"], 1.0 / 3.6,
            defaultTargetID: "speed.milesPerHour"
        ),
        linearUnit(
            "speed.milesPerHour", .speed, "Miles per Hour", "mph",
            ["mph", "mile per hour", "miles per hour"], 0.44704,
            defaultTargetID: "speed.kilometersPerHour"
        ),
        linearUnit(
            "speed.knots", .speed, "Knots", "kn",
            ["kn", "knot", "knots", "kt", "kts", "nautical mile per hour"], 0.514444444444,
            defaultTargetID: "speed.kilometersPerHour"
        ),
        linearUnit(
            "speed.feetPerSecond", .speed, "Feet per Second", "ft/s",
            ["ft/s", "fps", "foot per second", "feet per second"], 0.3048,
            defaultTargetID: "speed.metersPerSecond"
        ),
        linearUnit(
            "speed.feetPerMinute", .speed, "Feet per Minute", "ft/min",
            ["ft/min", "fpm", "foot per minute", "feet per minute"], 0.00508,
            defaultTargetID: "speed.metersPerSecond"
        ),
        linearUnit(
            "speed.mach", .speed, "Mach", "Mach",
            ["mach", "mach 1"], 340.29,
            defaultTargetID: "speed.kilometersPerHour"
        ),
        linearUnit(
            "speed.furlongsPerFortnight", .speed, "Furlongs per Fortnight", "fur/fortnight",
            ["fur/fortnight", "furlongs per fortnight"], 201.168 / 1_209_600,
            defaultTargetID: "speed.metersPerSecond"
        ),

    ]
}
