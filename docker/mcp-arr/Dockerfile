FROM node:24-bookworm-slim AS builder

# renovate: datasource=npm depName=mcp-arr-server
ARG MCP_ARR_VERSION=1.5.4
# renovate: datasource=npm depName=mcp-proxy
ARG MCP_PROXY_VERSION=1.0.0

RUN npm install -g mcp-arr-server@${MCP_ARR_VERSION} mcp-proxy@${MCP_PROXY_VERSION}

FROM gcr.io/distroless/nodejs24-debian12:nonroot

COPY --from=builder /usr/local/lib/node_modules /usr/local/lib/node_modules

ENTRYPOINT ["/nodejs/bin/node", "/usr/local/lib/node_modules/mcp-proxy/dist/bin/mcp-proxy.js", "--port=8080", "/nodejs/bin/node", "/usr/local/lib/node_modules/mcp-arr-server/dist/index.js"]
