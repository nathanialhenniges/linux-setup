#!/usr/bin/env node
'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const http = require('node:http');
const os = require('node:os');
const path = require('node:path');

const ROOT = path.resolve(__dirname, '..');
const DOCS = path.join(ROOT, 'docs');
const BASE_PATH = '/linux-setup/';
const SCREENSHOT_DIR = process.env.GUIDE_SCREENSHOT_DIR || path.join(os.tmpdir(), `linux-setup-guide-screenshots-${process.pid}`);
const EXPECTED_CHROME_PATHS = [
  process.env.CHROME_PATH,
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  '/usr/bin/google-chrome',
  '/usr/bin/chromium',
  '/usr/bin/chromium-browser',
].filter(Boolean);

function loadPlaywright() {
  try {
    return require('playwright');
  } catch (error) {
    throw new Error('Playwright is required. Run npm ci, then npm run test:guide.', { cause: error });
  }
}

function mimeType(filePath) {
  return ({
    '.css': 'text/css; charset=utf-8',
    '.html': 'text/html; charset=utf-8',
    '.png': 'image/png',
    '.svg': 'image/svg+xml',
  })[path.extname(filePath)] || 'application/octet-stream';
}

async function startServer() {
  const server = http.createServer((request, response) => {
    const pathname = new URL(request.url, 'http://127.0.0.1').pathname;
    if (pathname === '/linux-setup') {
      response.writeHead(308, { Location: BASE_PATH }).end();
      return;
    }

    if (!pathname.startsWith(BASE_PATH)) {
      response.writeHead(404).end('Not found');
      return;
    }

    const relativePath = decodeURIComponent(pathname.slice(BASE_PATH.length));
    const filePath = path.resolve(DOCS, relativePath || 'index.html');
    if (filePath !== DOCS && !filePath.startsWith(`${DOCS}${path.sep}`)) {
      response.writeHead(400).end('Bad path');
      return;
    }

    fs.readFile(filePath, (error, contents) => {
      if (error) {
        response.writeHead(404).end('Not found');
        return;
      }
      response.writeHead(200, {
        'Content-Type': mimeType(filePath),
        'Cache-Control': 'no-store',
        'X-Content-Type-Options': 'nosniff',
      }).end(contents);
    });
  });

  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', resolve);
  });
  const address = server.address();
  return {
    server,
    url: `http://127.0.0.1:${address.port}${BASE_PATH}`,
  };
}

function existingChromePath() {
  return EXPECTED_CHROME_PATHS.find((candidate) => fs.existsSync(candidate));
}

async function assertNoHorizontalOverflow(page, width) {
  const dimensions = await page.evaluate(() => ({
    viewport: document.documentElement.clientWidth,
    document: document.documentElement.scrollWidth,
    body: document.body.scrollWidth,
    main: (() => {
      const main = document.querySelector('main');
      const style = getComputedStyle(main);
      const rect = main.getBoundingClientRect();
      return {
        left: Math.round(rect.left), right: Math.round(rect.right), width: Math.round(rect.width),
        clientWidth: main.clientWidth, scrollWidth: main.scrollWidth,
        gridTemplateColumns: style.gridTemplateColumns,
        children: Array.from(main.children).map((child) => {
          const childRect = child.getBoundingClientRect();
          const childStyle = getComputedStyle(child);
          return {
            tag: child.tagName.toLowerCase(), id: child.id, left: Math.round(childRect.left),
            right: Math.round(childRect.right), width: Math.round(childRect.width),
            minWidth: childStyle.minWidth, maxWidth: childStyle.maxWidth,
            gridColumn: childStyle.gridColumn,
          };
        }),
      };
    })(),
    overflowing: Array.from(document.querySelectorAll('body *')).flatMap((element) => {
      const rect = element.getBoundingClientRect();
      if (rect.right <= document.documentElement.clientWidth + 1) return [];
      let clipped = false;
      for (let ancestor = element.parentElement; ancestor && ancestor !== document.documentElement; ancestor = ancestor.parentElement) {
        const style = getComputedStyle(ancestor);
        const ancestorRect = ancestor.getBoundingClientRect();
        if (['auto', 'hidden', 'clip', 'scroll'].includes(style.overflowX) && ancestorRect.right < rect.right - 1) {
          clipped = true;
          break;
        }
      }
      return clipped ? [] : [{
        tag: element.tagName.toLowerCase(),
        id: element.id,
        className: typeof element.className === 'string' ? element.className : '',
        left: Math.round(rect.left),
        right: Math.round(rect.right),
        scrollWidth: element.scrollWidth,
        clientWidth: element.clientWidth,
        text: (element.innerText || '').trim().slice(0, 60),
      }];
    }).sort((left, right) => right.right - left.right).slice(0, 5),
  }));
  assert.ok(
    dimensions.document <= dimensions.viewport && dimensions.body <= dimensions.viewport,
    `${width}px viewport overflows horizontally: ${JSON.stringify(dimensions)}`,
  );
}

