# Dockerfile for Clode Studio
# This creates a headless server image suitable for remote access

# Use Node.js 22 LTS as base image
FROM node:22-slim AS builder

# Install system dependencies for building
RUN apt-get update && apt-get install -y \
    git \
    python3 \
    make \
    g++ \
    libnss3-dev \
    libatk-bridge2.0-dev \
    libxcomposite-dev \
    libxdamage-dev \
    libxrandr-dev \
    libasound2-dev \
    libpangocairo-1.0-0 \
    libatk1.0-0 \
    libcairo-gobject2 \
    libgtk-3-0 \
    libgdk-pixbuf2.0-0 \
    libxss1 \
    libdrm2 \
    libxkbcommon0 \
    libatspi2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy package files and scripts needed for install
COPY package*.json ./
COPY scripts/download-ripgrep.js ./scripts/download-ripgrep.js

# Install all dependencies first (needed for build)
RUN npm install --ignore-scripts

# Run postinstall manually without electron-rebuild
RUN npx nuxt prepare && node scripts/download-ripgrep.js

# Copy rest of source code
COPY . .

# Build the application  
RUN npm run build && npm run electron:compile

# Clean up unnecessary files for smaller image
RUN rm -rf .nuxt/analyze .nuxt/dist/client/_nuxt/*.map

# Production stage
FROM node:22-slim AS runtime

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    xvfb \
    libnss3 \
    libatk-bridge2.0-0 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    libasound2 \
    libpangocairo-1.0-0 \
    libatk1.0-0 \
    libcairo-gobject2 \
    libgtk-3-0 \
    libgdk-pixbuf2.0-0 \
    libxss1 \
    libdrm2 \
    libxkbcommon0 \
    libatspi2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -s /bin/bash clode

# Set working directory
WORKDIR /app

# Copy built application from builder stage
COPY --from=builder --chown=clode:clode /app/node_modules ./node_modules
COPY --from=builder --chown=clode:clode /app/.output ./.output
COPY --from=builder --chown=clode:clode /app/electron ./electron
COPY --from=builder --chown=clode:clode /app/package.json ./package.json

# Install production dependencies without postinstall scripts
RUN npm install --production --ignore-scripts

# Create workspace directory
RUN mkdir -p /workspace && chown clode:clode /workspace

# Switch to non-root user
USER clode

# Set environment variables for headless mode
ENV CLODE_MODE=headless
ENV DISPLAY=:99
ENV CLODE_WORKSPACE_PATH=/workspace

# Expose port for web interface
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000 || exit 1

# Start script with virtual display and simpler startup
CMD ["sh", "-c", "Xvfb :99 -screen 0 1024x768x24 & CLODE_MODE=headless node .output/server/index.mjs"]