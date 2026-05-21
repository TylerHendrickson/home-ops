FROM node:24-bookworm-slim@sha256:4e6b70dd6cbfc88c8157ba19aa3d9f9cce6ba4703576d55459e45efcbc9c5f5d AS builder

# renovate: datasource=npm depName=@democratize-technology/vikunja-mcp
ARG VIKUNJA_MCP_VERSION=0.2.0
# renovate: datasource=npm depName=mcp-proxy
ARG MCP_PROXY_VERSION=1.0.0

RUN npm install -g "@democratize-technology/vikunja-mcp@${VIKUNJA_MCP_VERSION}" "mcp-proxy@${MCP_PROXY_VERSION}"

FROM gcr.io/distroless/nodejs24-debian12:nonroot

COPY --from=builder /usr/local/lib/node_modules/mcp-proxy /usr/local/lib/node_modules/mcp-proxy
COPY --from=builder /usr/local/lib/node_modules/@democratize-technology/vikunja-mcp /usr/local/lib/node_modules/@democratize-technology/vikunja-mcp

ENTRYPOINT ["/nodejs/bin/node", "/usr/local/lib/node_modules/mcp-proxy/dist/bin/mcp-proxy.js", "--port=8080", "/nodejs/bin/node", "/usr/local/lib/node_modules/@democratize-technology/vikunja-mcp/dist/index.js"]
