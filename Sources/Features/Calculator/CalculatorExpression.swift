//
//  CalculatorExpression.swift
//  Lightsearch
//
// Optional calculator feature implementation. This file contains the small,
// dependency-free expression parser used for arithmetic queries.

import Foundation
import Darwin

enum CalculatorExpressionEvaluator {
    /// Evaluates a complete calculator expression. Invalid expressions and
    /// non-finite results are rejected instead of being partially evaluated.
    static func evaluate(_ source: String, locale: Locale = .current) -> Double? {
        guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        var tokenizer = Tokenizer(source: source, locale: locale)
        guard let tokens = tokenizer.tokenize() else { return nil }

        var parser = Parser(tokens: tokens)
        return parser.parse()
    }

    /// Checks whether an expression represents solely a single number literal.
    static func isPlainNumber(_ source: String, locale: Locale = .current) -> Bool {
        guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        var tokenizer = Tokenizer(source: source, locale: locale)
        guard let tokens = tokenizer.tokenize(), tokens.last == .end else {
            return false
        }

        let contentTokens = tokens.dropLast()
        if contentTokens.count == 1, case .number = contentTokens.first {
            return true
        }
        if contentTokens.count == 2,
           (contentTokens.first == .plus || contentTokens.first == .minus),
           case .number = contentTokens.last {
            return true
        }

        return false
    }

    private enum Token: Equatable {
        case number(Double)
        case identifier(String)
        case plus
        case minus
        case multiply
        case divide
        case power
        case percent
        case percentPostfix
        case factorial
        case leftParenthesis
        case rightParenthesis
        case comma
        case end
    }

    private struct Tokenizer {
        private static let unicodeFractions: [Character: Double] = [
            "½": 0.5,
            "⅓": 1.0 / 3.0,
            "⅔": 2.0 / 3.0,
            "¼": 0.25,
            "¾": 0.75,
            "⅕": 0.2,
            "⅖": 0.4,
            "⅗": 0.6,
            "⅘": 0.8,
            "⅙": 1.0 / 6.0,
            "⅚": 5.0 / 6.0,
            "⅛": 0.125,
            "⅜": 0.375,
            "⅝": 0.625,
            "⅞": 0.875
        ]

        let characters: [Character]
        let locale: Locale
        let decimalSeparator: Character
        let groupingSeparator: Character
        var index = 0
        private var parenStack: [Bool] = []
        private var lastTokenWasIdentifier = false

        init(source: String, locale: Locale = .current) {
            self.characters = Array(source)
            self.locale = locale
            let dec = locale.decimalSeparator?.first ?? "."
            let grp = locale.groupingSeparator?.first ?? ","
            self.decimalSeparator = dec
            self.groupingSeparator = grp
        }

