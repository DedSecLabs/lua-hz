# Contributing

LuaHZ is a Horizon Gaming-specific MoonLoader helper, with original Lua/native implementations and separately acquired cosmetic assets. Start with [development setup](docs/DEVELOPMENT.md), [architecture](docs/ARCHITECTURE.md) and [current status](docs/STATUS.md). Agent instructions are in AGENTS.md.

Use a feature branch (codex/ is the default for agent work). Use conventional commit titles: `feat:` for features, `fix:` for corrections, `docs:` for documentation, `test:` for tests, and `build:` or `chore:` for tooling and maintenance. For example, `docs: clarify cruise control shortcuts`. Keep changes scoped; describe the user-visible trigger/result and relevant verification. A Lua change should run the offline suite. A native change must also preserve version/signature validation, reference ownership, default stock behavior, deactivation and installer rollback. Provide a user QA checklist for rendering/network behavior.

Preserve the MIT license and the mimgui/Lucide notices. See docs/ASSETS.md before adding images, fonts, binaries or derived material. Source exports intentionally exclude personal data, game files, compiled prerequisites and assets with unverified redistribution rights. Do not silently add runtime downloads or execute downloaded installers.

Open a pull request with the concrete problem, final behavior, tests and remaining live QA. Native supported-version changes require a separately verified adapter, not relaxed checks. Consolidation should update imports, source tests, build paths and handoff documents together.
