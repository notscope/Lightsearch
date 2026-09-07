// Correctness and contract tests for the calculator unit-conversion engine.

import Foundation
import XCTest
@testable import Lightsearch

@MainActor
final class UnitConversionTests: XCTestCase {
    private let usLocale = Locale(identifier: "en_US_POSIX")

    func testCatalogContainsEveryCategoryAndAllDefaultTargetsAreValid() {
        let units = ConversionUnitCatalog.all
        let expectedCounts = [
            "Length": 27,
            "Area": 12,
            "Volume": 25,
            "Mass": 19,
            "Temperature": 8,
            "Speed": 8,
            "Time": 16,
            "Angle": 8,
            "Pressure": 11,
            "Energy": 11,
            "Power": 6,
            "Frequency": 6,
            "Data": 10
        ]

        let actualCounts = Dictionary(
            grouping: units,
            by: { $0.category.rawValue }
        ).mapValues { $0.count }

        XCTAssertEqual(actualCounts, expectedCounts)
        XCTAssertEqual(units.count, expectedCounts.values.reduce(0, +))

        let unitsByID = Dictionary(grouping: units, by: { $0.id })
        XCTAssertEqual(
            unitsByID.count,
            units.count,
            "Every conversion unit must have a unique identifier"
        )

        for unit in units {
            XCTAssertFalse(unit.id.isEmpty)
            XCTAssertFalse(unit.name.isEmpty)
            XCTAssertFalse(unit.symbol.isEmpty)
            XCTAssertFalse(unit.aliases.isEmpty)
            XCTAssertTrue(unit.aliases.contains(unit.name))
            XCTAssertTrue(unit.coefficient.isFinite)
            XCTAssertNotEqual(unit.coefficient, 0)
            XCTAssertTrue(unit.offset.isFinite)

            guard let targets = unitsByID[unit.defaultTargetID],
                  let target = targets.first else {
                XCTFail(
                    "Missing default target \(unit.defaultTargetID) for \(unit.id)"
                )
                continue
            }

            XCTAssertEqual(
                target.category.rawValue,
                unit.category.rawValue,
                "Default target for \(unit.id) must stay in the same category"
            )
            XCTAssertNotEqual(
                target.id,
                unit.id,
                "Default target for \(unit.id) must be a different unit"
            )
        }
    }

    func testUnitDefinitionsRoundTripThroughTheirBaseUnits() {
        let sampleValues = [0.0, 1.0, -1.0, 12.345, 1_000.25]

        for unit in ConversionUnitCatalog.all {
            for value in sampleValues {
                let baseValue = unit.toBase(value)
                let restoredValue = unit.fromBase(baseValue)

                XCTAssertTrue(
                    baseValue.isFinite,
                    "Non-finite base value for \(unit.id) and \(value)"
                )
                XCTAssertEqual(
                    restoredValue,
                    value,
                    accuracy: max(1e-12, abs(value) * 1e-12),
                    "Base-unit round trip failed for \(unit.id) and \(value)"
                )
            }
        }
    }

    func testEveryDeclaredAliasCanConvertToItsDefaultTarget() {
        let units = ConversionUnitCatalog.all
        let unitsByID = Dictionary(grouping: units, by: { $0.id })
        var failures: [String] = []

        for unit in units {
            guard let target = unitsByID[unit.defaultTargetID]?.first else {
                failures.append("\(unit.id): missing target \(unit.defaultTargetID)")
                continue
            }

            for alias in unit.aliases {
                let query = "1 \(alias) to \(target.symbol)"
                guard let result = ConversionEngine.result(for: query, locale: usLocale) else {
                    failures.append("\(unit.id) alias \(alias.debugDescription) returned nil")
                    continue
                }

                if result.categoryTitle != unit.category.rawValue
                    || result.inputLabel != unit.name
                    || result.outputLabel != target.name {
                    failures.append(
                        "\(query.debugDescription) resolved as "
                            + "\(result.categoryTitle)/\(result.inputLabel)/\(result.outputLabel)"
                    )
                }
            }
        }

        XCTAssertTrue(
            failures.isEmpty,
            "Alias coverage failures (first 20):\n"
                + failures.prefix(20).joined(separator: "\n")
        )
    }