        mutating func tokenize() -> [Token]? {
            var tokens: [Token] = []

            while true {
                let hadWhitespace = skipWhitespace()
                guard index < characters.count else {
                    tokens.append(.end)
                    return tokens
                }

                let character = characters[index]
                switch character {
                case "+":
                    lastTokenWasIdentifier = false
                    index += 1
                    tokens.append(.plus)
                case "-", "−":
                    lastTokenWasIdentifier = false
                    index += 1
                    tokens.append(.minus)
                case "*", "×", "·", "⋅":
                    lastTokenWasIdentifier = false
                    index += 1
                    tokens.append(.multiply)
                case "/", "÷":
                    lastTokenWasIdentifier = false
                    index += 1
                    tokens.append(.divide)
                case "^":
                    lastTokenWasIdentifier = false
                    index += 1
                    tokens.append(.power)
                case "%":
                    lastTokenWasIdentifier = false
                    // An attached percent directly following an operand is
                    // postfix percentage syntax (50%, 50%+3, 50%*2, 50%(2+3)).
                    // A spaced percent is the binary remainder operator (10 % 3).
                    let isPostfix = !hadWhitespace
                    index += 1
                    tokens.append(isPostfix ? .percentPostfix : .percent)
                case "!":
                    lastTokenWasIdentifier = false
                    index += 1
                    tokens.append(.factorial)
                case "(":
                    parenStack.append(lastTokenWasIdentifier)
                    lastTokenWasIdentifier = false
                    index += 1
                    tokens.append(.leftParenthesis)
                case ")":
                    _ = parenStack.popLast()
                    lastTokenWasIdentifier = false
                    index += 1
                    tokens.append(.rightParenthesis)
                case ",":
                    lastTokenWasIdentifier = false
                    if decimalSeparator == ",", index + 1 < characters.count, isASCIIDigit(characters[index + 1]),
                       let number = readNumber() {
                        tokens.append(.number(number))
                    } else {
                        index += 1
                        tokens.append(.comma)
                    }
                case ";":
                    lastTokenWasIdentifier = false
                    index += 1
                    tokens.append(.comma)
                case "π":
                    index += 1
                    tokens.append(.identifier("pi"))
                    lastTokenWasIdentifier = true
                case "τ":
                    index += 1
                    tokens.append(.identifier("tau"))
                    lastTokenWasIdentifier = true
                case ".":
                    lastTokenWasIdentifier = false
                    guard let number = readNumber() else { return nil }
                    tokens.append(.number(number))
                default:
                    if let fraction = Self.unicodeFractions[character] {
                        lastTokenWasIdentifier = false
                        index += 1
                        tokens.append(.number(fraction))
                    } else if let superscriptValue = readSuperscriptNumber() {
                        lastTokenWasIdentifier = false
                        tokens.append(.power)
                        tokens.append(.number(superscriptValue))
                    } else if isASCIIDigit(character) {
                        lastTokenWasIdentifier = false
                        guard let number = readNumber() else { return nil }
                        tokens.append(.number(number))
                    } else if isIdentifierStart(character) {
                        let id = readIdentifier()
                        tokens.append(.identifier(id))
                        lastTokenWasIdentifier = true
                    } else {
                        return nil
                    }
                }
            }
        }

        private mutating func readSuperscriptNumber() -> Double? {
            let startIndex = index
            guard index < characters.count else { return nil }
            let superscripts: [Character: Character] = [
                "⁰": "0", "¹": "1", "²": "2", "³": "3", "⁴": "4",
                "⁵": "5", "⁶": "6", "⁷": "7", "⁸": "8", "⁹": "9"
            ]

            var isNegative = false
            let firstChar = characters[index]
            if firstChar == "⁻" {
                isNegative = true
                index += 1
            } else if firstChar == "⁺" {
                index += 1
            }

            var asciiString = ""
            while index < characters.count, let digit = superscripts[characters[index]] {
                asciiString.append(digit)
                index += 1
            }

            guard !asciiString.isEmpty, let value = Double(asciiString) else {
                index = startIndex
                return nil
            }
            return isNegative ? -value : value
        }

        private mutating func skipWhitespace() -> Bool {
            var skippedWhitespace = false
            while index < characters.count, characters[index].isWhitespace {
                skippedWhitespace = true
                index += 1
            }
            return skippedWhitespace
        }

        private mutating func readIdentifier() -> String {
            let start = index
            while index < characters.count, isIdentifierCharacter(characters[index]) {
                index += 1
            }

            return String(characters[start..<index]).lowercased()
        }

