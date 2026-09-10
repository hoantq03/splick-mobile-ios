import SwiftUI
import PhotosUI
import DesignSystem
import Localization
import SplickDomain

public struct CompleteOAuthProfileView: View {
    @StateObject private var viewModel: CompleteOAuthProfileViewModel
    @EnvironmentObject private var languageService: LanguageService
    @State private var showDateOfBirthPicker = false
    private let onFinished: (User) -> Void

    private static let fieldCornerRadius = SplickTheme.CornerRadius.pill
    private static let birthDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    public init(
        viewModel: @autoclosure @escaping () -> CompleteOAuthProfileViewModel,
        onFinished: @escaping (User) -> Void
    ) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.onFinished = onFinished
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SplickTheme.Spacing.lg) {
                    header

                    PhotosPicker(selection: $viewModel.selectedPhotoItem, matching: .images) {
                        avatar
                    }
                    .onChange(of: viewModel.selectedPhotoItem) { _ in
                        Task { await viewModel.onPhotoItemChanged() }
                    }

                    Text(languageService.text(.profileAvatarChangeHint))
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)

                    SplickTextField(
                        languageService.text(.authDisplayName),
                        text: $viewModel.displayName,
                        errorMessage: viewModel.displayNameError,
                        icon: "person",
                        cornerRadius: Self.fieldCornerRadius
                    )
                    .textInputAutocapitalization(.words)
                    .onChange(of: viewModel.displayName) { _ in viewModel.validateDisplayName() }

                    dateOfBirthField

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(SplickTheme.Typography.caption)
                            .foregroundStyle(SplickTheme.Colors.error)
                            .multilineTextAlignment(.center)
                    }

                    SplickButton(
                        languageService.text(.commonSave),
                        isLoading: viewModel.state.isLoading,
                        isDisabled: viewModel.state.isLoading
                    ) {
                        Task {
                            if let user = await viewModel.save() {
                                onFinished(user)
                            }
                        }
                    }

                    SplickButton(
                        languageService.text(.authSetupLater),
                        style: .ghost,
                        isDisabled: viewModel.state.isLoading
                    ) {
                        onFinished(viewModel.setupLater())
                    }
                }
                .padding(.horizontal, SplickTheme.Spacing.lg)
                .padding(.top, SplickTheme.Spacing.xl)
                .padding(.bottom, SplickTheme.Spacing.xl)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(SplickTheme.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showDateOfBirthPicker) {
                dateOfBirthPickerSheet
            }
        }
    }

    private var header: some View {
        VStack(spacing: SplickTheme.Spacing.xs) {
            Text(languageService.text(.authCompleteProfileTitle))
                .font(SplickTheme.Typography.title)
                .foregroundStyle(SplickTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)
            Text(languageService.text(.authCompleteProfileSubtitle))
                .font(SplickTheme.Typography.callout)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var avatar: some View {
        if let preview = viewModel.previewImage {
            Image(uiImage: preview)
                .resizable()
                .scaledToFill()
                .frame(width: 96, height: 96)
                .clipShape(Circle())
        } else {
            AvatarView(
                imageURL: viewModel.existingAvatarURL,
                name: viewModel.displayName,
                size: .large
            )
        }
    }

    private var dateOfBirthField: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxs) {
            Button {
                viewModel.prepareDateOfBirthPicker()
                showDateOfBirthPicker = true
            } label: {
                HStack(spacing: SplickTheme.Spacing.xs) {
                    Image(systemName: "calendar")
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                        .frame(width: 20)

                    if let dateOfBirth = viewModel.dateOfBirth {
                        Text(Self.birthDateFormatter.string(from: dateOfBirth))
                            .foregroundStyle(SplickTheme.Colors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text(languageService.text(.authDateOfBirthPlaceholder))
                            .foregroundStyle(SplickTheme.Colors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Text(languageService.text(.authDateOfBirthOptional))
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                }
                .padding(SplickTheme.Spacing.sm)
                .background(SplickTheme.Colors.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: Self.fieldCornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Self.fieldCornerRadius, style: .continuous)
                        .strokeBorder(
                            viewModel.dateOfBirthError != nil ? SplickTheme.Colors.error : Color.clear,
                            lineWidth: 1
                        )
                }
            }
            .buttonStyle(.plain)

            if let error = viewModel.dateOfBirthError {
                Text(error)
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.error)
            }
        }
    }

    private var dateOfBirthPickerSheet: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    languageService.text(.authDateOfBirth),
                    selection: $viewModel.dateOfBirthDraft,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding()

                Spacer()
            }
            .navigationTitle(languageService.text(.authDateOfBirthOptional))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageService.text(.commonClear)) {
                        viewModel.clearDateOfBirth()
                        showDateOfBirthPicker = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(languageService.text(.commonDone)) {
                        viewModel.confirmDateOfBirth()
                        showDateOfBirthPicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
