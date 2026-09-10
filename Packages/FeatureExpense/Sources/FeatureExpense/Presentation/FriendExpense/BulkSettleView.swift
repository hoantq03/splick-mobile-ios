import Common
import DesignSystem
import Foundation
import Localization
import PhotosUI
import SplickDomain
import SwiftUI
import UniformTypeIdentifiers

@MainActor
public final class BulkSettleViewModel: ObservableObject {
  public enum State: Equatable {
    case idle
    case uploading
    case submitting
    case success
    case failed(String)
  }

  @Published var note = ""
  @Published private(set) var state: State = .idle
  @Published private(set) var hasEvidence = false
  @Published private(set) var settlement: BulkSettlement?

  private let counterpartyId: UUID
  private let uploadEvidence: ExpenseEvidenceUpload
  private let submitUseCase: SubmitBulkSettlementUseCaseProtocol
  private let languageService: LanguageService
  private var evidenceData: Data?
  private var evidenceMimeType = "image/jpeg"

  public init(
    counterpartyId: UUID,
    uploadEvidence: @escaping ExpenseEvidenceUpload,
    submitUseCase: SubmitBulkSettlementUseCaseProtocol,
    languageService: LanguageService
  ) {
    self.counterpartyId = counterpartyId
    self.uploadEvidence = uploadEvidence
    self.submitUseCase = submitUseCase
    self.languageService = languageService
  }

  public func selectEvidence(data: Data, mimeType: String = "image/jpeg") {
    evidenceData = data
    evidenceMimeType = mimeType
    hasEvidence = true
    state = .idle
  }

  public func submit() async {
    guard let evidenceData else {
      state = .failed(languageService.text(.expenseBulkEvidenceRequired))
      return
    }
    do {
      state = .uploading
      let evidenceURL = try await uploadEvidence(evidenceData, evidenceMimeType)
      state = .submitting
      let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
      settlement = try await submitUseCase.execute(
        counterpartyId: counterpartyId,
        evidenceURL: evidenceURL,
        note: trimmedNote.isEmpty ? nil : trimmedNote
      )
      state = .success
    } catch {
      state = .failed(languageService.localizedMessage(for: error))
    }
  }
}

public struct BulkSettleView: View {
  @StateObject private var viewModel: BulkSettleViewModel
  @State private var selectedPhoto: PhotosPickerItem?
  @EnvironmentObject private var languageService: LanguageService
  @Environment(\.dismiss) private var dismiss
  private let onSubmitted: (BulkSettlement) -> Void

  public init(
    viewModel: BulkSettleViewModel,
    onSubmitted: @escaping (BulkSettlement) -> Void
  ) {
    _viewModel = StateObject(wrappedValue: viewModel)
    self.onSubmitted = onSubmitted
  }

  public var body: some View {
    NavigationStack {
      VStack(spacing: SplickTheme.Spacing.lg) {
        if case .success = viewModel.state {
          successContent
        } else {
          formContent
        }
      }
      .padding(SplickTheme.Spacing.lg)
      .navigationTitle(languageService.text(.expenseBulkTitle))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(languageService.text(.commonCancel)) { dismiss() }
        }
      }
    }
    .onChange(of: selectedPhoto) { item in
      guard let item else { return }
      Task {
        if let data = try? await item.loadTransferable(type: Data.self) {
          let mimeType = item.supportedContentTypes.first?.preferredMIMEType ?? "image/jpeg"
          viewModel.selectEvidence(data: data, mimeType: mimeType)
        }
      }
    }
  }

  private var formContent: some View {
    let hasEvidence = viewModel.hasEvidence
    let evidencePickerTitle =
      hasEvidence
      ? languageService.text(.expenseBulkEvidence)
      : languageService.text(.expenseBulkChooseEvidence)

    return VStack(alignment: .leading, spacing: SplickTheme.Spacing.md) {
      Text(languageService.text(.expenseBulkEvidence))
        .font(SplickTheme.Typography.headline)

      PhotosPicker(selection: $selectedPhoto, matching: .images) {
        Label(
          evidencePickerTitle,
          systemImage: hasEvidence ? "checkmark.circle.fill" : "photo"
        )
        .frame(maxWidth: .infinity)
        .padding()
        .background(SplickTheme.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.medium))
      }
      .accessibilityLabel(languageService.text(.expenseBulkChooseEvidence))

      TextField(languageService.text(.expenseBulkNote), text: $viewModel.note, axis: .vertical)
        .lineLimit(3...6)
        .padding()
        .background(SplickTheme.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.medium))

      if case .failed(let message) = viewModel.state {
        Text(message)
          .font(SplickTheme.Typography.caption)
          .foregroundStyle(SplickTheme.Colors.error)
          .accessibilityLabel(message)
      }

      SplickButton(submitTitle, style: .primary) {
        Task { await viewModel.submit() }
      }
      .disabled(!viewModel.hasEvidence || isWorking)
    }
  }

  private var successContent: some View {
    VStack(spacing: SplickTheme.Spacing.md) {
      Image(systemName: "clock.badge.checkmark.fill")
        .font(.system(size: 52))
        .foregroundStyle(SplickTheme.Colors.success)
      Text(languageService.text(.expenseBulkSuccess))
        .font(SplickTheme.Typography.headline)
        .multilineTextAlignment(.center)
      SplickButton(languageService.text(.commonDone), style: .primary) {
        if let settlement = viewModel.settlement {
          onSubmitted(settlement)
        } else {
          dismiss()
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .accessibilityElement(children: .combine)
  }

  private var isWorking: Bool {
    if case .uploading = viewModel.state { return true }
    if case .submitting = viewModel.state { return true }
    return false
  }

  private var submitTitle: String {
    switch viewModel.state {
    case .uploading:
      return languageService.text(.expenseBulkUploading)
    case .submitting:
      return languageService.text(.expenseBulkSubmitting)
    default:
      return languageService.text(.expenseBulkSubmit)
    }
  }
}