        private mutating func readNumber() -> Double? {
            let start = index
            var integerDigitCount = 0

            while index < characters.count, isASCIIDigit(characters[index]) {
                integerDigitCount += 1
                index += 1
            }

            var usedGroupingSeparator: Character?

            // Grouping separators cannot follow leading zeros (e.g. 0.125, 0,125, or 00,123 is not grouping)
            let allowsGrouping = characters[start] != "0"

            if allowsGrouping, index < characters.count, (characters[index] == "." || characters[index] == ",") {
                let sep = characters[index]
                if let (endIdx, groupCount) = groupingMatch(
                    from: index,
                    separator: sep,
                    integerDigitCount: integerDigitCount
                ) {
                    var isGrouping = false
                    if groupCount > 1 {
                        isGrouping = true
                    } else {
                        // Single separator followed by exactly 3 digits.
                        // If followed by the opposite decimal separator and digits, it's grouping (e.g. 1.234,56 or 1,234.56).
                        let otherSep: Character = (sep == "." ? "," : ".")
                        let hasOppositeDecimal = (endIdx < characters.count && characters[endIdx] == otherSep &&
                            endIdx + 1 < characters.count && isASCIIDigit(characters[endIdx + 1]))
                        let isDirectFunctionArg = (parenStack.last == true)
                        if hasOppositeDecimal {
                            isGrouping = true
                        } else if !isDirectFunctionArg && sep != decimalSeparator {
                            isGrouping = true
                        }
                    }

                    if isGrouping {
                        index = endIdx
                        usedGroupingSeparator = sep
                    }
                }
            }

            var hasFraction = false
            if index < characters.count {
                let char = characters[index]
                var isDecimal = false
                if let grp = usedGroupingSeparator {
                    if grp == "." && char == "," && (index + 1 < characters.count && isASCIIDigit(characters[index + 1])) {
                        isDecimal = true
                    } else if grp == "," && char == "." && (index + 1 < characters.count && isASCIIDigit(characters[index + 1])) {
                        isDecimal = true
                    }
                } else {
                    if char == "." {
                        isDecimal = true
                    } else if char == "," {
                        if decimalSeparator == "," {
                            isDecimal = true
                        }
                    }
                }

                if isDecimal {
                    index += 1
                    let fractionStart = index
                    while index < characters.count, isASCIIDigit(characters[index]) {
                        index += 1
                    }
                    hasFraction = (index > fractionStart)
                }
            }

            var mixedFraction = 0.0
            if integerDigitCount > 0, !hasFraction, index < characters.count,
               let frac = Self.unicodeFractions[characters[index]] {
                index += 1
                mixedFraction = frac
            }

            let hasDigits = integerDigitCount > 0 || hasFraction || mixedFraction > 0
            guard hasDigits else { return nil }

            let significandEnd = index

            // Only consume an exponent when it is complete. A directly
            // adjacent incomplete "e" is rejected rather than interpreted as
            // implicit multiplication by Euler's number.
            if mixedFraction == 0,
               index < characters.count,
               (characters[index] == "e" || characters[index] == "E") {
                var exponentIndex = index + 1
                if exponentIndex < characters.count,
                   characters[exponentIndex] == "+" || characters[exponentIndex] == "-" {
                    exponentIndex += 1
                }

                let exponentDigitsStart = exponentIndex
                while exponentIndex < characters.count,
                      isASCIIDigit(characters[exponentIndex]) {
                    exponentIndex += 1
                }

                if exponentIndex > exponentDigitsStart {
                    index = exponentIndex
                } else {
                    // Keep the parser from turning a partially typed
                    // scientific literal such as "1e" into a valid result.
                    return nil
                }
            }

            var rawNumber = String(characters[start..<index])
            if mixedFraction > 0 {
                rawNumber.removeLast()
            }
            if let grp = usedGroupingSeparator {
                rawNumber = rawNumber.replacingOccurrences(of: String(grp), with: "")
                rawNumber = rawNumber.replacingOccurrences(of: ",", with: ".")
            } else {
                rawNumber = rawNumber.replacingOccurrences(of: ",", with: ".")
            }

            guard let value = Double(rawNumber), value.isFinite else { return nil }
            let significand = String(characters[start..<significandEnd])
            if value == 0, significand.contains(where: { $0 >= "1" && $0 <= "9" }) {
                return nil // Nonzero literal underflowed to zero
            }
            return value + mixedFraction
        }

        private func groupingMatch(
            from separatorIndex: Int,
            separator: Character,
            integerDigitCount: Int
        ) -> (endIndex: Int, groupCount: Int)? {
            guard integerDigitCount >= 1, integerDigitCount <= 3 else {
                return nil
            }

            var cursor = separatorIndex
            var groupCount = 0
            while cursor < characters.count, characters[cursor] == separator {
                cursor += 1
                for _ in 0..<3 {
                    guard cursor < characters.count, isASCIIDigit(characters[cursor]) else {
                        return nil
                    }
                    cursor += 1
                }

                if cursor < characters.count, isASCIIDigit(characters[cursor]) {
                    return nil
                }
                groupCount += 1
            }

            guard groupCount > 0 else { return nil }
            return (cursor, groupCount)
        }

        private func isIdentifierStart(_ character: Character) -> Bool {
            character.isLetter || character == "_"
        }

        private func isIdentifierCharacter(_ character: Character) -> Bool {
            character.isLetter || isASCIIDigit(character) || character == "_"
        }

        private func isASCIIDigit(_ character: Character) -> Bool {
            character >= "0" && character <= "9"
        }
    }

