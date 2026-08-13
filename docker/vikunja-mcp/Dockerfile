FROM node:24-bookworm-slim@sha256:3638d9a6fe4030bd716be989438248074489337ba3275657f93595428be4fc03 AS builder

# renovate: datasource=npm depName=@democratize-technology/vikunja-mcp
ARG MCP_VERSION=0.2.0
# renovate: datasource=npm depName=mcp-proxy
ARG MCP_PROXY_VERSION=6.7.3

RUN npm install -g "@democratize-technology/vikunja-mcp@${MCP_VERSION}" "mcp-proxy@${MCP_PROXY_VERSION}"

FROM gcr.io/distroless/nodejs24-debian12:nonroot@sha256:14d42e2511532589a7c7e01a753667a74fcc96266e137e8125006b87b0c32d0a

COPY --from=builder /usr/local/lib/node_modules/mcp-proxy /usr/local/lib/node_modules/mcp-proxy
COPY --from=builder /usr/local/lib/node_modules/@democratize-technology/vikunja-mcp /usr/local/lib/node_modules/@democratize-technology/vikunja-mcp

ENTRYPOINT ["/nodejs/bin/node", "/usr/local/lib/node_modules/mcp-proxy/dist/bin/mcp-proxy.mjs", "--port=8080", "/nodejs/bin/node", "/usr/local/lib/node_modules/@democratize-technology/vikunja-mcp/dist/index.js"]
