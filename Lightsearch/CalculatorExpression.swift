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
    static func evaluate(_ source: String) -> Double? {
        guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        var tokenizer = Tokenizer(source: source)
        guard let tokens = tokenizer.tokenize() else { return nil }

        var parser = Parser(tokens: tokens)
        return parser.parse()
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
        let characters: [Character]
        var index = 0

        init(source: String) {
            characters = Array(source)
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
                    if isASCIIDigit(character) {
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

            if index < characters.count, characters[index] == ",",
               let groupingEnd = groupingEnd(
                   from: index,
                   integerDigitCount: integerDigitCount
               ) {
                index = groupingEnd
            }

            var hasDigits = integerDigitCount > 0
            if index < characters.count, characters[index] == "." {
                index += 1
                let fractionStart = index
                while index < characters.count, isASCIIDigit(characters[index]) {
                    index += 1
                }
                hasDigits = hasDigits || index > fractionStart
            }

            guard hasDigits else { return nil }

            // Only consume an exponent when it is complete. A directly
            // adjacent incomplete "e" is rejected rather than interpreted as
            // implicit multiplication by Euler's number.
            if index < characters.count,
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

            let rawNumber = String(characters[start..<index])
                .replacingOccurrences(of: ",", with: "")
            guard let value = Double(rawNumber), value.isFinite else { return nil }
            return value
        }

        private func groupingEnd(
            from commaIndex: Int,
            integerDigitCount: Int
        ) -> Int? {
            guard integerDigitCount >= 1, integerDigitCount <= 3 else {
                return nil
            }

            var cursor = commaIndex
            while cursor < characters.count, characters[cursor] == "," {
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
            }

            return cursor
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
        private static let operatorWords: Set<String> = [
            "by", "divided", "minus", "mod", "modulo", "multiplied",
            "negative", "over", "plus", "positive", "times"
        ]

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
                if consume(.plus) || consumeWord("plus") {
                    guard let rhs = parseMultiplicative(), let result = checked(value + rhs) else {
                        return nil
                    }
                    value = result
                } else if consume(.minus) || consumeWord("minus") {
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
                if consume(.multiply) || consumeWord("times") || consumeWords("multiplied", "by") {
                    guard let rhs = parseUnary(), let result = checked(value * rhs) else {
                        return nil
                    }
                    value = result
                } else if consume(.divide) || consumeWord("over") || consumeWords("divided", "by") {
                    guard let rhs = parseUnary(), rhs != 0,
                          let result = checked(value / rhs) else {
                        return nil
                    }
                    value = result
                } else if consume(.percent) || consumeWord("mod") || consumeWord("modulo") {
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
            if consume(.plus) || consumeWord("positive") {
                return parseUnary()
            }

            if consume(.minus) || consumeWord("negative") {
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

        private mutating func consumeWord(_ word: String) -> Bool {
            guard current == .identifier(word) else { return false }
            index += 1
            return true
        }

        private mutating func consumeWords(_ first: String, _ second: String) -> Bool {
            guard current == .identifier(first), index + 1 < tokens.count,
                  tokens[index + 1] == .identifier(second) else {
                return false
            }
            index += 2
            return true
        }

        private func startsImplicitMultiplication(_ token: Token) -> Bool {
            switch token {
            case let .identifier(name):
                return !isOperatorWord(name)
            case .leftParenthesis:
                return true
            default:
                return false
            }
        }

        private func isOperatorWord(_ name: String) -> Bool {
            Self.operatorWords.contains(name)
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

        private func checked(_ value: Double) -> Double? {
            value.isFinite ? value : nil
        }
    }
}
