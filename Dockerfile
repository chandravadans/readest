
# --- Base image ---
FROM docker.io/node:22-slim AS base
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable && corepack prepare pnpm@10.29.3 --activate
WORKDIR /app

# --- Install dependencies only for web app ---
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY apps/readest-app/package.json ./apps/readest-app/
COPY patches/ ./patches/
COPY packages/ ./packages/
RUN --mount=type=cache,id=pnpm,target=/pnpm/store pnpm install --frozen-lockfile


# --- Copy source and build web app ---
COPY apps/readest-app ./apps/readest-app
WORKDIR /app/apps/readest-app
COPY apps/readest-app/.env.web .env.web
COPY apps/readest-app/.env.local.example .env.local.example
RUN pnpm setup-vendors
# Install next-runtime-env for runtime variable injection
RUN pnpm add next-runtime-env
RUN pnpm build-web

# --- Production image ---
FROM docker.io/node:22-slim AS runner
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
WORKDIR /app

# Only copy necessary files for running the web app
COPY --from=base /app/apps/readest-app/.env.local.example ./apps/readest-app/.env.local.example
COPY --from=base /app/apps/readest-app/public ./apps/readest-app/public
COPY --from=base /app/apps/readest-app/.next ./apps/readest-app/.next
COPY --from=base /app/apps/readest-app/package.json ./apps/readest-app/package.json
COPY --from=base /app/node_modules ./node_modules
COPY --from=base /app/apps/readest-app/node_modules ./apps/readest-app/node_modules
# Copy entrypoint script
COPY apps/readest-app/scripts/entrypoint.sh ./apps/readest-app/scripts/entrypoint.sh
RUN chmod +x ./apps/readest-app/scripts/entrypoint.sh

WORKDIR /app/apps/readest-app
EXPOSE 3000
ENTRYPOINT ["./scripts/entrypoint.sh"]
CMD ["pnpm", "start-web", "-H", "0.0.0.0"]