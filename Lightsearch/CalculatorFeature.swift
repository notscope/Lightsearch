//
//  CalculatorFeature.swift
//  Lightsearch
//

import Foundation

@MainActor
final class CalculatorFeature: LauncherSearchFeature {
    let identifier = "calculator"
    var onChange: (() -> Void)?

    private let timeZoneResolver = TimeZoneResolver()
    private var timeZoneResolutionTask: Task<Void, Never>?
    private var resolvedTimeZone: TimeZone?
    private var currentQuery = ""

    func searchResults(for context: LauncherSearchContext) -> LauncherFeatureSearchOutput {
        guard let conversion = ConversionEngine.result(
            for: context.query,
            resolvedTimeZone: resolvedTimeZone
        ) else {
            return LauncherFeatureSearchOutput(
                results: [],
                placement: .beforeApplications
            )
        }

        return LauncherFeatureSearchOutput(
            results: [.conversion(conversion)],
            placement: .beforeApplications
        )
    }

    func queryChanged(_ query: String, page: LauncherPage) {
        currentQuery = query
        stop()
        guard page == .applications,
              let location = ConversionEngine.timeZoneLocation(for: query),
              location.count >= 2,
              ConversionEngine.result(for: query) == nil else {
            return
        }

        let querySnapshot = query
        timeZoneResolutionTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 250_000_000)
            } catch {
                return
            }

            guard !Task.isCancelled, let self else { return }
            let timeZone = await self.timeZoneResolver.resolve(location: location)

            guard !Task.isCancelled, self.currentQuery == querySnapshot else {
                return
            }

            self.resolvedTimeZone = timeZone
            self.onChange?()
        }
    }

    func stop() {
        timeZoneResolutionTask?.cancel()
        timeZoneResolutionTask = nil
        timeZoneResolver.cancel()
        resolvedTimeZone = nil
    }
}