    func testRepresentativeConversionsAcrossAllCategories() {
        let cases = [
            ConversionCase("1 m to ft", "Length", "Feet", "ft", 3.280839895013123),
            ConversionCase("1 km to mi", "Length", "Miles", "mi", 0.621371192237334),
            ConversionCase("12 in to cm", "Length", "Centimeters", "cm", 30.48),
            ConversionCase("1 nmi to km", "Length", "Kilometers", "km", 1.852),
            ConversionCase("1 m² to ft²", "Area", "Square Feet", "ft²", 10.763910416709722),
            ConversionCase("1 acre to m²", "Area", "Square Meters", "m²", 4_046.8564224),
            ConversionCase("1 mi² to km²", "Area", "Square Kilometers", "km²", 2.589988110336),
            ConversionCase("1 L to mL", "Volume", "Milliliters", "mL", 1_000),
            ConversionCase("1 us gallon to L", "Volume", "Liters", "L", 3.785411784),
            ConversionCase("1 imp gal to L", "Volume", "Liters", "L", 4.54609),
            ConversionCase("1 cup to mL", "Volume", "Milliliters", "mL", 236.5882365),
            ConversionCase("1 kg to lb", "Mass", "Pounds", "lb", 2.2046226218487757),
            ConversionCase("1 oz to g", "Mass", "Grams", "g", 28.349523125),
            ConversionCase("1 stone to kg", "Mass", "Kilograms", "kg", 6.35029318),
            ConversionCase("1 t to kg", "Mass", "Kilograms", "kg", 1_000),
            ConversionCase("0 c to f", "Temperature", "Fahrenheit", "°F", 32),
            ConversionCase("100 c to f", "Temperature", "Fahrenheit", "°F", 212),
            ConversionCase("32 f to c", "Temperature", "Celsius", "°C", 0),
            ConversionCase("0 c to K", "Temperature", "Kelvin", "K", 273.15),
            ConversionCase("-40 c to f", "Temperature", "Fahrenheit", "°F", -40),
            ConversionCase("1 m/s to km/h", "Speed", "Kilometers per Hour", "km/h", 3.6),
            ConversionCase("60 mph to km/h", "Speed", "Kilometers per Hour", "km/h", 96.56064),
            ConversionCase("1 knot to km/h", "Speed", "Kilometers per Hour", "km/h", 1.852),
            ConversionCase("1 Mach to km/h", "Speed", "Kilometers per Hour", "km/h", 1_225.044),
            ConversionCase("1 h to s", "Time", "Seconds", "s", 3_600),
            ConversionCase("1 day to h", "Time", "Hours", "h", 24),
            ConversionCase("1 year to day", "Time", "Days", "d", 365.2425),
            ConversionCase("1 fortnight to day", "Time", "Days", "d", 14),
            ConversionCase("1 shake to ns", "Time", "Nanoseconds", "ns", 10),
            ConversionCase("180 deg to rad", "Angle", "Radians", "rad", Double.pi),
            ConversionCase("1 turn to deg", "Angle", "Degrees", "°", 360),
            ConversionCase("1 arcsec to deg", "Angle", "Degrees", "°", 1.0 / 3_600),
            ConversionCase("200 gon to deg", "Angle", "Degrees", "°", 180),
            ConversionCase("1 atm to kPa", "Pressure", "Kilopascals", "kPa", 101.325),
            ConversionCase("1 bar to kPa", "Pressure", "Kilopascals", "kPa", 100),
            ConversionCase("1 psi to kPa", "Pressure", "Kilopascals", "kPa", 6.894757293168),
            ConversionCase("760 torr to Pa", "Pressure", "Pascals", "Pa", 101_325),
            ConversionCase("1 kWh to J", "Energy", "Joules", "J", 3_600_000),
            ConversionCase("1 cal to J", "Energy", "Joules", "J", 4.184),
            ConversionCase("1 BTU to J", "Energy", "Joules", "J", 1_055.05585262),
            ConversionCase("1 therm to kWh", "Energy", "Kilowatt-Hours", "kWh", 29.30011111111111),
            ConversionCase("1 kW to W", "Power", "Watts", "W", 1_000),
            ConversionCase("1 hp to W", "Power", "Watts", "W", 745.6998715822702),
            ConversionCase("1 PS to W", "Power", "Watts", "W", 735.49875),
            ConversionCase("1 BTU/h to W", "Power", "Watts", "W", 0.2930710701722222),
            ConversionCase("1 kHz to Hz", "Frequency", "Hertz", "Hz", 1_000),
            ConversionCase("60 rpm to Hz", "Frequency", "Hertz", "Hz", 1),
            ConversionCase("60 BPM to Hz", "Frequency", "Hertz", "Hz", 1),
            ConversionCase("1 KB to B", "Data", "Bytes", "B", 1_000),
            ConversionCase("1 KiB to B", "Data", "Bytes", "B", 1_024),
            ConversionCase("1 MB to KB", "Data", "Kilobytes", "KB", 1_000),
            ConversionCase("1 MiB to B", "Data", "Bytes", "B", 1_048_576)
        ]

        for conversionCase in cases {
            assertConversion(conversionCase)
        }
    }

