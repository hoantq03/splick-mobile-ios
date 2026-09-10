import SwiftUI
import Common
import DesignSystem
import Localization

public struct NearbyDiscoverySettingsView: View {
    @EnvironmentObject private var languageService: LanguageService
    @StateObject private var viewModel: NearbyDiscoverySettingsViewModel

    public init(nearbyDiscoveryUseCase: NearbyDiscoveryUseCaseProtocol) {
        _viewModel = StateObject(
            wrappedValue: NearbyDiscoverySettingsViewModel(useCase: nearbyDiscoveryUseCase)
        )
    }

    public var body: some View {
        List {
            Section(languageService.text(.friendsNearbyTitle)) {
                Toggle(languageService.text(.friendsNearbyEnable), isOn: enabledBinding)
                    .disabled(viewModel.saving)
            }

            Section {
                Text(languageService.text(.profileNearbyDiscoverySubtitle))
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.error)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(languageService.text(.profileNearbyDiscovery))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
        }
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { viewModel.nearbyEnabled },
            set: { viewModel.setEnabled($0) }
        )
    }
}

@MainActor
final class NearbyDiscoverySettingsViewModel: ObservableObject {
    @Published var nearbyEnabled = false
    @Published var saving = false
    @Published var errorMessage: String?

    private let useCase: NearbyDiscoveryUseCaseProtocol

    init(useCase: NearbyDiscoveryUseCaseProtocol) {
        self.useCase = useCase
    }

    func load() async {
        do {
            nearbyEnabled = try await useCase.preference()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setEnabled(_ enabled: Bool) {
        saving = true
        Task {
            do {
                nearbyEnabled = try await useCase.setPreference(enabled)
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
            saving = false
        }
    }
}
