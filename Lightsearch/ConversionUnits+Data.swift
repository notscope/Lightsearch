//
// ConversionUnits+Data.swift
// Lightsearch
//

import Foundation

extension ConversionUnitCatalog {
    static let data: [ConversionUnitDefinition] = [
        // MARK: - Digital storage
        // Decimal and IEC binary prefixes are both accepted.
        linearUnit(
            "data.bit", .data, "Bits", "bit",
            ["b", "bit", "bits"], 0.125,
            defaultTargetID: "data.byte"
        ),
        linearUnit(
            "data.byte", .data, "Bytes", "B",
            ["byte", "bytes", "B"], 1,
            defaultTargetID: "data.kilobyte"
        ),
        linearUnit(
            "data.kilobyte", .data, "Kilobytes", "KB",
            ["kb", "KB", "kilobyte", "kilobytes"], 1_000,
            defaultTargetID: "data.megabyte"
        ),
        linearUnit(
            "data.megabyte", .data, "Megabytes", "MB",
            ["mb", "MB", "megabyte", "megabytes"], 1_000_000,
            defaultTargetID: "data.gigabyte"
        ),
        linearUnit(
            "data.gigabyte", .data, "Gigabytes", "GB",
            ["gb", "GB", "gigabyte", "gigabytes"], 1_000_000_000,
            defaultTargetID: "data.terabyte"
        ),
        linearUnit(
            "data.terabyte", .data, "Terabytes", "TB",
            ["tb", "TB", "terabyte", "terabytes"], 1_000_000_000_000,
            defaultTargetID: "data.gigabyte"
        ),
        linearUnit(
            "data.kibibyte", .data, "Kibibytes", "KiB",
            ["kib", "kibibyte", "kibibytes"], 1_024,
            defaultTargetID: "data.byte"
        ),
        linearUnit(
            "data.mebibyte", .data, "Mebibytes", "MiB",
            ["mib", "mebibyte", "mebibytes"], 1_048_576,
            defaultTargetID: "data.kibibyte"
        ),
        linearUnit(
            "data.gibibyte", .data, "Gibibytes", "GiB",
            ["gib", "gibibyte", "gibibytes"], 1_073_741_824,
            defaultTargetID: "data.mebibyte"
        ),
        linearUnit(
            "data.tebibyte", .data, "Tebibytes", "TiB",
            ["tib", "tebibyte", "tebibytes"], 1_099_511_627_776,
            defaultTargetID: "data.gibibyte"
        )
    ]
}
