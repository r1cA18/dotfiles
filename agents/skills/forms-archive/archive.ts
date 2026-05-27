#!/usr/bin/env bun
/**
 * Microsoft Forms 全ページ アーカイバ。
 *
 * Usage:
 *   bun archive.ts <forms-url> [outputDir]
 *   bun archive.ts --login <forms-url>
 *
 * Env:
 *   FORMS_STATE_PATH  storageState JSON (default: ~/.agent-browser/forms-state.json)
 *   HEADED            "1" to show browser during archive
 *   MAX_PAGES         safety cap (default: 30)
 *   FORMAT            csv of {pdf, mhtml, html} (default: pdf,mhtml)
 *   DEBUG_DOM         "1" dumps page 1 HTML and exits
 */

import { chromium, type Locator, type Page } from "playwright";
import { mkdir, writeFile, chmod } from "node:fs/promises";
import { existsSync } from "node:fs";
import { extname, dirname, join, resolve } from "node:path";
import { homedir } from "node:os";

const STATE_PATH =
  process.env.FORMS_STATE_PATH ?? join(homedir(), ".agent-browser", "forms-state.json");
const HEADED = process.env.HEADED === "1";

const MAX_PAGES_RAW = Number(process.env.MAX_PAGES ?? 30);
const MAX_PAGES = Number.isFinite(MAX_PAGES_RAW) && MAX_PAGES_RAW > 0 ? MAX_PAGES_RAW : 30;

const VALID_FORMATS = new Set(["pdf", "mhtml", "html"]);
const FORMATS = parseFormats(process.env.FORMAT ?? "pdf,mhtml");
const SAVE_PDF = FORMATS.has("pdf");
const SAVE_MHTML = FORMATS.has("mhtml");
const SAVE_HTML = FORMATS.has("html");

const args = process.argv.slice(2);
const loginMode = args[0] === "--login";
const url = loginMode ? args[1] : args[0];
const outputDir = resolve((loginMode ? args[2] : args[1]) ?? "./docs");

if (!url) {
  console.error("Usage:");
  console.error("  bun archive.ts <forms-url> [outputDir]");
  console.error("  bun archive.ts --login <forms-url>");
  process.exit(1);
}

if (!isAllowedFormsUrl(url)) {
  console.error(`URL must be on forms.office.com or forms.cloud.microsoft: ${url}`);
  process.exit(1);
}

if (loginMode) {
  await runLogin(url);
  process.exit(0);
}

if (!existsSync(STATE_PATH)) {
  console.error(`storageState not found: ${STATE_PATH}`);
  console.error(`Run login first: bun ${process.argv[1]} --login "<forms-url>"`);
  process.exit(2);
}

await runArchive(url);

// --- modes ---

async function runLogin(formsUrl: string): Promise<void> {
  await mkdir(dirname(STATE_PATH), { recursive: true, mode: 0o700 });
  const browser = await chromium.launch({ headless: false });
  try {
    const context = await browser.newContext({ viewport: { width: 1280, height: 1000 } });
    const page = await context.newPage();
    console.log(`Opening: ${formsUrl}`);
    await page.goto(formsUrl, { waitUntil: "domcontentloaded", timeout: 60_000 });
    console.log("Complete Microsoft login (incl. MFA). Session will be saved automatically.");

    await waitForLoggedInForm(page);

    await page.waitForTimeout(1500);
    await context.storageState({ path: STATE_PATH });
    await chmod(STATE_PATH, 0o600).catch(() => {});
    console.log(`Saved storageState to: ${STATE_PATH}`);
  } finally {
    await browser.close().catch(() => {});
  }
}

