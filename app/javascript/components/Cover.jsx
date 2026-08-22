import React, { useState } from "react";
import { DiscIcon } from "./Icons";

// Discogs image URLs occasionally 403 on hotlink; fall back to a sleeve-shaped
// placeholder instead of a broken image icon.
export default function Cover({ src, alt, className = "", rounded = "rounded-lg" }) {
  const [failed, setFailed] = useState(false);

  if (!src || failed) {
    return (
      <div
        className={`flex items-center justify-center bg-ink-800 text-ink-600 ${rounded} ${className}`}
        aria-label={alt}
      >
        <DiscIcon size={28} />
      </div>
    );
  }

  return (
    <img
      src={src}
      alt={alt}
      loading="lazy"
      decoding="async"
      referrerPolicy="no-referrer"
      onError={() => setFailed(true)}
      className={`bg-ink-800 object-cover ${rounded} ${className}`}
    />
  );
}
