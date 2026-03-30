import SwiftUI

struct NoteEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject var viewModel: NoteEditorViewModel

    @State private var showingDeleteConfirm = false

    var body: some View {
        ZStack {
            AppTheme.canvas.ignoresSafeArea()

            VStack(spacing: 12) {
                // Title field
                TextField("Title", text: $viewModel.title)
                    .modifier(AppTheme.outlinedFieldStyle())
                    .padding(.horizontal, AppTheme.pagePadding)
                    .padding(.top, AppTheme.topPadding)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Content")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(AppTheme.textSecondary)

                    TextEditor(text: $viewModel.content)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(AppTheme.textPrimary)
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .frame(minHeight: 320)
                        .background(AppTheme.fieldFill)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                                .stroke(AppTheme.borderSubtle, lineWidth: AppTheme.borderWidth)
                        )
                }
                .padding(.horizontal, AppTheme.pagePadding)

                Spacer()

                HStack(spacing: 12) {
                    OutlinedActionButton(title: "SAVE") {
                        Task {
                            try? await viewModel.save()
                            dismiss()
                        }
                    }

                    OutlinedActionButton(title: "DELETE", titleColor: AppTheme.appBarPurple) {
                        showingDeleteConfirm = true
                    }
                }
                .padding(.horizontal, AppTheme.pagePadding)
                .padding(.bottom, 16)
            }
        }
        .navigationTitle("Note Organizer")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.appBarPurple, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .alert("Delete note?", isPresented: $showingDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    try? await viewModel.delete()
                    dismiss()
                }
            }
        } message: {
            Text("This will remove the note from the list.")
        }
    }
}

private struct OutlinedActionButton: View {
    let title: String
    var titleColor: Color = AppTheme.appBarPurple
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(titleColor)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                        .stroke(AppTheme.borderSubtle, lineWidth: AppTheme.borderWidth)
                )
        }
    }
}
