FROM node:24-bookworm-slim@sha256:235600a8101ab264e117b1768e925532262668dc9b581ef1dd7d96ced463b8e7 AS builder

# renovate: datasource=npm depName=mcp-arr-server
ARG MCP_VERSION=1.7.3
# renovate: datasource=npm depName=mcp-proxy
ARG MCP_PROXY_VERSION=6.5.7

RUN npm install -g mcp-arr-server@${MCP_VERSION} mcp-proxy@${MCP_PROXY_VERSION}

FROM gcr.io/distroless/nodejs24-debian12:nonroot@sha256:14d42e2511532589a7c7e01a753667a74fcc96266e137e8125006b87b0c32d0a

COPY --from=builder /usr/local/lib/node_modules/mcp-proxy /usr/local/lib/node_modules/mcp-proxy
COPY --from=builder /usr/local/lib/node_modules/mcp-arr-server /usr/local/lib/node_modules/mcp-arr-server

ENTRYPOINT ["/nodejs/bin/node", "/usr/local/lib/node_modules/mcp-proxy/dist/bin/mcp-proxy.mjs", "--port=8080", "/nodejs/bin/node", "/usr/local/lib/node_modules/mcp-arr-server/dist/index.js"]
