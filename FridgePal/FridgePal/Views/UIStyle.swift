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
    var size: CGFloat = 56
    var cornerRadius: CGFloat = AppCornerRadius.medium

    var body: some View {
        Group {
            if let imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(placeholder)
                    .font(size >= 100 ? .largeTitle : .title3)
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
            .background(tint.opacity(0.14), in: Capsule())
            .foregroundStyle(tint)
    }
}

extension ExpirationState {
    var tintColor: Color {
        switch self {
        case .fresh:
            Color(uiColor: .systemGreen)
        case .expiringSoon:
            Color(uiColor: .systemOrange)
        case .expired:
            Color(uiColor: .systemRed)
        case .noDate:
            .secondary
        }
    }

    var symbolName: String {
        switch self {
        case .fresh:
            "checkmark.circle.fill"
        case .expiringSoon:
            "clock.fill"
        case .expired:
            "exclamationmark.triangle.fill"
        case .noDate:
            "calendar"
        }
    }
}

extension FoodStatus {
    var tintColor: Color {
        switch self {
        case .eaten:
            Color(uiColor: .systemGreen)
        case .discarded:
            Color(uiColor: .systemOrange)
        case .expired:
            Color(uiColor: .systemRed)
        case .active:
            .secondary
        }
    }

    var symbolName: String {
        switch self {
        case .eaten:
            "checkmark.circle.fill"
        case .discarded:
            "trash.fill"
        case .expired:
            "exclamationmark.triangle.fill"
        case .active:
            "circle.fill"
        }
    }
}
