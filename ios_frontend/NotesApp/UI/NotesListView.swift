import SwiftUI

struct NotesListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject var viewModel: NotesListViewModel

    @State private var selectedNote: Note?
    @State private var showCreate: Bool = false
    @State private var createdNote: Note?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                AppTheme.canvas.ignoresSafeArea()

                VStack(spacing: 12) {
                    SearchField(text: $viewModel.searchText, placeholder: "Search notes...") {
                        viewModel.updateQuery(context: viewContext)
                    }
                    .padding(.horizontal, AppTheme.pagePadding)
                    .padding(.top, 12)

                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.notes) { note in
                                NoteCard(note: note)
                                    .onTapGesture {
                                        selectedNote = note
                                    }
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            Task { try? await viewModel.deleteNote(id: note.id) }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }

                            if viewModel.notes.isEmpty {
                                Text("No notes")
                                    .foregroundStyle(AppTheme.textMuted)
                                    .padding(.top, 40)
                            }
                        }
                        .padding(.horizontal, AppTheme.pagePadding)
                        .padding(.vertical, 12)
                    }
                }

                FloatingActionButton {
                    Task {
                        do {
                            let note = try await viewModel.newNote()
                            createdNote = note
                            showCreate = true
                        } catch {
                            // no-op
                        }
                    }
                }
                .padding(AppTheme.pagePadding)
            }
            .navigationTitle("Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.appBarPurple, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        viewModel.triggerSync()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    Button {
                        // Placeholder for overflow/menu.
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
            .onAppear {
                viewModel.bind(context: viewContext)
            }
            .onChange(of: viewModel.searchText) { _, _ in
                // Keep it responsive; this is lightweight with FRC.
                viewModel.updateQuery(context: viewContext)
            }
            .navigationDestination(item: $selectedNote) { note in
                NoteEditorView(
                    viewModel: NoteEditorViewModel(note: note, repository: viewModel.repositoryProxy, syncEngine: viewModel.syncEngineProxy)
                )
            }
            .navigationDestination(isPresented: $showCreate) {
                if let createdNote {
                    NoteEditorView(
                        viewModel: NoteEditorViewModel(note: createdNote, repository: viewModel.repositoryProxy, syncEngine: viewModel.syncEngineProxy)
                    )
                }
            }
        }
    }
}

// MARK: - Private helper views

private struct SearchField: View {
    @Binding var text: String
    let placeholder: String
    let onCommit: () -> Void

    var body: some View {
        TextField(placeholder, text: $text)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .modifier(AppTheme.outlinedFieldStyle())
            .foregroundStyle(AppTheme.textPrimary)
            .onSubmit(onCommit)
    }
}

private struct NoteCard: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(note.title.isEmpty ? "(Untitled)" : note.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)

            Text(note.previewText.isEmpty ? " " : note.previewText)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(2)

            Text("Updated: \(note.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(AppTheme.textMuted)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                .stroke(AppTheme.borderSubtle, lineWidth: AppTheme.borderWidth)
        )
    }
}

private struct FloatingActionButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(AppTheme.fabTeal)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
        }
        .accessibilityLabel("New note")
    }
}

// MARK: - ViewModel access shims
// SwiftUI Views should not own Core Data directly. We keep the ViewModel created externally,
// but need repository/sync references for destination VMs.
// These are internal-only computed props.

private extension NotesListViewModel {
    var repositoryProxy: NoteRepository { repository }
    var syncEngineProxy: SyncEngine { syncEngine }
}
