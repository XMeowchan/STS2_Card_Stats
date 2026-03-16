import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const collectorRoot = path.resolve(__dirname, '..');
const snapshotPath = path.join(collectorRoot, 'output', 'xhh', 'cards.snapshot.json');
const publicDir = path.join(collectorRoot, 'public');
const targetDataPath = path.join(publicDir, 'cards.json');
const targetIndexPath = path.join(publicDir, 'index.html');
const targetNoJekyllPath = path.join(publicDir, '.nojekyll');

const snapshot = JSON.parse(await fs.readFile(snapshotPath, 'utf8'));
validateCollectorSnapshot(snapshot);

const payload = convertSnapshot(snapshot);
await fs.rm(publicDir, { recursive: true, force: true });
await fs.mkdir(publicDir, { recursive: true });
await fs.writeFile(targetDataPath, JSON.stringify(payload, null, 2), 'utf8');
await fs.writeFile(targetIndexPath, buildIndexHtml(payload), 'utf8');
await fs.writeFile(targetNoJekyllPath, '', 'utf8');

console.log(`Built Pages payload: ${publicDir}`);

function validateCollectorSnapshot(value) {
  if (!value || !Array.isArray(value.cards)) {
    throw new Error('Collector snapshot must contain a cards array.');
  }

  if (!Array.isArray(value.categories)) {
    throw new Error('Collector snapshot must contain categories.');
  }
}

function convertSnapshot(value) {
  const syncedAt = value.syncedAt || new Date().toISOString();
  return {
    source: value.source || 'xiaoheihe',
    game: value.game || 'slay_the_spire_2',
    updated_at: syncedAt,
    categories: Array.isArray(value.categories) ? value.categories : [],
    cards: (value.cards || []).map((card) => convertCard(card, syncedAt)).filter(Boolean),
  };
}

function convertCard(card, syncedAt) {
  if (!card || typeof card.id !== 'string' || card.id.trim().length === 0) {
    return null;
  }

  const normalizedId = card.id.trim();
  const displayName = typeof card.name === 'string' && card.name.trim().length > 0 ? card.name.trim() : null;
  const asciiName = displayName && isAscii(displayName) ? displayName : null;
  const altIds = [...new Set([normalizedId, asciiName].filter(Boolean))];
  const stats = card.stats || {};

  return {
    id: normalizedId,
    alt_ids: altIds,
    name_cn: displayName,
    name_en: asciiName || (isAscii(normalizedId) ? normalizedId : null),
    category: card.category ?? null,
    type: card.type ?? null,
    rarity: card.rarity ?? null,
    cost: integerOrNull(card.cost),
    icon_url: card.iconUrl ?? null,
    desc: card.description ?? null,
    upgrade_desc: card.upgradeInfo?.desc ?? null,
    updated_at: syncedAt,
    stats: {
      win_rate: numberOrNull(stats.winRate),
      pick_rate: numberOrNull(stats.pickRate),
      skip_rate: numberOrNull(stats.skipRate),
      times_picked: integerOrNull(stats.timesPicked),
      times_won: integerOrNull(stats.timesWon),
      times_lost: integerOrNull(stats.timesLost),
      times_skipped: integerOrNull(stats.timesSkipped),
      win_rate_rank: integerOrNull(stats.winRateRank),
      pick_rate_rank: integerOrNull(stats.pickRateRank),
    },
  };
}

function buildIndexHtml(payload) {
  const updatedAt = payload.updated_at || new Date().toISOString();
  const cardCount = Array.isArray(payload.cards) ? payload.cards.length : 0;

  return [
    '<!DOCTYPE html>',
    "<html lang='en'>",
    '<head>',
    "  <meta charset='utf-8'>",
    "  <meta name='viewport' content='width=device-width, initial-scale=1'>",
    '  <title>STS2 Community Card Stats Snapshot</title>',
    '  <style>',
    '    body { font-family: Segoe UI, sans-serif; max-width: 720px; margin: 40px auto; padding: 0 16px; line-height: 1.6; color: #1b1e22; }',
    '    a { color: #0057a3; }',
    '    .meta { padding: 16px; border: 1px solid #d7dde5; border-radius: 12px; background: #f8fbff; }',
    '  </style>',
    '</head>',
    '<body>',
    '  <h1>STS2 Community Card Stats Snapshot</h1>',
    "  <div class='meta'>",
    `    <p><strong>Updated at:</strong> ${escapeHtml(updatedAt)}</p>`,
    `    <p><strong>Card count:</strong> ${cardCount}</p>`,
    "    <p><strong>JSON URL:</strong> <a href='cards.json'>cards.json</a></p>",
    '  </div>',
    '</body>',
    '</html>',
  ].join('\n');
}

function escapeHtml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
}

function isAscii(value) {
  return typeof value === 'string' && /^[A-Za-z0-9_ +'\-]+$/.test(value);
}

function numberOrNull(value) {
  if (value === null || value === undefined || value === '') {
    return null;
  }

  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function integerOrNull(value) {
  if (value === null || value === undefined || value === '') {
    return null;
  }

  const parsed = Number.parseInt(String(value), 10);
  return Number.isFinite(parsed) ? parsed : null;
}
