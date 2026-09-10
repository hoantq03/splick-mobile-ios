# Mobile request correlation

When an API call fails, the Splick iOS app captures the backend **trace ID** so users can share it with support and engineers can grep logs.

## Sources

The client resolves trace ID in this order:

1. Response header `X-Request-Id` (from Kong / Spring `RequestCorrelationFilter`)
2. JSON error body field `traceId` on `ApiErrorResponse`

## Logging

`APIClient` logs failed responses at error level:

```text
API failed status=500 traceId=550e8400-e29b-41d4-a716-446655440000
```

Category: `Network` (visible in Console.app when filtering subsystem `com.splick.app`).

## User-facing UI

- **`ErrorView(error:)`** — shows the human message plus a copyable **Reference ID** block when a trace ID is present.
- **`ErrorView(message:)`** / `LoadingState.failed` — message comes from `error.localizedDescription`, which appends `Reference: <traceId>` for network errors.

## Code

| Piece | Path |
|-------|------|
| Parse header/body | `Packages/SplickCore/Sources/Networking/APIClient.swift` |
| Error DTO | `Packages/SplickCore/Sources/Networking/APIErrorBody.swift` |
| Formatting | `Packages/SplickCore/Sources/Common/SplickErrorFormatting.swift` |
| UI | `Packages/SplickCore/Sources/DesignSystem/Components/ErrorView.swift` |

## Backend doc

See `splick-backend/docs/request-correlation.md` for the full HTTP + async (Redis Streams / outbox) flow.
