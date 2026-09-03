//
// ConversionUnits+Angle.swift
// Lightsearch
//

import Foundation

extension ConversionUnitCatalog {
    static let angle: [ConversionUnitDefinition] = [
        // MARK: - Angle
        linearUnit(
            "angle.radian", .angle, "Radians", "rad",
            ["rad", "radian", "radians"], 1,
            defaultTargetID: "angle.degree"
        ),
        linearUnit(
            "angle.degree", .angle, "Degrees", "°",
            ["deg", "degree", "degrees", "°"], Double.pi / 180,
            defaultTargetID: "angle.radian"
        ),
        linearUnit(
            "angle.arcminute", .angle, "Arcminutes", "′",
            ["arcmin", "arcminute", "arcminutes", "minute of arc", "minutes of arc"], Double.pi / 10_800,
            defaultTargetID: "angle.degree"
        ),
        linearUnit(
            "angle.arcsecond", .angle, "Arcseconds", "″",
            ["arcsec", "arcsecond", "arcseconds", "second of arc", "seconds of arc"], Double.pi / 648_000,
            defaultTargetID: "angle.degree"
        ),
        linearUnit(
            "angle.turn", .angle, "Turns", "turn",
            ["turn", "turns", "revolution", "revolutions", "rev"], 2 * Double.pi,
            defaultTargetID: "angle.degree"
        ),
        linearUnit(
            "angle.gradian", .angle, "Gradians", "gon",
            ["gon", "grad", "gradian", "gradians"], Double.pi / 200,
            defaultTargetID: "angle.degree"
        ),
        linearUnit(
            "angle.mil", .angle, "Mils", "mil",
            ["mil", "mils", "angular mil", "angular mils", "nato mil"], 2 * Double.pi / 6_400,
            defaultTargetID: "angle.degree"
        ),
        linearUnit(
            "angle.quadrant", .angle, "Quadrants", "quadrant",
            ["quadrant", "quadrants"], Double.pi / 2,
            defaultTargetID: "angle.degree"
        ),

    ]
}
