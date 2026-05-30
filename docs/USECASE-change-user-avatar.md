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

## Live APIs

The main app always uses live HTTP for feed, expense, notification, auth, and media (`DependencyContainer`).

Nếu đã từng lưu avatar với URL domain giả trên backend cũ → **đổi avatar lại** sau khi `SHARED_MEDIA_PUBLIC_BASE_URL` trỏ R2 public thật.

## Kiểm thử

1. Backend: `./gradlew devUp` + `runAuth` + `runMedia` (và `SHARED_MEDIA_PUBLIC_BASE_URL` = URL public R2 thật).
2. Đăng nhập → avatar góc trái (Feed/Friends/…) → **Profile settings** → **Edit profile** (mở sheet).
3. Chọn ảnh → **Save** → avatar cập nhật trên Profile và toolbar.
4. Chỉ đổi display name → Save → tên đổi, avatar giữ nguyên.

| Triệu chứng | Gợi ý |
|-------------|--------|
| Upload fail / 5xx | `runMedia` chưa chạy; Kong :8080 |
| Save OK, ảnh không load (`-1003`) | URL cũ trong DB — upload lại; kiểm tra `SHARED_MEDIA_PUBLIC_BASE_URL` |
| Simulator không reach API | `AppConstants.API.baseURL` = `http://localhost:8080/api`; device thật dùng IP Mac |

Nếu upload lỗi, xem message (vd. R2 CORS / HTTP status).

## Backend contract

Xem [`splick-backend/services/auth-service/docs/usecases/US-change-user-avatar.md`](../../splick-backend/services/auth-service/docs/usecases/US-change-user-avatar.md).