async function readCheckedIds(page) {
  return page.locator('[data-check]:checked').evaluateAll((boxes) => boxes.map((box) => box.id));
}

async function exportAndRead(page, keyboard = false) {
  const downloadPromise = page.waitForEvent('download');
  if (keyboard) {
    await page.locator('#export-progress').focus();
    await page.keyboard.press('Enter');
  } else {
    await page.locator('#export-progress').click();
  }
  const download = await downloadPromise;
  assert.equal(download.suggestedFilename(), 'macbook-air-progress.json');
  const downloadedPath = await download.path();
  assert.ok(downloadedPath, 'Export should produce a downloadable file');
  return JSON.parse(fs.readFileSync(downloadedPath, 'utf8'));
}

async function importPayload(page, payload, filename = 'macbook-air-progress.json') {
  const dialogSeen = new Promise((resolve) => page.once('dialog', async (dialog) => {
    const message = dialog.message();
    await dialog.accept();
    resolve(message);
  }));
  const fileChooserPromise = page.waitForEvent('filechooser');
  await page.locator('#import-progress').focus();
  await page.keyboard.press('Enter');
  const fileChooser = await fileChooserPromise;
  await fileChooser.setFiles({
    name: filename,
    mimeType: 'application/json',
    buffer: Buffer.from(typeof payload === 'string' ? payload : JSON.stringify(payload)),
  });
  return dialogSeen;
}

