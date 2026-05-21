FROM node:24-bookworm-slim AS builder

# renovate: datasource=npm depName=@democratize-technology/vikunja-mcp
ARG VIKUNJA_MCP_VERSION=0.2.0
# renovate: datasource=npm depName=mcp-proxy
ARG MCP_PROXY_VERSION=1.0.0

RUN npm install -g "@democratize-technology/vikunja-mcp@${VIKUNJA_MCP_VERSION}" "mcp-proxy@${MCP_PROXY_VERSION}"

FROM gcr.io/distroless/nodejs24-debian12:nonroot

COPY --from=builder /usr/local/lib/node_modules /usr/local/lib/node_modules

ENTRYPOINT ["/nodejs/bin/node", "/usr/local/lib/node_modules/mcp-proxy/dist/bin/mcp-proxy.js", "--port=8080", "/nodejs/bin/node", "/usr/local/lib/node_modules/@democratize-technology/vikunja-mcp/dist/index.js"]
