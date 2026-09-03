//
//  PerformanceBenchmarkTests.swift
//  LightsearchTests
//

import Darwin
import Foundation
import MapKit
import XCTest
@testable import Lightsearch

final class PerformanceBenchmarkTests: XCTestCase {

    struct MemoryStats {
        let footprintBytes: UInt64
        let residentBytes: UInt64

        var footprintMB: Double { Double(footprintBytes) / (1024.0 * 1024.0) }
        var residentMB: Double { Double(residentBytes) / (1024.0 * 1024.0) }

        static func current() -> MemoryStats {
            var info = task_vm_info_data_t()
            var count = mach_msg_type_number_t(
                MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size
            )
            let kerr = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                    task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
                }
            }
            guard kerr == KERN_SUCCESS else {
                return MemoryStats(footprintBytes: 0, residentBytes: 0)
            }
            return MemoryStats(
                footprintBytes: info.phys_footprint,
                residentBytes: UInt64(info.resident_size)
            )
        }
    }

    func testInstalledApplicationScannerBenchmark() {
        let beforeMem = MemoryStats.current()
        let startTime = CFAbsoluteTimeGetCurrent()

        let apps = InstalledApplicationScanner.scan()

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        let afterMem = MemoryStats.current()

        print("--- BENCHMARK: InstalledApplicationScanner ---")
        print("Scanned applications count: \(apps.count)")
        print(String(format: "Execution time: %.4f seconds (%.2f ms)", elapsed, elapsed * 1000.0))
        print(String(format: "Footprint before: %.2f MB -> after: %.2f MB (delta: %+.2f MB)",
                     beforeMem.footprintMB, afterMem.footprintMB, afterMem.footprintMB - beforeMem.footprintMB))
        print("---------------------------------------------")

        XCTAssertFalse(apps.isEmpty, "Scanner should discover installed applications on macOS")
        XCTAssertTrue(apps.contains { $0.name.caseInsensitiveCompare("Safari") == .orderedSame }, "Safari should be discovered")
        XCTAssertTrue(apps.contains { $0.name.caseInsensitiveCompare("Finder") == .orderedSame }, "Finder should be discovered")
    }

    func testSafariAndFinderSearchRanking() {
        let apps = InstalledApplicationScanner.scan()
        let safariResults = ApplicationSearch.rankedResults(apps, query: "safari")
        XCTAssertEqual(safariResults.first?.name, "Safari", "Safari must be the top search result for 'safari'")

        let finderResults = ApplicationSearch.rankedResults(apps, query: "finder")
        XCTAssertEqual(finderResults.first?.name, "Finder", "Finder must be the top search result for 'finder'")
    }

    func testTimeCountryLabels() async {
        let resolver = await TimeZoneResolver()
        let seattleResolved = await resolver.resolve(location: "seattle")
        XCTAssertEqual(seattleResolved?.country, "United States")

        let laResolved = await resolver.resolve(location: "la")
        XCTAssertEqual(laResolved?.country, "Laos")

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
        XCTAssertEqual(laConversion?.inputLabel, "Laos")

        let tokyoConversion = ConversionEngine.result(for: "time tokyo")
        XCTAssertEqual(tokyoConversion?.inputLabel, "Japan")

        let londonConversion = ConversionEngine.result(for: "time london")
        XCTAssertEqual(londonConversion?.inputLabel, "United Kingdom")
    }

    func testSystemPreferencesScannerBenchmark() {
        let beforeMem = MemoryStats.current()
        let startTime = CFAbsoluteTimeGetCurrent()

        let prefs = SystemPreferencesScanner.scan()

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        let afterMem = MemoryStats.current()

        print("--- BENCHMARK: SystemPreferencesScanner ---")
        print("Scanned preferences count: \(prefs.count)")
        print(String(format: "Execution time: %.4f seconds (%.2f ms)", elapsed, elapsed * 1000.0))
        print(String(format: "Footprint before: %.2f MB -> after: %.2f MB (delta: %+.2f MB)",
                     beforeMem.footprintMB, afterMem.footprintMB, afterMem.footprintMB - beforeMem.footprintMB))
        print("-------------------------------------------")

        XCTAssertFalse(prefs.isEmpty, "Scanner should discover system preference panes on macOS")
    }

    func testSearchQueryThroughputBenchmark() {
        let apps = InstalledApplicationScanner.scan()
        let prefs = SystemPreferencesScanner.scan()

        let queries = ["safari", "code", "term", "display", "sound", "network", "calc", "mail", "notes", "music"]

        let startTime = CFAbsoluteTimeGetCurrent()
        var matchCount = 0
        let iterations = 200

        for _ in 0..<iterations {
            for q in queries {
                let appResults = ApplicationSearch.rankedResults(apps, query: q)
                let prefResults = SystemPreferenceSearch.rankedResults(prefs, query: q, includeSubitems: true)
                matchCount += appResults.count + prefResults.count
            }
        }

        let totalQueries = iterations * queries.count
        let totalElapsed = CFAbsoluteTimeGetCurrent() - startTime
        let avgPerQueryUs = (totalElapsed / Double(totalQueries)) * 1_000_000.0

        print("--- BENCHMARK: Search Query Throughput ---")
        print("Total queries executed: \(totalQueries)")
        print("Total matches found: \(matchCount)")
        print(String(format: "Total time: %.4f seconds", totalElapsed))
        print(String(format: "Average time per query: %.2f µs (%.4f ms)", avgPerQueryUs, avgPerQueryUs / 1000.0))
        print("------------------------------------------")

        XCTAssertGreaterThan(matchCount, 0)
    }
}
