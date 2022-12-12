# syntax = docker/dockerfile:experimental
# Build app
FROM public.ecr.aws/docker/library/node:16-alpine as builder
ARG PNPM_VERSION=7.17.1
# Install pnpm
RUN npm --global install pnpm@${PNPM_VERSION}
# Cache APK
RUN --mount=type=cache,target=/var/cache/apk ln -vs /var/cache/apk /etc/apk/cache && \
	apk add --no-cache libc6-compat
WORKDIR /build
COPY pnpm-lock.yaml package.json ./
# Cache pnpm
RUN pnpm store path
RUN --mount=type=cache,target=/root/.local/share/pnpm/store/v3 \
    pnpm install --frozen-lockfile --prefer-offline
COPY . .
RUN npm run build
# Prune devDependencies
RUN pnpm prune --prod

FROM public.ecr.aws/docker/library/node:16-alpine AS runner
WORKDIR /app

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 vultra
USER vultra

# Copy needed files only
COPY --from=builder --chown=vultra:nodejs /build/.env ./.env
COPY --from=builder --chown=vultra:nodejs /build/public ./public
COPY --from=builder --chown=vultra:nodejs /build/.next/static ./.next/static
COPY --from=builder --chown=vultra:nodejs /build/.next/standalone ./

CMD node server.js