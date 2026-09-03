//
//  TimeZoneResolver.swift
//  Lightsearch
//
// Optional calculator/date-time feature implementation.

import MapKit

struct ResolvedLocation: Equatable {
    let timeZone: TimeZone
    let country: String?
}

@MainActor
final class TimeZoneResolver {
    private var cachedLocations: [String: ResolvedLocation] = [:]
    private var activeRequest: MKGeocodingRequest?

    func resolve(location: String) async -> ResolvedLocation? {
        let key = cacheKey(for: location)
        guard !key.isEmpty else { return nil }

        if let cached = cachedLocations[key] {
            return cached
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

            guard let mapItem = mapItems.first(where: { $0.timeZone != nil }),
                  let timeZone = mapItem.timeZone else {
                return nil
            }

            let country = mapItem.placemark.country
            let resolved = ResolvedLocation(timeZone: timeZone, country: country)
            cachedLocations[key] = resolved
            return resolved
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
