import { createHash } from 'node:crypto';
import process from 'node:process';

import {
  buildManifest,
  buildSnapshotMeta,
  createAlertPayload,
  DATABASE_URL,
  DEFAULT_CDP_URL,
  DEFAULT_CHROME_USER_DATA_DIR,
  DEFAULT_METRICS_AVAILABLE,
  DEFAULT_OUTPUT_PATH,
  ensureOutputDirectory,
  EXIT_CODE_FAILURE,
  EXIT_CODE_LOGIN,
  getLastGoodSnapshotAt,
  normalizeNumber,
  readJsonIfExists,
  SCHEMA_VERSION,
  sendAlert,
  validateSnapshot,
  writeJson,
  computeFileSha256,
} from './xhh-collector-common.mjs';

const LIST_ROUTE = '/game/slaythespire/v2/card/list';
const DETAIL_ROUTE = '/game/slaythespire/v2/card/detail';
const PAGE_SIZE = 100;
const exposedMd5Pages = new WeakSet();

class CollectorError extends Error {
  constructor(message, { exitCode = EXIT_CODE_FAILURE, status = 'network-error', stage = 'full-sync', help = null, cause } = {}) {
    super(message, { cause });
    this.name = 'CollectorError';
    this.exitCode = exitCode;
    this.status = status;
    this.stage = stage;
    this.help = help;
  }
}

function createDefaultOptions() {
  return {
    cdpUrl: DEFAULT_CDP_URL,
    chromeUserDataDir: DEFAULT_CHROME_USER_DATA_DIR,
    outputPath: DEFAULT_OUTPUT_PATH,
    withDetails: true,
    categories: null,
    detailLimit: null,
    keepaliveOnly: false,
    alertWebhook: null,
    help: false,
  };
}

async function loadPlaywright() {
  try {
    return await import('playwright');
  } catch (error) {
    throw new CollectorError('Missing playwright dependency. Install it first: npm install -D playwright', {
      status: 'config-error',
      stage: 'probe',
      cause: error,
    });
  }
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function parseArgs(argv, seedOptions = createDefaultOptions()) {
  const options = { ...seedOptions };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];

    if (arg === '--help' || arg === '-h') {
      options.help = true;
      continue;
    }

    if ((arg === '--mode' || arg === '--browser-mode') && argv[index + 1]) {
      const mode = argv[index + 1].trim().toLowerCase();
      index += 1;
      if (mode !== 'cdp') {
        throw new CollectorError('Persistent Playwright browser mode is disabled. Use a real Chrome/Edge session and attach over CDP instead.', {
          status: 'config-error',
          stage: 'probe',
        });
      }
      continue;
    }

    if (arg === '--cdp-url' && argv[index + 1]) {
      options.cdpUrl = argv[index + 1].trim();
      index += 1;
      continue;
    }

    if (arg === '--chrome-user-data-dir' && argv[index + 1]) {
      options.chromeUserDataDir = argv[index + 1].trim();
      index += 1;
      continue;
    }

    if (arg === '--output' && argv[index + 1]) {
      options.outputPath = argv[index + 1].trim();
      index += 1;
      continue;
    }

    if (arg === '--category' && argv[index + 1]) {
      options.categories = argv[index + 1]
        .split(',')
        .map((value) => value.trim())
        .filter(Boolean);
      index += 1;
      continue;
    }

    if (arg === '--detail-limit' && argv[index + 1]) {
      const parsed = Number.parseInt(argv[index + 1], 10);
      options.detailLimit = Number.isInteger(parsed) && parsed > 0 ? parsed : null;
      index += 1;
      continue;
    }

    if (arg === '--alert-webhook' && argv[index + 1]) {
      options.alertWebhook = argv[index + 1].trim();
      index += 1;
      continue;
    }

    if (arg === '--no-details') {
      options.withDetails = false;
      continue;
    }

    if (arg === '--keepalive-only') {
      options.keepaliveOnly = true;
      continue;
    }

    throw new CollectorError(`Unknown argument: ${arg}`, {
      status: 'config-error',
      stage: 'probe',
      help: 'Run `node tools/xhh-sts2-sync.mjs --help` to see supported flags.',
    });
  }

  return options;
}

