# Vote Service Dockerfile

FROM node:18-alpine AS runner
WORKDIR /app

# Create non-root user for security
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 voteservice

# Install production dependencies
COPY package.json ./
RUN npm install --omit=dev

# Copy application code
COPY . .

# Set ownership to non-root user
RUN chown -R voteservice:nodejs /app

# Switch to non-root user
USER voteservice

# Expose port
EXPOSE 8083

# Health check — PORT is injected by K8s (default 8083)
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:' + (process.env.PORT||8083) + '/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Set environment to production
ENV NODE_ENV=production

# Start the service
CMD ["node", "server.js"]
