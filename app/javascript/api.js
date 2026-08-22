const csrfToken = () =>
  document.querySelector('meta[name="csrf-token"]')?.getAttribute("content") ?? "";

class ApiError extends Error {
  constructor(message, { status, code } = {}) {
    super(message);
    this.name = "ApiError";
    this.status = status;
    this.code = code;
  }
}

async function request(path, { method = "GET", body, signal } = {}) {
  const response = await fetch(path, {
    method,
    signal,
    headers: {
      Accept: "application/json",
      ...(body ? { "Content-Type": "application/json" } : {}),
      ...(method !== "GET" ? { "X-CSRF-Token": csrfToken() } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });

  const text = await response.text();
  const payload = text ? JSON.parse(text) : null;

  if (!response.ok) {
    throw new ApiError(payload?.message ?? `Erro ${response.status}`, {
      status: response.status,
      code: payload?.error,
    });
  }

  return payload;
}

const toQuery = (params) => {
  const search = new URLSearchParams();
  Object.entries(params ?? {}).forEach(([key, value]) => {
    if (value !== undefined && value !== null && value !== "") search.set(key, value);
  });
  const query = search.toString();
  return query ? `?${query}` : "";
};

export const api = {
  items: (list, params, signal) =>
    request(`/api/${list}${toQuery(params)}`, { signal }),
  release: (discogsId, signal) => request(`/api/releases/${discogsId}`, { signal }),
  profile: (signal) => request("/api/profile", { signal }),
  syncStatus: (signal) => request("/api/sync", { signal }),
  startSync: () => request("/api/sync", { method: "POST" }),
};

export { ApiError };