    private struct Parser {
        private static let singleArgumentFunctionNames: Set<String> = [
            "abs", "asin", "asind", "asinr", "acos", "acosd", "acosr",
            "atan", "atand", "atanr", "cbrt", "ceil", "cos", "cosd",
            "cosh", "cosr", "deg", "degrees", "exp", "factorial", "fact",
            "floor", "ln", "log", "log10", "log2", "percent", "rad",
            "radians", "round", "sin", "sind", "sinr", "sinh", "sqrt",
            "tan", "tand", "tanr", "tanh", "trunc"
        ]

        let tokens: [Token]
        var index = 0
        private static let maxRecursionDepth = 200
        private var recursionDepth = 0

        init(tokens: [Token]) {
            self.tokens = tokens
        }

        private mutating func enterRecursion() -> Bool {
            recursionDepth += 1
            return recursionDepth <= Self.maxRecursionDepth
        }

        private mutating func leaveRecursion() {
            recursionDepth -= 1
        }

        mutating func parse() -> Double? {
            guard let value = parseAdditive(), current == .end, value.isFinite else {
                return nil
            }
            return value
        }

        private var current: Token {
            tokens[min(index, tokens.count - 1)]
        }

        private mutating func parseAdditive() -> Double? {
            guard enterRecursion() else { return nil }
            defer { leaveRecursion() }

            guard var value = parseMultiplicative() else { return nil }

            while true {
                if consume(.plus) {
                    guard let rhs = parseMultiplicative(), let result = checked(value + rhs) else {
                        return nil
                    }
                    value = result
                } else if consume(.minus) {
                    guard let rhs = parseMultiplicative(), let result = checked(value - rhs) else {
                        return nil
                    }
                    value = result
                } else {
                    return value
                }
            }
        }

        private mutating func parseMultiplicative() -> Double? {
            guard var value = parseUnary() else { return nil }

            while true {
                if consume(.multiply) {
                    guard let rhs = parseUnary(), let result = checked(value * rhs) else {
                        return nil
                    }
                    value = result
                } else if consume(.divide) {
                    guard let rhs = parseUnary(), rhs != 0,
                          let result = checked(value / rhs) else {
                        return nil
                    }
                    value = result
                } else if consume(.percent) {
                    guard let rhs = parseUnary(), rhs != 0,
                          let result = checked(value.truncatingRemainder(dividingBy: rhs)) else {
                        return nil
                    }
                    value = result
                } else if startsImplicitMultiplication(current) {
                    // Common calculator shorthand: 2π, 2(3 + 4), and
                    // 2sqrt(9).
                    guard let rhs = parseUnary(), let result = checked(value * rhs) else {
                        return nil
                    }
                    value = result
                } else {
                    return value
                }
            }
        }

        private mutating func parseUnary() -> Double? {
            guard enterRecursion() else { return nil }
            defer { leaveRecursion() }

            if consume(.plus) {
                return parseUnary()
            }

            if consume(.minus) {
                guard let value = parseUnary() else { return nil }
                return checked(-value)
            }

            return parsePower()
        }

        private mutating func parsePower() -> Double? {
            guard let base = parsePostfix() else { return nil }

            guard consume(.power) else { return base }
            guard let exponent = parseUnary() else { return nil }

            // pow() returns NaN for a negative base with a non-integral
            // exponent, and infinity for overflow. Both are invalid results.
            if base < 0 {
                guard let expInt = exactInteger(exponent) else {
                    return nil
                }
                if base == -1 {
                    return (expInt % 2 != 0) ? -1.0 : 1.0
                }
            }
            if base == 0, exponent < 0 {
                return nil
            }

            return checked(Darwin.pow(base, exponent))
        }

        private mutating func parsePostfix() -> Double? {
            guard var value = parsePrimary() else { return nil }

            while true {
                if consume(.factorial) {
                    guard let result = factorial(value) else { return nil }
                    value = result
                } else if consume(.percentPostfix) {
                    guard let result = checked(value / 100) else { return nil }
                    value = result
                } else {
                    return value
                }
            }
        }