    func testTemperatureOffsetsAndNonCelsiusScales() {
        let cases = [
            ConversionCase("0 c to K", "Temperature", "Kelvin", "K", 273.15),
            ConversionCase("273.15 K to c", "Temperature", "Celsius", "°C", 0),
            ConversionCase("491.67 R to c", "Temperature", "Celsius", "°C", 0),
            ConversionCase("80 ré to c", "Temperature", "Celsius", "°C", 100),
            ConversionCase("33 n to c", "Temperature", "Celsius", "°C", 100),
            ConversionCase("0 de to c", "Temperature", "Celsius", "°C", 100),
            ConversionCase("150 de to c", "Temperature", "Celsius", "°C", 0)
        ]

        for conversionCase in cases {
            assertConversion(conversionCase)
        }
    }

    func testDefaultTargetsAndImplicitOneValueConversions() {
        let defaultCases = [
            ConversionCase("1 m", "Length", "Feet", "ft", 3.280839895013123),
            ConversionCase("1 kg", "Mass", "Pounds", "lb", 2.2046226218487757),
            ConversionCase("1 c", "Temperature", "Fahrenheit", "°F", 33.8),
            ConversionCase("1 L", "Volume", "US Gallons", "gal", 0.2641720523581484),
            ConversionCase("1 m/s", "Speed", "Kilometers per Hour", "km/h", 3.6),
            ConversionCase("1 s", "Time", "Minutes", "min", 1.0 / 60),
            ConversionCase("1 rad", "Angle", "Degrees", "°", 57.29577951308232),
            ConversionCase("1 Pa", "Pressure", "Kilopascals", "kPa", 0.001),
            ConversionCase("1 J", "Energy", "Calories", "cal", 1.0 / 4.184),
            ConversionCase("1 W", "Power", "Kilowatts", "kW", 0.001),
            ConversionCase("1 Hz", "Frequency", "Kilohertz", "kHz", 0.001),
            ConversionCase("1 B", "Data", "Kilobytes", "KB", 0.001)
        ]

        for conversionCase in defaultCases {
            assertConversion(conversionCase)
        }

        assertConversion(
            ConversionCase("m to ft", "Length", "Feet", "ft", 3.280839895013123)
        )
        assertConversion(
            ConversionCase("kg into lb", "Mass", "Pounds", "lb", 2.2046226218487757)
        )
    }