function printUsage() {
  console.log(`XHH STS2 collector\n\nUsage:\n  node tools/xhh-sts2-sync.mjs [options]\n\nOptions:\n  --cdp-url <url>                 CDP endpoint for a real Chrome/Edge session\n  --chrome-user-data-dir <path>   Dedicated Chrome profile path used by the collector\n  --output <file>                 Output snapshot path (manifest.json is written beside it)\n  --category <csv>                Optional category allow-list, for example ironclad,silent\n  --no-details                    Export card list stats only\n  --detail-limit <n>              Only fetch the first N detail records\n  --keepalive-only                Probe card/list only and refresh manifest status\n  --alert-webhook <url>           Send JSON alerts on login/relogin/failure\n  --help                          Show this message\n\nWindows bootstrap:\n  powershell -ExecutionPolicy Bypass -File tools/start-xhh-chrome.ps1\n`);
}

function buildRuntimeMetadata(options) {
  return {
    transport: 'real-chrome-cdp',
    cdpUrl: options.cdpUrl,
    chromeUserDataDir: options.chromeUserDataDir,
    withDetails: options.withDetails,
    keepaliveOnly: options.keepaliveOnly,
    detailLimit: options.detailLimit ?? null,
  };
}

function printStartup(options, paths) {
  console.log('Collector mode: CDP attach to a real browser');
  console.log(`CDP target: ${options.cdpUrl}`);
  console.log(`Chrome user data dir: ${options.chromeUserDataDir}`);
  console.log(`Snapshot path: ${paths.snapshotPath}`);
  console.log(`Manifest path: ${paths.manifestPath}`);
}

async function connectToBrowser(chromium, cdpUrl, chromeUserDataDir) {
  try {
    const browser = await chromium.connectOverCDP(cdpUrl);
    const context = browser.contexts()[0];

    if (!context) {
      throw new Error('No browser context was exposed over CDP.');
    }

    return {
      context,
      close: async () => {
        await browser.close();
      },
    };
  } catch (error) {
    throw new CollectorError(
      `Failed to attach to Chrome at ${cdpUrl}. Start a real Chrome/Edge instance first with --remote-debugging-port and a dedicated --user-data-dir.`,
      {
        status: 'network-error',
        stage: 'probe',
        help: `Expected user data dir: ${chromeUserDataDir}`,
        cause: error,
      },
    );
  }
}

async function getCollectorPage(context) {
  const existingPages = context.pages();
  const preferredPage = existingPages.find((page) => page.url().includes('xiaoheihe.cn'));
  if (preferredPage) {
    return preferredPage;
  }

  return context.newPage();
}

async function waitForClientReady(page) {
  await page.goto(DATABASE_URL, { waitUntil: 'domcontentloaded' });
  await page.waitForFunction(
    () => document.readyState === 'interactive' || document.readyState === 'complete',
    { timeout: 30_000 },
  );
  await ensureFetchHelper(page);
}