        private mutating func parsePrimary() -> Double? {
            switch current {
            case let .number(value):
                index += 1
                return value
            case let .identifier(name):
                index += 1

                if let constant = constant(named: name) {
                    return constant
                }

                if consume(.leftParenthesis) {
                    var arguments: [Double] = []
                    if !consume(.rightParenthesis) {
                        while true {
                            guard let argument = parseAdditive() else { return nil }
                            arguments.append(argument)

                            if consume(.rightParenthesis) {
                                break
                            }
                            guard consume(.comma) else { return nil }
                        }
                    }
                    return evaluateFunction(name, arguments: arguments)
                }

                // Support the familiar calculator form "sqrt 9" as well as
                // "sqrt(9)". Multi-argument functions require parentheses.
                guard isSingleArgumentFunction(name), let argument = parseUnary() else {
                    return nil
                }
                return evaluateFunction(name, arguments: [argument])
            case .leftParenthesis:
                index += 1
                guard let value = parseAdditive(), consume(.rightParenthesis) else {
                    return nil
                }
                return value
            default:
                return nil
            }
        }

        private mutating func consume(_ token: Token) -> Bool {
            guard current == token else { return false }
            index += 1
            return true
        }

        private func startsImplicitMultiplication(_ token: Token) -> Bool {
            switch token {
            case .identifier, .leftParenthesis:
                return true
            default:
                return false
            }
        }

        private func constant(named name: String) -> Double? {
            switch name {
            case "pi":
                return .pi
            case "tau":
                return 2 * .pi
            case "e":
                return Darwin.exp(1)
            case "phi", "goldenratio":
                return (1 + Darwin.sqrt(5)) / 2
            default:
                return nil
            }
        }

        private func isSingleArgumentFunction(_ name: String) -> Bool {
            Self.singleArgumentFunctionNames.contains(name)
        }

        private func evaluateFunction(_ name: String, arguments: [Double]) -> Double? {
            switch name {
            case "abs":
                return unary(arguments) { abs($0) }
            case "sqrt":
                return unary(arguments) { value in
                    value >= 0 ? Darwin.sqrt(value) : .nan
                }
            case "cbrt":
                return unary(arguments) { Darwin.cbrt($0) }
            case "floor":
                return unary(arguments) { Darwin.floor($0) }
            case "ceil":
                return unary(arguments) { Darwin.ceil($0) }
            case "round":
                return unary(arguments) { Darwin.round($0) }
            case "trunc":
                return unary(arguments) { $0.rounded(.towardZero) }
            case "ln":
                return unary(arguments) { value in
                    value > 0 ? Darwin.log(value) : .nan
                }
            case "log", "log10":
                if arguments.count == 1 {
                    return checked(Darwin.log10(arguments[0]))
                }
                guard arguments.count == 2,
                      arguments[0] > 0,
                      arguments[1] > 0,
                      arguments[1] != 1 else {
                    return nil
                }
                return checked(Darwin.log(arguments[0]) / Darwin.log(arguments[1]))
            case "log2":
                return unary(arguments) { value in
                    value > 0 ? Darwin.log2(value) : .nan
                }
            case "exp":
                return unary(arguments) { Darwin.exp($0) }
            case "sin", "sind":
                return unary(arguments) { sine($0, degrees: true) }
            case "cos", "cosd":
                return unary(arguments) { cosine($0, degrees: true) }
            case "tan", "tand":
                return unary(arguments) { tangent($0, degrees: true) }
            case "sinr":
                return unary(arguments) { sine($0, degrees: false) }
            case "cosr":
                return unary(arguments) { cosine($0, degrees: false) }
            case "tanr":
                return unary(arguments) { tangent($0, degrees: false) }
            case "asin", "asind":
                return inverseUnary(arguments, function: Darwin.asin, degrees: true)
            case "acos", "acosd":
                return inverseUnary(arguments, function: Darwin.acos, degrees: true)
            case "atan", "atand":
                return inverseUnary(arguments, function: Darwin.atan, degrees: true)
            case "asinr":
                return inverseUnary(arguments, function: Darwin.asin, degrees: false)
            case "acosr":
                return inverseUnary(arguments, function: Darwin.acos, degrees: false)
            case "atanr":
                return inverseUnary(arguments, function: Darwin.atan, degrees: false)
            case "sinh":
                return unary(arguments) { Darwin.sinh($0) }
            case "cosh":
                return unary(arguments) { Darwin.cosh($0) }
            case "tanh":
                return unary(arguments) { Darwin.tanh($0) }
            case "rad", "radians":
                return unary(arguments) { ($0 / 180.0) * .pi }
            case "deg", "degrees":
                return unary(arguments) { ($0 / .pi) * 180.0 }
            case "percent":
                return unary(arguments) { $0 / 100 }
            case "factorial", "fact":
                guard arguments.count == 1 else { return nil }
                return factorial(arguments[0])
            case "pow":
                guard arguments.count == 2 else { return nil }
                return checkedPower(arguments[0], arguments[1])
            case "root":
                guard arguments.count == 2, arguments[1] != 0 else { return nil }
                let radicand = arguments[0]
                let degree = arguments[1]
                if radicand < 0 {
                    guard let degInt = exactInteger(degree), degInt % 2 != 0 else {
                        return nil
                    }
                    let positiveRoot = Darwin.pow(-radicand, 1.0 / degree)
                    return checked(-positiveRoot)
                }
                return checkedPower(radicand, 1.0 / degree)
            case "mod", "modulo":
                guard arguments.count == 2, arguments[1] != 0 else { return nil }
                return checked(arguments[0].truncatingRemainder(dividingBy: arguments[1]))
            case "min":
                guard !arguments.isEmpty else { return nil }
                return checked(arguments.min() ?? .nan)
            case "max":
                guard !arguments.isEmpty else { return nil }
                return checked(arguments.max() ?? .nan)
            case "sum":
                guard !arguments.isEmpty else { return nil }
                return checked(neumaierSum(arguments))
            case "avg", "average", "mean":
                guard !arguments.isEmpty else { return nil }
                return checked(neumaierSum(arguments) / Double(arguments.count))
            case "hypot":
                guard arguments.count == 2 else { return nil }
                return checked(Darwin.hypot(arguments[0], arguments[1]))
            case "ncr", "comb", "choose":
                guard arguments.count == 2 else { return nil }
                return combinations(arguments[0], arguments[1])
            case "npr", "perm":
                guard arguments.count == 2 else { return nil }
                return permutations(arguments[0], arguments[1])
            case "gcd":
                guard arguments.count >= 2 else { return nil }
                return gcd(arguments)
            case "lcm":
                guard arguments.count >= 2 else { return nil }
                return lcm(arguments)
            default:
                return nil
            }
        }

