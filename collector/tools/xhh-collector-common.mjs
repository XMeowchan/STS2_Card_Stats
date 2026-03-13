import crypto from 'node:crypto';
import fs from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';

export const DATABASE_URL = 'https://www.xiaoheihe.cn/game/slay_the_spire/database_v2/card_database';
export const DEFAULT_CDP_URL = 'http://127.0.0.1:9222';
export const DEFAULT_CHROME_USER_DATA_DIR = 'C:\\xhh-collector-profile';
export const DEFAULT_OUTPUT_PATH = path.resolve(process.cwd(), 'output', 'xhh', 'cards.snapshot.json');
export const DEFAULT_ALERT_TIMEOUT_MS = 10_000;
export const EXIT_CODE_LOGIN = 10;
export const EXIT_CODE_FAILURE = 11;
export const SCHEMA_VERSION = 1;
export const DEFAULT_METRICS_AVAILABLE = [
  'winRate',
  'pickRate',
  'skipRate',
  'timesWon',
  'timesLost',
  'timesPicked',
  'timesSkipped',
  'winRateRank',
  'pickRateRank',
];

export function resolveOutputPaths(outputPath) {
  const snapshotPath = path.resolve(outputPath ?? DEFAULT_OUTPUT_PATH);
  const outputDir = path.dirname(snapshotPath);
  return {
    outputDir,
    snapshotPath,
    manifestPath: path.join(outputDir, 'manifest.json'),
  };
}

export async function ensureOutputDirectory(outputPath) {
  const paths = resolveOutputPaths(outputPath);
  await fs.mkdir(paths.outputDir, { recursive: true });
  return paths;
}

export async function readJsonIfExists(filePath) {
  try {
    return JSON.parse(await fs.readFile(filePath, 'utf8'));
  } catch (error) {
    if (error?.code === 'ENOENT') {
      return null;
    }
    throw error;
  }
}

export async function writeJson(filePath, data) {
  await fs.mkdir(path.dirname(filePath), { recursive: true });
  await fs.writeFile(filePath, `${JSON.stringify(data, null, 2)}\n`, 'utf8');
}

export async function computeFileSha256(filePath) {
  const buffer = await fs.readFile(filePath);
  return crypto.createHash('sha256').update(buffer).digest('hex');
}

export function getLastGoodSnapshotAt(manifest) {
  return manifest?.lastGoodSnapshotAt ?? manifest?.snapshot?.syncedAt ?? null;
}

export function buildSnapshotMeta({ snapshotPath, sha256, snapshot }) {
  return {
    path: path.basename(snapshotPath),
    sha256,
    syncedAt: snapshot.syncedAt ?? null,
    cardsCount: snapshot.exportedCardCount ?? snapshot.cards?.length ?? 0,
    totalStatsCount: snapshot.totalStatsCount ?? null,
    categories: snapshot.categories ?? [],
    withDetails: Boolean(snapshot.withDetails),
    detailLimit: snapshot.detailLimit ?? null,
  };
}

export function buildManifest({
  status,
  stage,
  attemptAt,
  lastGoodSnapshotAt,
  snapshotMeta,
  runtime,
  errorMessage,
  metricsAvailable,
  extra = {},
}) {
  return {
    schemaVersion: SCHEMA_VERSION,
    source: 'xiaoheihe',
    game: 'slay_the_spire_2',
    status,
    stage,
    generatedAt: attemptAt,
    lastAttemptAt: attemptAt,
    lastGoodSnapshotAt: lastGoodSnapshotAt ?? null,
    snapshot: snapshotMeta ?? null,
    metricsAvailable: metricsAvailable ?? DEFAULT_METRICS_AVAILABLE,
    runtime: runtime ?? null,
    error: errorMessage ? { message: errorMessage } : null,
    ...extra,
  };
}

export function createAlertPayload({
  stage,
  status,
  attemptAt,
  lastGoodSnapshotAt,
  errorMessage,
  outputPath,
}) {
  return {
    time: attemptAt,
    stage,
    status,
    lastGoodSnapshotAt: lastGoodSnapshotAt ?? null,
    outputPath,
    error: errorMessage ?? null,
  };
}

export async function sendAlert(url, payload) {
  if (!url) {
    return;
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), DEFAULT_ALERT_TIMEOUT_MS);

  try {
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
      },
      body: JSON.stringify(payload),
      signal: controller.signal,
    });

    if (!response.ok) {
      throw new Error(`Alert webhook returned HTTP ${response.status}`);
    }
  } finally {
    clearTimeout(timeout);
  }
}

export function validateSnapshot(snapshot) {
  if (!snapshot || !Array.isArray(snapshot.cards)) {
    throw new Error('Snapshot must contain a cards array.');
  }

  if (!Array.isArray(snapshot.categories)) {
    throw new Error('Snapshot must contain categories.');
  }

  if (snapshot.exportedCardCount != null && snapshot.exportedCardCount != snapshot.cards.length) {
    throw new Error(
      `exportedCardCount (${snapshot.exportedCardCount}) does not match cards.length (${snapshot.cards.length}).`,
    );
  }

  const seen = new Set();
  for (const card of snapshot.cards) {
    if (!card || typeof card.id !== 'string' || !card.id.trim()) {
      throw new Error('Each card must have a non-empty string id.');
    }

    if (seen.has(card.id)) {
      throw new Error(`Duplicate card id detected: ${card.id}`);
    }
    seen.add(card.id);
    validateCardStats(card.stats, card.id);
  }

  return {
    uniqueCardCount: seen.size,
  };
}

function validateCardStats(stats, cardId) {
  if (!stats || typeof stats !== 'object') {
    throw new Error(`Card ${cardId} is missing stats.`);
  }

  const numericFields = [
    'timesWon',
    'timesLost',
    'timesPicked',
    'timesSkipped',
    'winRate',
    'pickRate',
    'skipRate',
    'winRateRank',
    'pickRateRank',
    'upgradeRate',
  ];

  for (const field of numericFields) {
    const value = stats[field];
    if (value == null) {
      continue;
    }

    if (typeof value !== 'number' || Number.isNaN(value)) {
      throw new Error(`Card ${cardId} has invalid numeric field ${field}.`);
    }
  }
}

export function normalizeNumber(value) {
  if (value === '' || value == null) {
    return null;
  }

  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}
