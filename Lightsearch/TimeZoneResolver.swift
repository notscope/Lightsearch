//
//  TimeZoneResolver.swift
//  Lightsearch
//
// Optional calculator/date-time feature implementation.

import MapKit

@MainActor
final class TimeZoneResolver {
    private var cachedTimeZones: [String: TimeZone] = [:]
    private var activeRequest: MKGeocodingRequest?

    func resolve(location: String) async -> TimeZone? {
        let key = cacheKey(for: location)
        guard !key.isEmpty else { return nil }

        if let cachedTimeZone = cachedTimeZones[key] {
            return cachedTimeZone
        }

        activeRequest?.cancel()
        guard let request = MKGeocodingRequest(addressString: location) else {
            return nil
        }
        activeRequest = request

        defer {
            if activeRequest === request {
                activeRequest = nil
            }
        }

        do {
            let mapItems = try await request.mapItems
            guard !Task.isCancelled else { return nil }

            guard let timeZone = mapItems.compactMap(\.timeZone).first else {
                return nil
            }

            cachedTimeZones[key] = timeZone
            return timeZone
        } catch {
            return nil
        }
    }

    func cancel() {
        activeRequest?.cancel()
        activeRequest = nil
    }

    private func cacheKey(for location: String) -> String {
        location
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(
                options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive],
                locale: .current
            )
            .lowercased()
    }
}
