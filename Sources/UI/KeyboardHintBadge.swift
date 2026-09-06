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
        case action(symbol: String, label: String)
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

    init(action label: String, symbol: String = "return", style: Style = .regular) {
        self.content = .action(symbol: symbol, label: label)
        self.style = style
    }

    init<V: View>(style: Style = .regular, @ViewBuilder content: () -> V) {
        self.content = .custom(AnyView(content()))
        self.style = style
    }

    private var isSingleCharacterOrIcon: Bool {
        switch content {
        case let .text(text, _):
            return text.count <= 1
        case .systemImage:
            return true
        case .action, .custom:
            return false
        }
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
            case let .action(symbol, label):
                HStack(spacing: 4) {
                    Image(systemName: symbol)
                        .font(.system(size: style.fontSize - 1, weight: .medium))

                    Text(label)
                        .font(.system(
                            size: style.fontSize - 1,
                            weight: .semibold,
                            design: .rounded
                        ))
                }
                .foregroundStyle(.secondary)
            case let .custom(customView):
                customView
            }
        }
        .padding(.horizontal, isSingleCharacterOrIcon ? 0 : 7)
        .frame(
            width: isSingleCharacterOrIcon ? style.height : nil,
            height: style.height
        )
        .frame(minWidth: isSingleCharacterOrIcon ? nil : style.height)
        .background {
            RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                .fill(Color.primary.opacity(0.08))
        }
        .overlay {
            RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.8)
        }
    }
}

extension KeyboardHintBadge {
    /// Renders an action key hint badge, e.g. `KeyboardHintBadge.action("Open")`
    static func action(_ label: String = "Open", symbol: String = "return", style: Style = .regular) -> KeyboardHintBadge {
        KeyboardHintBadge(action: label, symbol: symbol, style: style)
    }

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
