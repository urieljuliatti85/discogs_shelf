import React from "react";
import { DiscIcon } from "./Icons";

export default function EmptyState({ title, description, action }) {
  return (
    <div className="animate-in flex flex-col items-center justify-center rounded-2xl border border-dashed border-ink-700 bg-ink-900/40 px-6 py-20 text-center">
      <DiscIcon size={40} className="text-ink-600" />
      <h2 className="mt-5 text-lg font-semibold text-ink-100">{title}</h2>
      {description && <p className="mt-2 max-w-md text-sm text-ink-400">{description}</p>}
      {action && <div className="mt-6">{action}</div>}
    </div>
  );
}
