FROM node:24-bookworm-slim AS builder

# renovate: datasource=npm depName=@democratize-technology/vikunja-mcp
ARG VIKUNJA_MCP_VERSION=0.2.0
# renovate: datasource=npm depName=mcp-proxy
ARG MCP_PROXY_VERSION=1.0.0

RUN npm install -g "@democratize-technology/vikunja-mcp@${VIKUNJA_MCP_VERSION}" "mcp-proxy@${MCP_PROXY_VERSION}"

FROM gcr.io/distroless/base-debian12:nonroot

COPY --from=builder /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=builder /usr/local/bin/vikunja-mcp /usr/local/bin/
COPY --from=builder /usr/local/bin/mcp-proxy /usr/local/bin/
COPY --from=builder /usr/local/bin/node /usr/local/bin/

ENTRYPOINT ["/usr/local/bin/mcp-proxy", "--port=8080", "--", "/usr/local/bin/vikunja-mcp"]