async function ensureFetchHelper(page) {
  if (!exposedMd5Pages.has(page)) {
    await page.exposeFunction('__xhhMd5', async (text) => createHash('md5').update(text).digest('hex'));
    exposedMd5Pages.add(page);
  }

  await page.evaluate(async () => {
    if (window.__xhhSts2SyncHelper) {
      return;
    }

    const ALPHABET = 'AB45STUVWZEFGJ6CH01D237IXYPQRKLMN89';
    const API_BASE = 'https://api.xiaoheihe.cn';

    const x1 = (value) => ((value & 128) ? (((value << 1) ^ 27) & 255) : (value << 1));
    const x2 = (value) => x1(value) ^ value;
    const x3 = (value) => x2(x1(value));
    const x4 = (value) => x3(x2(x1(value)));
    const xe = (value) => x4(value) ^ x3(value) ^ x2(value);

    const xx = (input) => {
      const bytes = [...input];
      const result = [0, 0, 0, 0];
      result[0] = xe(bytes[0]) ^ x4(bytes[1]) ^ x3(bytes[2]) ^ x2(bytes[3]);
      result[1] = x2(bytes[0]) ^ xe(bytes[1]) ^ x4(bytes[2]) ^ x3(bytes[3]);
      result[2] = x3(bytes[0]) ^ x2(bytes[1]) ^ xe(bytes[2]) ^ x4(bytes[3]);
      result[3] = x4(bytes[0]) ^ x3(bytes[1]) ^ x2(bytes[2]) ^ xe(bytes[3]);
      bytes[0] = result[0];
      bytes[1] = result[1];
      bytes[2] = result[2];
      bytes[3] = result[3];
      return bytes;
    };

    const xt6 = (text, alphabet, endIndex) => {
      const sub = alphabet.slice(0, endIndex);
      let output = '';
      for (const char of text) {
        output += sub[char.charCodeAt(0) % sub.length];
      }
      return output;
    };

    const xt4 = (text, alphabet) => {
      let output = '';
      for (const char of text) {
        output += alphabet[char.charCodeAt(0) % alphabet.length];
      }
      return output;
    };

    const combineStrings = (parts) => {
      const maxLength = Math.max(...parts.map((part) => part.length));
      let output = '';
      for (let index = 0; index < maxLength; index += 1) {
        for (const part of parts) {
          if (index < part.length) {
            output += part[index];
          }
        }
      }
      return output;
    };

    const gencode = async (rawPath, timestamp, nonce) => {
      const normalizedPath = `/${rawPath.split('/').filter(Boolean).join('/')}/`;
      const mixed = combineStrings([
        xt6(String(timestamp), ALPHABET, -2),
        xt4(normalizedPath, ALPHABET),
        xt4(nonce, ALPHABET),
      ]).slice(0, 20);

      const digest = await window.__xhhMd5(mixed);
      const checksum = String(
        xx(digest.slice(-6).split('').map((char) => char.charCodeAt(0)))
          .reduce((sum, value) => sum + value, 0) % 100,
      ).padStart(2, '0');

      return `${xt6(digest.slice(0, 5), ALPHABET, -4)}${checksum}`;
    };

    const makeUrl = async (route, extraParams) => {
      const timestamp = Math.floor(Date.now() / 1000);
      const nonce = (await window.__xhhMd5(
        `${timestamp}${Date.now()}${Math.random()}${navigator.userAgent}${location.host}`,
      )).toUpperCase();
      const hkey = await gencode(route, timestamp + 1, nonce);

      const params = new URLSearchParams({
        app: 'heybox',
        heybox_id: '',
        os_type: 'web',
        x_app: 'heybox',
        x_client_type: 'weboutapp',
        x_os_type: 'Windows',
        x_client_version: '',
        version: '999.0.4',
        hkey,
        _time: String(timestamp),
        nonce,
        ...extraParams,
      });

      return `${API_BASE}${route}?${params.toString()}`;
    };

    window.__xhhSts2SyncHelper = {
      apiGet: async (route, params) => {
        const response = await fetch(await makeUrl(route, params), {
          credentials: 'include',
        });

        const text = await response.text();
        return JSON.parse(text);
      },
    };
  });
}

async function apiGet(page, route, params) {
  await ensureFetchHelper(page);
  return page.evaluate(
    async ({ routeValue, paramsValue }) => window.__xhhSts2SyncHelper.apiGet(routeValue, paramsValue),
    {
      routeValue: route,
      paramsValue: params,
    },
  );
}

function isLoginStatus(status) {
  return status === 'login' || status === 'relogin';
}

