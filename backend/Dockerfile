# ==============================================================================
# WASEL NALUT SUPER-APP BACKEND DOCKERFILE
# Lightweight, multi-stage Node.js 20 Alpine container
# ==============================================================================

FROM node:20-alpine AS base

# Install necessary runtime dependencies
RUN apk add --no-cache libc6-compat

WORKDIR /app

# Copy package files for dependency caching
COPY package*.json ./

# Install production dependencies only
RUN npm ci --omit=dev

# Copy application source code and seed data
COPY . .

# Set environment defaults
ENV NODE_ENV=production
ENV PORT=3000

# Expose HTTP & WebSocket port
EXPOSE 3000

# Non-root user for container security
USER node

# Healthcheck
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:${PORT}/ || exit 1

# Start the unified Express + Socket.io server
CMD ["node", "server.js"]