    func testSeparatorsPrefixesAndNumericInputForms() {
        let cases = [
            ConversionCase("2m to cm", "Length", "Centimeters", "cm", 200),
            ConversionCase("1,000 m to ft", "Length", "Feet", "ft", 3_280.839895013123),
            ConversionCase("1.5 km into m", "Length", "Meters", "m", 1_500),
            ConversionCase("3 ft -> in", "Length", "Inches", "in", 36),
            ConversionCase("4 yd => ft", "Length", "Feet", "ft", 12),
            ConversionCase("5 mi = km", "Length", "Kilometers", "km", 8.04672),
            ConversionCase("6 in as cm", "Length", "Centimeters", "cm", 15.24),
            ConversionCase("7 meters in centimeters", "Length", "Centimeters", "cm", 700),
            ConversionCase("convert 8 m to cm", "Length", "Centimeters", "cm", 800),
            ConversionCase("conversion 9 m to cm", "Length", "Centimeters", "cm", 900),
            ConversionCase("what is 10 m to cm", "Length", "Centimeters", "cm", 1_000),
            ConversionCase("what's 11 m to cm", "Length", "Centimeters", "cm", 1_100),
            // "to" must win over the unit-like word "in" when both appear.
            ConversionCase("1 in to cm", "Length", "Centimeters", "cm", 2.54)
        ]

        for conversionCase in cases {
            assertConversion(conversionCase)
        }
    }

    func testAliasesAreCaseWhitespaceAndUnicodeInsensitive() {
        let cases = [
            ConversionCase(" 1 METERS TO FEET ", "Length", "Feet", "ft", 3.280839895013123),
            ConversionCase("1 µm to mm", "Length", "Millimeters", "mm", 0.001),
            ConversionCase("1 μm to mm", "Length", "Millimeters", "mm", 0.001),
            ConversionCase("1 M² to FT²", "Area", "Square Feet", "ft²", 10.763910416709722),
            ConversionCase("1 Réaumur to Celsius", "Temperature", "Celsius", "°C", 1.25),
            ConversionCase("1 ft⋅lb to J", "Energy", "Joules", "J", 1.3558179483314004),
            ConversionCase("1 m³ to L", "Volume", "Liters", "L", 1_000)
        ]

        for conversionCase in cases {
            assertConversion(conversionCase)
        }
    }

    func testLocaleAwareNumericParsingAndFormatting() {
        let germanLocale = Locale(identifier: "de_DE")
        let germanDecimal = ConversionEngine.result(
            for: "1,5 m to cm",
            locale: germanLocale
        )
        XCTAssertEqual(germanDecimal?.inputValue, "1,5 m")
        XCTAssertEqual(germanDecimal?.outputValue, "150 cm")

        let germanGrouped = ConversionEngine.result(
            for: "1.000 m to cm",
            locale: germanLocale
        )
        XCTAssertEqual(germanGrouped?.inputValue, "1.000 m")
        XCTAssertEqual(germanGrouped?.outputValue, "100.000 cm")

        let usGrouped = ConversionEngine.result(
            for: "1,000 m to cm",
            locale: usLocale
        )
        XCTAssertEqual(usGrouped?.inputValue, "1,000 m")
        XCTAssertEqual(usGrouped?.outputValue, "100,000 cm")
    }

    func testZeroNegativeAndScientificNumericInputs() {
        let cases = [
            ConversionCase("0 m to ft", "Length", "Feet", "ft", 0),
            ConversionCase("-10 m to cm", "Length", "Centimeters", "cm", -1_000),
            ConversionCase("0.5 kg to g", "Mass", "Grams", "g", 500),
            ConversionCase("1e3 m to cm", "Length", "Centimeters", "cm", 100_000),
            ConversionCase("-40 f to c", "Temperature", "Celsius", "°C", -40)
        ]

        for conversionCase in cases {
            assertConversion(conversionCase)
        }
    }

    func testInvalidAndCrossCategoryConversionsAreRejected() {
        let invalidQueries = [
            "",
            "   ",
            "10",
            "m",
            "1 unknown to m",
            "1 m to unknown",
            "1 m to kg",
            "1 kg to m",
            "1 c to m",
            "1 m to",
            "1 m ->",
            "1 m =",
            "abc m to ft",
            "1.2.3 m to ft",
            "NaN m to ft",
            "∞ m to ft",
            "1e309 m to ft",
            "1e308 km to m",
            "1 m to cm to ft"
        ]

        for query in invalidQueries {
            XCTAssertNil(
                ConversionEngine.result(for: query, locale: usLocale),
                "Expected converter to reject \(query.debugDescription)"
            )
        }
    }