async function runArchive(formsUrl: string): Promise<void> {
  await mkdir(outputDir, { recursive: true });
  const pdfDir = join(outputDir, "PDF");
  const mhtmlDir = join(outputDir, "MHTML");
  const htmlDir = join(outputDir, "HTML");
  if (SAVE_PDF) await mkdir(pdfDir, { recursive: true });
  if (SAVE_MHTML) await mkdir(mhtmlDir, { recursive: true });
  if (SAVE_HTML) await mkdir(htmlDir, { recursive: true });

  const browser = await chromium.launch({ headless: !HEADED });
  try {
    const context = await browser.newContext({
      storageState: STATE_PATH,
      viewport: { width: 1280, height: 1800 },
    });
    const page = await context.newPage();

    console.log(`Opening: ${formsUrl}`);
    await page.goto(formsUrl, { waitUntil: "networkidle", timeout: 60_000 });
    await waitForFormReady(page);
    await settle(page);

    if (process.env.DEBUG_DOM === "1") {
      const dumpPath = resolve(outputDir, "_debug-page1.html");
      await writeFile(dumpPath, await page.content(), "utf8");
      console.log(`DOM dump saved: ${dumpPath}`);
      return;
    }

    for (let n = 1; n <= MAX_PAGES; n++) {
      await settle(page);

      if (SAVE_PDF) await savePDF(page, join(pdfDir, `${n}.pdf`));
      if (SAVE_MHTML) await saveMHTML(page, join(mhtmlDir, `${n}.mhtml`));
      if (SAVE_HTML) await saveSelfContainedHTML(page, join(htmlDir, `${n}.html`));

      await fillRequired(page);

      const next = page.locator('[data-automation-id="nextButton"]').first();
      const submit = page.locator('[data-automation-id="submitButton"]').first();
      const hasNext = await existsAndVisible(next);
      const hasSubmit = await existsAndVisible(submit);

      if (!hasNext && hasSubmit) {
        console.log("Final page reached. Not submitting.");
        break;
      }
      if (!hasNext) {
        console.log('No "next" button found. Stopping.');
        break;
      }

      const beforeSig = await pageSignature(page);
      await next.scrollIntoViewIfNeeded();
      await next.click();
      await page.waitForLoadState("networkidle", { timeout: 30_000 }).catch(() => {});
      await waitForFormReady(page);
      await settle(page);
      const afterSig = await pageSignature(page);
      if (beforeSig === afterSig) {
        console.error(`Page ${n} did not advance. Likely a required field this script can't fill.`);
        const dumpPath = resolve(outputDir, `_debug-stuck-page${n}.html`);
        await writeFile(dumpPath, await page.content(), "utf8");
        console.error(`DOM dump: ${dumpPath}`);
        break;
      }
    }

    console.log(`All pages saved to: ${outputDir}`);
  } finally {
    await browser.close().catch(() => {});
  }
}

// --- helpers ---

function parseFormats(raw: string): Set<string> {
  const out = new Set<string>();
  for (const token of raw.toLowerCase().split(/[,\s]+/).filter(Boolean)) {
    if (token === "both") {
      out.add("pdf");
      out.add("mhtml");
    } else if (VALID_FORMATS.has(token)) {
      out.add(token);
    } else {
      console.warn(`Unknown FORMAT token "${token}" — ignored. Valid: pdf,mhtml,html,both`);
    }
  }
  if (out.size === 0) {
    console.warn('FORMAT resolved to empty set — falling back to "pdf,mhtml"');
    out.add("pdf");
    out.add("mhtml");
  }
  return out;
}

function isAllowedFormsUrl(u: string): boolean {
  try {
    const host = new URL(u).host.toLowerCase();
    return host === "forms.office.com" || host.endsWith(".forms.office.com")
      || host === "forms.cloud.microsoft" || host.endsWith(".forms.cloud.microsoft");
  } catch {
    return false;
  }
}

async function settle(page: Page): Promise<void> {
  await page.waitForTimeout(800);
}

async function existsAndVisible(locator: Locator): Promise<boolean> {
  return (await locator.count()) > 0 && (await locator.isVisible());
}

