# ─── Build Stage ───
FROM node:24-alpine AS builder
WORKDIR /build

# Install build deps
RUN apk upgrade --no-cache && \
    apk add --no-cache python3 make g++ sqlite-dev

COPY node-service/package*.json ./
RUN npm ci --only=production && npm cache clean --force

# Runtime stage
FROM node:24-alpine
WORKDIR /app

# Patch OS vulnerabilities (fixes OpenSSL, musl, zlib)
RUN apk upgrade --no-cache && \
    apk add --no-cache sqlite-libs

# Create non-root user (Alpine syntax)
RUN addgroup -S -g 1001 nodejs && \
    adduser -S -u 1001 -G nodejs nodejs

# Copy node_modules from builder (correct ARM64 binary)
COPY --from=builder /build/node_modules ./node_modules

# Copy app files explicitly — avoid wildcards
COPY node-service/package*.json .
COPY node-service/*.js .

RUN chown -R nodejs:nodejs /app
USER nodejs

ENV NODE_ENV=production
ENV PORT=3000
EXPOSE 3000
CMD ["node", "server.js"]