FROM node:22-bookworm-slim AS builder
RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 make g++ \
    && rm -rf /var/lib/apt/lists/*
RUN corepack enable
WORKDIR /opt/repo

COPY config/theia.app.json config/theia.app.json
COPY scripts/sync-theia-config.js scripts/sync-theia-config.js
COPY ide/package.json ide/yarn.lock ide/
RUN node scripts/sync-theia-config.js

WORKDIR /opt/repo/ide
ENV PUPPETEER_SKIP_DOWNLOAD=true
RUN yarn install --frozen-lockfile --network-timeout 600000 --network-concurrency 4

COPY ide/ ./
RUN node_modules/.bin/theia build
RUN node_modules/.bin/theia download:plugins --ignore-errors

RUN sed -i 's#/opt/homebrew/opt/openjdk@25/libexec/openjdk.jdk/Contents/Home#/opt/java/openjdk#' package.json

# ---- runtime: JDK (for the Java extension), Node and Python ----
FROM eclipse-temurin:25-jdk-jammy AS runtime

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       curl ca-certificates gnupg python3 python3-pip git \
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/theia
COPY --from=builder /opt/repo/ide/package.json /opt/repo/ide/yarn.lock ./
COPY --from=builder /opt/repo/ide/node_modules ./node_modules
COPY --from=builder /opt/repo/ide/lib ./lib
COPY --from=builder /opt/repo/ide/src-gen ./src-gen
COPY --from=builder /opt/repo/ide/plugins ./plugins

COPY workspace /opt/sample-workspace

COPY config/docker/entrypoint.sh /opt/entrypoint.sh
RUN chmod +x /opt/entrypoint.sh

ENV THEIA_PORT=80
ENV WORKSPACE_DIR=/home/workspace
EXPOSE 80

ENTRYPOINT ["/opt/entrypoint.sh"]
