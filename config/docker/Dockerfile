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

# Node via NodeSource's apt repo, added directly rather than piping their
# installer script into `bash -` as root: that script is unpinned, remote,
# and fully arbitrary. This way the only thing fetched and executed outside
# apt's own verification is a GPG public key (inert data) -- every actual
# package download is then checked against it by apt itself, the same trust
# model every other apt-installed package in this image already uses.
# Official method: https://github.com/nodesource/distributions/wiki/Repository-Manual-Installation
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       curl ca-certificates gnupg python3 python3-pip git util-linux \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && printf 'Types: deb\nURIs: https://deb.nodesource.com/node_22.x/\nSuites: nodistro\nComponents: main\nSigned-By: /etc/apt/keyrings/nodesource.gpg\n' > /etc/apt/sources.list.d/nodesource.sources \
    && apt-get update \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

RUN useradd --uid 1000 --create-home --shell /bin/bash theia

WORKDIR /opt/theia
COPY --from=builder /opt/repo/ide/package.json /opt/repo/ide/yarn.lock ./
COPY --from=builder /opt/repo/ide/node_modules ./node_modules
COPY --from=builder /opt/repo/ide/lib ./lib
COPY --from=builder /opt/repo/ide/src-gen ./src-gen
COPY --from=builder /opt/repo/ide/plugins ./plugins
RUN chown -R theia:theia /opt/theia

COPY workspace /opt/sample-workspace
RUN chown -R theia:theia /opt/sample-workspace

COPY config/docker/entrypoint.sh /opt/entrypoint.sh
RUN chmod +x /opt/entrypoint.sh

ENV THEIA_PORT=80
ENV WORKSPACE_DIR=/home/workspace

ENV THEIA_WEBVIEW_EXTERNAL_ENDPOINT={{hostname}}
EXPOSE 80

ENTRYPOINT ["/opt/entrypoint.sh"]
