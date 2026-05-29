import DesignSystem
import PhotosUI
import SwiftUI

struct MediaSourceSheet: View {
    let onCamera: () -> Void
    let onCancel: () -> Void
    @Binding var photoPickerItems: [PhotosPickerItem]
    let onPhotoPicked: ([PhotosPickerItem]) -> Void

    var body: some View {
        VStack(spacing: SplickTheme.Spacing.lg) {
            Capsule()
                .fill(SplickTheme.Colors.divider)
                .frame(width: 44, height: 5)
                .padding(.top, SplickTheme.Spacing.sm)

            Text("Chọn nguồn")
                .font(SplickTheme.Typography.title)
                .foregroundStyle(SplickTheme.Colors.textPrimary)

            VStack(spacing: SplickTheme.Spacing.sm) {
                sourceButton(
                    title: "Chụp ảnh / quay video",
                    icon: "camera.fill",
                    action: onCamera
                )

                PhotosPicker(
                    selection: $photoPickerItems,
                    maxSelectionCount: 1,
                    matching: .any(of: [.images, .videos])
                ) {
                    sourceButtonLabel(
                        title: "Thư viện ảnh",
                        icon: "photo.on.rectangle.angled"
                    )
                }
                .onChange(of: photoPickerItems) { _, items in
                    guard !items.isEmpty else { return }
                    onPhotoPicked(items)
                }
            }

            Button("Huỷ", action: onCancel)
                .font(SplickTheme.Typography.callout)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .padding(.bottom, SplickTheme.Spacing.md)
        }
        .padding(.horizontal, SplickTheme.Spacing.lg)
        .presentationDetents([.height(320)])
        .presentationDragIndicator(.hidden)
        .presentationBackground {
            if #available(iOS 26.0, *) {
                Color.clear
            } else {
                Rectangle().fill(.ultraThinMaterial)
            }
        }
    }

    private func sourceButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            sourceButtonLabel(title: title, icon: icon)
        }
        .buttonStyle(.plain)
    }

    private func sourceButtonLabel(title: String, icon: String) -> some View {
        HStack(spacing: SplickTheme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .frame(width: 32)
            Text(title)
                .font(SplickTheme.Typography.headline)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(SplickTheme.Colors.textTertiary)
        }
        .foregroundStyle(SplickTheme.Colors.textPrimary)
        .padding(SplickTheme.Spacing.md)
        .frame(maxWidth: .infinity)
        .background(sourceButtonBackground)
    }

    @ViewBuilder
    private var sourceButtonBackground: some View {
        if #available(iOS 26.0, *) {
            RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.large, style: .continuous)
                .fill(.clear)
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.large, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.large, style: .continuous)
                .fill(.ultraThinMaterial)
        }
    }
}
