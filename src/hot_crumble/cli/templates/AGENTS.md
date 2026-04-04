# Hot Crumble (Crystal web framework)

This project uses the **hot-crumble** framework for server-rendered Crystal applications.
These notes are written for coding agents working in this repo.

## Common commands

- Install dependencies: `shards install`
- Run dev server (watch mode): `./watch.sh`
- Build the app: `shards build`
- Run the app: `crystal run --error-trace src/<app>.cr -- --port 8080`
- Run tests: `crystal spec`
- Format code: `crystal tool format`

## Project layout (conventional)

- `src/<app>.cr` — main entrypoint (typically `Crumble::Server.start`)
- `src/pages/` — GET pages (`Crumble::Page`)
- `src/resources/` — REST-style handlers (`Crumble::Resource`)
- `src/actions/` — Turbo actions (`Crumble::Turbo::Action`) and model actions
- `src/views/` — layouts and reusable components (often `include Crumble::ContextView`)
- `src/crumble/` — request/session glue (`RequestContext`, `Session`, etc.)

## Hot Crumble usage

- **Pages**: subclass `Crumble::Page`. Routes are derived from class names (e.g. `ArticlesPage` → `/articles`). Use `template do ... end` directly in the page class.
- **Resources**: subclass `Crumble::Resource` and implement `index/show/create/update/destroy` as needed. Use `render`, `redirect`, and `redirect_back`.
- **Actions**: subclass `Crumble::Turbo::Action` or use model actions to update part of the page while broadcasting Turbo stream refreshes to connected clients.
- **Views/components**: prefer IO-based rendering (`#to_html(io : IO)`) and Crumble’s typed DSLs instead of assembling HTML strings.

## Helper shards (use them directly)

Hot Crumble bundles helper shards. Prefer their typed DSLs over stringly-typed HTML/CSS/JS:

- `to_html` — typed HTML DSL used for templates/layouts. Layouts are objects with `#to_html(io : IO)` that `yield` a page body.
- `css` — CSS builder. Prefer `style do ... end` with `css_class`/`css_id` for scoped selectors instead of raw CSS strings.
- `js` — JavaScript builder. Prefer `JS::Code` + `def_to_js` for small scripts instead of inline `<script>` strings.
- `crumble-turbo` — Turbo actions and model actions for interactive UI flows.
- `crumble-orma` — model/page integration and typed persistence helpers.

If you `require "to_html"`, `require "css"`, or `require "js"` in app code, consider listing them as direct dependencies in `shard.yml` so version pinning stays explicit.
