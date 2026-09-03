//
//  Conversion.swift
//  Lightsearch
//
// Optional calculator feature implementation. Keep calculator-specific
// parsing and evaluation out of the application-search core.

import Foundation
import Darwin

struct ConversionResult: Identifiable {
    let categoryTitle: String
    let inputValue: String
    let inputLabel: String
    let outputValue: String
    let outputLabel: String
    let copyText: String

    var id: String {
        "conversion:\(categoryTitle):\(inputValue):\(inputLabel):\(outputValue):\(outputLabel)"
    }
}

enum ConversionEngine {
    static func result(
        for query: String,
        now: Date = Date(),
        resolvedTimeZone: TimeZone? = nil
    ) -> ConversionResult? {
        let cleanedQuery = cleanQuery(query)
        guard !cleanedQuery.isEmpty else { return nil }

        if let trigonometryResult = trigonometryResult(for: cleanedQuery) {
            return trigonometryResult
        }

        if let dateTimeResult = dateTimeResult(
            for: cleanedQuery,
            now: now,
            resolvedTimeZone: resolvedTimeZone
        ) {
            return dateTimeResult
        }

        if let measurementResult = measurementResult(for: cleanedQuery) {
            return measurementResult
        }

        return calculatorResult(for: cleanedQuery)
    }

    static func timeZoneLocation(for query: String) -> String? {
        currentTimeLocation(from: cleanQuery(query))
    }

    private struct NumericInput {
        let value: Double
        let unitText: String
    }

    private struct SplitQuery {
        let source: String
        let target: String?
    }

    private struct ParsedDate {
        let date: Date
        let hasTime: Bool
        let timeZone: TimeZone
    }

    private enum TrigonometricFunction: String {
        case sin
        case cos
        case tan

        var displayName: String {
            switch self {
            case .sin:
                return "Sine"
            case .cos:
                return "Cosine"
            case .tan:
                return "Tangent"
            }
        }

        func evaluate(_ radians: Double) -> Double? {
            switch self {
            case .sin:
                return Darwin.sin(radians)
            case .cos:
                return Darwin.cos(radians)
            case .tan:
                guard abs(Darwin.cos(radians)) > 1e-12 else { return nil }
                return Darwin.tan(radians)
            }
        }
    }

