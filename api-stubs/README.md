# API Stubs — Offline Backend Simulation

Lightweight JSON stub server for development without the real backend.

## Setup

```bash
# Install json-server (one-time)
npm install -g json-server

# Run stub server on port 8080
json-server --watch db.json --routes routes.json --port 8080
```

## Available Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | /api/v1/auth/login | Returns mock auth session |
| POST | /api/v1/auth/register | Returns mock auth session |
| GET | /api/v1/feed | Returns paginated posts |
| GET | /api/v1/expenses | Returns expense list |
| GET | /api/v1/expenses/debts | Returns debt summary |
| GET | /api/v1/notifications | Returns notifications |

## Custom Responses

Edit `db.json` to add/modify test data. The server auto-reloads on file changes.

## Usage with iOS Code

Set `AppConstants.API.baseURL` to `http://localhost:8080/api` (already configured for DEBUG builds).
