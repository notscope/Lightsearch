import Foundation

let fileSearchActionID = "io.notscope.Lightsearch.action.file-search"
let clipboardHistoryActionID = "io.notscope.Lightsearch.action.clipboard-history"
let colorPickerActionID = "io.notscope.Lightsearch.action.color-picker"

enum LauncherPage: Equatable {
    case applications
    case files
    case clipboard
}

enum LauncherResult: Identifiable {
    case conversion(ConversionResult)
    case systemPreference(SystemPreference)
    case application(InstalledApplication)
    case fileSearch
    case clipboardHistory
    case colorPicker

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
        case .clipboardHistory:
            return clipboardHistoryActionID
        case .colorPicker:
            return colorPickerActionID
        }
    }

    var kind: SearchKindFilter? {
        switch self {
        case .conversion:
            return nil
        case .systemPreference:
            return .settings
        case .application:
            return .apps
        case .fileSearch, .clipboardHistory, .colorPicker:
            return .actions
        }
    }
}