function assertOkPayload(payload, { stage, label }) {
  const status = payload?.status ?? 'unknown';
  if (status === 'ok') {
    return;
  }

  throw new CollectorError(`${label} returned status ${status}.`, {
    exitCode: isLoginStatus(status) ? EXIT_CODE_LOGIN : EXIT_CODE_FAILURE,
    status: isLoginStatus(status) ? status : 'api-error',
    stage,
  });
}

function buildProbeParams() {
  return {
    offset: 0,
    limit: 1,
    q: '',
    card_category: 'ironclad',
    card_type: '',
    card_rarity: '',
    sort_by: 'win_rate',
    sort_order: 1,
  };
}

async function runProbe(page) {
  await waitForClientReady(page);
  const probe = await apiGet(page, LIST_ROUTE, buildProbeParams());
  assertOkPayload(probe, {
    stage: 'probe',
    label: 'card/list probe',
  });
  return probe;
}

function getCategoryValues(probe, forcedCategories) {
  if (forcedCategories?.length) {
    return forcedCategories;
  }

  const categoryFilter = probe.result?.filter_list?.find((item) => item.key === 'card_category');
  const values = (categoryFilter?.filter_items ?? [])
    .map((item) => item.value)
    .filter(Boolean);

  if (values.length === 0) {
    throw new CollectorError('No card categories were returned by card/list.', {
      status: 'schema-error',
      stage: 'full-sync',
    });
  }

  return values;
}

async function fetchCategoryCardStats(page, category) {
  const items = [];
  let offset = 0;

  while (true) {
    const payload = await apiGet(page, LIST_ROUTE, {
      offset,
      limit: PAGE_SIZE,
      q: '',
      card_category: category,
      card_type: '',
      card_rarity: '',
      sort_by: 'win_rate',
      sort_order: 1,
    });

    assertOkPayload(payload, {
      stage: 'full-sync',
      label: `card/list for category ${category}`,
    });

    const batch = payload.result?.card_stat_list ?? [];
    items.push(...batch);

    if (batch.length < PAGE_SIZE) {
      break;
    }

    offset += batch.length;
    await sleep(150);
  }

  return items;
}

async function fetchCardDetail(page, cardId) {
  const payload = await apiGet(page, DETAIL_ROUTE, { card_id: cardId });
  assertOkPayload(payload, {
    stage: 'full-sync',
    label: `card/detail for ${cardId}`,
  });
  return payload.result;
}

function dedupeStatsByCardId(items) {
  const deduped = new Map();
  for (const item of items) {
    if (!deduped.has(item.card_id)) {
      deduped.set(item.card_id, item);
    }
  }
  return [...deduped.values()];
}

function mergeCardData(stat, detail) {
  const cardInfo = detail?.card_info ?? {};
  const cardStat = detail?.card_stat ?? stat ?? {};
  const matchList = detail?.card_match_info_list ?? [];

  return {
    id: cardInfo.id ?? cardStat.card_id ?? stat.card_id,
    name: cardInfo.name ?? cardStat.card_name ?? stat.card_name,
    category: cardInfo.category ?? stat.__category ?? null,
    type: cardInfo.card_type ?? null,
    rarity: cardInfo.card_rarity ?? null,
    cost: cardInfo.cost ?? null,
    magic: cardInfo.magic ?? null,
    exhaust: cardInfo.exhaust ?? false,
    retain: cardInfo.retain ?? false,
    innate: cardInfo.innate ?? false,
    ethereal: cardInfo.is_ethereal ?? false,
    upgraded: cardInfo.is_upgraded ?? false,
    iconUrl: cardInfo.cdn_url ?? cardStat.card_icon ?? stat.card_icon ?? null,
    description: cardInfo.desc ?? null,
    upgradeInfo: cardInfo.upgrade_info ?? null,
    stats: {
      timesWon: normalizeNumber(cardStat.times_won),
      timesLost: normalizeNumber(cardStat.times_lost),
      timesPicked: normalizeNumber(cardStat.times_picked),
      timesSkipped: normalizeNumber(cardStat.times_skipped),
      winRate: normalizeNumber(cardStat.win_rate),
      pickRate: normalizeNumber(cardStat.pick_rate),
      skipRate: normalizeNumber(cardStat.skip_rate),
      winRateRank: normalizeNumber(cardStat.win_rate_rank),
      pickRateRank: normalizeNumber(cardStat.pick_rate_rank),
      upgradeRate: null,
    },
    sampleMatches: matchList.map((match) => ({
      matchId: match.match_id,
      playerName: match.player_name,
      playerIcon: match.player_icon,
      startTime: match.start_time,
      ascensionLevel: match.ascension_level,
      duration: match.duration,
      deckSize: match.deck_size,
      isWin: match.is_win,
      cardIconList: match.card_icon_list ?? [],
    })),
  };
}

