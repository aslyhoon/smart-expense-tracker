// ---------------------------------------------------------------------------
// Central API helper for the Smart Expense Tracker frontend.
// - Reads VITE_API_URL / VITE_ML_URL from import.meta.env (see .env.example)
//   with the shared-contract fallbacks.
// - All backend endpoints live under VITE_API_URL + "/api".
// - Adds `Authorization: Bearer <token>` automatically when a JWT is present
//   in localStorage (saved after /auth/login or /auth/signup).
// ---------------------------------------------------------------------------

export const API_URL = import.meta.env.VITE_API_URL || "http://localhost:8080";
export const ML_URL = import.meta.env.VITE_ML_URL || "http://localhost:8000";

const TOKEN_KEY = "set_token";

// Shared vocab from the project contract.
export const CATEGORIES = [
  "Food",
  "Transport",
  "Shopping",
  "Utilities",
  "Rent",
  "Subscriptions",
  "Health",
  "Entertainment",
  "Education",
  "Travel",
  "Other",
];

export const PAYMENT_MODES = ["UPI", "Cash", "Card", "NetBanking", "Wallet"];

export function getToken() {
  return localStorage.getItem(TOKEN_KEY);
}

export function setToken(token) {
  if (token) localStorage.setItem(TOKEN_KEY, token);
}

export function clearToken() {
  localStorage.removeItem(TOKEN_KEY);
  localStorage.removeItem("set_user");
}

export function saveUser(user) {
  localStorage.setItem("set_user", JSON.stringify(user));
}

export function getUser() {
  try {
    return JSON.parse(localStorage.getItem("set_user"));
  } catch {
    return null;
  }
}

function authHeaders(extra = {}) {
  const headers = { ...extra };
  const token = getToken();
  if (token) headers["Authorization"] = `Bearer ${token}`;
  return headers;
}

// Low-level fetch wrapper: builds the URL, attaches the auth header,
// JSON-encodes bodies, and throws a readable Error on non-2xx responses.
async function request(base, path, { method = "GET", body, headers = {} } = {}) {
  const res = await fetch(`${base}${path}`, {
    method,
    headers: authHeaders(
      body && !(body instanceof FormData)
        ? { "Content-Type": "application/json", ...headers }
        : headers
    ),
    body: body instanceof FormData ? body : body ? JSON.stringify(body) : undefined,
  });

  if (!res.ok) {
    let message = `Request failed (${res.status})`;
    try {
      const data = await res.json();
      message = data.message || data.error || message;
    } catch {
      // Not JSON — keep the generic message.
    }
    const err = new Error(message);
    err.status = res.status;
    throw err;
  }

  // Some endpoints (204 No Content) have no body.
  const text = await res.text();
  return text ? JSON.parse(text) : null;
}

// ---- Backend (Spring Boot) ------------------------------------------------
export const api = {
  // Auth
  signup: (data) => request(API_URL, "/api/auth/signup", { method: "POST", body: data }),
  login: (data) => request(API_URL, "/api/auth/login", { method: "POST", body: data }),

  // Expenses
  listExpenses: (params = {}) => {
    const q = new URLSearchParams(params).toString();
    return request(API_URL, `/api/expenses${q ? `?${q}` : ""}`);
  },
  createExpense: (data) => request(API_URL, "/api/expenses", { method: "POST", body: data }),
  updateExpense: (id, data) => request(API_URL, `/api/expenses/${id}`, { method: "PUT", body: data }),
  deleteExpense: (id) => request(API_URL, `/api/expenses/${id}`, { method: "DELETE" }),
  // Send a corrected category — used by the backend to train its merchant_map.
  correctCategory: (id, category) =>
    request(API_URL, `/api/expenses/${id}/correct`, { method: "POST", body: { category } }),
  // period=month&year&month  |  period=year&year  etc.
  summary: (params) => {
    const q = new URLSearchParams(params).toString();
    return request(API_URL, `/api/expenses/summary${q ? `?${q}` : ""}`);
  },

  // Budgets
  listBudgets: () => request(API_URL, "/api/budgets"),
  createBudget: (data) => request(API_URL, "/api/budgets", { method: "POST", body: data }),
  updateBudget: (id, data) => request(API_URL, `/api/budgets/${id}`, { method: "PUT", body: data }),
  deleteBudget: (id) => request(API_URL, `/api/budgets/${id}`, { method: "DELETE" }),
  budgetAlerts: () => request(API_URL, "/api/budgets/alerts"),

  // Recurring expenses
  listRecurring: () => request(API_URL, "/api/recurring"),
  createRecurring: (data) => request(API_URL, "/api/recurring", { method: "POST", body: data }),
  updateRecurring: (id, data) =>
    request(API_URL, `/api/recurring/${id}`, { method: "PUT", body: data }),
  deleteRecurring: (id) => request(API_URL, `/api/recurring/${id}`, { method: "DELETE" }),

  // UPI QR helpers
  parseQr: (payload) =>
    request(API_URL, "/api/qr/parse", { method: "POST", body: { payload } }),
  scanQrImage: (file) => {
    const form = new FormData();
    form.append("file", file);
    return request(API_URL, "/api/qr/scan-image", { method: "POST", body: form });
  },

  // Mock bank consent flow
  bankConsent: () => request(API_URL, "/api/bank/consent", { method: "POST" }),
  bankAccounts: () => request(API_URL, "/api/bank/accounts"),
  bankSync: () => request(API_URL, "/api/bank/sync", { method: "POST" }),
  bankImport: (file) => {
    const form = new FormData();
    form.append("file", file);
    return request(API_URL, "/api/bank/import", { method: "POST", body: form });
  },
};

// ---- ML service (FastAPI) -------------------------------------------------
// The ML service is separate from the backend; it does not need auth here.
export const ml = {
  // POST {text} -> {category, confidence, source}
  categorize: (payload) => request(ML_URL, "/categorize", { method: "POST", body: payload }),
  // POST {transactions, budgets, prev_month_total, current_month_total, ...}
  //   -> {insights: [natural-language strings], anomalies: [...]}
  insights: (payload) => request(ML_URL, "/insights", { method: "POST", body: payload }),
  // POST {monthly_totals: {"Food": [...], ...}} -> {forecast: {"Food": n, ...}, method}
  forecast: (payload) => request(ML_URL, "/forecast", { method: "POST", body: payload }),
};
