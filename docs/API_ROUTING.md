# iOS API routing (gateway-aligned)

Mobile calls **only** the public gateway base URL; paths mirror `splick-backend` controllers.

## URL shape

```text
{baseURL} + {path}
= http://localhost:8080/api + /v1/auth/login
= http://localhost:8080/api/v1/auth/login
```

| Build | `AppConstants.API.baseURL` |
|-------|----------------------------|
| DEBUG | `http://localhost:8080/api` |
| Release | `https://api.splick.app/api` |

Defined in `Packages/SplickCore/Sources/Common/Constants.swift`.

## Path convention

All REST paths start with **`/v1/{domain}/...`** (never `/auth/...` or `/social/...` without `v1`).

| Domain | Swift enum | Prefix |
|--------|------------|--------|
| Auth | `AuthEndpoint` | `/v1/auth` |
| Social | `SocialEndpoint` | `/v1/social` |
| Expense | `ExpenseEndpoint` | `/v1/expenses` |
| Feed | `FeedEndpoint` | `/v1/feed` |
| Media | `MediaEndpoint` | `/v1/media` |
| Notifications | `NotificationEndpoint` | `/v1/notifications` |

Source of truth: `splick-backend/openapi/openapi.yaml` and [`splick-backend/docs/API_ROUTING.md`](../../splick-backend/docs/API_ROUTING.md).

## Google Sign-In (iOS)

The app uses **native** Google Sign-In → `POST /v1/auth/google` with `idToken`.

It does **not** use browser OAuth redirect URLs (`/v1/auth/oauth2/...`). Those are for web clients only.

## Not called from iOS

| Backend | Reason |
|---------|--------|
| `communication-service :8087` | Internal S2S (OTP/email) |
| `POST /v1/auth/validate` | Service-to-service JWT check |
| Konga / Kong Admin | Ops tooling |

## When backend routes change

1. Update `splick-backend` controller + OpenAPI.
2. Update the matching `*Endpoint.swift` in this repo.
3. Keep `baseURL` ending with `/api` (no version in base URL).
