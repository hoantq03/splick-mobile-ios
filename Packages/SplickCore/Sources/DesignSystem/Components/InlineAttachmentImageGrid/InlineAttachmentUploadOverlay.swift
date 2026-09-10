import SwiftUI

struct InlineAttachmentUploadOverlay: View {
    let uploadStatus: InlineAttachmentUploadStatus
    let onRetry: (() -> Void)?

    var body: some View {
        switch uploadStatus {
        case .uploading:
            ZStack {
                Color.black.opacity(0.28)
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.regular)
                    .tint(.white)
            }
            .accessibilityLabel("Đang tải ảnh lên")

        case .failed:
            ZStack {
                Color.black.opacity(0.45)
                VStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(SplickTheme.Colors.error)
                    if let onRetry {
                        Button(action: onRetry) {
                            Text("Thử lại")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.white.opacity(0.22)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Thử tải lại ảnh")
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Tải ảnh thất bại")

        case .uploaded:
            EmptyView()
        }
    }
}
