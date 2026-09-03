//
// ConversionUnits+Duration.swift
// Lightsearch
//

import Foundation

extension ConversionUnitCatalog {
    static let duration: [ConversionUnitDefinition] = [
        // MARK: - Duration
        linearUnit(
            "duration.nanosecond", .duration, "Nanoseconds", "ns",
            ["ns", "nanosecond", "nanoseconds"], 1e-9,
            defaultTargetID: "duration.microsecond"
        ),
        linearUnit(
            "duration.microsecond", .duration, "Microseconds", "µs",
            ["us", "µs", "microsecond", "microseconds"], 1e-6,
            defaultTargetID: "duration.millisecond"
        ),
        linearUnit(
            "duration.millisecond", .duration, "Milliseconds", "ms",
            ["ms", "millisecond", "milliseconds"], 0.001,
            defaultTargetID: "duration.second"
        ),
        linearUnit(
            "duration.second", .duration, "Seconds", "s",
            ["s", "sec", "secs", "second", "seconds"], 1,
            defaultTargetID: "duration.minute"
        ),
        linearUnit(
            "duration.minute", .duration, "Minutes", "min",
            ["min", "mins", "minute", "minutes"], 60,
            defaultTargetID: "duration.hour"
        ),
        linearUnit(
            "duration.hour", .duration, "Hours", "h",
            ["h", "hr", "hrs", "hour", "hours"], 3_600,
            defaultTargetID: "duration.day"
        ),
        linearUnit(
            "duration.day", .duration, "Days", "d",
            ["d", "day", "days"], 86_400,
            defaultTargetID: "duration.week"
        ),
        linearUnit(
            "duration.week", .duration, "Weeks", "wk",
            ["wk", "wks", "week", "weeks"], 604_800,
            defaultTargetID: "duration.day"
        ),
        linearUnit(
            "duration.fortnight", .duration, "Fortnights", "fortnight",
            ["fortnight", "fortnights"], 1_209_600,
            defaultTargetID: "duration.day"
        ),
        linearUnit(
            "duration.month", .duration, "Months", "mo",
            ["mo", "month", "months"], 2_629_746,
            defaultTargetID: "duration.day"
        ),
        linearUnit(
            "duration.year", .duration, "Years", "yr",
            ["yr", "yrs", "year", "years"], 31_556_952,
            defaultTargetID: "duration.day"
        ),
        linearUnit(
            "duration.decade", .duration, "Decades", "decade",
            ["decade", "decades"], 315_569_520,
            defaultTargetID: "duration.year"
        ),
        linearUnit(
            "duration.century", .duration, "Centuries", "century",
            ["century", "centuries"], 3_155_695_200,
            defaultTargetID: "duration.year"
        ),
        linearUnit(
            "duration.shake", .duration, "Shakes", "shake",
            ["shake", "shakes"], 1e-8,
            defaultTargetID: "duration.nanosecond"
        ),
        linearUnit(
            "duration.siderealDay", .duration, "Sidereal Days", "sidereal day",
            ["sidereal day", "sidereal days"], 86_164.0905,
            defaultTargetID: "duration.hour"
        ),
        linearUnit(
            "duration.moment", .duration, "Moments", "moment",
            ["moment", "moments"], 90,
            defaultTargetID: "duration.second"
        ),

    ]
}