async function waitForFormReady(page: Page): Promise<void> {
  // MS Forms is an SPA: networkidle returns before content paints.
  await page
    .locator('[data-automation-id="questionItem"], [data-automation-id="submitButton"]')
    .first()
    .waitFor({ state: "visible", timeout: 30_000 })
    .catch(() => {
      console.warn("waitForFormReady: form content did not appear in 30s");
    });
}

async function waitForLoggedInForm(page: Page): Promise<void> {
  const LOGIN_TIMEOUT_MS = 10 * 60 * 1000;
  const start = Date.now();
  let detectedOnce = false;
  while (Date.now() - start <= LOGIN_TIMEOUT_MS) {
    const host = safeHost(page.url());
    const onForms = host.endsWith("forms.office.com") || host.endsWith("forms.cloud.microsoft");
    if (onForms) {
      const ready = await page
        .locator('[data-automation-id="nextButton"], [data-automation-id="submitButton"]')
        .first()
        .isVisible()
        .catch(() => false);
      if (ready) {
        // require two consecutive detections to avoid catching a transient render
        if (detectedOnce) return;
        detectedOnce = true;
      } else {
        detectedOnce = false;
      }
    } else {
      detectedOnce = false;
    }
    await page.waitForTimeout(1500);
  }
  throw new Error("Login timeout (10 min).");
}

function safeHost(u: string): string {
  try {
    return new URL(u).host;
  } catch {
    return "";
  }
}

async function savePDF(page: Page, outPath: string): Promise<void> {
  const dim = await page.evaluate(() => ({
    w: Math.max(document.documentElement.scrollWidth, 1024),
    h: Math.max(document.documentElement.scrollHeight, 800),
  }));
  await page.pdf({
    path: outPath,
    printBackground: true,
    width: `${dim.w}px`,
    height: `${dim.h}px`,
    margin: { top: "0", right: "0", bottom: "0", left: "0" },
  });
  console.log(`Saved: ${outPath}`);
}

async function saveMHTML(page: Page, outPath: string): Promise<void> {
  const session = await page.context().newCDPSession(page);
  try {
    const { data } = (await session.send("Page.captureSnapshot", { format: "mhtml" })) as {
      data: string;
    };
    await writeFile(outPath, data, "utf8");
    console.log(`Saved: ${outPath}`);
  } finally {
    await session.detach().catch(() => {});
  }
}

/**
 * Best-effort self-contained HTML. MHTML is more accurate — prefer it.
 * Only inlines <img src> and <link rel=stylesheet>; does NOT handle srcset,
 * <picture>/<source>, background-image, @font-face, or CSS url() recursion.
 */
