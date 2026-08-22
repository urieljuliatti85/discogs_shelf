import React from "react";

const base = {
  fill: "none",
  stroke: "currentColor",
  strokeWidth: 1.7,
  strokeLinecap: "round",
  strokeLinejoin: "round",
};

const Svg = ({ children, size = 18, ...props }) => (
  <svg viewBox="0 0 24 24" width={size} height={size} {...base} {...props}>
    {children}
  </svg>
);

export const DiscIcon = (props) => (
  <Svg {...props}>
    <circle cx="12" cy="12" r="9" />
    <circle cx="12" cy="12" r="2.6" />
    <path d="M12 5.5a6.5 6.5 0 0 1 6.5 6.5" />
  </Svg>
);

export const HeartIcon = (props) => (
  <Svg {...props}>
    <path d="M12 20s-7-4.4-7-9.2A3.9 3.9 0 0 1 12 8a3.9 3.9 0 0 1 7 2.8C19 15.6 12 20 12 20Z" />
  </Svg>
);

export const ChartIcon = (props) => (
  <Svg {...props}>
    <path d="M4 20V10M10 20V4M16 20v-7M22 20H2" />
  </Svg>
);

export const SearchIcon = (props) => (
  <Svg {...props}>
    <circle cx="11" cy="11" r="6.5" />
    <path d="m16 16 4 4" />
  </Svg>
);

export const SyncIcon = (props) => (
  <Svg {...props}>
    <path d="M20 11a8 8 0 0 0-14-4.5L4 9" />
    <path d="M4 13a8 8 0 0 0 14 4.5L20 15" />
    <path d="M4 4v5h5M20 20v-5h-5" />
  </Svg>
);

export const GridIcon = (props) => (
  <Svg {...props}>
    <rect x="3.5" y="3.5" width="7" height="7" rx="1.4" />
    <rect x="13.5" y="3.5" width="7" height="7" rx="1.4" />
    <rect x="3.5" y="13.5" width="7" height="7" rx="1.4" />
    <rect x="13.5" y="13.5" width="7" height="7" rx="1.4" />
  </Svg>
);

export const ListIcon = (props) => (
  <Svg {...props}>
    <path d="M8 6h13M8 12h13M8 18h13M3.5 6h.01M3.5 12h.01M3.5 18h.01" />
  </Svg>
);

export const ArrowLeftIcon = (props) => (
  <Svg {...props}>
    <path d="M19 12H5M11 18l-6-6 6-6" />
  </Svg>
);

export const ExternalIcon = (props) => (
  <Svg {...props}>
    <path d="M14 4h6v6M20 4l-8.5 8.5" />
    <path d="M18 14v5a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1h5" />
  </Svg>
);

export const CloseIcon = (props) => (
  <Svg {...props}>
    <path d="m6 6 12 12M18 6 6 18" />
  </Svg>
);
