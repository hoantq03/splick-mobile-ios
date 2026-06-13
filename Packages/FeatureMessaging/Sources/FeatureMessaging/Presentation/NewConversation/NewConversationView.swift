import SwiftUI
import Common
import DesignSystem
import SplickDomain

public struct NewConversationView: View {
    @ObservedObject private var viewModel: NewConversationViewModel
    @Environment(\.dismiss) private var dismiss

    public init(viewModel: NewConversationViewModel) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
    }

    public var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .idle, .loading:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                case .loaded(let friends) where friends.isEmpty:
                    EmptyStateView(
                        icon: "person.2.slash",
                        title: "No friends yet",
                        message: "Add friends to start a conversation."
                    )

                case .loaded(let friends):
                    friendList(friends)

                case .failed(let message):
                    ErrorView(message: message) {
                        Task { await viewModel.load() }
                    }
                }
            }
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .task { await viewModel.load() }
        .alert("Unable to start conversation", isPresented: createErrorPresented) {
            Button("OK", role: .cancel) {
                viewModel.clearCreateError()
            }
        } message: {
            Text(viewModel.createError ?? "")
        }
    }

    private var createErrorPresented: Binding<Bool> {
        Binding(
            get: { viewModel.createError != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.clearCreateError()
                }
            }
        )
    }

    @ViewBuilder
    private func friendList(_ friends: [UserSummary]) -> some View {
        List(friends) { friend in
            Button {
                Task {
                    let created = await viewModel.startConversation(with: friend)
                    if created {
                        dismiss()
                    }
                }
            } label: {
                HStack(spacing: SplickTheme.Spacing.sm) {
                    Circle()
                        .fill(SplickTheme.Colors.secondaryBackground)
                        .frame(width: 40, height: 40)
                        .overlay {
                            Image(systemName: "person.fill")
                                .foregroundStyle(SplickTheme.Colors.textTertiary)
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(friend.displayName)
                            .font(SplickTheme.Typography.callout)
                            .foregroundStyle(SplickTheme.Colors.textPrimary)
                        Text("@\(friend.username)")
                            .font(SplickTheme.Typography.caption)
                            .foregroundStyle(SplickTheme.Colors.textSecondary)
                    }
                    Spacer()
                    if viewModel.isCreating {
                        ProgressView().controlSize(.small)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isCreating)
        }
        .listStyle(.plain)
    }
}
