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
        assertValue("50 % -3", equals: 2)
        assertValue("50 % (2 + 3)", equals: 0)

        // Attached percent is always postfix percentage
        assertValue("50%", equals: 0.5)
        assertValue("50%%", equals: 0.005)
        assertValue("50%+3", equals: 3.5)
        assertValue("50%*2", equals: 1)
        assertValue("50%/2", equals: 0.25)
        assertValue("50%^2", equals: 0.25)
        assertValue("50%²", equals: 0.25)
        assertValue("50%-3", equals: -2.5)
        assertValue("50% - 3", equals: -2.5)
        assertValue("100 * 25%", equals: 25)
        assertValue("50%(2 + 3)", equals: 2.5)
        assertValue("50%pi", equals: 0.5 * Double.pi)
        assertValue("50%π", equals: 0.5 * Double.pi)
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
        assertValue("pi(2)", equals: 2 * Double.pi)
        assertValue("π(2)", equals: 2 * Double.pi)
        assertValue("e(2)", equals: 2 * exp(1))
        assertValue("tau(2)", equals: 4 * Double.pi)
        assertValue("phi(2)", equals: 1 + sqrt(5))
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
        assertValue("root(-8, 3)", equals: -2)
        assertValue("root(-32, 5)", equals: -2)
        assertValue("root(-8, -3)", equals: -0.5)
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
            "2 *",
            "2 ^",
            "2 /",
            "2 %",
            "(2 +",
            "sin(",
            "sqrt(",
            "+",
            "-",
            "(",
            ")",
            "(2 + 3",
            "2 + 3)",
            "()",
            "( )",
            "(())",
            "2 + ()",
            "() + 2",
            ")(",
            "())()",
            "2 ** 3",
            "2 // 3",
            "2 / 0",
            "1 / (2 - 2)",
            "1 divided by 0",
            "1 over 0",
            "2 % 0",
            "10 mod 0",
            "10 modulo 0",
            "mod(10, 0)",
            "modulo(10, 0)",
            "50 %",
            "sqrt()",
            "sqrt(1, 2)",
            "sqrt(-1)",
            "cbrt()",
            "cbrt(1, 2)",
            "ln()",
            "ln(1, 2)",
            "ln(0)",
            "ln(-1)",
            "log()",
            "log(0)",
            "log(-1)",
            "log(10, 1)",
            "log(10, 0)",
            "log(10, -2)",
            "log(-10, 10)",
            "log(0, 10)",
            "log(10, 10, 10)",
            "log2()",
            "log2(1, 2)",
            "log2(0)",
            "log2(-1)",
            "(-2) ^ 0.5",
            "0 ^ -1",
            "0 ^ -0.5",
            "tan(90)",
            "tan(270)",
            "tan(-90)",
            "tand(90)",
            "tand(270)",
            "tanr(pi / 2)",
            "tanr(-pi / 2)",
            "tanr(3 * pi / 2)",
            "asin(2)",
            "asin(-2)",
            "asin(1.01)",
            "asin(-1.01)",
            "acos(2)",
            "acos(-2)",
            "acos(1.01)",
            "acos(-1.01)",
            "asinr(2)",
            "acosr(2)",
            "factorial(-1)",
            "factorial(-5)",
            "factorial(3.5)",
            "fact(-1)",
            "fact(3.5)",
            "(-1)!",
            "(-5)!",
            "171!",
            "1e",
            "1e+",
            "1e-",
            "2e",
            "2e+",
            "2e-",
            "1,2",
            "1,2345",
            "1,234,5678",
            "1..2",
            "1.2.3",
            "..",
            ".",
            ",",
            ",1",
            "1,",
            "1,,2",
            "2 3",
            "12 34",
            "(2) 3",
            "(2 + 3) 4",
            "2 ? 3",
            "unknown",
            "unknown(2)",
            "min()",
            "min(1,)",
            "min(,1)",
            "max()",
            "sum()",
            "avg()",
            "average()",
            "mean()",
            "hypot()",
            "hypot(1)",
            "hypot(1, 2, 3)",
            "pow()",
            "pow(1)",
            "pow(1, 2, 3)",
            "root()",
            "root(1)",
            "root(1, 2, 3)",
            "root(16, 0)",
            "root(0, -2)",
            "root(-16, 2)",
            "root(-8, 2)",
            "root(-8, 2.5)",
            "root(-8, 4)",
            "mod()",
            "mod(1)",
            "mod(1, 2, 3)",
            "modulo()",
            "modulo(1)",
            "modulo(1, 2, 3)",
            "2 divided 4",
            "2 multiplied 4",
            "10 divided by",
            "10 multiplied by",
            "10 plus",
            "10 minus",
            "10 mod",
            "10 modulo",
            "positive",
            "negative",
            "by 5",
            "over 2",
            "divided by 2",
            "multiplied by 2",
            "2 + 3 apples",
            "safari",
            "chrome",
            "settings",
            "terminal",
            "finder",
            "git status",
            "/System/Applications",
            "apple.com",
            "$50",
            "100$",
            "@user",
            "#hashtag",
            "0,123",
            "00,123"
        ]

        for expression in invalidExpressions {
            XCTAssertNil(
                CalculatorExpressionEvaluator.evaluate(expression, locale: Locale(identifier: "en_US")),
                "Expected invalid expression to be rejected: \(expression.debugDescription)"
            )
        }
    }

    func testOverflowAndNonFiniteResultsReturnNil() {
        let unsafeExpressions = [
            "10 ^ 400",
            "(-10) ^ 401.5",
            "1e308 * 1e308",
            "1e308 + 1e308",
            "-1e308 - 1e308",
            "1e308 / 1e-10",
            "exp(1000)",
            "factorial(171)",
            "fact(171)",
            "pow(10, 400)",
            "hypot(1.5e308, 1.5e308)",
            "sum(1e308, 1e308)",
            "avg(1e308, 1e308)",
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

        let prefixedMultiplication = ConversionEngine.result(for: "what is 10 * 5")
        XCTAssertEqual(prefixedMultiplication?.categoryTitle, "Calculator")
        XCTAssertEqual(prefixedMultiplication?.outputValue, "50")

        let prefixedDivision = ConversionEngine.result(for: "what's 100 / 4")
        XCTAssertEqual(prefixedDivision?.categoryTitle, "Calculator")
        XCTAssertEqual(prefixedDivision?.outputValue, "25")

        let convertPrefixed = ConversionEngine.result(for: "convert 2 + 2")
        XCTAssertEqual(convertPrefixed?.categoryTitle, "Calculator")
        XCTAssertEqual(convertPrefixed?.outputValue, "4")

        let mixedTrigonometry = ConversionEngine.result(for: "sin(30) + 1")
        XCTAssertEqual(mixedTrigonometry?.categoryTitle, "Calculator")
        XCTAssertEqual(mixedTrigonometry?.outputValue, displayNumber(1.5))

        let measurementLength = ConversionEngine.result(for: "10 m to ft")
        XCTAssertEqual(measurementLength?.categoryTitle, "Length")

        let measurementTemp = ConversionEngine.result(for: "100 c to f")
        XCTAssertEqual(measurementTemp?.categoryTitle, "Temperature")

        XCTAssertNil(ConversionEngine.result(for: "not a calculator expression"))
    }

    func testPlainNumbersDoNotTriggerCalculatorMenu() {
        let plainNumbers = [
            "12123123",
            "0",
            "5",
            "-5",
            "+5",
            "42",
            "100",
            "1,000",
            "12,345.5",
            "10.000.000",
            "10,000,000",
            "10,5",
            "0.5",
            ".5",
            "5.",
            "1.5e2",
            "2E-3",
            "(12123123)",
            "((5))",
            "(-5)"
        ]

        for number in plainNumbers {
            XCTAssertNil(
                ConversionEngine.result(for: number),
                "Expected plain number not to show calculator menu: \(number.debugDescription)"
            )
        }

        let validEquations = [
            "12123123 + 1",
            "5 * 5",
            "10 - 2",
            "8 / 2",
            "10 % 3",
            "2 ^ 8",
            "5!",
            "50%",
            "sqrt(81)",
            "pi",
            "(2 + 3) * 4"
        ]

        for equation in validEquations {
            XCTAssertNotNil(
                ConversionEngine.result(for: equation),
                "Expected actual equation to trigger calculator menu: \(equation.debugDescription)"
            )
        }
    }

    func testWordBasedOperatorsAreRejected() {
        let rejectedWordOperators = [
            "2 plus 3",
            "8 minus 3",
            "2 times 3",
            "2 multiplied by 3",
            "8 divided by 2",
            "8 over 2",
            "10 mod 3",
            "10 modulo 3",
            "positive 5",
            "negative 5",
            "positive negative 5",
            "negative negative 5",
            "2 * negative 3",
            "2 + negative 3",
            "2 plus 3 * 4",
            "(2 plus 3) times 4",
            "10 minus 2 times 3",
            "24 divided by 3 divided by 2",
            "2 times 3 times 4",
            "24 over 3 over 2",
            "10 mod 4 mod 3",
            "2 plus 3 multiplied by 4",
            "2 PLUS 3",
            "10 MINUS 4",
            "3 TIMES 5",
            "8 DIVIDED BY 2",
            "8 OVER 2",
            "10 MOD 3"
        ]

        for expression in rejectedWordOperators {
            XCTAssertNil(
                CalculatorExpressionEvaluator.evaluate(expression),
                "Expected word-based operator expression to be rejected: \(expression.debugDescription)"
            )
        }
    }

    func testCaseInsensitiveKeywordsAndFunctions() {
        assertValue("SIN(30)", equals: 0.5, accuracy: 1e-12)
        assertValue("COS(60)", equals: 0.5, accuracy: 1e-12)
        assertValue("TAN(45)", equals: 1, accuracy: 1e-12)
        assertValue("SQRT(16)", equals: 4)
        assertValue("CBRT(27)", equals: 3)
        assertValue("LOG(100)", equals: 2)
        assertValue("LN(E)", equals: 1, accuracy: 1e-12)
        assertValue("ABS(-5)", equals: 5)
        assertValue("MIN(4, 2)", equals: 2)
        assertValue("MAX(4, 2)", equals: 4)
        assertValue("SUM(1, 2, 3)", equals: 6)
        assertValue("PI", equals: Double.pi)
        assertValue("TAU", equals: 2 * Double.pi)
        assertValue("PHI", equals: (1 + sqrt(5)) / 2)
        assertValue("GOLDENRATIO", equals: (1 + sqrt(5)) / 2)
    }

    func testSingleArgumentFunctionsWithoutParentheses() {
        assertValue("cbrt 27", equals: 3)
        assertValue("cbrt -8", equals: -2)
        assertValue("abs -10", equals: 10)
        assertValue("floor 3.9", equals: 3)
        assertValue("ceil 3.1", equals: 4)
        assertValue("round 3.5", equals: 4)
        assertValue("trunc -3.9", equals: -3)
        assertValue("ln e", equals: 1, accuracy: 1e-12)
        assertValue("log 100", equals: 2)
        assertValue("log10 1000", equals: 3)
        assertValue("log2 8", equals: 3)
        assertValue("exp 0", equals: 1)
        assertValue("deg pi", equals: 180, accuracy: 1e-12)
        assertValue("rad 180", equals: Double.pi, accuracy: 1e-12)
        assertValue("sinh 0", equals: 0, accuracy: 1e-12)
        assertValue("cosh 0", equals: 1, accuracy: 1e-12)
        assertValue("tanh 0", equals: 0, accuracy: 1e-12)
        assertValue("percent 50", equals: 0.5)
        assertValue("sin 30 + cos 60", equals: 1, accuracy: 1e-12)
    }

    func testExplicitDegreeAndRadianTrigonometry() {
        assertValue("tand(45)", equals: 1, accuracy: 1e-12)
        assertValue("tand 45", equals: 1, accuracy: 1e-12)
        assertValue("asind(1)", equals: 90, accuracy: 1e-12)
        assertValue("asind(0.5)", equals: 30, accuracy: 1e-12)
        assertValue("acosd(0)", equals: 90, accuracy: 1e-12)
        assertValue("acosd(0.5)", equals: 60, accuracy: 1e-12)
        assertValue("atand(1)", equals: 45, accuracy: 1e-12)
        assertValue("sin(-30)", equals: -0.5, accuracy: 1e-12)
        assertValue("cos(-60)", equals: 0.5, accuracy: 1e-12)
        assertValue("tan(-45)", equals: -1, accuracy: 1e-12)
        assertValue("asinr(0)", equals: 0, accuracy: 1e-12)
        assertValue("asinr(-1)", equals: -Double.pi / 2, accuracy: 1e-12)
        assertValue("acosr(0)", equals: Double.pi / 2, accuracy: 1e-12)
        assertValue("acosr(-1)", equals: Double.pi, accuracy: 1e-12)
        assertValue("atanr(0)", equals: 0, accuracy: 1e-12)
        assertValue("atanr(-1)", equals: -Double.pi / 4, accuracy: 1e-12)
        assertValue("sinh(-1)", equals: -sinh(1), accuracy: 1e-12)
        assertValue("cosh(-1)", equals: cosh(1), accuracy: 1e-12)
        assertValue("tanh(-1)", equals: -tanh(1), accuracy: 1e-12)
        assertValue("cosh(2)^2 - sinh(2)^2", equals: 1, accuracy: 1e-12)
    }

    func testAlgebraicIdentitiesAndConstants() {
        assertValue("phi ^ 2 - phi - 1", equals: 0, accuracy: 1e-12)
        assertValue("goldenratio ^ 2 - goldenratio - 1", equals: 0, accuracy: 1e-12)
        assertValue("2phi", equals: 1 + sqrt(5), accuracy: 1e-12)
        assertValue("2tau", equals: 4 * Double.pi, accuracy: 1e-12)
        assertValue("(2 + 1)pi", equals: 3 * Double.pi, accuracy: 1e-12)
        assertValue("pi / 2", equals: Double.pi / 2, accuracy: 1e-12)
        assertValue("tau / 4", equals: Double.pi / 2, accuracy: 1e-12)
    }

    func testFactorialBoundaryAndComposition() {
        var expectedFactorial170 = 1.0
        for factor in 2...170 {
            expectedFactorial170 *= Double(factor)
        }
        assertValue("170!", equals: expectedFactorial170, accuracy: expectedFactorial170 * 1e-14)
        assertValue("factorial(170)", equals: expectedFactorial170, accuracy: expectedFactorial170 * 1e-14)
        assertValue("(3!)!", equals: 720)
        assertValue("3! ^ 2", equals: 36)
        assertValue("2 ^ 3!", equals: 64)
        assertValue("(4!)%", equals: 0.24, accuracy: 1e-12)
        assertValue("factorial(0)", equals: 1)
        assertValue("fact(0)", equals: 1)
        assertValue("fact(1)", equals: 1)
        assertValue("-3!", equals: -6)
        assertValue("-(3!)", equals: -6)
    }

    func testModuloAndPercentEdgeCases() {
        assertValue("5.5 % 2", equals: 1.5)
        assertValue("mod(5.5, 2)", equals: 1.5)
        assertValue("modulo(5.5, 2)", equals: 1.5)
        assertValue("mod(7.5, 2.5)", equals: 0)
        assertValue("10 % -4", equals: 2)
        assertValue("-10 % 4", equals: -2)
        assertValue("-10 % -4", equals: -2)
        assertValue("(2 + 3)%", equals: 0.05, accuracy: 1e-12)
        assertValue("(50%) ^ 2", equals: 0.25, accuracy: 1e-12)
        assertValue("2 ^ 50%", equals: sqrt(2), accuracy: 1e-12)
        assertValue("min(50%, 25%)", equals: 0.25, accuracy: 1e-12)
    }

    func testAggregateFunctionsEdgeCases() {
        assertValue("min(42)", equals: 42)
        assertValue("max(42)", equals: 42)
        assertValue("sum(42)", equals: 42)
        assertValue("avg(42)", equals: 42)
        assertValue("average(42)", equals: 42)
        assertValue("mean(42)", equals: 42)
        assertValue("sum(-5, 5)", equals: 0)
        assertValue("sum(1, -2, 3, -4, 5)", equals: 3)
        assertValue("min(2 + 3, 3 * 3, 10 / 2)", equals: 5)
        assertValue("max(2 + 3, 3 * 3, 10 / 2)", equals: 9)
        assertValue("sum(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)", equals: 55)
        assertValue("avg(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)", equals: 5.5)
        assertValue("hypot(0, 0)", equals: 0)
        assertValue("hypot(-3, 4)", equals: 5)
        assertValue("hypot(3, -4)", equals: 5)
        assertValue("hypot(-3, -4)", equals: 5)
    }

    func testLogarithmsAndRootsEdgeCases() {
        assertValue("log(1000, 10)", equals: 3)
        assertValue("log(64, 4)", equals: 3)
        assertValue("log(16, 2)", equals: 4)
        assertValue("log(5, 5)", equals: 1)
        assertValue("log(1, 5)", equals: 0)
        assertValue("log10(0.1)", equals: -1, accuracy: 1e-12)
        assertValue("log2(0.5)", equals: -1, accuracy: 1e-12)
        assertValue("log2(1024)", equals: 10)
        assertValue("ln(1)", equals: 0)
        assertValue("root(0, 5)", equals: 0)
        assertValue("root(1000, 3)", equals: 10, accuracy: 1e-12)
        assertValue("root(64, 6)", equals: 2, accuracy: 1e-12)
        assertValue("root(1, 100)", equals: 1)
        assertValue("cbrt(0)", equals: 0)
        assertValue("cbrt(-0.0)", equals: 0)
        assertValue("cbrt(-27)", equals: -3)
    }

    func testRoundingNegativeValuesAndBoundaries() {
        assertValue("floor(-3.1)", equals: -4)
        assertValue("floor(3.0)", equals: 3)
        assertValue("floor(-3.0)", equals: -3)
        assertValue("ceil(-3.9)", equals: -3)
        assertValue("ceil(3.0)", equals: 3)
        assertValue("ceil(-3.0)", equals: -3)
        assertValue("round(2.5)", equals: 3)
        assertValue("round(-2.5)", equals: -3)
        assertValue("round(0.0)", equals: 0)
        assertValue("trunc(3.9)", equals: 3)
        assertValue("trunc(3.0)", equals: 3)
        assertValue("trunc(-3.0)", equals: -3)
    }

    func testNumberFormattingAndUnicodeOperators() {
        assertValue(".0", equals: 0)
        assertValue("0.", equals: 0)
        assertValue(".5 + .5", equals: 1)
        assertValue("1. + 2.", equals: 3)
        assertValue("3 ⋅ 4", equals: 12)
        assertValue("−5", equals: -5)
        assertValue("2 + −3", equals: -1)
        assertValue("5 − −3", equals: 8)
    }

    func testImplicitMultiplicationExpansions() {
        assertValue("(2 + 3)(4 + 5)", equals: 45)
        assertValue("2(3)(4)(5)", equals: 120)
        assertValue("(2)(3)(4)", equals: 24)
        assertValue("3(2pi)", equals: 6 * Double.pi)
    }

    func testDeeplyNestedParentheses() {
        assertValue("((((((((2 + 3))))))))", equals: 5)
        assertValue("(1 + (2 * (3 + (4 * (5 - 3)))))", equals: 23)

        // Recursion depth limit guard: returns nil instead of overflowing stack
        let nested300 = String(repeating: "(", count: 300) + "1" + String(repeating: ")", count: 300)
        XCTAssertNil(CalculatorExpressionEvaluator.evaluate(nested300))

        let unary300 = String(repeating: "-", count: 300) + "1"
        XCTAssertNil(CalculatorExpressionEvaluator.evaluate(unary300))
    }

    private func assertValue(
        _ expression: String,
        equals expected: Double,
        accuracy: Double = 1e-10,
        locale: Locale = Locale(identifier: "en_US"),
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let actual = CalculatorExpressionEvaluator.evaluate(expression, locale: locale) else {
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

    func testTidyLargeNumberAndScientificFormatting() {
        guard let powerResult = ConversionEngine.result(for: "57^144") else {
            XCTFail("Expected result for 57^144")
            return
        }

        XCTAssertTrue(
            powerResult.outputValue.contains("× 10²⁵²"),
            "Expected output to contain scientific notation with superscripts, got: \(powerResult.outputValue)"
        )
        XCTAssertFalse(
            powerResult.outputValue.contains("E"),
            "Expected output not to contain raw 'E', got: \(powerResult.outputValue)"
        )
        XCTAssertFalse(
            powerResult.outputValue.contains("e"),
            "Expected output not to contain raw 'e', got: \(powerResult.outputValue)"
        )

        if let smallResult = ConversionEngine.result(for: "1e-12 * 2") {
            XCTAssertTrue(
                smallResult.outputValue.contains("× 10⁻¹²"),
                "Expected output to contain negative superscripts, got: \(smallResult.outputValue)"
            )
        }

        assertValue("10²", equals: 100)
        assertValue("2³", equals: 8)
        assertValue("10⁻²", equals: 0.01)
        assertValue("7 × 10²", equals: 700)
    }

    func testLocaleAwareNumberParsingAndFormatting() {
        let usLocale = Locale(identifier: "en_US")
        let idLocale = Locale(identifier: "en_ID")
        let deLocale = Locale(identifier: "de_DE")

        // Millions with period grouping: 10.000.000
        XCTAssertEqual(CalculatorExpressionEvaluator.evaluate("10.000.000 + 5", locale: idLocale), 10_000_005)
        XCTAssertEqual(CalculatorExpressionEvaluator.evaluate("10.000.000 + 5", locale: usLocale), 10_000_005)
        XCTAssertEqual(CalculatorExpressionEvaluator.evaluate("10.000.000 + 5", locale: deLocale), 10_000_005)

        // Millions with comma grouping: 10,000,000
        XCTAssertEqual(CalculatorExpressionEvaluator.evaluate("10,000,000 + 5", locale: usLocale), 10_000_005)
        XCTAssertEqual(CalculatorExpressionEvaluator.evaluate("10,000,000 + 5", locale: idLocale), 10_000_005)

        // Comma decimals in comma-decimal locales (en_ID, de_DE):
        XCTAssertEqual(CalculatorExpressionEvaluator.evaluate("10,5 + 2", locale: idLocale), 12.5)
        XCTAssertEqual(CalculatorExpressionEvaluator.evaluate("10,5 + 2", locale: deLocale), 12.5)
        XCTAssertEqual(CalculatorExpressionEvaluator.evaluate(",5 + 1", locale: idLocale), 1.5)
        XCTAssertEqual(CalculatorExpressionEvaluator.evaluate("10.000.000,5 + 1", locale: idLocale), 10_000_001.5)

        // Period decimals in period-decimal locales:
        XCTAssertEqual(CalculatorExpressionEvaluator.evaluate("10.5 + 2", locale: usLocale), 12.5)
        XCTAssertEqual(CalculatorExpressionEvaluator.evaluate(".5 + 1", locale: usLocale), 1.5)
        XCTAssertEqual(CalculatorExpressionEvaluator.evaluate("10,000,000.5 + 1", locale: usLocale), 10_000_001.5)

        // Single separator with 3 trailing digits respects locale
        XCTAssertEqual(CalculatorExpressionEvaluator.evaluate("1.234 + 1", locale: usLocale), 2.234)
        XCTAssertEqual(CalculatorExpressionEvaluator.evaluate("1,234 + 1", locale: usLocale), 1235)
        XCTAssertEqual(CalculatorExpressionEvaluator.evaluate("1,234 + 1", locale: deLocale), 2.234)
        XCTAssertEqual(CalculatorExpressionEvaluator.evaluate("1.234 + 1", locale: deLocale), 1235)
        XCTAssertEqual(CalculatorExpressionEvaluator.evaluate("1,234 + 1", locale: idLocale), 2.234)
        XCTAssertEqual(CalculatorExpressionEvaluator.evaluate("1.234 + 1", locale: idLocale), 1235)

        // Single grouping with opposite decimal
        XCTAssertEqual(CalculatorExpressionEvaluator.evaluate("1,234.56 + 1", locale: usLocale), 1235.56)
        XCTAssertEqual(CalculatorExpressionEvaluator.evaluate("1.234,56 + 1", locale: deLocale), 1235.56)
        XCTAssertEqual(CalculatorExpressionEvaluator.evaluate("1.234,56 + 1", locale: idLocale), 1235.56)

        // Function arguments disambiguation:
        XCTAssertEqual(CalculatorExpressionEvaluator.evaluate("min(10, 5)", locale: usLocale), 5)
        XCTAssertEqual(CalculatorExpressionEvaluator.evaluate("min(10; 5)", locale: idLocale), 5)
        XCTAssertEqual(CalculatorExpressionEvaluator.evaluate("min(10,5; 20,5)", locale: idLocale), 10.5)

        // ConversionEngine results in different locales:
        let idResult = ConversionEngine.result(for: "10.000.000 + 500", locale: idLocale)
        XCTAssertEqual(idResult?.categoryTitle, "Calculator")
        XCTAssertEqual(idResult?.outputValue, "10.000.500")

        let usResult = ConversionEngine.result(for: "10,000,000 + 500", locale: usLocale)
        XCTAssertEqual(usResult?.categoryTitle, "Calculator")
        XCTAssertEqual(usResult?.outputValue, "10,000,500")

        // Plain numbers are suppressed:
        XCTAssertNil(ConversionEngine.result(for: "10.000.000", locale: idLocale))
        XCTAssertNil(ConversionEngine.result(for: "10,000,000", locale: idLocale))
        XCTAssertNil(ConversionEngine.result(for: "10.000.000", locale: usLocale))
        XCTAssertNil(ConversionEngine.result(for: "10,000,000", locale: usLocale))
        XCTAssertNil(ConversionEngine.result(for: "10,5", locale: idLocale))
        XCTAssertNil(ConversionEngine.result(for: "10.5", locale: usLocale))
    }

    func testCombinatoricsAndNumberTheoryFunctions() {
        assertValue("nCr(10, 2)", equals: 45)
        assertValue("ncr(10, 2)", equals: 45)
        assertValue("comb(10, 2)", equals: 45)
        assertValue("choose(10, 2)", equals: 45)
        assertValue("nCr(5, 5)", equals: 1)
        assertValue("nCr(5, 0)", equals: 1)
        assertValue("nCr(5, 6)", equals: 0)
        assertValue("nCr(100, 2)", equals: 4950)

        assertValue("nPr(10, 2)", equals: 90)
        assertValue("npr(10, 2)", equals: 90)
        assertValue("perm(10, 2)", equals: 90)
        assertValue("nPr(5, 5)", equals: 120)
        assertValue("nPr(5, 0)", equals: 1)
        assertValue("nPr(5, 6)", equals: 0)

        XCTAssertNil(CalculatorExpressionEvaluator.evaluate("nCr(4.5, 2)"))
        XCTAssertNil(CalculatorExpressionEvaluator.evaluate("nCr(4, 2.5)"))
        XCTAssertNil(CalculatorExpressionEvaluator.evaluate("nCr(-5, 2)"))
        XCTAssertNil(CalculatorExpressionEvaluator.evaluate("nCr(5, -2)"))
        XCTAssertNil(CalculatorExpressionEvaluator.evaluate("nPr(4.5, 2)"))
        XCTAssertNil(CalculatorExpressionEvaluator.evaluate("nPr(-5, 2)"))

        assertValue("gcd(12, 18)", equals: 6)
        assertValue("gcd(-12, 18)", equals: 6)
        assertValue("gcd(12, 18, 24)", equals: 6)
        assertValue("gcd(7, 13)", equals: 1)
        assertValue("gcd(0, 5)", equals: 5)
        assertValue("gcd(5, 0)", equals: 5)
        assertValue("gcd(0, 0)", equals: 0)
        XCTAssertNil(CalculatorExpressionEvaluator.evaluate("gcd(12.5, 4)"))
        XCTAssertNil(CalculatorExpressionEvaluator.evaluate("gcd(12)"))

        assertValue("lcm(4, 6)", equals: 12)
        assertValue("lcm(-4, 6)", equals: 12)
        assertValue("lcm(12, 18, 24)", equals: 72)
        assertValue("lcm(2, 3, 5)", equals: 30)
        assertValue("lcm(3, 4, 6, 8, 12)", equals: 24)
        assertValue("lcm(6, 8, 10, 12, 14, 16)", equals: 1680)
        assertValue("lcm(0, 5)", equals: 0)
        assertValue("lcm(5, 0)", equals: 0)
        XCTAssertNil(CalculatorExpressionEvaluator.evaluate("lcm(4.5, 6)"))
        XCTAssertNil(CalculatorExpressionEvaluator.evaluate("lcm(4)"))
    }

    func testUnicodeFractions() {
        assertValue("½", equals: 0.5)
        assertValue("¼", equals: 0.25)
        assertValue("¾", equals: 0.75)
        assertValue("⅛", equals: 0.125)
        assertValue("⅜", equals: 0.375)
        assertValue("⅝", equals: 0.625)
        assertValue("⅞", equals: 0.875)
        assertValue("⅕", equals: 0.2)
        assertValue("⅖", equals: 0.4)
        assertValue("⅗", equals: 0.6)
        assertValue("⅘", equals: 0.8)
        assertValue("⅓ + ⅔", equals: 1.0)
        assertValue("⅙ + ⅚", equals: 1.0)

        assertValue("½ + ½", equals: 1.0)
        assertValue("10 * ½", equals: 5.0)
        assertValue("3 * ¾", equals: 2.25)
        assertValue("1 - ¼", equals: 0.75)

        assertValue("2½", equals: 2.5)
        assertValue("1¼", equals: 1.25)
        assertValue("3¾", equals: 3.75)
        assertValue("2½ + ¼", equals: 2.75)
        assertValue("2½ * 2", equals: 5.0)

        XCTAssertNil(ConversionEngine.result(for: "½"))
        XCTAssertNil(ConversionEngine.result(for: "2½"))
    }

    func testIntegerSafetyBoundaries() {
        XCTAssertNil(CalculatorExpressionEvaluator.evaluate("nCr(100000000000000000000, 2)"))
        XCTAssertNil(CalculatorExpressionEvaluator.evaluate("nPr(100000000000000000000, 2)"))
        XCTAssertNil(CalculatorExpressionEvaluator.evaluate("nCr(1e20, 2)"))
        XCTAssertNil(CalculatorExpressionEvaluator.evaluate("nPr(1e20, 2)"))
        XCTAssertNil(CalculatorExpressionEvaluator.evaluate("lcm(100000000000000000000, 2)"))
        XCTAssertNil(CalculatorExpressionEvaluator.evaluate("lcm(1e20, 3)"))
        XCTAssertNil(CalculatorExpressionEvaluator.evaluate("lcm(9223372036854775808, 2)"))
        XCTAssertNil(CalculatorExpressionEvaluator.evaluate("gcd(9007199254740993, 2)"))
        XCTAssertNil(CalculatorExpressionEvaluator.evaluate("lcm(9007199254740993, 2)"))
        XCTAssertNil(CalculatorExpressionEvaluator.evaluate("nCr(9007199254740993, 1)"))
        XCTAssertNil(CalculatorExpressionEvaluator.evaluate("nPr(9007199254740993, 1)"))

        assertValue("gcd(9007199254740991, 1)", equals: 1)
        assertValue("lcm(9007199254740991, 1)", equals: 9_007_199_254_740_991)
    }

    func testUnaryPowerEdgePrecedence() {
        assertValue("2^-2", equals: 0.25)
        assertValue("2^-2^2", equals: 1.0 / 16.0)
        assertValue("-2^-2", equals: -0.25)
        assertValue("(-2)^-2", equals: 0.25)
        assertValue("-2^2^3", equals: -256)
    }

    func testSuperscriptEdgeCases() {
        assertValue("2¹⁰", equals: 1024)
        assertValue("2⁺²", equals: 4)
        assertValue("2⁰", equals: 1)
        assertValue("2⁻⁰", equals: 1)
        assertValue("2⁻¹⁰", equals: 1.0 / 1024.0)

        XCTAssertNil(CalculatorExpressionEvaluator.evaluate("2⁻"))
        XCTAssertNil(CalculatorExpressionEvaluator.evaluate("2⁺"))
        XCTAssertNil(CalculatorExpressionEvaluator.evaluate("⁻²"))
        XCTAssertNil(CalculatorExpressionEvaluator.evaluate("⁺²"))
    }

    func testLargeFlatExpressionDoesNotCrash() {
        let expression = Array(repeating: "1", count: 5_000).joined(separator: "+")
        XCTAssertEqual(CalculatorExpressionEvaluator.evaluate(expression), 5_000)

        let args = Array(repeating: "1", count: 1_000).joined(separator: ", ")
        XCTAssertEqual(
            CalculatorExpressionEvaluator.evaluate("sum(\(args))", locale: Locale(identifier: "en_US")),
            1_000
        )
    }

    func testAlgebraicInvariantsAndProperties() throws {
        let usLocale = Locale(identifier: "en_US")
        let pairs: [(Double, Double)] = [(2, 3), (7, 13), (100, 25), (0.5, 0.25)]
        for (a, b) in pairs {
            let sumAB = try XCTUnwrap(CalculatorExpressionEvaluator.evaluate("\(a) + \(b)", locale: usLocale))
            let sumBA = try XCTUnwrap(CalculatorExpressionEvaluator.evaluate("\(b) + \(a)", locale: usLocale))
            XCTAssertEqual(sumAB, sumBA)

            let mulAB = try XCTUnwrap(CalculatorExpressionEvaluator.evaluate("\(a) * \(b)", locale: usLocale))
            let mulBA = try XCTUnwrap(CalculatorExpressionEvaluator.evaluate("\(b) * \(a)", locale: usLocale))
            XCTAssertEqual(mulAB, mulBA)

            XCTAssertEqual(CalculatorExpressionEvaluator.evaluate("\(a) + 0", locale: usLocale), a)
            XCTAssertEqual(CalculatorExpressionEvaluator.evaluate("\(a) * 1", locale: usLocale), a)

            XCTAssertEqual(CalculatorExpressionEvaluator.evaluate("--\(a)", locale: usLocale), a)
            XCTAssertEqual(CalculatorExpressionEvaluator.evaluate("(\(a))", locale: usLocale), a)

            XCTAssertEqual(CalculatorExpressionEvaluator.evaluate("\(a)%", locale: usLocale), a / 100)

            XCTAssertEqual(CalculatorExpressionEvaluator.evaluate("\(a)^0", locale: usLocale), 1)
            XCTAssertEqual(CalculatorExpressionEvaluator.evaluate("\(a)^1", locale: usLocale), a)
        }

        let intPairs: [(Int64, Int64)] = [(12, 18), (7, 13), (48, 180), (14, 35)]
        for (a, b) in intPairs {
            let gcdAB = try XCTUnwrap(CalculatorExpressionEvaluator.evaluate("gcd(\(a), \(b))", locale: usLocale))
            let gcdBA = try XCTUnwrap(CalculatorExpressionEvaluator.evaluate("gcd(\(b), \(a))", locale: usLocale))
            XCTAssertEqual(gcdAB, gcdBA)

            let lcmAB = try XCTUnwrap(CalculatorExpressionEvaluator.evaluate("lcm(\(a), \(b))", locale: usLocale))
            let lcmBA = try XCTUnwrap(CalculatorExpressionEvaluator.evaluate("lcm(\(b), \(a))", locale: usLocale))
            XCTAssertEqual(lcmAB, lcmBA)

            XCTAssertEqual(gcdAB * lcmAB, Double(a * b))
            XCTAssertEqual(CalculatorExpressionEvaluator.evaluate("gcd(\(a), 0)", locale: usLocale), Double(a))
        }
    }

    func testFunctionCommaGroupingAmbiguity() {
        assertValue("pow(2,100)", equals: pow(2, 100))
        assertValue("mod(2,100)", equals: 2)
        assertValue("gcd(2,100)", equals: 2)
        assertValue("sum(2,100)", equals: 102)
        assertValue("avg(2,100)", equals: 51)
        assertValue("min(1,234)", equals: 1)
        assertValue("log(8,100)", equals: log(8) / log(100))
        assertValue("hypot(3,400)", equals: Darwin.hypot(3, 400))
    }

    func testCombinationExactnessRegression() {
        assertValue("nCr(56,24)", equals: 4_355_031_703_297_275, accuracy: 0)
        assertValue("nCr(60,20)", equals: 4_191_844_505_805_495, accuracy: 0)
        assertValue("nCr(56,25)", equals: 5_574_440_580_220_512, accuracy: 0)
    }

    func testNegativePowerIntegerPrecisionBoundary() {
        assertValue("(-1)^9007199254740991", equals: -1)
        assertValue("(-1)^9007199254740990", equals: 1)
        assertValue("pow(-1, 9007199254740991)", equals: -1)
        assertValue("pow(-1, 9007199254740990)", equals: 1)

        XCTAssertNil(CalculatorExpressionEvaluator.evaluate("(-1)^9007199254740993"))
        XCTAssertNil(CalculatorExpressionEvaluator.evaluate("pow(-1, 9007199254740993)"))
    }

    func testSuperscriptConstants() {
        assertValue("pi²", equals: Double.pi * Double.pi)
        assertValue("π²", equals: Double.pi * Double.pi)
        assertValue("e²", equals: exp(2))
        assertValue("tau²", equals: pow(2 * Double.pi, 2))
        assertValue("2pi²", equals: 2 * Double.pi * Double.pi)
        let phi = (1 + sqrt(5)) / 2
        assertValue("phi²", equals: phi * phi)
    }

    func testLiteralUnderflowDoesNotBecomeExactZero() {
        XCTAssertNil(CalculatorExpressionEvaluator.evaluate("1e-400"))
        XCTAssertNil(CalculatorExpressionEvaluator.evaluate("factorial(1e-400)"))
        XCTAssertNil(CalculatorExpressionEvaluator.evaluate("(-2)^1e-400"))
        XCTAssertNil(CalculatorExpressionEvaluator.evaluate("gcd(1e-400, 2)"))
        XCTAssertNil(CalculatorExpressionEvaluator.evaluate("0^-1e-400"))

        // Exact zeros remain valid
        assertValue("0", equals: 0)
        assertValue("0.0", equals: 0)
        assertValue("0e5", equals: 0)
    }

    func testLargeDegreeTrigReduction() {
        assertValue("sin(360000000000090)", equals: 1, accuracy: 1e-12)
        assertValue("cos(360000000000090)", equals: 0, accuracy: 1e-12)
        XCTAssertNil(CalculatorExpressionEvaluator.evaluate("tan(360000000000090)"))
    }

    func testDegreeRadianOverflowSafety() {
        assertValue("rad(1e308)", equals: (1e308 / 180.0) * Double.pi)
        assertValue("degrees(1e306)", equals: (1e306 / Double.pi) * 180.0)
    }

    func testCompensatedSummationOrderIndependence() {
        assertValue("sum(1e16, 1, -1e16)", equals: 1)
        assertValue("sum(1e16, -1e16, 1)", equals: 1)
        assertValue("avg(1e16, 1, -1e16)", equals: 1.0 / 3.0)
        assertValue("avg(1e16, -1e16, 1)", equals: 1.0 / 3.0)
    }

    func testTrailingCommaDecimalInCommaLocales() {
        let deLocale = Locale(identifier: "de_DE")
        let idLocale = Locale(identifier: "en_ID")
        XCTAssertEqual(CalculatorExpressionEvaluator.evaluate("5, + 1", locale: deLocale), 6)
        XCTAssertEqual(CalculatorExpressionEvaluator.evaluate("0, + 1", locale: deLocale), 1)
        XCTAssertEqual(CalculatorExpressionEvaluator.evaluate("5, + 1", locale: idLocale), 6)
    }

    func testDoubleFactorialAndImplicitDivisionPrecedenceDocumentation() {
        // Lightsearch implements chained factorial: 3!! = (3!)! = 720
        assertValue("3!!", equals: 720)
        assertValue("(3!)!", equals: 720)

        // Implicit multiplication has left-to-right precedence with division:
        // 1/2pi = (1/2) * pi = pi/2
        assertValue("1/2pi", equals: Double.pi / 2.0)
        assertValue("2/3(4)", equals: (2.0 / 3.0) * 4.0)
    }
}
