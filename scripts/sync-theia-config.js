#!/usr/bin/env node
// Merges config/theia.app.json (the single source of truth for IDE branding,
// default preferences, and bundled VS Code extensions) into ide/package.json.

"use strict";
const fs = require("fs");
const path = require("path");

const repoRoot = path.resolve(__dirname, "..");
const configPath = path.join(repoRoot, "config", "theia.app.json");
const pkgPath = path.join(repoRoot, "ide", "package.json");

const appConfig = JSON.parse(fs.readFileSync(configPath, "utf8"));
const pkg = JSON.parse(fs.readFileSync(pkgPath, "utf8"));

pkg.theia = pkg.theia || {};
pkg.theia.target = pkg.theia.target || "browser";
pkg.theia.frontend = {
  config: {
    applicationName: appConfig.applicationName,
    defaultTheme: appConfig.defaultTheme,
    defaultIconTheme: appConfig.defaultIconTheme,
    preferences: appConfig.preferences
  }
};
pkg.theiaPluginsDir = appConfig.theiaPluginsDir;
pkg.theiaPlugins = appConfig.theiaPlugins;

fs.writeFileSync(pkgPath, JSON.stringify(pkg, null, 2) + "\n");
console.log(`Synced ${path.relative(repoRoot, configPath)} -> ${path.relative(repoRoot, pkgPath)}`);
