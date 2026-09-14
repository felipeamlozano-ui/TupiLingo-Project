/**
 * TupiLingo — Persistent Chrome Dev Session for Antigravity Browser Tools.
 * Launches system Google Chrome with remote debugging on port 9222,
 * keeps the window open, and navigates to World Builder.
 */

const { chromium } = require('playwright');
const path = require('path');

(async () => {
  console.log('====================================================');
  console.log('Launching Google Chrome with Remote Debugging (9222)');
  console.log('====================================================');

  const userDataDir = path.join(__dirname, '.chrome_profile');

  // Launch persistent context with system Google Chrome
  const context = await chromium.launchPersistentContext(userDataDir, {
    channel: 'chrome',
    headless: false,
    viewport: { width: 1440, height: 900 },
    args: [
      '--remote-debugging-port=9222',
      '--remote-debugging-address=0.0.0.0',
      '--no-first-run',
      '--no-default-browser-check',
      '--disable-blink-features=AutomationControlled',
    ],
  });

  const page = context.pages().length > 0 ? context.pages()[0] : await context.newPage();

  console.log('Navigating to http://127.0.0.1:8080/#/admin/world-builder ...');
  await page.goto('http://127.0.0.1:8080/#/admin/world-builder', { waitUntil: 'domcontentloaded' });

  console.log('[OK] Google Chrome is now open and connected to http://127.0.0.1:8080/#/admin/world-builder');
  console.log('[OK] CDP Remote Debugging Port 9222 is active for IDE Browser tools / mirroring.');
  console.log('[*] Session is persistent. Do not close this terminal to keep the session alive.');

  // Keep process alive
  await new Promise(() => {});
})();
