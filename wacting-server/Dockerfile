# Base Image
FROM node:20-slim AS builder

WORKDIR /app

# Install dependencies needed for node-gyp or any native build tools
# RUN apt-get update && apt-get install -y python3 make g++

# Copy package configuration
COPY package*.json ./
COPY prisma ./prisma/

# Install dependencies
RUN npm install

# Generate Prisma Client (force native engine generation inside container)
RUN npx prisma generate

# Copy the rest of the source code
COPY . .

# Compile TypeScript to JavaScript
RUN npm run build

# --- Production Image ---
FROM node:20-slim

WORKDIR /app

# Install OpenSSL for Prisma (Debian-based)
RUN apt-get update && apt-get install -y openssl && rm -rf /var/lib/apt/lists/*

# Copy built artifacts from builder stage (smaller final image)
COPY --from=builder /app/package*.json ./
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/prisma ./prisma
COPY --from=builder /app/dist ./dist

# Keep the reverse-proxy configuration available just in case needed
COPY nginx.conf ./

EXPOSE 3000

# Start Native Node instance
CMD ["npm", "start"]