async function collectSnapshot(page, probe, options) {
  const categories = getCategoryValues(probe, options.categories);
  console.log(`Categories to fetch: ${categories.join(', ')}`);

  const rawByCategory = {};
  const allStats = [];

  for (const category of categories) {
    console.log(`Fetching card list for category: ${category}`);
    const categoryStats = await fetchCategoryCardStats(page, category);
    rawByCategory[category] = categoryStats;
    allStats.push(...categoryStats.map((item) => ({ ...item, __category: category })));
    await sleep(150);
  }

  const dedupedStats = dedupeStatsByCardId(allStats);
  if (dedupedStats.length === 0) {
    throw new CollectorError('card/list returned zero cards after pagination.', {
      status: 'schema-error',
      stage: 'full-sync',
    });
  }

  let detailTargets = dedupedStats;
  if (Number.isInteger(options.detailLimit) && options.detailLimit > 0) {
    detailTargets = dedupedStats.slice(0, options.detailLimit);
    console.log(`Detail limit enabled: only fetching first ${detailTargets.length} cards.`);
  }

  const cards = [];
  if (!options.withDetails) {
    for (const stat of dedupedStats) {
      cards.push(mergeCardData(stat, null));
    }
  } else {
    for (let index = 0; index < detailTargets.length; index += 1) {
      const stat = detailTargets[index];
      console.log(`Fetching detail ${index + 1}/${detailTargets.length}: ${stat.card_name} (${stat.card_id})`);
      const detail = await fetchCardDetail(page, stat.card_id);
      cards.push(mergeCardData(stat, detail));
      await sleep(120);
    }
  }

  const snapshot = {
    schemaVersion: SCHEMA_VERSION,
    source: 'xiaoheihe',
    game: 'slay_the_spire_2',
    syncedAt: new Date().toISOString(),
    syncMode: 'cdp',
    databaseUrl: DATABASE_URL,
    cdpUrl: options.cdpUrl,
    chromeUserDataDir: options.chromeUserDataDir,
    categories,
    filters: probe.result?.filter_list ?? [],
    withDetails: options.withDetails,
    detailLimit: options.detailLimit,
    totalStatsCount: dedupedStats.length,
    exportedCardCount: cards.length,
    cards,
    rawByCategory,
  };

  validateSnapshot(snapshot);
  return snapshot;
}

function normalizeCollectorError(error, fallbackStage) {
  if (error instanceof CollectorError) {
    return error;
  }

  return new CollectorError(error?.message ?? String(error), {
    status: 'network-error',
    stage: fallbackStage,
    cause: error,
  });
}

async function writeProbeManifest(options, existingManifest) {
  const paths = await ensureOutputDirectory(options.outputPath);
  const attemptAt = new Date().toISOString();
  const manifest = buildManifest({
    status: 'ok',
    stage: 'probe',
    attemptAt,
    lastGoodSnapshotAt: getLastGoodSnapshotAt(existingManifest),
    snapshotMeta: existingManifest?.snapshot ?? null,
    runtime: buildRuntimeMetadata(options),
    metricsAvailable: existingManifest?.metricsAvailable ?? DEFAULT_METRICS_AVAILABLE,
  });
  await writeJson(paths.manifestPath, manifest);
  return { paths, manifest };
}

