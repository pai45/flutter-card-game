# Shared typography

Space Grotesk body/control and Orbitron display/HUD styles are generated from the canonical StatOz Designer manifest. Run `node scripts/typography-library.mjs` to regenerate this checkout, or append `--check` to detect stale files. The local manifest, font and license are committed; Flutter builds do not read Designer or fetch fonts. Shared changes originate in Designer and are copied with its `npm run typography:sync:all` command. Use `StatOzTypography` / `AppTheme` / `Cyber`; preserve accessibility text scaling.
