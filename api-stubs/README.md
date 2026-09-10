# API Stubs — Offline feature simulation

JSON stub server for **feed, expense, and notifications** during development.

Authentication is **not** stubbed — use `splick-backend` (gateway `:8080`) from the iOS app.

## Setup

```bash
npm install -g json-server
json-server --watch db.json --routes routes.json --port 8080
```

Note: port `8080` conflicts with the API gateway. Use stubs only when the gateway is stopped, or run json-server on another port and adjust non-auth client base URLs if needed.

## Stubbed endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | /api/v1/feed | Paginated posts |
| GET | /api/v1/expenses | Expense list |
| GET | /api/v1/expenses/debts | Debt summary |
| GET | /api/v1/notifications | Notifications |

## Auth (live backend)

| Method | Path | Backend |
|--------|------|---------|
| POST | /api/v1/auth/login | auth-service via gateway |
| POST | /api/v1/auth/register | auth-service via gateway |
| POST | /api/v1/auth/email/otp/request | auth-service via gateway |

Run auth-service and communication-service with Gmail SMTP configured in `splick-backend/.env` (see `docs/email-smtp.md`).