async function saveSelfContainedHTML(page: Page, outPath: string): Promise<void> {
  let html = await page.content();
  const baseUrl = page.url();
  const request = page.context().request;

  const imgSet = new Set(collectUrls(html, /<img\b[^>]*?\bsrc=["']([^"']+)["']/gi, baseUrl));
  const cssSet = new Set(
    collectUrls(
      html,
      /<link\b[^>]*?rel=["']stylesheet["'][^>]*?href=["']([^"']+)["']/gi,
      baseUrl
    )
  );

  const fetched = new Map<string, { dataUrl?: string; cssText?: string }>();
  await Promise.all(
    [...imgSet, ...cssSet].map(async (u) => {
      try {
        const res = await request.get(u);
        if (!res.ok()) return;
        if (cssSet.has(u)) {
          fetched.set(u, { cssText: await res.text() });
        } else {
          const body = await res.body();
          const mime = guessMime(u, res.headers()["content-type"]);
          if (!mime) return;
          fetched.set(u, { dataUrl: `data:${mime};base64,${body.toString("base64")}` });
        }
      } catch {
        /* leave original URL */
      }
    })
  );

  for (const u of imgSet) {
    const dataUrl = fetched.get(u)?.dataUrl;
    if (!dataUrl) continue;
    for (const p of urlPatterns(u)) {
      html = html.replace(
        new RegExp(`(<img\\b[^>]*?\\bsrc=["'])${escapeRe(p)}(["'])`, "gi"),
        `$1${dataUrl}$2`
      );
    }
  }

  for (const u of cssSet) {
    const cssText = fetched.get(u)?.cssText;
    if (!cssText) continue;
    const styleTag = `<style>${cssText.replace(/<\/style>/gi, "<\\/style>")}</style>`;
    for (const p of urlPatterns(u)) {
      html = html.replace(
        new RegExp(
          `<link\\b[^>]*?rel=["']stylesheet["'][^>]*?href=["']${escapeRe(p)}["'][^>]*?>`,
          "gi"
        ),
        styleTag
      );
    }
  }

  html = html.replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, "");
  html = html.replace(/<script\b[^>]*\/>/gi, "");

  await writeFile(outPath, html, "utf8");
  console.log(`Saved: ${outPath}`);
}

function collectUrls(html: string, re: RegExp, baseUrl: string): string[] {
  const out: string[] = [];
  for (const m of html.matchAll(re)) {
    const u = m[1];
    if (!u || u.startsWith("data:") || u.startsWith("blob:") || u.startsWith("javascript:")) continue;
    try {
      out.push(new URL(u, baseUrl).toString());
    } catch {
      /* skip */
    }
  }
  return out;
}

function urlPatterns(u: string): string[] {
  try {
    const parsed = new URL(u);
    const pathAndSearch = parsed.pathname + parsed.search;
    const hostless = u.replace(/^https?:\/\/[^/]+/, "");
    return [...new Set([u, pathAndSearch, hostless])];
  } catch {
    return [u];
  }
}

function guessMime(url: string, headerCt: string | undefined): string | null {
  if (headerCt) return headerCt.split(";")[0].trim();
  const ext = extname(new URL(url).pathname).toLowerCase();
  switch (ext) {
    case ".png": return "image/png";
    case ".jpg":
    case ".jpeg": return "image/jpeg";
    case ".gif": return "image/gif";
    case ".webp": return "image/webp";
    case ".svg": return "image/svg+xml";
    case ".ico": return "image/x-icon";
    default: return null;
  }
}

function escapeRe(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

async function pageSignature(page: Page): Promise<string> {
  return page
    .evaluate(() => {
      const items = document.querySelectorAll('[data-automation-id="questionItem"]');
      const parts = [`count:${items.length}`];
      for (const item of Array.from(items).slice(0, 3)) {
        const title = item.querySelector('[data-automation-id="questionTitle"]')?.textContent ?? "";
        parts.push(title.replace(/\s+/g, " ").trim().slice(0, 80));
      }
      return parts.join("|");
    })
    .catch(() => "");
}

/**
 * Auto-fill required fields just enough to advance to the next page.
 * Handles MS Forms `[data-automation-id]` radios and textInput (textarea/input).
 * Other controls (rating, dropdown, date) are NOT handled — extend as needed.
 */
async function fillRequired(page: Page): Promise<void> {
  const items = page.locator('[data-automation-id="questionItem"]');
  const n = await items.count();
  for (let i = 0; i < n; i++) {
    const item = items.nth(i);
    const required = (await item.locator('[data-automation-id="requiredStar"]').count()) > 0;
    if (!required) continue;

    const checkedRadio = await item.locator('[role="radio"][aria-checked="true"]').count();
    if (checkedRadio > 0) continue;

    const textbox = item.locator('[data-automation-id="textInput"]').first();
    const hasTextbox = (await textbox.count()) > 0;
    if (hasTextbox) {
      const val = await textbox.inputValue().catch(() => "");
      if (val) continue;
    }

    const firstRadio = item.locator('[role="radio"]').first();
    if ((await firstRadio.count()) > 0) {
      await firstRadio.click().catch(() => {});
      continue;
    }
    if (hasTextbox) {
      await textbox.fill("-").catch(() => {});
    }
  }
}