        private func unary(
            _ arguments: [Double],
            _ function: (Double) -> Double
        ) -> Double? {
            guard arguments.count == 1 else { return nil }
            return checked(function(arguments[0]))
        }

        private func inverseUnary(
            _ arguments: [Double],
            function: (Double) -> Double,
            degrees: Bool
        ) -> Double? {
            guard arguments.count == 1 else { return nil }
            let result = function(arguments[0])
            guard result.isFinite else { return nil }
            return checked(degrees ? (result / .pi) * 180.0 : result)
        }

        private func sine(_ value: Double, degrees: Bool) -> Double {
            if degrees {
                let reduced = value.truncatingRemainder(dividingBy: 360)
                return Darwin.sin((reduced / 180.0) * .pi)
            }
            return Darwin.sin(value)
        }

        private func cosine(_ value: Double, degrees: Bool) -> Double {
            if degrees {
                let reduced = value.truncatingRemainder(dividingBy: 360)
                return Darwin.cos((reduced / 180.0) * .pi)
            }
            return Darwin.cos(value)
        }

        private func tangent(_ value: Double, degrees: Bool) -> Double {
            if degrees {
                let reduced = value.truncatingRemainder(dividingBy: 360)
                let angleIn180 = abs(reduced).truncatingRemainder(dividingBy: 180)
                guard abs(angleIn180 - 90) > 1e-10 else { return .nan }
                let radians = (reduced / 180.0) * .pi
                guard abs(Darwin.cos(radians)) > 1e-12 else { return .nan }
                return Darwin.tan(radians)
            }
            guard abs(Darwin.cos(value)) > 1e-12 else { return .nan }
            return Darwin.tan(value)
        }

        private func factorial(_ value: Double) -> Double? {
            guard value.isFinite,
                  value >= 0,
                  value.rounded(.towardZero) == value,
                  value <= 170 else {
                return nil
            }

            var result = 1.0
            if value >= 2 {
                for factor in 2...Int(value) {
                    result *= Double(factor)
                }
            }
            return checked(result)
        }

