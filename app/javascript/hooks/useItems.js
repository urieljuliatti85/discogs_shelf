import { useCallback, useEffect, useRef, useState } from "react";
import { api } from "../api";

export function useItems(list, params, version = 0) {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const controller = useRef(null);
  const key = JSON.stringify(params);

  const load = useCallback(async () => {
    controller.current?.abort();
    const next = new AbortController();
    controller.current = next;

    setLoading(true);
    try {
      const payload = await api.items(list, JSON.parse(key), next.signal);
      setData(payload);
      setError(null);
    } catch (err) {
      if (err.name === "AbortError") return;
      setError(err);
    } finally {
      if (!next.signal.aborted) setLoading(false);
    }
  }, [list, key, version]);

  useEffect(() => {
    load();
    return () => controller.current?.abort();
  }, [load]);

  return { data, loading, error, reload: load };
}

export function useDebounced(value, delay = 300) {
  const [debounced, setDebounced] = useState(value);

  useEffect(() => {
    const timer = setTimeout(() => setDebounced(value), delay);
    return () => clearTimeout(timer);
  }, [value, delay]);

  return debounced;
}
