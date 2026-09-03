//
//  CalculatorExpressionTests.swift
//  LightsearchTests
//

import XCTest
@testable import Lightsearch

@MainActor
final class CalculatorExpressionTests: XCTestCase {
    func testArithmeticPrecedenceAndAssociativity() {
        assertValue("2 + 3 * 4", equals: 14)
        assertValue("2 * 3 + 4", equals: 10)
        assertValue("2 + 3 * 4 ^ 2", equals: 50)
        assertValue("(2 + 3) * 4", equals: 20)
        assertValue("2 * (3 + 4)", equals: 14)
        assertValue("((2 + 3) * (4 - 1)) / 5", equals: 3)
        assertValue("10 - 2 - 3", equals: 5)
        assertValue("24 / 3 / 2", equals: 4)
        assertValue("2 ^ 3 ^ 2", equals: 512)
        assertValue("2 ^ (3 ^ 2)", equals: 512)
        assertValue("(2 ^ 3) ^ 2", equals: 64)
        assertValue("2 ^ -3", equals: 0.125)
        assertValue("2 ^ 0", equals: 1)
        assertValue("0 ^ 0", equals: 1)
        assertValue("0 ^ 2", equals: 0)
        assertValue("(-2) ^ 3", equals: -8)
        assertValue("-2 ^ 2", equals: -4)
        assertValue("(-2) ^ 2", equals: 4)
        assertValue("-(2 + 3) * -4", equals: 20)
        assertValue("2 + -3", equals: -1)
        assertValue("2 - -3", equals: 5)
        assertValue("--5", equals: 5)
        assertValue("++5", equals: 5)
        assertValue("-(-(-5))", equals: -5)
    }

    func testWhitespaceAndCommonOperatorSpellings() {
        assertValue("2+3", equals: 5)
        assertValue("  2   +   3  ", equals: 5)
        assertValue("2−3", equals: -1)
        assertValue("2 × 3", equals: 6)
        assertValue("2·3", equals: 6)
        assertValue("8 ÷ 2", equals: 4)
        assertValue("2 plus 3", equals: 5)
        assertValue("8 minus 3", equals: 5)
        assertValue("2 times 3", equals: 6)
        assertValue("2 multiplied by 3", equals: 6)
        assertValue("8 divided by 2", equals: 4)
        assertValue("8 over 2", equals: 4)
        assertValue("10 mod 3", equals: 1)
        assertValue("10 modulo 3", equals: 1)
    }

    func testDecimalGroupingAndScientificNotation() {
        assertValue("0", equals: 0)
        assertValue("5", equals: 5)
        assertValue("5.", equals: 5)
        assertValue(".5", equals: 0.5)
        assertValue("0.125", equals: 0.125)
        assertValue("1,000 + 2", equals: 1_002)
        assertValue("12,345.5", equals: 12_345.5)
        assertValue("1,000,000 / 10", equals: 100_000)
        assertValue("1.5e2", equals: 150)
        assertValue("2E-3", equals: 0.002)
        assertValue("6.02e23 / 1e23", equals: 6.02)
        assertValue("1e-9 * 1e9", equals: 1)
    }

    func testModuloAndPercentOperators() {
        assertValue("10 % 3", equals: 1)
        assertValue("10 % 3 + 2", equals: 3)
        assertValue("10 + 7 % 4", equals: 13)
        assertValue("-10 % 3", equals: -1)
        assertValue("10 % -3", equals: 1)
        assertValue("50%", equals: 0.5)
        assertValue("50%%", equals: 0.005)
        assertValue("50% - 3", equals: -2.5)
        assertValue("50%-3", equals: 2)
        assertValue("50 % -3", equals: 2)
        assertValue("100 * 25%", equals: 25)
        assertValue("percent(25)", equals: 0.25)
        assertValue("mod(10, 4)", equals: 2)
        assertValue("modulo(17, 5)", equals: 2)
    }

    func testImplicitMultiplication() {
        assertValue("2(3 + 4)", equals: 14)
        assertValue("(2 + 3)(4 - 1)", equals: 15)
        assertValue("2pi", equals: 2 * Double.pi)
        assertValue("2 π", equals: 2 * Double.pi)
        assertValue("3sqrt(4)", equals: 6)
        assertValue("2 sqrt(9)", equals: 6)
        assertValue("2(3)(4)", equals: 24)
    }

    func testConstants() {
        assertValue("pi", equals: Double.pi)
        assertValue("π", equals: Double.pi)
        assertValue("tau", equals: 2 * Double.pi)
        assertValue("τ", equals: 2 * Double.pi)
        assertValue("e", equals: exp(1))
        assertValue("phi", equals: (1 + sqrt(5)) / 2)
        assertValue("goldenratio", equals: (1 + sqrt(5)) / 2)
        assertValue("pi + e", equals: Double.pi + exp(1))
    }

