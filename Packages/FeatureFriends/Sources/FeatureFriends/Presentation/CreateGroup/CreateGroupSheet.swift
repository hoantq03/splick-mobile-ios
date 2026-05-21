import SwiftUI
import DesignSystem

struct CreateGroupSheet: View {
    @ObservedObject var viewModel: CreateGroupViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: SplickTheme.Spacing.lg) {
                VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
                    Text("Tên nhóm")
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)

                    TextField("VD: Chuyến Đà Lạt", text: $viewModel.name)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
                    Text("Mô tả (tuỳ chọn)")
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)

                    TextField("Mô tả ngắn", text: $viewModel.groupDescription, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...5)
                }

                SplickButton(
                    "Tạo nhóm",
                    isLoading: viewModel.isLoading,
                    isDisabled: viewModel.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ) {
                    Task { await viewModel.create() }
                }

                if let success = viewModel.successMessage {
                    Text(success)
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.success)
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.error)
                }

                Spacer()
            }
            .padding(SplickTheme.Spacing.md)
            .navigationTitle("Tạo nhóm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
        }
    }
}
