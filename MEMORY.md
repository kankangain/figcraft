# FigCraft — Project Memory

## Project Identity

**FigCraft** is a clean-room, open-source, pure-Rust (egui) reimplementation of the Figma design workflow:
- Interface design, auto layout, components and variants, styles and variables, prototyping and inspection
- Runs natively on macOS, Windows, Linux, FreeBSD, and in the browser via WebAssembly
- Part of the **Crafting Apps** family (siblings: VectorCraft, PhotoCraft, FilmCraft, LightCraft, PdfCraft, EffectCraft, DesignCraft)
- Built by the **ArtCraft** team and community (https://getartcraft.com/)
- Dual-licensed: MIT OR Apache-2.0

**Current Stage:** Alpha (~53% ready for real work)
- Menu/command breadth: 100% (212/212 catalogued items)
- Feature breadth: ~85% (core editor ~94%)
- Next milestone: Beta (requires reliable `.fig` import + multiplayer with accounts)

## Core Principles (Non-Negotiable)

### Clean-Room Implementation
- Behaviour comes from **public documentation and black-box observation only** with synthetic documents
- Never read, disassemble, or copy anything inside Figma's application bundle, web bundle, or network traffic
- Never copy GPL/AGPL code
- Reference screenshots of Figma stay local under gitignored `plan/figma/screenshots/` — never committed

### Asset Policy (Absolute Rule)
- **Never add, copy, trace, redraw-from, embed, or ship any icon, image, illustration, cursor, logo, template, UI kit, preset library, font file, or screenshot from Figma, Adobe, Avid, Autodesk, or any other product**
- Every asset must be: original work (MIT OR Apache-2.0), OSI open source, public domain/CC0, or CC with redistribution allowed
- Every asset file must have a row in `ATTRIBUTION.md` (path, author, source, licence, notes)
- `cargo xtask assets` (part of `cargo xtask ci`) fails on unlisted files under `assets/`, `docs/brand/`, `docs/images/`
- UI icons are drawn in code (`crates/ui-egui/src/icons.rs`) from simple primitives — keep it that way
- App icon is the owner's chameleon drawing, vectorised (`assets/app-icon/figcraft.svg`)
- Fonts live in `storytold/craft-fonts` — never in this repo. Build input via `CRAFT_FONTS_DIR`
- Demo/test content is synthetic or public domain only

### Never Crash
- No `unwrap()`, `expect()`, `panic!`, `unreachable!`, `todo!`, `unimplemented!` in shipped code (workspace clippy lints deny them; tests may use them)
- Return `Result`/`Option`; use `.get()` for data-derived indexes; slice strings only at char boundaries; check floats are finite; cap sizes
- `figcraft_engine::guard` turns a panicking command into `EngineError::Internal` with document rollback
- `unsafe_code = "forbid"` workspace-wide
- Every crash fix comes with a regression test; extend fuzz/sweep tests when adding parsers/commands

### Architecture
- **Everything is a command** — user-visible behaviour = command in `crates/engine/src/cmd/*` (`spec!(id, label, params doc, undoable, run)`) + tests
- Menus, shortcuts, Actions palette, CLI, control channel, MCP server all dispatch the same command IDs
- Command IDs follow Figma's menu catalog in `crates/engine/src/catalog.rs`
- **Programmatic calls never open dialogs** — commands only request UI (`Session::request_ui`); control channel drops dialog requests
- **Layering enforced by `cargo xtask layers`**:
  - L0: geom/color → L1: doc → L2: layout/text/pathops/plugin/collab → L3: render/format → L4: svg/pdf → L5: engine → L6: ui-egui/mcp → apps
  - Nothing below L6 depends on egui/eframe/rfd/winit — **UI crate is swappable**
- **UI is thin**: panels read engine state, act through `app.run(id, params)` / `app.set_props(ids, props)`; colours from `theme::Tokens`
- **Time goes through `chrono`** — never hand-roll UTC/calendar conversion; only output format string owned by crate
- **Rust only** (no handwritten JS/TS); **Never break wasm** (`cargo xtask wasm`)

### Quality Gates (Before Every Commit)
```
cargo xtask ci  # fmt, clippy -D warnings, tests, layers, assets, wasm
```
- One task per commit with milestone ID in message (e.g., `M2.1: auto layout wrap`)
- Commit after every landed arc of work; push to `main`

## Project Structure

### Workspace Crates (`crates/`)
| Crate | Purpose |
|-------|---------|
| `geom` | Geometry primitives (L0) |
| `color` | Colour spaces, blending (L0) |
| `doc` | Document model (L1) |
| `layout` | Auto layout, constraints (L2) |
| `text` | Text shaping, fonts, bidi (L2) |
| `pathops` | Boolean ops, vector networks (L2) |
| `plugin` | WASM plugin runtime (L2) |
| `collab` | Multiplayer core, CRDTs (L2) |
| `render` | CPU renderer (tiny-skia) (L3) |
| `format` | Import/export: .figcraft, .fig, REST JSON, SVG, PDF, PNG, etc. (L3) |
| `svg` | SVG export (L4) |
| `pdf` | PDF export (L4) |
| `engine` | Command registry, document engine (L5) |
| `ui-egui` | egui-based desktop UI (L6) |
| `mcp` | Model Context Protocol server (L6) |
| `collab-net` | Network transport for collaboration (L6) |

### Applications (`apps/`)
- `figcraft` — Desktop app (eframe/egui)
- `figcraft-cli` — Headless CLI (`info`, `export`, `run`, `commands`, `mcp`)
- `figcraft-web` — WebAssembly build (Trunk)

### Other
- `xtask` — Build automation (layers, assets, icons, wasm, ci, parity, bench)
- `plugins/sdk` — Rust SDK for WASM plugins
- `plugins/examples/` — Example plugins (counter, tidy-names, swatch-grid)
- `docs/` — Extensive documentation (parity, gaps, roadmap, control-protocol, mcp, cli, server, etc.)
- `plan/` — Local-only (gitignored): STATUS.md, execution-plan.md, figma/ reference notes
- `contributors/` — Contributor credits (people.toml + generated contributors.json)

## Development Workflow

### Starting a Session
1. Read `ROADMAP.md` (stage, headline numbers, estimates) and `docs/gaps.md` (ranked work list)
2. Read `plan/STATUS.md` and `plan/execution-plan.md` if present; reference notes in `plan/figma/*.md`
3. Orient → plan → implement + test → verify (screenshot) → record (ROADMAP, devlog) → commit

### Running the App
```bash
# Desktop app
cargo run --release -p figcraft

# With control channel (pick free port)
cargo run -p figcraft -- --control <port> [file.figcraft|file.svg|image]

# Control channel JSON lines:
{"id":1,"method":"engine.execute","params":{"command":"shape.rectangle","params":{"x":10,"y":10,"width":100,"height":50}}}
{"id":2,"method":"ui.screenshot","params":{"path":"/tmp/shot.png"}}

# Headless CLI
figcraft-cli render landing.figcraft -o landing.png --scale 2
figcraft-cli export landing.figcraft -o out/ --format svg
figcraft-cli run build-card.json --out card.figcraft
figcraft-cli commands --filter autoLayout
figcraft-cli mcp
figcraft-cli mcp --attach 47800

# Web build (requires trunk)
cargo xtask wasm
```

### Key Commands
- `cargo xtask ci` — Full quality gate (fmt, clippy, tests, layers, assets, wasm)
- `cargo xtask parity` — Measures menu/command breadth against catalog
- `cargo xtask bench` — Performance benchmarks
- `cargo xtask layers` — Verify layering
- `cargo xtask assets` — Verify asset attribution
- `cargo xtask icon` — Render app icon PNGs from SVG
- `cargo test --workspace` — Test suite

## Current Priorities (from gaps.md)

1. **`.fig` import's tail** (5–10h) — real-file fixes, table cells, connectors without saved paths (beta blocker)
2. **Multiplayer & sharing without accounts** (42–84h) — accounts, teams, per-person permissions (beta blocker)
3. **Real Figma file corpus** (15–30h) — import real docs, compare against Figma exports
4. **Tool-by-tool interaction pass** (40–60h) — cursors, modifiers, hover, popovers, snapping
5. **Localization native reviews** (29–51h) — es, fr, de, pt-BR, ja, ko, zh-Hans, es-419 drafts need native speakers

## Environment & Conventions

### Platform-Specific
- **Shell gotcha**: `mv`/`cp` may be aliased interactive — use `/bin/mv -f`
- **Parallel agents**: Separate `CARGO_TARGET_DIR` per agent, edit only owned crates/files, write manifests atomically, delete target dir when done

### Fonts
- System fonts scanned at runtime; `craft-fonts` optional build input for release builds
- `.cargo/config.toml` points to `../craft-fonts` for local builds
- `crates/text/build.rs` embeds fonts; everything must build/test/run without craft-fonts

### Date/Time
- All date/time conversion through `chrono` (workspace dependency)
- Exception: range extension past chrono's range uses 400-year Gregorian cycles (146,097 days)

### Contributor Credits
- About ▸ Contributors compiled from `contributors/contributors.json` (generated) + `contributors/people.toml` (self-chosen names)
- Agents: check if human's GitHub username has `[people.<username>]` entry; if not, ask once if they want credit beyond username
- Never add/edit/guess/copy anyone else's entry; never hand-edit `contributors.json`
- Maintainers refresh: `python3 ../../craftrules/scripts/contributors.py .`

### Documentation Standards
- Progress docs follow craftrules `standards/progress-docs.md`
- When a task lands: update affected rows in ROADMAP/gaps/target-app-parity + status line + revision history in same commit
- Grade by behaviour against incumbent, not by menu item existence; err low

## Key Documentation Files

| File | Purpose |
|------|---------|
| `ROADMAP.md` | One-page summary: stage, headline numbers, progress log |
| `docs/roadmap.md` | Milestones, current focus, alpha gate, revision history |
| `docs/target-app-parity.md` | Authoritative assessment with weighted dimensions |
| `docs/gaps.md` | Ranked work list with estimates and evidence |
| `docs/parity-checklist.md` | Generated menu checklist (`cargo xtask parity`) |
| `docs/control-protocol.md` | JSON control channel protocol |
| `docs/mcp.md` | MCP server usage |
| `docs/cli.md` | CLI reference |
| `docs/server.md` | Self-hosted server deployment |
| `docs/collab-protocol.md` | Multiplayer protocol |
| `docs/plugins.md` | Plugin SDK and API |
| `docs/translating.md` | Adding a language |
| `docs/architecture.md` | System architecture |
| `docs/*-parity.md` | Per-area deep checklists |

## Communication Channels
- **Discord**: https://discord.gg/artcraft (community hub)
- **Website**: https://getartcraft.com/apps/figcraft
- **GitHub**: https://github.com/storytold/figcraft

## Version & Release Info
- Workspace version: 0.10.0 (Cargo.toml)
- Rust edition: 2024
- Minimum Rust: 1.95
- Release builds: signed/notarized macOS, Windows installers (x64/x86/arm64), Linux (AppImage, .deb, .rpm, Flatpak, tarball), FreeBSD, web
- Release process: `docs/releasing.md`, `docs/release-playbook.md`

## Laya Decision Engine
- Globally connected MCP server for fast (~ms), local, offline typed decisions
- Tools: `check`, `classify`, `score`, `decide`, `triage`, `detect_language`, `explain_routing`, `list_models`
- **Policy**: Default to laya for judgment calls (classify, route, triage, gate, score) instead of guessing
- Load `laya-decisions` skill on first use in session
- Trust confidence, not label alone; act on high-confidence, verify near 0.5
- Choice sets ≤ 10 options (11+ uncalibrated)
- State can be text or JSON; batch related questions in one `decide` call
- **Do NOT use** for fact verification, code/API/schema claims, open-ended generation, extraction, or explanations

---

*Last updated: 2026-10-23 (session start)*