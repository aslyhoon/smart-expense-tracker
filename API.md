# API Reference

Base URL: `http://localhost:8080`. All paths are prefixed with `/api`.

Authentication: JWT in the `Authorization: Bearer <token>` header. The token is returned by signup/login. Every endpoint below requires auth **except** `POST /api/auth/signup` and `POST /api/auth/login`.

ML service (separate, `http://localhost:8000`): `/categorize`, `/insights`, `/forecast`. These are called server-to-server by the backend; they do not require the JWT.

## Endpoint Table

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/api/auth/signup` | No | Register a new user; returns token + user |
| POST | `/api/auth/login` | No | Log in; returns token + user |
| GET | `/api/expenses?month=2026-09&category=Food` | Yes | List expenses, optionally filtered by month (`YYYY-MM`) and/or category |
| POST | `/api/expenses` | Yes | Create an expense |
| GET | `/api/expenses/{id}` | Yes | Get one expense |
| PUT | `/api/expenses/{id}` | Yes | Update an expense |
| DELETE | `/api/expenses/{id}` | Yes | Delete an expense (204, no body) |
| POST | `/api/expenses/{id}/correct` | Yes | Correct an expense's category; feeds merchant_map learning |
| GET | `/api/expenses/summary?period=month&year=2026&month=9` | Yes | Monthly summary: totals, by-category, by-day, count |
| GET | `/api/budgets` | Yes | List budgets |
| POST | `/api/budgets` | Yes | Create a budget |
| PUT | `/api/budgets/{id}` | Yes | Update a budget |
| DELETE | `/api/budgets/{id}` | Yes | Delete a budget (204, no body) |
| GET | `/api/budgets/alerts` | Yes | Budget usage with OK / NEAR / EXCEEDED status |
| GET | `/api/recurring` | Yes | List recurring expense rules |
| POST | `/api/recurring` | Yes | Create a recurring rule |
| PUT | `/api/recurring/{id}` | Yes | Update a recurring rule |
| DELETE | `/api/recurring/{id}` | Yes | Delete a recurring rule (204, no body) |
| POST | `/api/qr/parse` | Yes | Parse a UPI payload string into payee/amount/note |
| POST | `/api/qr/scan-image` | Yes | Upload a QR image (multipart `file`); returns parsed UPI fields or OCR fallback |
| POST | `/api/bank/consent` | Yes | Grant consent for a bank; returns consentId |
| GET | `/api/bank/accounts` | Yes | List (masked) accounts under the user's consents |
| POST | `/api/bank/sync` | Yes | Sync new transactions from the provider (dedup + auto-categorize) |
| POST | `/api/bank/import` | Yes | Import a statement file (multipart `file`: CSV / XLSX / PDF) |
| POST | `http://localhost:8000/categorize` | No | ML: suggest a category for free text |
| POST | `http://localhost:8000/insights` | No | ML: spending insights + anomalies |
| POST | `http://localhost:8000/forecast` | No | ML: next-month spend forecast |

Common error responses: `400` (validation error), `401` (missing/invalid token), `404` (unknown id), `409` (duplicate, e.g. email already registered or duplicate budget for category).

## Samples

### 1. Signup

`POST /api/auth/signup` -> `201 Created`

Request:

```json
{
  "name": "Demo User",
  "email": "demo@example.com",
  "password": "demo1234"
}
```

Response:

```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
    "name": "Demo User",
    "email": "demo@example.com"
  }
}
```

### 2. Login

`POST /api/auth/login` -> `200 OK`

Request:

```json
{
  "email": "demo@example.com",
  "password": "demo1234"
}
```

Response:

```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
    "name": "Demo User",
    "email": "demo@example.com"
  }
}
```

### 3. Create expense

`POST /api/expenses` -> `201 Created`

Request:

```json
{
  "amount": 249.00,
  "category": "Food",
  "date": "2026-09-25",
  "paymentMode": "UPI",
  "merchant": "Swiggy",
  "notes": "Lunch order",
  "isRecurring": false
}
```

Response:

```json
{
  "id": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
  "amount": 249.00,
  "category": "Food",
  "date": "2026-09-25",
  "paymentMode": "UPI",
  "merchant": "Swiggy",
  "notes": "Lunch order",
  "source": "MANUAL",
  "bankTxnRef": null,
  "createdAt": "2026-09-25T07:50:00Z"
}
```

### 4. Monthly summary

`GET /api/expenses/summary?period=month&year=2026&month=9` -> `200 OK`

Response:

```json
{
  "totalSpent": 18450.75,
  "transactionCount": 42,
  "byCategory": [
    { "category": "Food", "total": 5230.00, "count": 15 },
    { "category": "Transport", "total": 1870.50, "count": 9 },
    { "category": "Shopping", "total": 4100.25, "count": 6 },
    { "category": "Utilities", "total": 3250.00, "count": 4 },
    { "category": "Entertainment", "total": 4000.00, "count": 8 }
  ],
  "byDay": [
    { "date": "2026-09-01", "total": 640.00 },
    { "date": "2026-09-02", "total": 1120.50 },
    { "date": "2026-09-03", "total": 0.00 }
  ]
}
```

### 5. Budget alerts

`GET /api/budgets/alerts` -> `200 OK`

Response:

```json
[
  {
    "category": "Food",
    "limit": 6000.00,
    "spent": 5230.00,
    "percentUsed": 87.2,
    "status": "NEAR"
  },
  {
    "category": "Shopping",
    "limit": 3000.00,
    "spent": 4100.25,
    "percentUsed": 136.7,
    "status": "EXCEEDED"
  },
  {
    "category": "Transport",
    "limit": 2500.00,
    "spent": 1870.50,
    "percentUsed": 74.8,
    "status": "OK"
  }
]
```

`status` is `NEAR` when `percentUsed >= alertThreshold * 100` (default threshold 80) but the limit is not exceeded, `EXCEEDED` when `spent > limit`, otherwise `OK`.

### 6. QR parse

`POST /api/qr/parse` -> `200 OK`

Request:

```json
{
  "payload": "upi://pay?pa=swiggy@upi&pn=Swiggy&am=249.00&cu=INR&tn=Lunch%20order"
}
```

Response:

```json
{
  "payeeVpa": "swiggy@upi",
  "payeeName": "Swiggy",
  "amount": 249.00,
  "note": "Lunch order",
  "currency": "INR"
}
```

Missing parameters are returned as `null` (e.g. a QR without `am` yields `"amount": null`, and the frontend leaves the amount field empty for the user).

### 7. Bank import

`POST /api/bank/import` (multipart form, field `file`: CSV / XLSX / PDF) -> `200 OK`

Response:

```json
{
  "imported": 18,
  "skipped": 4
}
```

`imported` counts transactions saved as new expenses (`source=BANK`); `skipped` counts rows rejected as duplicates (matching `bank_txn_ref`) or unparseable. Imported rows are auto-categorized via the ML service, same as `/api/bank/sync`.

### 8. ML categorize (ML service)

`POST http://localhost:8000/categorize` -> `200 OK`

Request:

```json
{
  "text": "Swiggy lunch order 249"
}
```

Response:

```json
{
  "category": "Food",
  "confidence": 0.93,
  "source": "model"
}
```

`source` is `"merchant_map"` when the category came from the learned merchant rule table, `"model"` when it came from the ML classifier, and `"fallback"` when a default (e.g. `Other`) was applied.
