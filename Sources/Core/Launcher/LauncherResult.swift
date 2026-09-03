//
//  LauncherResult.swift
//  Lightsearch
//

import Foundation

let fileSearchActionID = "io.notscope.Lightsearch.action.file-search"

enum LauncherPage: Equatable {
    case applications
    case files
}

enum LauncherResult: Identifiable {
    case conversion(ConversionResult)
    case systemPreference(SystemPreference)
    case application(InstalledApplication)
    case fileSearch

    var id: String {
        switch self {
        case let .conversion(conversion):
            return conversion.id
        case let .systemPreference(preference):
            return preference.id
        case let .application(application):
            return application.id
        case .fileSearch:
            return fileSearchActionID
        }
    }
}
