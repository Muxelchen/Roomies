# 🐳 Roomies Backend - Production Dockerfile
# Multi-stage build for security and performance optimization

# ===== BUILD STAGE =====
FROM node:18-alpine AS builder

# Set working directory
WORKDIR /app

# Create non-root user for security
RUN addgroup -g 1001 -S nodejs \
    && adduser -S roomies -u 1001 -G nodejs

# Install dependencies for native modules
RUN apk add --no-cache \
    python3 \
    make \
    g++ \
    pkgconfig \
    pixman-dev \
    cairo-dev \
    pango-dev \
    libjpeg-turbo-dev \
    giflib-dev

# Copy package files
COPY package*.json ./
COPY tsconfig*.json ./

# Install dependencies
RUN npm ci --only=production --ignore-scripts \
    && npm cache clean --force

# Copy source code
COPY src/ src/

# Build application
RUN npm run build

# ===== PRODUCTION STAGE =====
FROM node:18-alpine AS production

# Install security updates
RUN apk update && apk upgrade

# Create non-root user
RUN addgroup -g 1001 -S nodejs \
    && adduser -S roomies -u 1001 -G nodejs

# Install production dependencies
RUN apk add --no-cache \
    dumb-init \
    curl \
    ca-certificates

# Set working directory
WORKDIR /app

# Copy built application from builder stage
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/package*.json ./

# Create required directories
RUN mkdir -p /app/logs /app/uploads /app/certs \
    && chown -R roomies:nodejs /app

# Copy certificate directory (for APNS keys)
RUN mkdir -p /app/certs \
    && chown roomies:nodejs /app/certs

# Switch to non-root user
USER roomies

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

# Environment variables
ENV NODE_ENV=production
ENV PORT=3000

# Use dumb-init for proper signal handling
ENTRYPOINT ["dumb-init", "--"]

# Start application
CMD ["node", "--max-old-space-size=512", "dist/server.js"]

# Metadata
LABEL maintainer="roomies@example.com"
LABEL version="1.0.0"
LABEL description="Roomies Backend API Server"
