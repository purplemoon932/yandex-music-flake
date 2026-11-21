#!/usr/bin/env node
import { readFileSync, writeFileSync } from "node:fs";

const target = process.argv[2];
if (!target) {
  console.error("usage: disable-updates.mjs <path to index.js>");
  process.exit(1);
}

const patches = [
  // Never hit the network: make the periodic update check a no-op.
  [
    `      const updateResult = await electronUpdater.autoUpdater.checkForUpdates();`,
    `      const updateResult = null;`
  ],
  // Never quit-and-install: DebUpdater runs `dpkg -i` through sudo, which
  // would trample the Nix store.
  [
    `  install() {
    this.logger.info("Installing a new version", this.latestAvailableVersion);
    this.updateStatus = UpdateStatus.INSTALLING;
    state.willQuit = true;
    electronUpdater.autoUpdater.quitAndInstall();
  }`,
    `  install() {
    this.logger.info("Update installation is disabled by packaging");
  }`
  ],
  // Drop the "Check for updates" tray menu item (Linux tray).
  [
    `    {
      label: formatMessage({ id: "desktop.check-for-updates" }),
      click() {
        updater.check();
      }
    },
`,
    ``
  ],
  // Drop the "Check for updates" item from the macOS app menu.
  [
    `        {
          label: formatMessage({ id: "desktop.check-for-updates" }),
          click() {
            updater.check();
          }
        },
`,
    ``
  ],
  // Do not start the 30-minute polling timer / update listener.
  [
    `  {
    updater.start();
    updater.onUpdate((version) => {
      sendUpdateAvailable(window, version);
    });
  }
`,
    ``
  ],
  // No release-notes fetch from the update server on app start.
  [
    `    await loadAndSendReleaseNotes(window, language);
`,
    ``
  ],
  // Remove now-unused updater singleton in the tray-menu factory.
  [
    `const createContextMenu$1 = (window) => {
  const updater = getUpdater();
`,
    `const createContextMenu$1 = (window) => {
`
  ],
  // Remove now-unused updater singleton in the app-menu factory.
  [
    `};const createContextMenu = (window) => {
  const updater = getUpdater();
`,
    `};const createContextMenu = (window) => {
`
  ]
];

let data = readFileSync(target, "utf8");

for (const [from, to] of patches) {
  const count = data.split(from).length - 1;
  if (count !== 1) {
    console.error(`disable-updates: expected exactly 1 match, got ${count}`);
    console.error("--- anchor ---");
    console.error(JSON.stringify(from.slice(0, 300)));
    process.exit(1);
  }
  data = data.replace(from, to);
}

writeFileSync(target, data);
console.log("disable-updates: all patches applied");