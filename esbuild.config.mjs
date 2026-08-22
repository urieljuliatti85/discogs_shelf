import * as esbuild from "esbuild";

const watch = process.argv.includes("--watch");
// `rails assets:precompile` sets RAILS_ENV but not NODE_ENV, so honour both.
const production =
  process.env.NODE_ENV === "production" ||
  process.env.RAILS_ENV === "production" ||
  process.argv.includes("--production");

const config = {
  entryPoints: ["app/javascript/application.jsx"],
  bundle: true,
  outdir: "app/assets/builds",
  publicPath: "/assets",
  format: "esm",
  target: ["es2022"],
  loader: { ".js": "jsx" },
  sourcemap: !production,
  minify: production,
  define: {
    "process.env.NODE_ENV": JSON.stringify(production ? "production" : "development"),
  },
  logLevel: "info",
};

if (watch) {
  const context = await esbuild.context(config);
  await context.watch();
} else {
  await esbuild.build(config);
}
