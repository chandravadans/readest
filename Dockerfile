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

# Prepare .env.local with placeholders for runtime injection
RUN env_source=/app/apps/readest-app/.env.local.example; \
	env_target=/app/apps/readest-app/.env.local; \
	awk -F= '/^NEXT_PUBLIC_/ && $1 != "" { printf "%s=\\$%s\n", $1, $1 }' $env_source >> $env_target && \
	# Replace placeholder to avoid build errors
	sed -i 's|^NEXT_PUBLIC_SUPABASE_URL=.*$|NEXT_PUBLIC_SUPABASE_URL=https://your-supabase-url.com|' $env_target

ENV CI="true"
RUN pnpm install
RUN pnpm --filter=@readest/readest-app setup-vendors && \
	pnpm --filter=@readest/readest-app build-web

# Replace placeholder in built JS files with runtime env variable
RUN find /app/apps/readest-app/.next -name "*.js" -type f -exec sed -i "s|https://your-supabase-url.com|\$NEXT_PUBLIC_SUPABASE_URL|g" {} +

RUN rm -rf /app/apps/readest-app/.next/cache && \
	pnpm --filter=@readest/readest-app install dotenv-cli @next/bundle-analyzer -P

# --- Production image ---
FROM base AS production
ENV NODE_ENV=production
WORKDIR /app

COPY --from=base /app/apps/readest-app/package.json /app/apps/readest-app/package.json
COPY --from=base /app/package.json /app/package.json
COPY --from=base /app/pnpm-lock.yaml /app/pnpm-workspace.yaml ./
COPY --from=base /app/apps/readest-app/.next /app/apps/readest-app/.next
COPY --from=base /app/apps/readest-app/public /app/apps/readest-app/public

ENV CI="true"
RUN pnpm fetch --prod && pnpm install -r --offline --prod && \
	# Install gettext for envsubst
	apt-get update && apt-get install -y gettext-base && \
	rm -rf /var/lib/apt/lists/*

    # Add at the end to leverage cache
COPY ./docker-entrypoint.sh /docker-entrypoint.sh

RUN chmod +x /docker-entrypoint.sh && \
	rm -rf packages/tauri* apps/readest-app/src-tauri

WORKDIR /app/apps/readest-app
ENTRYPOINT ["/docker-entrypoint.sh"]
EXPOSE 3000