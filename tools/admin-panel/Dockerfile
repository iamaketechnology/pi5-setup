# =============================================================================
# PI5 Control Center - Dockerfile
# =============================================================================
# Production-ready Node.js container with SSH client capabilities
# Version: 2.0.0
# =============================================================================

FROM node:18-alpine

# Install SSH client and system utilities
RUN apk add --no-cache \
    openssh-client \
    bash \
    git

# Create app directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy application files
COPY server.js ./
COPY public ./public/

# Create config directory
RUN mkdir -p /app/config

# Expose port
EXPOSE 4000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD node -e "require('http').get('http://localhost:4000/api/status', (r) => process.exit(r.statusCode === 200 ? 0 : 1))"

# Start application
CMD ["node", "server.js"]
