FROM node:20-alpine AS builder

# renovate: datasource=npm depName=mcp-arr-server
ARG MCP_ARR_VERSION=1.5.4
# renovate: datasource=npm depName=mcp-proxy
ARG MCP_PROXY_VERSION=1.0.0

RUN npm install -g mcp-arr-server@${MCP_ARR_VERSION} mcp-proxy@${MCP_PROXY_VERSION}

FROM gcr.io/distroless/base-debian12:nonroot

COPY --from=builder /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=builder /usr/local/bin/mcp-arr /usr/local/bin/
COPY --from=builder /usr/local/bin/mcp-proxy /usr/local/bin/
COPY --from=builder /usr/local/bin/node /usr/local/bin/

ENTRYPOINT ["/usr/local/bin/mcp-proxy", "--port=8080", "--", "/usr/local/bin/mcp-arr"]