    func testRootsAndRoundingFunctions() {
        assertValue("sqrt(9)", equals: 3)
        assertValue("sqrt 16", equals: 4)
        assertValue("sqrt(81) + sqrt(16)", equals: 13)
        assertValue("sqrt(2)^2", equals: 2, accuracy: 1e-9)
        assertValue("cbrt(27)", equals: 3)
        assertValue("cbrt(-8)", equals: -2)
        assertValue("root(27, 3)", equals: 3)
        assertValue("root(16, 4)", equals: 2)
        assertValue("abs(-12.5)", equals: 12.5)
        assertValue("floor(3.9)", equals: 3)
        assertValue("ceil(3.1)", equals: 4)
        assertValue("round(3.5)", equals: 4)
        assertValue("round(-3.5)", equals: -4)
        assertValue("trunc(-3.9)", equals: -3)
    }

    func testLogarithmAndExponentialFunctions() {
        assertValue("ln(e)", equals: 1, accuracy: 1e-12)
        assertValue("ln(exp(1))", equals: 1, accuracy: 1e-12)
        assertValue("log(100)", equals: 2)
        assertValue("log10(1000)", equals: 3)
        assertValue("log2(8)", equals: 3)
        assertValue("log(8, 2)", equals: 3)
        assertValue("log(81, 3)", equals: 4)
        assertValue("exp(0)", equals: 1)
        assertValue("exp(ln(5))", equals: 5, accuracy: 1e-12)
        assertValue("ln(100) / ln(10)", equals: 2, accuracy: 1e-12)
    }

    func testTrigonometricFunctionsUseDegreesByDefault() {
        assertValue("sin(0)", equals: 0, accuracy: 1e-12)
        assertValue("sin 30", equals: 0.5, accuracy: 1e-12)
        assertValue("cos(60)", equals: 0.5, accuracy: 1e-12)
        assertValue("tan(45)", equals: 1, accuracy: 1e-12)
        assertValue("sin(30 + 30)", equals: 0.8660254037844386, accuracy: 1e-12)
        assertValue("sinr(pi / 2)", equals: 1, accuracy: 1e-12)
        assertValue("cosr(pi)", equals: -1, accuracy: 1e-12)
        assertValue("tanr(pi / 4)", equals: 1, accuracy: 1e-12)
        assertValue("sind(90)", equals: 1, accuracy: 1e-12)
        assertValue("cosd(180)", equals: -1, accuracy: 1e-12)
        assertValue("radians(180)", equals: Double.pi, accuracy: 1e-12)
        assertValue("rad(90)", equals: Double.pi / 2, accuracy: 1e-12)
        assertValue("degrees(pi)", equals: 180, accuracy: 1e-12)
        assertValue("deg(pi / 2)", equals: 90, accuracy: 1e-12)
    }

    func testInverseAndHyperbolicTrigonometricFunctions() {
        assertValue("asin(1)", equals: 90, accuracy: 1e-12)
        assertValue("acos(0)", equals: 90, accuracy: 1e-12)
        assertValue("atan(1)", equals: 45, accuracy: 1e-12)
        assertValue("asinr(1)", equals: Double.pi / 2, accuracy: 1e-12)
        assertValue("acosr(1)", equals: 0, accuracy: 1e-12)
        assertValue("atanr(1)", equals: Double.pi / 4, accuracy: 1e-12)
        assertValue("sinh(0)", equals: 0, accuracy: 1e-12)
        assertValue("cosh(0)", equals: 1, accuracy: 1e-12)
        assertValue("tanh(0)", equals: 0, accuracy: 1e-12)
    }

    func testFactorialAndAggregateFunctions() {
        assertValue("0!", equals: 1)
        assertValue("1!", equals: 1)
        assertValue("5!", equals: 120)
        assertValue("3! + 2", equals: 8)
        assertValue("factorial(6)", equals: 720)
        assertValue("fact(7)", equals: 5_040)
        assertValue("min(4, 2, 9, -1)", equals: -1)
        assertValue("max(4, 2, 9, -1)", equals: 9)
        assertValue("sum(1, 2, 3, 4)", equals: 10)
        assertValue("avg(1, 2, 3, 4)", equals: 2.5)
        assertValue("average(2, 4, 6)", equals: 4)
        assertValue("mean(3, 6, 9)", equals: 6)
        assertValue("hypot(3, 4)", equals: 5)
        assertValue("pow(2, 8)", equals: 256)
    }

