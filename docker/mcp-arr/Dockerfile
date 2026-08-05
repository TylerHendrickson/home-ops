FROM node:24-bookworm-slim@sha256:cd84903a12dbd26b46f1f3b8144a2568c41c5d37ddd0c7a80a34c7a19786b35f AS builder

# renovate: datasource=npm depName=mcp-arr-server
ARG MCP_VERSION=1.7.3
# renovate: datasource=npm depName=mcp-proxy
ARG MCP_PROXY_VERSION=6.6.0

RUN npm install -g mcp-arr-server@${MCP_VERSION} mcp-proxy@${MCP_PROXY_VERSION}

FROM gcr.io/distroless/nodejs24-debian12:nonroot@sha256:14d42e2511532589a7c7e01a753667a74fcc96266e137e8125006b87b0c32d0a

COPY --from=builder /usr/local/lib/node_modules/mcp-proxy /usr/local/lib/node_modules/mcp-proxy
COPY --from=builder /usr/local/lib/node_modules/mcp-arr-server /usr/local/lib/node_modules/mcp-arr-server

ENTRYPOINT ["/nodejs/bin/node", "/usr/local/lib/node_modules/mcp-proxy/dist/bin/mcp-proxy.mjs", "--port=8080", "/nodejs/bin/node", "/usr/local/lib/node_modules/mcp-arr-server/dist/index.js"]
