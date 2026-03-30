import SwiftUI

enum AppTheme {
    // Color palette approximated from the reference screenshots.
    static let appBarPurple = Color(red: 0.353, green: 0.176, blue: 1.0) // ~ #5A2DFF
    static let fabTeal = Color(red: 0.067, green: 0.718, blue: 0.651)     // ~ #11B7A6

    // Canvas/background
    static let canvas = Color.white

    // Surfaces/fields
    static let surface = Color.white
    static let fieldFill = Color(red: 0.965, green: 0.965, blue: 0.973) // subtle light gray fill

    // Strokes + text
    static let borderSubtle = Color(red: 0.871, green: 0.871, blue: 0.871) // ~ #DEDEDE
    static let textPrimary = Color(red: 0.067, green: 0.067, blue: 0.067)  // ~ #111
    static let textSecondary = Color(red: 0.267, green: 0.267, blue: 0.267) // ~ #444
    static let textMuted = Color(red: 0.541, green: 0.541, blue: 0.541)    // ~ #8A8A8A

    // Sizing/spacing
    static let pagePadding: CGFloat = 16
    static let topPadding: CGFloat = 12

    static let fieldHeight: CGFloat = 44
    static let cornerRadius: CGFloat = 8
    static let cardCornerRadius: CGFloat = 6
    static let borderWidth: CGFloat = 1

    static let fabSize: CGFloat = 56

    static func outlinedFieldStyle() -> some ViewModifier {
        OutlinedFieldModifier()
    }

    static func cardStyle() -> some ViewModifier {
        CardModifier()
    }
}

private struct OutlinedFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 14, weight: .regular))
            .foregroundStyle(AppTheme.textPrimary)
            .frame(minHeight: AppTheme.fieldHeight)
            .padding(.horizontal, 12)
            .background(AppTheme.fieldFill)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .stroke(AppTheme.borderSubtle, lineWidth: AppTheme.borderWidth)
            )
    }
}

private struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                    .stroke(AppTheme.borderSubtle, lineWidth: AppTheme.borderWidth)
            )
    }
}
