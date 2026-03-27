import SwiftUI

enum AppTheme {
    // Color palette approximated from assets/kf_notes_app_design_notes.md
    static let appBarPurple = Color(red: 0.353, green: 0.176, blue: 1.0) // ~ #5A2DFF
    static let fabTeal = Color(red: 0.067, green: 0.718, blue: 0.651)     // ~ #11B7A6
    static let canvas = Color.white

    static let borderSubtle = Color(red: 0.871, green: 0.871, blue: 0.871) // ~ #DEDEDE
    static let textPrimary = Color(red: 0.067, green: 0.067, blue: 0.067)  // ~ #111
    static let textSecondary = Color(red: 0.267, green: 0.267, blue: 0.267) // ~ #444
    static let textMuted = Color(red: 0.541, green: 0.541, blue: 0.541)    // ~ #8A8A8A

    // Sizing/spacing (8pt grid)
    static let pagePadding: CGFloat = 16
    static let fieldHeight: CGFloat = 40
    static let cornerRadius: CGFloat = 4
    static let borderWidth: CGFloat = 1

    static func outlinedFieldStyle() -> some ViewModifier {
        OutlinedFieldModifier()
    }
}

private struct OutlinedFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(minHeight: AppTheme.fieldHeight)
            .padding(.horizontal, 12)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .stroke(AppTheme.borderSubtle, lineWidth: AppTheme.borderWidth)
            )
    }
}
