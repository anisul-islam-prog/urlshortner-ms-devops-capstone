# ─── Build Stage ───
FROM node:24.11-alpine AS builder
WORKDIR /build

RUN apk add --no-cache python3 make g++ py3-setuptools sqlite-dev

COPY node-service/package*.json ./
RUN npm ci --only=production && npm cache clean --force

# ─── Runtime Stage ───
FROM node:24.11-alpine
WORKDIR /app

RUN apk add --no-cache sqlite-libs && \
    addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Copy node_modules from builder (correct ARM64 binary)
COPY --from=builder /build/node_modules ./node_modules

# Copy app files explicitly — avoid wildcards
COPY node-service/ .

RUN chown -R nodejs:nodejs /app
USER nodejs

ENV NODE_ENV=production
ENV PORT=3000
EXPOSE 3000
CMD ["node", "server.js"]