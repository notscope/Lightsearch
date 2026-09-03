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
    private var resolvedLocation: ResolvedLocation?
    private var currentQuery = ""

    func searchResults(for context: LauncherSearchContext) -> LauncherFeatureSearchOutput {
        guard let conversion = ConversionEngine.result(
            for: context.query,
            resolvedTimeZone: resolvedLocation?.timeZone,
            resolvedCountry: resolvedLocation?.country
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
              location.count >= 2 else {
            return
        }

        if let immediateResult = ConversionEngine.result(for: query),
           immediateResult.inputLabel != "Current time" {
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
            let locationInfo = await self.timeZoneResolver.resolve(location: location)

            guard !Task.isCancelled, self.currentQuery == querySnapshot else {
                return
            }

            self.resolvedLocation = locationInfo
            self.onChange?()
        }
    }

    func stop() {
        timeZoneResolutionTask?.cancel()
        timeZoneResolutionTask = nil
        timeZoneResolver.cancel()
        resolvedLocation = nil
    }
}
