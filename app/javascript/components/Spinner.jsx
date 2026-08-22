import React from "react";

export default function Spinner({ size = 16, className = "" }) {
  return (
    <span
      role="status"
      aria-label="Carregando"
      style={{ width: size, height: size, borderWidth: Math.max(2, size / 8) }}
      className={`inline-block animate-spin rounded-full border-ink-600 border-t-wax-400 ${className}`}
    />
  );
}