async function writeSuccessArtifacts(options, snapshot) {
  const paths = await ensureOutputDirectory(options.outputPath);
  await writeJson(paths.snapshotPath, snapshot);
  const sha256 = await computeFileSha256(paths.snapshotPath);
  const attemptAt = new Date().toISOString();
  const manifest = buildManifest({
    status: 'ok',
    stage: 'full-sync',
    attemptAt,
    lastGoodSnapshotAt: snapshot.syncedAt,
    snapshotMeta: buildSnapshotMeta({
      snapshotPath: paths.snapshotPath,
      sha256,
      snapshot,
    }),
    runtime: buildRuntimeMetadata(options),
    metricsAvailable: DEFAULT_METRICS_AVAILABLE,
  });
  await writeJson(paths.manifestPath, manifest);
  return { paths, manifest };
}

async function handleFailure(options, existingManifest, error) {
  const normalized = normalizeCollectorError(error, options.keepaliveOnly ? 'probe' : 'full-sync');
  const paths = await ensureOutputDirectory(options.outputPath);
  const attemptAt = new Date().toISOString();
  const lastGoodSnapshotAt = getLastGoodSnapshotAt(existingManifest);
  const manifest = buildManifest({
    status: normalized.status,
    stage: normalized.stage,
    attemptAt,
    lastGoodSnapshotAt,
    snapshotMeta: existingManifest?.snapshot ?? null,
    runtime: buildRuntimeMetadata(options),
    metricsAvailable: existingManifest?.metricsAvailable ?? DEFAULT_METRICS_AVAILABLE,
    errorMessage: normalized.message,
    extra: {
      help: normalized.help ?? null,
    },
  });
  await writeJson(paths.manifestPath, manifest);

  if (options.alertWebhook) {
    try {
      await sendAlert(options.alertWebhook, createAlertPayload({
        stage: normalized.stage,
        status: normalized.status,
        attemptAt,
        lastGoodSnapshotAt,
        errorMessage: normalized.message,
        outputPath: paths.snapshotPath,
      }));
      console.error(`Alert sent to ${options.alertWebhook}`);
    } catch (alertError) {
      console.error(`Failed to send alert: ${alertError.message}`);
    }
  }

  console.error(normalized.message);
  if (normalized.help) {
    console.error(normalized.help);
  }
  process.exitCode = normalized.exitCode;
}

async function main() {
  let options = createDefaultOptions();
  let existingManifest = null;
  let session = null;

  try {
    options = parseArgs(process.argv.slice(2), options);
    if (options.help) {
      printUsage();
      return;
    }

    const paths = await ensureOutputDirectory(options.outputPath);
    existingManifest = await readJsonIfExists(paths.manifestPath);
    printStartup(options, paths);

    const { chromium } = await loadPlaywright();
    session = await connectToBrowser(chromium, options.cdpUrl, options.chromeUserDataDir);
    const page = await getCollectorPage(session.context);
    const probe = await runProbe(page);

    if (options.keepaliveOnly) {
      await writeProbeManifest(options, existingManifest);
      console.log('Keepalive probe succeeded. Manifest status refreshed without touching the snapshot.');
      return;
    }

    const snapshot = await collectSnapshot(page, probe, options);
    const { paths: successPaths } = await writeSuccessArtifacts(options, snapshot);
    console.log(`Full sync succeeded. Snapshot written to: ${successPaths.snapshotPath}`);
    console.log(`Manifest written to: ${successPaths.manifestPath}`);
  } catch (error) {
    await handleFailure(options, existingManifest, error);
  } finally {
    if (session) {
      await session.close();
    }
  }
}

await main();
