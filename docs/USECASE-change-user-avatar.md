# iOS — Đổi ảnh đại diện (user avatar)

## Mục tiêu

User đổi avatar từ **Profile → Edit profile**; app upload qua media-service (presigned R2) rồi cập nhật profile qua auth.

## Luồng

```text
ProfileSettingsView → Edit profile
  → PhotosPicker chọn ảnh
  → UploadUserAvatarUseCase (initiate → PUT R2 → complete)
  → UpdateProfileUseCase → PATCH /v1/auth/me { avatarUrl }
  → AppState cập nhật currentUser
```

## Thành phần

| Layer | Type | File |
|-------|------|------|
| UI | `EditProfileView` | `FeatureAuth/.../EditProfile/EditProfileView.swift` |
| ViewModel | `EditProfileViewModel` | `FeatureAuth/.../EditProfile/EditProfileViewModel.swift` |
| Upload | `UploadUserAvatarUseCase` | `FeatureMedia/.../UploadUserAvatarUseCase.swift` |
| Network | `MediaRepository`, `PresignedUploadClient` | `FeatureMedia`, `SplickCore/Networking` |
| Profile API | `UpdateProfileUseCase` | `FeatureAuth/.../UpdateProfileUseCase.swift` |
| DI | `DependencyContainer.uploadUserAvatarUseCase` | `SplickApp/Sources/DI/DependencyContainer.swift` |

## Giới hạn client

- Export JPEG, tối đa **5 MB** (`AppConstants.Media.maxAvatarSizeBytes`).
- Không nhập URL thủ công trên UI production.

## Kiểm thử

1. Đăng nhập → avatar góc phải → Profile → **Edit profile**.
2. Chọn ảnh → **Save** → quay lại, avatar mới hiển thị.
3. Chỉ đổi display name (không chọn ảnh) → Save → tên cập nhật, avatar giữ nguyên.

## Backend contract

Xem [`splick-backend/services/auth-service/docs/usecases/US-change-user-avatar.md`](../../splick-backend/services/auth-service/docs/usecases/US-change-user-avatar.md).
