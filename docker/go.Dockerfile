# ─── Build Stage ───
FROM golang:1.24-alpine AS builder
WORKDIR /build

# Install CGO toolchain for SQLite
RUN apk add --no-cache gcc musl-dev sqlite-dev

COPY go-service/go.mod go-service/go.sum ./
RUN go mod download

COPY go-service/ .
ENV CGO_ENABLED=1
RUN go build -tags "libsqlite3" -o urlshortener main.go

# ─── Runtime Stage ───
FROM alpine:3.19
WORKDIR /app

# SQLite runtime library + CA certs for outbound HTTPS
RUN apk add --no-cache sqlite-libs ca-certificates && \
    addgroup -g 1000 -S appgroup && \
    adduser -u 1000 -S appuser -G appgroup

COPY --from=builder /build/urlshortener .
RUN chown -R appuser:appgroup /app

USER appuser
ENV GIN_MODE=release
EXPOSE 8000

ENTRYPOINT ["./urlshortener"]