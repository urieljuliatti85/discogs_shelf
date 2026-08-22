import { useCallback, useEffect, useRef, useState } from "react";
import { api } from "../api";

const POLL_MS = 1500;

// Polls /api/sync only while a run is in flight, then calls onFinished once so
// the current list can refresh itself.
export function useSync(onFinished) {
  const [status, setStatus] = useState(null);
  const [error, setError] = useState(null);
  const timer = useRef(null);
  const wasRunning = useRef(false);
  const finishedCallback = useRef(onFinished);

  finishedCallback.current = onFinished;

  const isRunning = status?.status === "running" || status?.status === "pending";

  const poll = useCallback(async () => {
    try {
      const next = await api.syncStatus();
      setStatus(next);

      const running = next?.status === "running" || next?.status === "pending";
      if (wasRunning.current && !running) finishedCallback.current?.(next);
      wasRunning.current = running;
      return running;
    } catch (err) {
      setError(err);
      return false;
    }
  }, []);

  useEffect(() => {
    poll();
    return () => clearTimeout(timer.current);
  }, [poll]);

  useEffect(() => {
    if (!isRunning) return undefined;
    timer.current = setTimeout(poll, POLL_MS);
    return () => clearTimeout(timer.current);
  }, [isRunning, status, poll]);

  const start = useCallback(async () => {
    setError(null);
    try {
      const next = await api.startSync();
      setStatus(next);
      wasRunning.current = true;
    } catch (err) {
      setError(err);
    }
  }, []);

  return { status, isRunning, error, start, refresh: poll };
}