        private func checkedPower(_ base: Double, _ exponent: Double) -> Double? {
            if base < 0 {
                guard let expInt = exactInteger(exponent) else {
                    return nil
                }
                if base == -1 {
                    return (expInt % 2 != 0) ? -1.0 : 1.0
                }
            }
            if base == 0, exponent < 0 {
                return nil
            }
            return checked(Darwin.pow(base, exponent))
        }

        private func neumaierSum(_ values: [Double]) -> Double {
            var sum = 0.0
            var c = 0.0
            for v in values {
                let t = sum + v
                if abs(sum) >= abs(v) {
                    c += (sum - t) + v
                } else {
                    c += (v - t) + sum
                }
                sum = t
            }
            return sum + c
        }

        private static let maxExactInteger = 9_007_199_254_740_991.0 // 2^53 - 1

        private func exactInteger(_ value: Double) -> Int64? {
            guard value.isFinite,
                  value.rounded(.towardZero) == value,
                  abs(value) <= Self.maxExactInteger else {
                return nil
            }
            return Int64(value)
        }

        private func combinations(_ nVal: Double, _ rVal: Double) -> Double? {
            guard let n64 = exactInteger(nVal),
                  let r64 = exactInteger(rVal),
                  n64 >= 0, r64 >= 0 else {
                return nil
            }

            if r64 > n64 {
                return 0
            }
            if r64 == 0 || r64 == n64 {
                return 1
            }

            let n = Int(n64)
            let r = Int(r64)
            let k = min(r, n - r)
            var result: Int64 = 1
            for i in 1...k {
                let g = gcd2(result, Int64(i))
                let rDivided = result / g
                let iDivided = Int64(i) / g
                let term = Int64(n - i + 1)
                guard term % iDivided == 0 else { return nil }
                let termDivided = term / iDivided
                let (nextResult, overflow) = rDivided.multipliedReportingOverflow(by: termDivided)
                guard !overflow, Double(nextResult) <= Self.maxExactInteger else {
                    return nil
                }
                result = nextResult
            }
            return Double(result)
        }

        private func permutations(_ nVal: Double, _ rVal: Double) -> Double? {
            guard let n64 = exactInteger(nVal),
                  let r64 = exactInteger(rVal),
                  n64 >= 0, r64 >= 0 else {
                return nil
            }

            if r64 > n64 {
                return 0
            }
            if r64 == 0 {
                return 1
            }

            let n = Int(n64)
            let r = Int(r64)
            var result = 1.0
            for i in 0..<r {
                result *= Double(n - i)
                guard result.isFinite else { return nil }
            }
            return checked(result.rounded())
        }

        private func gcd(_ arguments: [Double]) -> Double? {
            guard arguments.count >= 2 else { return nil }
            var result: Int64 = 0

            for (index, arg) in arguments.enumerated() {
                guard let intVal = exactInteger(arg) else {
                    return nil
                }
                let absVal = abs(intVal)
                if index == 0 {
                    result = absVal
                } else {
                    result = gcd2(result, absVal)
                }
            }

            return Double(result)
        }

        private func gcd2(_ a: Int64, _ b: Int64) -> Int64 {
            var x = a
            var y = b
            while y != 0 {
                let temp = y
                y = x % y
                x = temp
            }
            return x
        }

        private func lcm(_ arguments: [Double]) -> Double? {
            guard arguments.count >= 2 else { return nil }
            var result: Int64 = 0

            for (index, arg) in arguments.enumerated() {
                guard let intVal = exactInteger(arg) else {
                    return nil
                }
                let absVal = abs(intVal)
                if index == 0 {
                    result = absVal
                } else {
                    if result == 0 || absVal == 0 {
                        result = 0
                    } else {
                        let g = gcd2(result, absVal)
                        guard g > 0 else { return nil }
                        let divided = result / g
                        let (product, overflow) = divided.multipliedReportingOverflow(by: absVal)
                        guard !overflow, Double(product) <= Self.maxExactInteger else {
                            return nil
                        }
                        result = product
                    }
                }
            }

            return Double(result)
        }

        private func checked(_ value: Double) -> Double? {
            value.isFinite ? value : nil
        }
    }
}