    func testResultMetadataAndCopyTextStayConsistent() {
        guard let result = ConversionEngine.result(
            for: "2 meters to centimeters",
            locale: usLocale
        ) else {
            XCTFail("Expected a length conversion result")
            return
        }

        XCTAssertEqual(result.categoryTitle, "Length")
        XCTAssertEqual(result.inputValue, "2 m")
        XCTAssertEqual(result.inputLabel, "Meters")
        XCTAssertEqual(result.outputValue, "200 cm")
        XCTAssertEqual(result.outputLabel, "Centimeters")
        XCTAssertEqual(result.copyText, result.outputValue)
        XCTAssertTrue(result.id.hasPrefix("conversion:Length:"))
    }

    private struct ConversionCase {
        let query: String
        let category: String
        let outputLabel: String
        let outputSymbol: String
        let expectedValue: Double

        init(
            _ query: String,
            _ category: String,
            _ outputLabel: String,
            _ outputSymbol: String,
            _ expectedValue: Double
        ) {
            self.query = query
            self.category = category
            self.outputLabel = outputLabel
            self.outputSymbol = outputSymbol
            self.expectedValue = expectedValue
        }
    }

    private func assertConversion(
        _ conversionCase: ConversionCase,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let result = ConversionEngine.result(
            for: conversionCase.query,
            locale: usLocale
        ) else {
            XCTFail(
                "Expected conversion result for \(conversionCase.query.debugDescription)",
                file: file,
                line: line
            )
            return
        }

        XCTAssertEqual(
            result.categoryTitle,
            conversionCase.category,
            file: file,
            line: line
        )
        XCTAssertEqual(
            result.outputLabel,
            conversionCase.outputLabel,
            file: file,
            line: line
        )
        XCTAssertEqual(
            result.copyText,
            result.outputValue,
            file: file,
            line: line
        )

        guard let actualValue = displayedNumber(
            result.outputValue,
            symbol: conversionCase.outputSymbol,
            locale: usLocale
        ) else {
            XCTFail(
                "Could not parse displayed output \(result.outputValue.debugDescription)"
                    + " for \(conversionCase.query.debugDescription)",
                file: file,
                line: line
            )
            return
        }

        XCTAssertEqual(
            actualValue,
            conversionCase.expectedValue,
            accuracy: max(1e-9, abs(conversionCase.expectedValue) * 1e-10),
            "Unexpected value for \(conversionCase.query.debugDescription)",
            file: file,
            line: line
        )
    }

    private func displayedNumber(
        _ output: String,
        symbol: String,
        locale: Locale
    ) -> Double? {
        let suffix = " \(symbol)"
        guard output.hasSuffix(suffix) else { return nil }

        let numberText = String(output.dropLast(suffix.count))

        if let scientificSeparator = numberText.range(of: " × 10") {
            let mantissaText = String(numberText[..<scientificSeparator.lowerBound])
            let exponentText = String(numberText[scientificSeparator.upperBound...])
                .map { superscriptDigit in
                    switch superscriptDigit {
                    case "⁻": return "-"
                    case "⁺": return "+"
                    case "⁰": return "0"
                    case "¹": return "1"
                    case "²": return "2"
                    case "³": return "3"
                    case "⁴": return "4"
                    case "⁵": return "5"
                    case "⁶": return "6"
                    case "⁷": return "7"
                    case "⁸": return "8"
                    case "⁹": return "9"
                    default: return String(superscriptDigit)
                    }
                }
                .joined()

            guard let mantissa = Double(mantissaText),
                  let exponent = Int(exponentText) else {
                return nil
            }
            return mantissa * pow(10, Double(exponent))
        }

        let normalizedNumber = locale.identifier.hasPrefix("en_")
            ? numberText.replacingOccurrences(of: ",", with: "")
            : numberText
        return Double(normalizedNumber)
    }
}
