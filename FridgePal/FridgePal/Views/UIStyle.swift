import SwiftUI

enum AppSpacing {
    static let xSmall: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let xLarge: CGFloat = 20
    static let xxLarge: CGFloat = 24
}

enum AppCornerRadius {
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let xLarge: CGFloat = 20
}

enum AppSizing {
    static let defaultThumbnailSize: CGFloat = 56
    static let largeThumbnailFontThreshold: CGFloat = 100
}

enum AppOpacity {
    static let badgeFill: Double = 0.14
}

extension View {
    func appCardStyle(padding: CGFloat = AppSpacing.large) -> some View {
        modifier(AppCardModifier(contentPadding: padding))
    }
}

private struct AppCardModifier: ViewModifier {
    let contentPadding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(contentPadding)
            .background(
                RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
    }
}

struct AppSectionHeader: View {
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)

            if let subtitle {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct FoodThumbnailView: View {
    let imageData: Data?
    let placeholder: String
    var size: CGFloat = AppSizing.defaultThumbnailSize
    var cornerRadius: CGFloat = AppCornerRadius.medium

    var body: some View {
        Group {
            if let imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(placeholder)
                    .font(size >= AppSizing.largeThumbnailFontThreshold ? .largeTitle : .title3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

struct StatusBadge: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.footnote.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, AppSpacing.small)
            .padding(.vertical, AppSpacing.xSmall)
            .background(tint.opacity(AppOpacity.badgeFill), in: Capsule())
            .foregroundStyle(tint)
    }
}

private enum StatusTone {
    case positive
    case warning
    case critical
    case neutral

    var tintColor: Color {
        switch self {
        case .positive:
            Color(uiColor: .systemGreen)
        case .warning:
            Color(uiColor: .systemOrange)
        case .critical:
            Color(uiColor: .systemRed)
        case .neutral:
            .secondary
        }
    }

    var symbolName: String {
        switch self {
        case .positive:
            "checkmark.circle.fill"
        case .warning:
            "clock.fill"
        case .critical:
            "exclamationmark.triangle.fill"
        case .neutral:
            "calendar"
        }
    }
}

extension ExpirationState {
    private var tone: StatusTone {
        switch self {
        case .fresh:
            .positive
        case .expiringSoon:
            .warning
        case .expired:
            .critical
        case .noDate:
            .neutral
        }
    }

    var tintColor: Color {
        tone.tintColor
    }

    var symbolName: String {
        tone.symbolName
    }
}

extension FoodStatus {
    private var tone: StatusTone {
        switch self {
        case .eaten:
            .positive
        case .discarded:
            .warning
        case .expired:
            .critical
        case .active:
            .neutral
        }
    }

    var tintColor: Color {
        tone.tintColor
    }

    var symbolName: String {
        switch self {
        case .discarded:
            "trash.fill"
        case .active:
            "circle.fill"
        default:
            tone.symbolName
        }
    }
}
