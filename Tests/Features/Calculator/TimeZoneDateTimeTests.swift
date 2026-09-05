//
//  TimeZoneDateTimeTests.swift
//  LightsearchTests
//
// Regression and correctness tests for TimeZone resolution, country labels,
// and date-time conversions in the optional Calculator feature.

import Foundation
import MapKit
import XCTest
@testable import Lightsearch

final class TimeZoneDateTimeTests: XCTestCase {

    func testTimeCountryLabels() async {
        let resolver = await TimeZoneResolver()
        let seattleResolved = await resolver.resolve(location: "seattle")
        XCTAssertEqual(seattleResolved?.country, "United States")

        let laResolved = await resolver.resolve(location: "la")
        XCTAssertTrue(laResolved?.country == "Laos" || laResolved?.country == "United States")

        let seattleConversion = ConversionEngine.result(
            for: "time seattle",
            resolvedTimeZone: seattleResolved?.timeZone,
            resolvedCountry: seattleResolved?.country
        )
        XCTAssertEqual(seattleConversion?.inputLabel, "United States")

        let laConversion = ConversionEngine.result(
            for: "time la",
            resolvedTimeZone: laResolved?.timeZone,
            resolvedCountry: laResolved?.country
        )
        XCTAssertTrue(laConversion?.inputLabel == "Laos" || laConversion?.inputLabel == "United States")


        let tokyoConversion = ConversionEngine.result(for: "time tokyo")
        XCTAssertEqual(tokyoConversion?.inputLabel, "Japan")

        let londonConversion = ConversionEngine.result(for: "time london")
        XCTAssertEqual(londonConversion?.inputLabel, "United Kingdom")

        let drcConversion = ConversionEngine.result(for: "time drc")
        XCTAssertEqual(drcConversion?.inputLabel, "Democratic Republic of the Congo")

        let prcConversion = ConversionEngine.result(for: "time prc")
        XCTAssertEqual(prcConversion?.inputLabel, "China")
    }

    func testTimeZoneResolverCaching() async {
        let resolver = await TimeZoneResolver()
        let first = await resolver.resolve(location: "seattle")
        let second = await resolver.resolve(location: "SEATTLE")
        XCTAssertEqual(first, second, "TimeZoneResolver should return cached values case-insensitively")
    }

    func testDateTimeConversionResults() {
        let referenceDate = Date(timeIntervalSince1970: 1725400000)

        let epochResult = ConversionEngine.result(for: "1725400000 epoch", now: referenceDate)
        XCTAssertNotNil(epochResult)
        XCTAssertEqual(epochResult?.categoryTitle, "Date & Time")

        let todayResult = ConversionEngine.result(for: "today", now: referenceDate)
        XCTAssertNotNil(todayResult)
        XCTAssertEqual(todayResult?.inputLabel, "Date")

        let relativeResult = ConversionEngine.result(for: "in 2 days", now: referenceDate)
        XCTAssertNotNil(relativeResult)
        XCTAssertEqual(relativeResult?.inputLabel, "Relative date")
    }
}
