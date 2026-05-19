# Vikunja MCP server

In-cluster MCP server exposing Vikunja to Claude Code over Streamable HTTP / SSE at
`https://vikunja-mcp.${SECRET_DOMAIN}/mcp` (and `/sse`).

## Architecture

```
[Claude Code]  ──HTTPS + X-API-Key── ▶  [mcp-proxy]  ──stdio── ▶  [vikunja-mcp]  ──Vikunja REST── ▶  [Vikunja]
                  ↑                                                                ↑
              MCP_API_KEY                                                  VIKUNJA_API_TOKEN
```

Single container running [`mcp-proxy`](https://www.npmjs.com/package/mcp-proxy)
([punkpeye/mcp-proxy](https://github.com/punkpeye/mcp-proxy)) which spawns
[`@democratize-technology/vikunja-mcp`](https://github.com/democratize-technology/vikunja-mcp)
as a stdio subprocess. Both packages installed at startup via nested `npx -y` — no
custom image. Cold-start cost is ~30s of npm fetch per pod restart; restarts are
infrequent enough not to matter for a holdover deployment.

## Why this is a holdover

The Vikunja project has an open PR for an **official** MCP server. Once it
merges and ships a release, swap this deployment to the official server (see
"Swap procedure" below) — the surrounding infrastructure (ingress, ExternalSecret,
chart, transport choice) carries over.

## Required 1Password fields

Single 1Password item `vikunja-mcp` (api credential type) with two fields:

- **`VIKUNJA_API_TOKEN`** — Vikunja API token starting with `tk_`. Generated in
  Vikunja UI → Settings → API Tokens. Used by `vikunja-mcp` to authenticate
  against Vikunja's REST API. Rotates whenever you regenerate it.
- **`MCP_API_KEY`** — random secret (e.g. `openssl rand -hex 32`). Used by
  `mcp-proxy` to gate the HTTP endpoint via `X-API-Key` header. Defense-in-depth
  on top of `ingressClassName: internal`.

The Vikunja JWT signing key (`VIKUNJA_SERVICE_SECRET`) lives in the separate
`vikunja` 1P item and is unrelated to MCP-layer auth.

## Claude Code client configuration

Add to `~/.claude.json` (or per-project `.claude/mcp.json`):

```json
{
  "mcpServers": {
    "vikunja": {
      "type": "http",
      "url": "https://vikunja-mcp.${SECRET_DOMAIN}/mcp",
      "headers": {
        "X-API-Key": "<MCP_API_KEY from 1Password>"
      }
    }
  }
}
```

`type: "http"` selects the Streamable HTTP transport (the `/mcp` endpoint). Use
`type: "sse"` + `url: ".../sse"` if you need the older SSE transport for some reason.

## Swap procedure (when the official Vikunja MCP server ships)

When `go-vikunja/vikunja#<PR>` merges and the official MCP server is released:

1. **Verify** the official server's transport support. If it natively serves
   Streamable HTTP / SSE (likely, given it's an upstream project), the
   `mcp-proxy` layer becomes unnecessary.
2. **Replace** [`helmrelease.yaml`](./helmrelease.yaml)'s container spec with
   the official image and entrypoint. Drop the `npx` invocations.
3. **Re-verify** the auth shape. The official server may not use mcp-proxy's
   `--apiKey` header convention — read its docs and adjust the
   [`externalsecret.yaml`](./externalsecret.yaml) template + helmrelease args.
4. **Renovate**: ensure the new image is tracked by an
   appropriate Renovate datasource.
5. **Bookkeeping**: changelog entry; strike-through the "Vikunja official MCP
   server availability" re-check entry in `.claude/audits/2026-05-06-annotated.md`.

The `ks.yaml` wiring, `ocirepository.yaml`, and ingress shape do not need to
change.

## Renovate notes

Three version pins in [`helmrelease.yaml`](./helmrelease.yaml) are all tracked:

- **Node base image** (`docker.io/library/node:20-bookworm-slim@sha256:…`) —
  picked up by Renovate's built-in `helm-values` manager. Digest updates produce
  `chore(container)` PRs whenever a new `20-bookworm-slim` build publishes
  (frequent, since the tag tracks both Debian and Node 20.x patch releases).
- **`mcp-proxy` npm package** — pinned via `MCP_PROXY_VERSION` env var with a
  `# renovate: datasource=npm depName=mcp-proxy` directive. Matched by the
  existing `customManagers` regex in Renovate.
- **`@democratize-technology/vikunja-mcp` npm package** — pinned via
  `VIKUNJA_MCP_VERSION` env var with a `# renovate:` directive. Same regex
  manager.

The shell expansion of `${MCP_PROXY_VERSION}` and `${VIKUNJA_MCP_VERSION}` in
the container args happens at startup via `sh -c`. Both env vars are injected
through Kubernetes `env:` and visible to the shell process.