    func testNestedAndMixedExpressions() {
        assertValue("sqrt(9) + log(100) * 2", equals: 7)
        assertValue("(1 + 2) ^ 3 - sqrt(16)", equals: 23)
        assertValue("min(2, sqrt(9), 4)", equals: 2)
        assertValue("max(2, abs(-9) / 3, 4)", equals: 4)
        assertValue("sum(1, 2, 3) * avg(2, 4)", equals: 18)
        assertValue("sin(30) ^ 2 + cos(30) ^ 2", equals: 1, accuracy: 1e-12)
        assertValue("2 ^ 3 % 5", equals: 3)
        assertValue("(2 + 3)! / 10", equals: 12)
        assertValue("sqrt(abs(-16)) + cbrt(8)", equals: 6)
        assertValue("log(2 ^ 10, 2)", equals: 10)
    }

    func testInvalidAndUnsafeExpressionsReturnNil() {
        let invalidExpressions = [
            "",
            "   ",
            "2 +",
            "+",
            "-",
            "(",
            ")",
            "(2 + 3",
            "2 + 3)",
            "2 ** 3",
            "2 // 3",
            "2 / 0",
            "2 % 0",
            "50 %",
            "sqrt()",
            "sqrt(1, 2)",
            "sqrt(-1)",
            "ln(0)",
            "ln(-1)",
            "log(0)",
            "log(-1)",
            "log(10, 1)",
            "log(10, 0)",
            "(-2) ^ 0.5",
            "0 ^ -1",
            "tan(90)",
            "tanr(pi / 2)",
            "asin(2)",
            "acos(-2)",
            "factorial(-1)",
            "factorial(3.5)",
            "171!",
            "1e",
            "1e+",
            "1e-",
            "1,2",
            "1,2345",
            "1,234,5678",
            "1..2",
            "2 ? 3",
            "unknown",
            "unknown(2)",
            "min()",
            "min(1,)",
            "min(,1)",
            "sum()",
            "2 divided 4",
            "2 multiplied 4",
            "2 + 3 apples"
        ]

        for expression in invalidExpressions {
            XCTAssertNil(
                CalculatorExpressionEvaluator.evaluate(expression),
                "Expected invalid expression to be rejected: \(expression.debugDescription)"
            )
        }
    }

    func testOverflowAndNonFiniteResultsReturnNil() {
        let unsafeExpressions = [
            "10 ^ 400",
            "(-10) ^ 401.5",
            "1e308 * 1e308",
            "exp(1000)",
            "factorial(171)",
            "sqrt(1e309)",
            "1e309"
        ]

        for expression in unsafeExpressions {
            XCTAssertNil(
                CalculatorExpressionEvaluator.evaluate(expression),
                "Expected non-finite expression to be rejected: \(expression.debugDescription)"
            )
        }
    }

    func testConversionEngineExposesArithmeticWithoutBreakingConversions() {
        let arithmetic = ConversionEngine.result(for: "(2 + 3) * 4")
        XCTAssertEqual(arithmetic?.categoryTitle, "Calculator")
        XCTAssertEqual(arithmetic?.inputLabel, "Expression")
        XCTAssertEqual(arithmetic?.outputValue, "20")
        XCTAssertEqual(arithmetic?.copyText, "20")

        let squareRoot = ConversionEngine.result(for: "sqrt(81)")
        XCTAssertEqual(squareRoot?.categoryTitle, "Calculator")
        XCTAssertEqual(squareRoot?.outputValue, "9")

        let prefixedArithmetic = ConversionEngine.result(for: "what is 2 + 3")
        XCTAssertEqual(prefixedArithmetic?.categoryTitle, "Calculator")
        XCTAssertEqual(prefixedArithmetic?.outputValue, "5")

        let unitConversion = ConversionEngine.result(for: "1 c to f")
        XCTAssertEqual(unitConversion?.categoryTitle, "Temperature")
        XCTAssertEqual(unitConversion?.outputLabel, "Fahrenheit")

        let directTrigonometry = ConversionEngine.result(for: "sin 30")
        XCTAssertEqual(directTrigonometry?.categoryTitle, "Trigonometry")
        XCTAssertEqual(directTrigonometry?.outputValue, displayNumber(0.5))

        let date = ConversionEngine.result(for: "2024-01-01")
        XCTAssertEqual(date?.categoryTitle, "Date & Time")

        let slashDate = ConversionEngine.result(for: "1/1/2020")
        XCTAssertEqual(slashDate?.categoryTitle, "Date & Time")

        XCTAssertNil(ConversionEngine.result(for: "not a calculator expression"))
    }

    private func assertValue(
        _ expression: String,
        equals expected: Double,
        accuracy: Double = 1e-10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let actual = CalculatorExpressionEvaluator.evaluate(expression) else {
            XCTFail("Expected a value for \(expression.debugDescription)", file: file, line: line)
            return
        }

        XCTAssertEqual(actual, expected, accuracy: accuracy, expression, file: file, line: line)
        XCTAssertTrue(actual.isFinite, "Result must be finite: \(expression)", file: file, line: line)
    }

    private func displayNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.maximumFractionDigits = 12
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}