    private static func cleanQuery(_ query: String) -> String {
        var result = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixes = ["convert ", "conversion ", "what is ", "what's "]

        for prefix in prefixes where result.lowercased().hasPrefix(prefix) {
            result.removeFirst(prefix.count)
            break
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func trigonometryResult(for query: String) -> ConversionResult? {
        let pattern = #"(?i)^\s*(sin|cos|tan)\s*(\(\s*)?([+-]?(?:(?:\d{1,3}(?:,\d{3})+)|(?:\d+(?:\.\d*)?)|(?:\.\d+))(?:[eE][+-]?\d+)?)\s*(°|degrees?|deg|radians?|rad)?\s*(\))?\s*$"#
        guard let match = firstMatch(in: query, pattern: pattern),
              match.count >= 6,
              let function = TrigonometricFunction(rawValue: match[1].lowercased()) else {
            return nil
        }

        let hasOpeningParenthesis = !match[2].isEmpty
        let hasClosingParenthesis = !match[5].isEmpty
        guard hasOpeningParenthesis == hasClosingParenthesis else { return nil }

        let numberText = match[3].replacingOccurrences(of: ",", with: "")
        guard let value = Double(numberText) else { return nil }

        let angleUnit = match[4].lowercased()
        let usesRadians = ["rad", "radian", "radians"].contains(angleUnit)
        let radians = usesRadians ? value : value * .pi / 180
        guard let result = function.evaluate(radians), result.isFinite else { return nil }

        let normalizedResult = abs(result) < 1e-12 ? 0 : result
        let inputUnit = usesRadians ? " rad" : "°"
        let output = formatNumber(normalizedResult)

        return ConversionResult(
            categoryTitle: "Trigonometry",
            inputValue: "\(function.rawValue)(\(formatNumber(value))\(inputUnit))",
            inputLabel: function.displayName,
            outputValue: output,
            outputLabel: "Result",
            copyText: output
        )
    }

    private static func measurementResult(for query: String) -> ConversionResult? {
        let splitQuery = splitQuery(query)
        let numericInput = parseNumericInput(splitQuery.source)
            ?? parseImplicitNumericInput(
                splitQuery.source,
                defaultValue: splitQuery.target == nil ? nil : 1
            )
        guard let numericInput else { return nil }

        let sourceCandidates = matchingUnits(for: numericInput.unitText)
        guard !sourceCandidates.isEmpty else { return nil }

        let source: ConversionUnitDefinition
        let target: ConversionUnitDefinition

        if let targetText = splitQuery.target {
            let targetCandidates = matchingUnits(for: targetText)
            guard !targetCandidates.isEmpty else { return nil }

            var matchingPair: (ConversionUnitDefinition, ConversionUnitDefinition)?
            for sourceCandidate in sourceCandidates {
                if let targetCandidate = targetCandidates.first(where: {
                    sourceCandidate.category == $0.category
                        && sourceCandidate.id != $0.id
                }) {
                    matchingPair = (sourceCandidate, targetCandidate)
                    break
                }
            }

            guard let matchingPair else {
                return nil
            }

            source = matchingPair.0
            target = matchingPair.1
        } else {
            guard let sourceCandidate = sourceCandidates.first,
                  let targetCandidate = ConversionUnitCatalog.all.first(where: {
                      $0.id == sourceCandidate.defaultTargetID
                  }) else {
                return nil
            }

            source = sourceCandidate
            target = targetCandidate
        }

        let convertedValue = target.fromBase(source.toBase(numericInput.value))
        guard convertedValue.isFinite else { return nil }

        let inputNumber = formatNumber(numericInput.value)
        let outputNumber = formatNumber(convertedValue)
        let outputText = "\(outputNumber) \(target.symbol)"

        return ConversionResult(
            categoryTitle: source.category.rawValue,
            inputValue: "\(inputNumber) \(source.symbol)",
            inputLabel: source.name,
            outputValue: outputText,
            outputLabel: target.name,
            copyText: outputText
        )
    }

    private static func calculatorResult(for query: String) -> ConversionResult? {
        guard let value = CalculatorExpressionEvaluator.evaluate(query) else {
            return nil
        }

        let output = formatNumber(value == 0 ? 0 : value)
        return ConversionResult(
            categoryTitle: "Calculator",
            inputValue: query,
            inputLabel: "Expression",
            outputValue: output,
            outputLabel: "Result",
            copyText: output
        )
    }

    private static func parseNumericInput(_ text: String) -> NumericInput? {
        let pattern = #"^\s*([+-]?(?:(?:\d{1,3}(?:,\d{3})+)|(?:\d+(?:\.\d*)?)|(?:\.\d+))(?:[eE][+-]?\d+)?)\s*(.*?)\s*$"#
        guard let match = firstMatch(in: text, pattern: pattern),
              match.count >= 3 else {
            return nil
        }

        let numberText = match[1].replacingOccurrences(of: ",", with: "")
        guard let value = Double(numberText) else { return nil }

        let unitText = match[2].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !unitText.isEmpty else { return nil }
        return NumericInput(value: value, unitText: unitText)
    }

    private static func parseImplicitNumericInput(
        _ text: String,
        defaultValue: Double?
    ) -> NumericInput? {
        guard let defaultValue else { return nil }
        let unitText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !unitText.isEmpty else { return nil }
        return NumericInput(value: defaultValue, unitText: unitText)
    }

    private static func matchingUnits(for text: String) -> [ConversionUnitDefinition] {
        let normalizedText = normalizeUnit(text)
        guard !normalizedText.isEmpty else { return [] }

        return ConversionUnitCatalog.all.filter { unit in
            unit.aliases.contains { normalizeUnit($0) == normalizedText }
        }
    }

    private static func normalizeUnit(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(
                options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive],
                locale: .current
            )
            .lowercased()
            .replacingOccurrences(of: "µ", with: "u")
            .replacingOccurrences(of: "μ", with: "u")
            .replacingOccurrences(of: "°", with: "")
            .replacingOccurrences(of: "²", with: "2")
            .replacingOccurrences(of: "³", with: "3")
            .replacingOccurrences(of: "−", with: "-")
            .replacingOccurrences(of: "·", with: "")
            .replacingOccurrences(of: "⋅", with: "")
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    private static func splitQuery(_ query: String) -> SplitQuery {
        let symbolSeparators = ["->", "=>", "="]
        for separator in symbolSeparators {
            if let range = query.range(of: separator) {
                let source = String(query[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                let target = String(query[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !source.isEmpty, !target.isEmpty {
                    return SplitQuery(source: source, target: target)
                }
            }
        }

        // Check the less ambiguous words first, so "1 in to cm" is split at
        // "to" rather than treating "in" as the target separator.
        for separator in [" to ", " into ", " as ", " in "] {
            if let range = query.range(of: separator, options: [.caseInsensitive]) {
                let source = String(query[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                let target = String(query[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !source.isEmpty, !target.isEmpty {
                    return SplitQuery(source: source, target: target)
                }
            }
        }

        return SplitQuery(source: query, target: nil)
    }

    private static func dateTimeResult(
        for query: String,
        now: Date,
        resolvedTimeZone: TimeZone?
    ) -> ConversionResult? {
        let splitQuery = splitQuery(query)
        let normalizedSource = normalizeUnit(splitQuery.source)

        if ["now", "current time", "current date", "current date time", "current datetime"].contains(normalizedSource) {
            let output = formatDateTime(now, dateStyle: .medium, timeStyle: .short, timeZone: .current)
            return ConversionResult(
                categoryTitle: "Date & Time",
                inputValue: "Now",
                inputLabel: "Current time",
                outputValue: output,
                outputLabel: "Current time, \(timeZoneLabel(.current, at: now))",
                copyText: output
            )
        }

        if let dayOffset: Int = ["today": 0, "tomorrow": 1, "yesterday": -1][normalizedSource] {
            let calendar = calendar(for: .current)
            let date = calendar.date(byAdding: .day, value: dayOffset, to: now) ?? now
            let output = formatDateTime(date, dateStyle: .full, timeStyle: .none, timeZone: .current)
            return ConversionResult(
                categoryTitle: "Date & Time",
                inputValue: splitQuery.source,
                inputLabel: "Date",
                outputValue: output,
                outputLabel: timeZoneLabel(.current, at: date),
                copyText: output
            )
        }

        if let relativeDateResult = relativeDateResult(
            for: splitQuery.source,
            now: now
        ) {
            return relativeDateResult
        }

        if let epochDate = epochDate(from: splitQuery.source) {
            return dateResult(
                for: ParsedDate(date: epochDate, hasTime: true, timeZone: .current),
                sourceText: splitQuery.source,
                targetText: splitQuery.target
            )
        }

        if let currentTimeResult = currentTimeResult(
            for: query,
            now: now,
            resolvedTimeZone: resolvedTimeZone
        ) {
            return currentTimeResult
        }

        if let timeResult = timeResult(
            sourceText: splitQuery.source,
            targetText: splitQuery.target,
            now: now
        ) {
            return timeResult
        }

        guard let parsedDate = parseDate(splitQuery.source, relativeTo: now) else {
            return nil
        }

        return dateResult(
            for: parsedDate,
            sourceText: splitQuery.source,
            targetText: splitQuery.target
        )
    }

    private static func relativeDateResult(
        for sourceText: String,
        now: Date
    ) -> ConversionResult? {
        let patterns: [(String, Int)] = [
            (#"(?i)^\s*(\d+)\s+(day|days|week|weeks|month|months|year|years)\s+ago\s*$"#, -1),
            (#"(?i)^\s*in\s+(\d+)\s+(day|days|week|weeks|month|months|year|years)\s*$"#, 1),
            (#"(?i)^\s*(\d+)\s+(day|days|week|weeks|month|months|year|years)\s+(?:from now|from today)\s*$"#, 1)
        ]

        for (pattern, direction) in patterns {
            guard let match = firstMatch(in: sourceText, pattern: pattern),
                  match.count >= 3,
                  let amount = Int(match[1]) else {
                continue
            }

            let unit = match[2].lowercased()
            let (component, multiplier): (Calendar.Component, Int)
            switch unit {
            case "day", "days":
                component = .day
                multiplier = 1
            case "week", "weeks":
                component = .day
                multiplier = 7
            case "month", "months":
                component = .month
                multiplier = 1
            case "year", "years":
                component = .year
                multiplier = 1
            default:
                continue
            }

            let (scaledAmount, scaleOverflow) = amount.multipliedReportingOverflow(by: multiplier)
            guard !scaleOverflow else { return nil }

            let (signedAmount, signOverflow) = scaledAmount.multipliedReportingOverflow(by: direction)
            guard !signOverflow else { return nil }

            let calendar = calendar(for: .current)
            guard let date = calendar.date(byAdding: component, value: signedAmount, to: now) else {
                return nil
            }

            let output = formatDateTime(
                date,
                dateStyle: .full,
                timeStyle: .none,
                timeZone: .current
            )
            return ConversionResult(
                categoryTitle: "Date & Time",
                inputValue: sourceText.trimmingCharacters(in: .whitespacesAndNewlines),
                inputLabel: "Relative date",
                outputValue: output,
                outputLabel: timeZoneLabel(.current, at: date),
                copyText: output
            )
        }

        return nil
    }

    private static func epochDate(from text: String) -> Date? {
        let patterns = [
            #"^\s*([+-]?(?:\d+(?:\.\d+)?))\s*(?:unix|epoch|timestamp)(?:\s*(?:seconds?|s))?\s*$"#,
            #"^\s*(?:unix|epoch|timestamp)\s*([+-]?(?:\d+(?:\.\d+)?))\s*$"#
        ]

        for pattern in patterns {
            guard let match = firstMatch(in: text, pattern: pattern),
                  match.count >= 2,
                  let number = Double(match[1]) else {
                continue
            }

            let seconds = abs(number) >= 100_000_000_000 ? number / 1_000 : number
            return Date(timeIntervalSince1970: seconds)
        }

        return nil
    }

    private static func currentTimeLocation(from sourceText: String) -> String? {
        let trimmedSource = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercasedSource = trimmedSource.lowercased()
        let prefixes = [
            "what time is it in ",
            "current time in ",
            "time in ",
            "time "
        ]

        for prefix in prefixes {
            guard lowercasedSource.hasPrefix(prefix) else { continue }

            let locationText = String(trimmedSource.dropFirst(prefix.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return locationText.isEmpty ? nil : locationText
        }

        return nil
    }

    private static func currentTimeResult(
        for sourceText: String,
        now: Date,
        resolvedTimeZone: TimeZone?
    ) -> ConversionResult? {
        guard let locationText = currentTimeLocation(from: sourceText),
              let targetTimeZone = timeZone(for: locationText) ?? resolvedTimeZone else {
            return nil
        }

        let output = formatTimeWithDateContext(
            now,
            timeZone: targetTimeZone,
            relativeTo: now
        )
        return ConversionResult(
            categoryTitle: "Date & Time",
            inputValue: "Time in \(locationText)",
            inputLabel: "Current time",
            outputValue: output,
            outputLabel: timeZoneComparisonLabel(targetTimeZone, at: now),
            copyText: output
        )
    }

    private static func formatTimeWithDateContext(
        _ date: Date,
        timeZone: TimeZone,
        relativeTo referenceDate: Date
    ) -> String {
        let time = formatDateTime(
            date,
            dateStyle: .none,
            timeStyle: .short,
            timeZone: timeZone
        )

        guard let dayOffset = calendarDayOffset(
            for: date,
            in: timeZone,
            relativeTo: referenceDate
        ) else {
            return time
        }

        switch dayOffset {
        case -1:
            return "Yesterday, \(time)"
        case 0:
            return time
        case 1:
            return "Tomorrow, \(time)"
        default:
            let dateText = formatDateTime(
                date,
                dateStyle: .full,
                timeStyle: .none,
                timeZone: timeZone
            )
            return "\(dateText), \(time)"
        }
    }

    private static func calendarDayOffset(
        for date: Date,
        in timeZone: TimeZone,
        relativeTo referenceDate: Date
    ) -> Int? {
        let referenceCalendar = calendar(for: .current)
        let targetCalendar = calendar(for: timeZone)
        let dateComponents: Set<Calendar.Component> = [.era, .year, .month, .day]
        let referenceDayComponents = referenceCalendar.dateComponents(
            dateComponents,
            from: referenceDate
        )
        let targetDayComponents = targetCalendar.dateComponents(
            dateComponents,
            from: date
        )

        guard let referenceDay = referenceCalendar.date(from: referenceDayComponents),
              let targetDay = referenceCalendar.date(from: targetDayComponents) else {
            return nil
        }

        return referenceCalendar.dateComponents(
            [.day],
            from: referenceDay,
            to: targetDay
        ).day
    }

    private static func timeResult(
        sourceText: String,
        targetText: String?,
        now: Date
    ) -> ConversionResult? {
        let sourceTimeZoneInfo = splitTimeZone(from: sourceText)
        guard let clock = parseClock(sourceTimeZoneInfo.timeText) else { return nil }

        let sourceTimeZone = sourceTimeZoneInfo.timeZone ?? .current
        let targetTimeZone: TimeZone
        if let targetText {
            guard let parsedTargetTimeZone = timeZone(for: targetText) else { return nil }
            targetTimeZone = parsedTargetTimeZone
        } else {
            guard sourceTimeZoneInfo.timeZone != nil else { return nil }
            targetTimeZone = .current
        }

        let sourceCalendar = calendar(for: sourceTimeZone)
        let dateComponents = sourceCalendar.dateComponents([.year, .month, .day], from: now)
        var components = DateComponents()
        components.year = dateComponents.year
        components.month = dateComponents.month
        components.day = dateComponents.day
        components.hour = clock.hour
        components.minute = clock.minute
        components.second = clock.second

        guard let date = sourceCalendar.date(from: components) else { return nil }

        let inputValue = sourceTimeZoneInfo.timeZone == nil
            ? sourceTimeZoneInfo.timeText
            : "\(sourceTimeZoneInfo.timeText) \(timeZoneLabel(sourceTimeZone, at: date))"
        let output = formatTimeWithDateContext(
            date,
            timeZone: targetTimeZone,
            relativeTo: now
        )

        return ConversionResult(
            categoryTitle: "Date & Time",
            inputValue: inputValue,
            inputLabel: timeZoneLabel(sourceTimeZone, at: date),
            outputValue: output,
            outputLabel: timeZoneComparisonLabel(targetTimeZone, at: date),
            copyText: output
        )
    }

    private static func parseClock(_ text: String) -> (hour: Int, minute: Int, second: Int)? {
        let pattern = #"^\s*(\d{1,2})(?::(\d{2}))?(?::(\d{2}))?\s*([aApP])?\.?[mM]?\.?\s*$"#
        guard let match = firstMatch(in: text, pattern: pattern),
              match.count >= 5,
              let rawHour = Int(match[1]),
              let rawMinute = Int(match[2].isEmpty ? "0" : match[2]),
              let rawSecond = Int(match[3].isEmpty ? "0" : match[3]) else {
            return nil
        }

        guard rawMinute < 60, rawSecond < 60 else { return nil }

        let meridiem = match[4].lowercased()
        var hour = rawHour
        if !meridiem.isEmpty {
            guard rawHour >= 1, rawHour <= 12 else { return nil }
            if meridiem == "p" {
                hour = rawHour == 12 ? 12 : rawHour + 12
            } else {
                hour = rawHour == 12 ? 0 : rawHour
            }
        } else {
            guard rawHour < 24 else { return nil }
        }

        return (hour, rawMinute, rawSecond)
    }

    private static func splitTimeZone(from text: String) -> (timeText: String, timeZone: TimeZone?) {
        let parts = text.split(whereSeparator: { $0.isWhitespace })
        guard let lastPart = parts.last,
              let timeZone = timeZone(for: String(lastPart)) else {
            return (text.trimmingCharacters(in: .whitespacesAndNewlines), nil)
        }

        let timeText = parts.dropLast().joined(separator: " ")
        guard !timeText.isEmpty else {
            return (text.trimmingCharacters(in: .whitespacesAndNewlines), nil)
        }
        return (timeText, timeZone)
    }

    private static func parseDate(_ text: String, relativeTo now: Date) -> ParsedDate? {
        let sourceTimeZoneInfo = splitTimeZone(from: text)
        let sourceText = sourceTimeZoneInfo.timeText
        let sourceTimeZone = sourceTimeZoneInfo.timeZone ?? .current

        if sourceText.contains("T") || sourceText.hasSuffix("Z") {
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = isoFormatter.date(from: sourceText) {
                return ParsedDate(date: date, hasTime: true, timeZone: sourceTimeZone)
            }

            isoFormatter.formatOptions = [.withInternetDateTime]
            if let date = isoFormatter.date(from: sourceText) {
                return ParsedDate(date: date, hasTime: true, timeZone: sourceTimeZone)
            }
        }

        let formats: [(String, Bool)] = [
            ("yyyy-MM-dd HH:mm:ss", true),
            ("yyyy-MM-dd HH:mm", true),
            ("yyyy/MM/dd HH:mm", true),
            ("MM/dd/yyyy HH:mm", true),
            ("dd/MM/yyyy HH:mm", true),
            ("yyyy-MM-dd", false),
            ("yyyy/MM/dd", false),
            ("MM/dd/yyyy", false),
            ("dd/MM/yyyy", false),
            ("MMMM d, yyyy", false),
            ("MMM d, yyyy", false),
            ("d MMMM yyyy", false),
            ("d MMM yyyy", false)
        ]

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar(for: sourceTimeZone)
        formatter.timeZone = sourceTimeZone
        formatter.isLenient = false

        for (format, hasTime) in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: sourceText) {
                return ParsedDate(date: date, hasTime: hasTime, timeZone: sourceTimeZone)
            }
        }

        // Accept a clock with an explicit date omitted only through the time
        // parser; this guard keeps strings such as "12" from becoming dates.
        _ = now
        return nil
    }

    private static func dateResult(
        for parsedDate: ParsedDate,
        sourceText: String,
        targetText: String?
    ) -> ConversionResult {
        if let targetText {
            let normalizedTarget = normalizeUnit(targetText)
            if ["unix", "epoch", "timestamp", "unix timestamp"].contains(normalizedTarget) {
                let output = formatNumber(parsedDate.date.timeIntervalSince1970)
                return ConversionResult(
                    categoryTitle: "Date & Time",
                    inputValue: sourceText,
                    inputLabel: parsedDate.hasTime ? "Date & time" : "Date",
                    outputValue: output,
                    outputLabel: "Unix timestamp",
                    copyText: output
                )
            }

            if ["iso", "iso 8601", "yyyy-mm-dd"].contains(normalizedTarget) {
                let output = formatDateTime(
                    parsedDate.date,
                    dateStyle: .none,
                    timeStyle: .none,
                    timeZone: parsedDate.timeZone,
                    fixedFormat: parsedDate.hasTime ? "yyyy-MM-dd'T'HH:mm:ssXXX" : "yyyy-MM-dd"
                )
                return ConversionResult(
                    categoryTitle: "Date & Time",
                    inputValue: sourceText,
                    inputLabel: parsedDate.hasTime ? "Date & time" : "Date",
                    outputValue: output,
                    outputLabel: "ISO 8601",
                    copyText: output
                )
            }

            if ["us", "american", "mm/dd/yyyy"].contains(normalizedTarget) {
                let output = formatDateTime(
                    parsedDate.date,
                    dateStyle: .none,
                    timeStyle: .none,
                    timeZone: parsedDate.timeZone,
                    fixedFormat: "MM/dd/yyyy"
                )
                return ConversionResult(
                    categoryTitle: "Date & Time",
                    inputValue: sourceText,
                    inputLabel: parsedDate.hasTime ? "Date & time" : "Date",
                    outputValue: output,
                    outputLabel: "US date",
                    copyText: output
                )
            }

            if ["eu", "european", "dd/mm/yyyy"].contains(normalizedTarget) {
                let output = formatDateTime(
                    parsedDate.date,
                    dateStyle: .none,
                    timeStyle: .none,
                    timeZone: parsedDate.timeZone,
                    fixedFormat: "dd/MM/yyyy"
                )
                return ConversionResult(
                    categoryTitle: "Date & Time",
                    inputValue: sourceText,
                    inputLabel: parsedDate.hasTime ? "Date & time" : "Date",
                    outputValue: output,
                    outputLabel: "European date",
                    copyText: output
                )
            }

            if let targetTimeZone = timeZone(for: targetText) {
                let output = formatDateTime(
                    parsedDate.date,
                    dateStyle: parsedDate.hasTime ? .medium : .full,
                    timeStyle: parsedDate.hasTime ? .short : .none,
                    timeZone: targetTimeZone
                )
                return ConversionResult(
                    categoryTitle: "Date & Time",
                    inputValue: sourceText,
                    inputLabel: timeZoneLabel(parsedDate.timeZone, at: parsedDate.date),
                    outputValue: output,
                    outputLabel: timeZoneLabel(targetTimeZone, at: parsedDate.date),
                    copyText: output
                )
            }
        }

        let output = formatDateTime(
            parsedDate.date,
            dateStyle: parsedDate.hasTime ? .medium : .full,
            timeStyle: parsedDate.hasTime ? .short : .none,
            timeZone: .current
        )
        return ConversionResult(
            categoryTitle: "Date & Time",
            inputValue: sourceText,
            inputLabel: parsedDate.hasTime ? "Date & time" : "Date",
            outputValue: output,
            outputLabel: timeZoneLabel(.current, at: parsedDate.date),
            copyText: output
        )
    }

    private static func timeZone(for text: String) -> TimeZone? {
        let normalized = normalizeUnit(text)
        let identifiers: [String: String] = [
            "utc": "UTC",
            "gmt": "GMT",
            "z": "UTC",
            "pst": "America/Los_Angeles",
            "pdt": "America/Los_Angeles",
            "pacific": "America/Los_Angeles",
            "mst": "America/Denver",
            "mdt": "America/Denver",
            "mountain": "America/Denver",
            "cst": "America/Chicago",
            "cdt": "America/Chicago",
            "central": "America/Chicago",
            "est": "America/New_York",
            "edt": "America/New_York",
            "eastern": "America/New_York",
            "cet": "Europe/Paris",
            "cest": "Europe/Paris",
            "central european": "Europe/Paris",
            "bst": "Europe/London",
            "uk": "Europe/London",
            "ist": "Asia/Kolkata",
            "india": "Asia/Kolkata",
            "jst": "Asia/Tokyo",
            "japan": "Asia/Tokyo",
            "kst": "Asia/Seoul",
            "korea": "Asia/Seoul",
            "wib": "Asia/Jakarta",
            "western indonesia": "Asia/Jakarta",
            "wita": "Asia/Makassar",
            "central indonesia": "Asia/Makassar",
            "wit": "Asia/Jayapura",
            "eastern indonesia": "Asia/Jayapura",
            "sgt": "Asia/Singapore",
            "singapore": "Asia/Singapore",
            "aest": "Australia/Sydney",
            "aedt": "Australia/Sydney",
            "sydney": "Australia/Sydney",
            "nzst": "Pacific/Auckland",
            "nzdt": "Pacific/Auckland",
            "auckland": "Pacific/Auckland",
            "local": TimeZone.current.identifier
        ]

        if let identifier = identifiers[normalized] {
            return TimeZone(identifier: identifier)
        }

        if let cityIdentifier = TimeZone.knownTimeZoneIdentifiers.first(where: { identifier in
            guard let city = identifier.split(separator: "/").last else { return false }
            let cityName = String(city).replacingOccurrences(of: "_", with: " ")
            return normalizeUnit(cityName) == normalized
        }) {
            return TimeZone(identifier: cityIdentifier)
        }

        return TimeZone(identifier: text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func timeZoneLabel(_ timeZone: TimeZone, at date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.dateFormat = "z"
        return formatter.string(from: date)
    }

    private static func timeZoneComparisonLabel(_ timeZone: TimeZone, at date: Date) -> String {
        let zoneLabel = timeZoneLabel(timeZone, at: date)
        let offsetDifference = timeZone.secondsFromGMT(for: date)
            - TimeZone.current.secondsFromGMT(for: date)
        guard offsetDifference != 0 else { return zoneLabel }

        let absoluteMinutes = abs(offsetDifference) / 60
        let hours = absoluteMinutes / 60
        let minutes = absoluteMinutes % 60
        let amount: String

        if minutes == 0 {
            amount = "\(hours) \(hours == 1 ? "hour" : "hours")"
        } else if hours == 0 {
            amount = "\(minutes) \(minutes == 1 ? "minute" : "minutes")"
        } else {
            amount = "\(hours) \(hours == 1 ? "hour" : "hours") "
                + "\(minutes) \(minutes == 1 ? "minute" : "minutes")"
        }

        let direction = offsetDifference > 0 ? "ahead" : "behind"
        return "\(zoneLabel), \(amount) \(direction)"
    }

    private static func calendar(for timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    private static func formatDateTime(
        _ date: Date,
        dateStyle: DateFormatter.Style,
        timeStyle: DateFormatter.Style,
        timeZone: TimeZone,
        fixedFormat: String? = nil
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.calendar = calendar(for: timeZone)
        formatter.timeZone = timeZone
        if let fixedFormat {
            formatter.dateFormat = fixedFormat
        } else {
            formatter.dateStyle = dateStyle
            formatter.timeStyle = timeStyle
        }
        return formatter.string(from: date)
    }

    private static func formatNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.usesGroupingSeparator = false
        if value != 0, abs(value) >= 1e15 || abs(value) < 1e-9 {
            formatter.numberStyle = .scientific
            formatter.usesSignificantDigits = true
            formatter.maximumSignificantDigits = 12
            formatter.minimumSignificantDigits = 1
        } else {
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 12
            formatter.minimumFractionDigits = 0
        }
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    private static func firstMatch(in text: String, pattern: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range) else {
            return nil
        }

        return (0..<match.numberOfRanges).map { index in
            let captureRange = match.range(at: index)
            guard captureRange.location != NSNotFound,
                  let swiftRange = Range(captureRange, in: text) else {
                return ""
            }
            return String(text[swiftRange])
        }
    }
}
