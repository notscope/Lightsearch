import SwiftUI

/// A reusable keycap badge representing keyboard input hints and shortcuts.
struct KeyboardHintBadge: View {
    enum Style {
        case regular // 22pt height (standard launcher row badge)
        case compact // 19pt height (compact menus / toolbars)

        var height: CGFloat {
            switch self {
            case .regular: return 22
            case .compact: return 19
            }
        }

        var fontSize: CGFloat {
            switch self {
            case .regular: return 12
            case .compact: return 11
            }
        }

        var cornerRadius: CGFloat {
            return 5
        }
    }

    private enum Content {
        case text(String, isMonospaced: Bool)
        case systemImage(String)
        case custom(AnyView)
    }

    private let content: Content
    private let style: Style

    init(_ text: String, isMonospaced: Bool = false, style: Style = .regular) {
        self.content = .text(text, isMonospaced: isMonospaced)
        self.style = style
    }

    init(symbol: String, style: Style = .regular) {
        self.content = .text(symbol, isMonospaced: false)
        self.style = style
    }

    init(_ number: Int, style: Style = .regular) {
        self.content = .text("\(number)", isMonospaced: true)
        self.style = style
    }

    init(systemImage: String, style: Style = .regular) {
        self.content = .systemImage(systemImage)
        self.style = style
    }

    init<V: View>(style: Style = .regular, @ViewBuilder content: () -> V) {
        self.content = .custom(AnyView(content()))
        self.style = style
    }

    var body: some View {
        Group {
            switch content {
            case let .text(text, isMonospaced):
                Text(text)
                    .font(.system(
                        size: style.fontSize,
                        weight: .semibold,
                        design: isMonospaced ? .monospaced : .rounded
                    ))
                    .foregroundStyle(.secondary)
            case let .systemImage(name):
                Image(systemName: name)
                    .font(.system(size: style.fontSize - 1, weight: .semibold))
                    .foregroundStyle(.secondary)
            case let .custom(customView):
                customView
            }
        }
        .frame(minWidth: style.height, minHeight: style.height)
        .padding(.horizontal, horizontalPadding)
        .background {
            RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                .fill(Color.primary.opacity(0.08))
        }
        .overlay {
            RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.8)
        }
    }

    private var horizontalPadding: CGFloat {
        switch content {
        case let .text(text, _):
            return text.count > 1 ? 5 : 2
        case .systemImage:
            return 2
        case .custom:
            return 4
        }
    }
}

extension KeyboardHintBadge {
    /// Renders a combo sequence of keyboard hints, e.g. `KeyboardHintBadge.combo("⌘", "K")`
    static func combo(_ keys: String..., style: Style = .regular) -> some View {
        HStack(spacing: 3) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                KeyboardHintBadge(key, style: style)
            }
        }
    }
}

typealias KeycapView = KeyboardHintBadge
