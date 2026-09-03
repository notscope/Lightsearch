//
//  PerformanceBenchmarkTests.swift
//  LightsearchTests
//

import Darwin
import Foundation
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
