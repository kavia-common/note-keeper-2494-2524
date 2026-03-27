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
                    .padding(.top, 12)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Content")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(AppTheme.textPrimary)

                    TextEditor(text: $viewModel.content)
                        .padding(8)
                        .frame(minHeight: 280)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                                .stroke(AppTheme.borderSubtle, lineWidth: AppTheme.borderWidth)
                        )
                        .foregroundStyle(AppTheme.textPrimary)
                }
                .padding(.horizontal, AppTheme.pagePadding)

                Spacer()

                HStack(spacing: 16) {
                    OutlinedActionButton(title: "SAVE") {
                        Task {
                            try? await viewModel.save()
                            dismiss()
                        }
                    }

                    OutlinedActionButton(title: "DELETE") {
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.appBarPurple)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                        .stroke(AppTheme.borderSubtle, lineWidth: AppTheme.borderWidth)
                )
        }
    }
}
