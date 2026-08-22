import React from "react";

export default function StarRating({ value = 0, max = 5, size = "text-sm" }) {
  if (!value) return null;

  return (
    <span className={`${size} tracking-tight text-wax-400`} title={`${value} de ${max}`}>
      {"★".repeat(value)}
      <span className="text-ink-600">{"★".repeat(max - value)}</span>
    </span>
  );
}