async function run() {
  const { chromium } = loadPlaywright();
  const { server, url } = await startServer();
  let browser;
  const failures = [];
  const pageErrors = [];
  const checks = [];
  fs.mkdirSync(SCREENSHOT_DIR, { recursive: true });

  const browserOptions = { headless: true };
  const executablePath = existingChromePath();
  if (executablePath) browserOptions.executablePath = executablePath;

  try {
    browser = await chromium.launch(browserOptions);
    const context = await browser.newContext({
      acceptDownloads: true,
      viewport: { width: 1440, height: 1000 },
    });
    const page = await context.newPage();
    page.on('pageerror', (error) => pageErrors.push(error.message));
    await context.grantPermissions(['clipboard-read', 'clipboard-write'], { origin: url.slice(0, url.indexOf(BASE_PATH)) });
    await page.goto(url, { waitUntil: 'networkidle' });

    await page.locator('#focused-actions').evaluate((element) => { element.open = false; });
    assert.equal(await page.locator('#focused-actions').evaluate((element) => element.open), false);
    await page.screenshot({ path: path.join(SCREENSHOT_DIR, 'guide-desktop-viewport.png') });
    await page.screenshot({ path: path.join(SCREENSHOT_DIR, 'guide-desktop.png'), fullPage: true });
    await page.locator('#setup').screenshot({ path: path.join(SCREENSHOT_DIR, 'guide-setup-section.png') });
    await assertNoHorizontalOverflow(page, 1440);
    checks.push('desktop layout and full-page screenshot');

    assert.equal(await page.title(), 'MrDemonWolf, Inc. | MacBook Air Linux Guide');
    assert.equal(await page.locator('h1').count(), 1, 'Page should have exactly one h1');
    assert.equal(await page.locator('#continue-setup').getAttribute('href'), '#ready');
    assert.ok(await page.locator('#export-progress').isVisible());
    assert.ok(await page.locator('#import-progress').isVisible());
    checks.push('page title, primary heading, and progress transfer controls');

    const semanticAudit = await page.evaluate(() => {
      const headings = Array.from(document.querySelectorAll('h1,h2,h3,h4,h5,h6'))
        .map((heading) => Number(heading.tagName.slice(1)));
      const missingAlt = Array.from(document.images)
        .filter((image) => !image.hasAttribute('alt'))
        .map((image) => image.src);
      const unlabeledChecks = Array.from(document.querySelectorAll('input[type="checkbox"]'))
        .filter((input) => input.labels.length === 0)
        .map((input) => input.id);
      const unlinkedCopy = Array.from(document.querySelectorAll('[data-copy]'))
        .filter((button) => !document.getElementById(button.dataset.copy))
        .map((button) => button.dataset.copy);
      const unnamedButtons = Array.from(document.querySelectorAll('button'))
        .filter((button) => !button.textContent.trim() && !button.getAttribute('aria-label'))
        .map((button) => button.id);
      const unnamedLinks = Array.from(document.querySelectorAll('a'))
        .filter((link) => !link.textContent.trim() && !Array.from(link.images).some((image) => image.alt.trim()))
        .map((link) => link.href);
      const skippedHeadingLevels = [];
      for (let index = 1; index < headings.length; index += 1) {
        if (headings[index] > headings[index - 1] + 1) skippedHeadingLevels.push(`${headings[index - 1]} to ${headings[index]}`);
      }
      return { headings, missingAlt, unlabeledChecks, unlinkedCopy, unnamedButtons, unnamedLinks, skippedHeadingLevels };
    });
    assert.deepEqual(semanticAudit.missingAlt, [], 'Images should declare alt text, including decorative empty alt');
    assert.deepEqual(semanticAudit.unlabeledChecks, [], 'Every checklist control should have an associated label');
    assert.deepEqual(semanticAudit.unlinkedCopy, [], 'Every copy control should point to a command block');
    assert.deepEqual(semanticAudit.unnamedButtons, [], 'Every button should have a name');
    assert.deepEqual(semanticAudit.unnamedLinks, [], 'Every link should have a name');
    assert.deepEqual(semanticAudit.skippedHeadingLevels, [], 'Heading levels should not skip a level');
    checks.push('heading order, labels, image alt attributes, and control names');

    await page.keyboard.press('Tab');
    assert.equal(await page.evaluate(() => document.activeElement.className), 'skip-link', 'First keyboard stop should be Skip to the guide');
    const skipLinkTop = await page.locator('.skip-link').evaluate((element) => Number.parseFloat(getComputedStyle(element).top));
    assert.ok(skipLinkTop >= 0, `Skip link should become visible on focus (top=${skipLinkTop}px)`);
    await page.keyboard.press('Enter');
    assert.equal(new URL(page.url()).hash, '#guide');

    const firstCheckbox = page.locator('[data-check]').first();
    await firstCheckbox.press('Space');
    assert.equal(await firstCheckbox.isChecked(), true, 'Space should toggle a focused checkbox');
    const focusStyle = await firstCheckbox.evaluate((element) => ({
      outline: getComputedStyle(element).outlineStyle,
      width: getComputedStyle(element).outlineWidth,
    }));
    assert.equal(focusStyle.outline, 'solid', 'Keyboard focus should have a visible outline');
    assert.equal(focusStyle.width, '3px');
    const checkboxCount = await page.locator('[data-check]').count();
    assert.match(await page.locator('#progress-text').textContent(), new RegExp(`1 of ${checkboxCount} steps checked`));
    assert.equal(await page.locator('[role="progressbar"]').getAttribute('aria-valuenow'), String(Math.round(100 / checkboxCount)));
    const saved = await page.evaluate(() => JSON.parse(localStorage.getItem('mba-reinstall-checklist-v1')));
    assert.deepEqual(saved, [await firstCheckbox.getAttribute('id')]);
    await page.reload({ waitUntil: 'networkidle' });
    assert.equal(await page.locator('[data-check]:checked').count(), 1, 'A reload should restore saved progress');
    checks.push('skip link, keyboard checkbox toggle, visible focus, progress feedback and persistence');

    const readyChecks = page.locator('#ready [data-check]');
    for (let index = 0; index < await readyChecks.count(); index += 1) await readyChecks.nth(index).check();
    assert.equal(await page.locator('#continue-setup').getAttribute('href'), '#internet', 'Continue should jump to the first incomplete section');

    const readyIds = await readCheckedIds(page);
    const exported = await exportAndRead(page, true);
    assert.equal(exported.version, 1);
    assert.deepEqual(exported.checked, readyIds);
    assert.match(await page.locator('#progress-status').textContent(), /Progress file saved/i);
    checks.push('progress export download and schema');

    for (let index = 0; index < await page.locator('[data-check]').count(); index += 1) {
      await page.locator('[data-check]').nth(index).check();
    }
    assert.equal(await page.locator('[role="progressbar"]').getAttribute('aria-valuenow'), '100');
    assert.equal(await page.locator('#continue-setup').getAttribute('href'), '#first-login', 'Completed checklist should continue to first login');

    const resetDialog = new Promise((resolve) => page.once('dialog', async (dialog) => {
      assert.match(dialog.message(), /Clear the saved checkboxes/);
      await dialog.accept();
      resolve();
    }));
    await page.locator('#reset-progress').focus();
    await page.keyboard.press('Space');
    await resetDialog;
    assert.equal(await page.locator('[data-check]:checked').count(), 0);
    assert.equal(await page.evaluate(() => localStorage.getItem('mba-reinstall-checklist-v1')), '[]');

    const importedIds = ['erase-ok', 'charger'];
    const importDialogMessage = await importPayload(page, { version: 1, checked: importedIds });
    assert.match(importDialogMessage, /Replace this browser/);
    assert.deepEqual(await readCheckedIds(page), importedIds, 'Valid import should replace the current progress');
    assert.match(await page.locator('#progress-status').textContent(), /Progress loaded/i);
    assert.equal(await page.locator('#continue-setup').getAttribute('href'), '#ready');

    await page.locator('#progress-file').setInputFiles({
      name: 'invalid-progress.json',
      mimeType: 'application/json',
      buffer: Buffer.from(JSON.stringify({ version: 2, checked: ['erase-disk'] })),
    });
    assert.deepEqual(await readCheckedIds(page), importedIds, 'Invalid import must preserve current progress');
    assert.match(await page.locator('#progress-status').textContent(), /Could not load this file/i);

    const beforeCancelledImport = await readCheckedIds(page);
    const cancelImportDialog = new Promise((resolve) => page.once('dialog', async (dialog) => {
      await dialog.dismiss();
      resolve();
    }));
    await page.locator('#progress-file').setInputFiles({
      name: 'cancelled-progress.json',
      mimeType: 'application/json',
      buffer: Buffer.from(JSON.stringify({ version: 1, checked: ['erase-disk'] })),
    });
    await cancelImportDialog;
    assert.deepEqual(await readCheckedIds(page), beforeCancelledImport, 'Cancelling import confirmation must preserve progress');

    await page.locator('#progress-file').setInputFiles({
      name: 'oversized-progress.json',
      mimeType: 'application/json',
      buffer: Buffer.alloc(65537, ' '),
    });
    assert.deepEqual(await readCheckedIds(page), beforeCancelledImport, 'Oversized import must preserve progress');
    assert.match(await page.locator('#progress-status').textContent(), /Could not load this file/i);

    const exportedAgain = await exportAndRead(page);
    assert.deepEqual(exportedAgain.checked, importedIds, 'Import/export round-trip should preserve checked IDs');
    checks.push('continue-to-next, reset confirmation, validated import, invalid-file recovery, and import/export round-trip');

    const focusedActions = page.locator('#focused-actions');
    await focusedActions.evaluate((element) => { element.open = true; });
    const appList = await focusedActions.innerText();
    assert.match(appList, /Dock\s+— Files, Chrome, 1Password/i, 'Optional app list should visibly name 1Password in the dock');
    assert.match(appList, /App grid\s+— Plex, Upscayl, and LibrePods/i, 'Optional app list should distinguish apps in the app grid');
    await focusedActions.screenshot({ path: path.join(SCREENSHOT_DIR, 'guide-focused-actions.png') });
    const copyButtons = page.locator('[data-copy]');
    const copyCount = await copyButtons.count();
    for (let index = 0; index < copyCount; index += 1) {
      const button = copyButtons.nth(index);
      const commandId = await button.getAttribute('data-copy');
      const command = await page.locator(`#${commandId}`).textContent();
      assert.ok(command && command.trim(), `Command block ${commandId} should not be empty`);
      if (index === 0) {
        await button.focus();
        await page.keyboard.press('Enter');
      } else {
        await button.click();
      }
      assert.equal(await page.evaluate(() => navigator.clipboard.readText()), command, `Copy control ${commandId} should copy its command`);
    }
    assert.equal(copyCount, await page.locator('[data-copy]').evaluateAll((buttons) => new Set(buttons.map((button) => button.dataset.copy)).size), 'Copy targets should be unique');
    checks.push(`${copyCount} copy controls write their matching command to the clipboard`);

    for (const width of [320, 375, 390, 768, 1280]) {
      await page.setViewportSize({ width, height: width < 500 ? 844 : 900 });
      await assertNoHorizontalOverflow(page, width);
    }
    checks.push('no horizontal page overflow at 320, 375, 390, 768, or 1280 CSS pixels');

    await page.setViewportSize({ width: 390, height: 844 });
    const mobileTargets = await page.locator('button:visible, a:visible, input[type="checkbox"]:visible').evaluateAll((elements) => elements.map((element) => {
      const rect = element.getBoundingClientRect();
      return { name: element.innerText.trim().slice(0, 50), width: Math.round(rect.width), height: Math.round(rect.height) };
    }).filter((target) => target.width < 24 || target.height < 24));
    assert.deepEqual(mobileTargets, [], 'Visible mobile buttons, links, and checkboxes should meet WCAG 2.2 minimum target size');
    checks.push('mobile visible link/button/checkbox minimum target dimensions');

    await page.locator('#focused-actions').evaluate((element) => { element.open = false; });
    await page.evaluate(async () => {
      document.documentElement.style.scrollBehavior = 'auto';
      history.replaceState(null, '', window.location.pathname + window.location.search);
      window.scrollTo({ top: 0, left: 0, behavior: 'instant' });
      document.documentElement.scrollTop = 0;
      document.body.scrollTop = 0;
      await new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve)));
    });
    assert.equal(await page.evaluate(() => window.scrollY), 0, 'Mobile hero screenshot should start at the top of the page');
    await page.screenshot({ path: path.join(SCREENSHOT_DIR, 'guide-mobile-viewport.png') });
    await page.screenshot({ path: path.join(SCREENSHOT_DIR, 'guide-mobile.png'), fullPage: true });
    checks.push('top-of-page mobile hero screenshot');

    const fallbackContext = await browser.newContext({ viewport: { width: 1280, height: 900 } });
    await fallbackContext.addInitScript(() => {
      Object.defineProperty(navigator, 'clipboard', {
        configurable: true,
        value: { writeText: () => Promise.reject(new Error('clipboard permission denied')) },
      });
    });
    const fallbackPage = await fallbackContext.newPage();
    const fallbackPageErrors = [];
    fallbackPage.on('pageerror', (error) => fallbackPageErrors.push(error.message));
    await fallbackPage.goto(url, { waitUntil: 'networkidle' });
    const fallbackCommand = await fallbackPage.locator('#cmd-all').textContent();
    await fallbackPage.locator('[data-copy="cmd-all"]').click();
    assert.equal(await fallbackPage.evaluate(() => window.getSelection().toString()), fallbackCommand);
    assert.match(await fallbackPage.locator('#copy-status').textContent(), /Command selected/i);
    assert.deepEqual(fallbackPageErrors, [], 'Clipboard fallback should not throw browser errors');
    await fallbackContext.close();
    checks.push('copy fallback selects the command when clipboard write is denied');

    const storageContext = await browser.newContext({ viewport: { width: 1280, height: 900 } });
    await storageContext.addInitScript(() => {
      Object.defineProperty(window, 'localStorage', {
        configurable: true,
        value: {
          getItem: () => { throw new DOMException('Storage blocked', 'SecurityError'); },
          setItem: () => { throw new DOMException('Storage blocked', 'SecurityError'); },
          removeItem: () => { throw new DOMException('Storage blocked', 'SecurityError'); },
        },
      });
    });
    const storagePage = await storageContext.newPage();
    const storagePageErrors = [];
    storagePage.on('pageerror', (error) => storagePageErrors.push(error.message));
    await storagePage.goto(url, { waitUntil: 'networkidle' });
    await storagePage.locator('[data-check]').first().check();
    assert.match(await storagePage.locator('#progress-text').textContent(), /^1 of \d+ steps checked$/);
    await storagePage.reload({ waitUntil: 'networkidle' });
    assert.equal(await storagePage.locator('[data-check]:checked').count(), 0, 'Blocked storage should not prevent the guide from loading, but persistence is unavailable');
    await exportAndRead(storagePage);
    assert.deepEqual(storagePageErrors, [], 'Blocked local storage should not throw browser errors');
    await storageContext.close();
    checks.push('guide remains usable and exportable when browser local storage is blocked');

    assert.deepEqual(pageErrors, [], `Browser should not throw uncaught errors: ${pageErrors.join('; ')}`);
    console.log(JSON.stringify({
      result: 'PASS',
      checks,
      viewportWidths: [320, 375, 390, 768, 1280, 1440],
      checklistItems: checkboxCount,
      copyButtons: copyCount,
      screenshots: [
        path.join(SCREENSHOT_DIR, 'guide-desktop-viewport.png'),
        path.join(SCREENSHOT_DIR, 'guide-desktop.png'),
        path.join(SCREENSHOT_DIR, 'guide-setup-section.png'),
        path.join(SCREENSHOT_DIR, 'guide-focused-actions.png'),
        path.join(SCREENSHOT_DIR, 'guide-mobile-viewport.png'),
        path.join(SCREENSHOT_DIR, 'guide-mobile.png'),
      ],
    }, null, 2));
    await context.close();
  } finally {
    if (browser) await browser.close();
    await new Promise((resolve) => server.close(resolve));
  }
}

run().catch((error) => {
  console.error(error.stack || error);
  process.exitCode = 1;
});
