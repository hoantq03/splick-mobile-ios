# iOS Localization (vi / en)

Splick iOS uses a **code-first** localization layer in `SplickCore/Localization`, separate from system `InfoPlist.strings` for permission dialogs.

## Architecture

| Piece | Location | Role |
|-------|----------|------|
| `L10nKey` | `Packages/SplickCore/Sources/Localization/L10nKey.swift` | Stable string keys (`feed.title`, `expense.loading`, …) |
| `StringsVi` / `StringsEn` | Same folder | Shell strings: tabs, auth, profile, common actions |
| `StringsFeatureVi` / `StringsFeatureEn` | Same folder | Feature strings: feed, friends, expense, notification |
| `L10n` | `L10n.swift` | Merges locale tables at runtime |
| `LanguageService` | `LanguageService.swift` | Current locale (UserDefaults + API sync) |
| `InfoPlist.strings` | `SplickApp/Resources/{en,vi}.lproj/` | System permission prompts |

Default development language is **Vietnamese** (`DEVELOPMENT_LANGUAGE = vi`). In-app language follows the user’s choice in Profile → Language and syncs to backend `preferredLocale`.

## Using strings in SwiftUI

```swift
import Localization

struct MyView: View {
    @EnvironmentObject private var languageService: LanguageService

    var body: some View {
        Text(languageService.text(.feedTitle))
    }
}
```

Format strings use `String(format:languageService.text(.expensePaidBy), name)`.

Domain enums can expose helpers (see `ExpenseL10n.swift`):

```swift
Text(status.title(using: languageService))
```

Ensure the view hierarchy receives `LanguageService` via `.languageService()` on the app root (already wired in `SplickApp`).

## Adding a new user-facing string

1. Add a case to `L10nKey` with a stable dot-separated raw value.
2. Add the translation to **every** locale file:
   - Shell → `StringsVi.swift` / `StringsEn.swift`
   - Feature → `StringsFeatureVi.swift` / `StringsFeatureEn.swift`
3. Run parity test: `swift test --filter L10nKeyParityTests` (from `Packages/SplickCore` on macOS).
4. Replace hardcoded text in the view with `languageService.text(.yourKey)`.
5. Add `import Localization` and `@EnvironmentObject languageService` if missing.

**Rule:** one Swift dictionary file per locale — do not split the same locale across many files.

## Adding a new language (e.g. `ja`)

1. Add `AppLocale.ja` (or extend `AppLocale`) with BCP-47 tag `ja`.
2. Create `StringsJa.swift` and `StringsFeatureJa.swift` mirroring vi/en structure.
3. Register tables in `L10n.swift` (`strings(for:)` switch).
4. Add Profile picker option and backend allow-list if API validates locale.
5. Add `ja.lproj/InfoPlist.strings` for permission strings.
6. Update `L10nKeyParityTests` expected locale count if applicable.
7. Run parity tests — all keys must exist in every table.

## InfoPlist.strings

Permission keys in `Info.plist` stay as English fallbacks. Localized copies live in:

- `SplickApp/Resources/en.lproj/InfoPlist.strings`
- `SplickApp/Resources/vi.lproj/InfoPlist.strings`

iOS picks the file matching the device/app language. Regenerate Xcode project after adding `.lproj` folders:

```bash
make setup
```

## API alignment

`APIClient` sends `Accept-Language` from `LanguageService.currentLocale`. Keep mobile locale tags aligned with backend `shared-i18n` (`vi`, `en`).

## Checklist before merge

- [ ] New keys in all locale files
- [ ] `L10nKeyParityTests` passes
- [ ] Feature `Package.swift` depends on `Localization` product
- [ ] Views use `@EnvironmentObject languageService`, not hardcoded strings
- [ ] Permission strings updated in all `InfoPlist.strings` locales
