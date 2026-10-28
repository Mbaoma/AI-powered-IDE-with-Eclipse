FROM node:22-bookworm-slim AS builder
RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 make g++ \
    && rm -rf /var/lib/apt/lists/*
RUN corepack enable
WORKDIR /opt/repo

COPY config/theia.app.json config/theia.app.json
COPY scripts/sync-theia-config.js scripts/sync-theia-config.js
COPY ide/ ide/
RUN node scripts/sync-theia-config.js

WORKDIR /opt/repo/ide
RUN node -e " \
  const fs = require('fs'); \
  const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8')); \
  pkg.theia.frontend.config.preferences['java.jdt.ls.java.home'] = '/opt/java/openjdk'; \
  fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n'); \
"

ENV PUPPETEER_SKIP_DOWNLOAD=true
RUN yarn install --frozen-lockfile --network-timeout 600000 --network-concurrency 4
RUN node_modules/.bin/theia build
RUN node_modules/.bin/theia download:plugins --ignore-errors

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

ENV THEIA_WEBVIEW_EXTERNAL_ENDPOINT={{hostname}}
EXPOSE 80

ENTRYPOINT ["/opt/entrypoint.sh"]
