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
                    index += 1
                    tokens.append(.plus)
                case "-", "−":
                    index += 1
                    tokens.append(.minus)
                case "*", "×", "·", "⋅":
                    index += 1
                    tokens.append(.multiply)
                case "/", "÷":
                    index += 1
                    tokens.append(.divide)
                case "^":
                    index += 1
                    tokens.append(.power)
                case "%":
                    // A directly attached percent followed by whitespace,
                    // punctuation, or the end is postfix percentage syntax
                    // (50% - 3). A spaced percent or one followed by an
                    // operand remains the binary modulo operator (10 % 3).
                    let nextIndex = index + 1
                    let nextCharacter = nextIndex < characters.count
                        ? characters[nextIndex]
                        : nil
                    let isPostfix = !hadWhitespace && (
                        nextCharacter == nil
                            || nextCharacter?.isWhitespace == true
                            || nextCharacter == ")"
                            || nextCharacter == ","
                            || nextCharacter == "%"
                    )
                    index += 1
                    tokens.append(isPostfix ? .percentPostfix : .percent)
                case "!":
                    index += 1
                    tokens.append(.factorial)
                case "(":
                    index += 1
                    tokens.append(.leftParenthesis)
                case ")":
                    index += 1
                    tokens.append(.rightParenthesis)
                case ",":
                    if decimalSeparator == ",", index + 1 < characters.count, isASCIIDigit(characters[index + 1]),
                       let number = readNumber() {
                        tokens.append(.number(number))
                    } else {
                        index += 1
                        tokens.append(.comma)
                    }
                case ";":
                    index += 1
                    tokens.append(.comma)
                case "π":
                    index += 1
                    tokens.append(.identifier("pi"))
                case "τ":
                    index += 1
                    tokens.append(.identifier("tau"))
                case ".":
                    guard let number = readNumber() else { return nil }
                    tokens.append(.number(number))
                default:
                    if let fraction = Self.unicodeFractions[character] {
                        index += 1
                        tokens.append(.number(fraction))
                    } else if let superscriptValue = readSuperscriptNumber() {
                        tokens.append(.power)
                        tokens.append(.number(superscriptValue))
                    } else if isASCIIDigit(character) {
                        guard let number = readNumber() else { return nil }
                        tokens.append(.number(number))
                    } else if isIdentifierStart(character) {
                        tokens.append(.identifier(readIdentifier()))
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

            // Grouping separators cannot follow a leading zero (e.g. 0.125 or 0,125 is always decimal)
            let allowsGrouping = (characters[start] != "0" || integerDigitCount > 1)

            if allowsGrouping, index < characters.count, (characters[index] == "." || characters[index] == ",") {
                let sep = characters[index]
                if let (endIdx, _) = groupingMatch(
                    from: index,
                    separator: sep,
                    integerDigitCount: integerDigitCount
                ) {
                    index = endIdx
                    usedGroupingSeparator = sep
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
                    } else if char == "," && (index + 1 < characters.count && isASCIIDigit(characters[index + 1])) {
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
            character.isLetter || character.isNumber || character == "_"
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
            if base < 0, exponent.rounded(.towardZero) != exponent {
                return nil
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

                if let constant = constant(named: name) {
                    return constant
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
                return unary(arguments) { $0 * .pi / 180 }
            case "deg", "degrees":
                return unary(arguments) { $0 * 180 / .pi }
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
                return checkedPower(arguments[0], 1 / arguments[1])
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
                return checked(arguments.reduce(0, +))
            case "avg", "average", "mean":
                guard !arguments.isEmpty else { return nil }
                return checked(arguments.reduce(0, +) / Double(arguments.count))
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
            return checked(degrees ? result * 180 / .pi : result)
        }

        private func sine(_ value: Double, degrees: Bool) -> Double {
            Darwin.sin(degrees ? value * .pi / 180 : value)
        }

        private func cosine(_ value: Double, degrees: Bool) -> Double {
            Darwin.cos(degrees ? value * .pi / 180 : value)
        }

        private func tangent(_ value: Double, degrees: Bool) -> Double {
            let radians = degrees ? value * .pi / 180 : value
            guard abs(Darwin.cos(radians)) > 1e-12 else { return .nan }
            return Darwin.tan(radians)
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
            if base < 0, exponent.rounded(.towardZero) != exponent {
                return nil
            }
            if base == 0, exponent < 0 {
                return nil
            }
            return checked(Darwin.pow(base, exponent))
        }

        private func combinations(_ nVal: Double, _ rVal: Double) -> Double? {
            guard nVal.isFinite, rVal.isFinite,
                  nVal >= 0, rVal >= 0,
                  nVal.rounded(.towardZero) == nVal,
                  rVal.rounded(.towardZero) == rVal else {
                return nil
            }

            let n = Int(min(nVal, Double(Int.max)))
            let r = Int(min(rVal, Double(Int.max)))

            if r > n {
                return 0
            }
            if r == 0 || r == n {
                return 1
            }

            let k = min(r, n - r)
            var result = 1.0
            for i in 1...k {
                result = (result * Double(n - i + 1)) / Double(i)
                guard result.isFinite else { return nil }
            }
            return checked(result.rounded())
        }

        private func permutations(_ nVal: Double, _ rVal: Double) -> Double? {
            guard nVal.isFinite, rVal.isFinite,
                  nVal >= 0, rVal >= 0,
                  nVal.rounded(.towardZero) == nVal,
                  rVal.rounded(.towardZero) == rVal else {
                return nil
            }

            let n = Int(min(nVal, Double(Int.max)))
            let r = Int(min(rVal, Double(Int.max)))

            if r > n {
                return 0
            }
            if r == 0 {
                return 1
            }

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
                guard arg.isFinite,
                      arg.rounded(.towardZero) == arg,
                      abs(arg) < Double(Int64.max) else {
                    return nil
                }
                let intVal = abs(Int64(arg))
                if index == 0 {
                    result = intVal
                } else {
                    result = gcd2(result, intVal)
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
            var result: Double = 0

            for (index, arg) in arguments.enumerated() {
                guard arg.isFinite,
                      arg.rounded(.towardZero) == arg else {
                    return nil
                }
                let absArg = abs(arg)
                if index == 0 {
                    result = absArg
                } else {
                    if result == 0 || absArg == 0 {
                        result = 0
                    } else {
                        let g = Double(gcd2(Int64(min(result, Double(Int64.max - 1))), Int64(min(absArg, Double(Int64.max - 1)))))
                        guard g > 0 else { return nil }
                        result = (result / g) * absArg
                        guard result.isFinite else { return nil }
                    }
                }
            }

            return checked(result.rounded())
        }

        private func checked(_ value: Double) -> Double? {
            value.isFinite ? value : nil
        }
    }
}
