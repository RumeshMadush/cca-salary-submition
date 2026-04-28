# BFF Service Dockerfile

FROM node:18-alpine AS runner
WORKDIR /app

# Create non-root user for security
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 bffservice

# Install production dependencies
COPY package.json ./
RUN npm install --omit=dev

# Copy application code
COPY . .

# Set ownership to non-root user
RUN chown -R bffservice:nodejs /app

# Switch to non-root user
USER bffservice

EXPOSE 4000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:' + (process.env.PORT||4000) + '/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

ENV NODE_ENV=production

CMD ["node", "server.js"]
