import { fileURLToPath } from 'node:url';
import fs from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const argv = process.argv.slice(2);
const configPath = getArgValue('--config') ?? path.resolve(process.cwd(), 'syncer.config.json');
const projectRoot = path.resolve(__dirname, '..');
const dataDir = path.join(projectRoot, 'data');
const statePath = path.join(dataDir, 'sync_state.json');
const cardsPath = path.join(dataDir, 'cards.json');
const fallbackPath = path.join(dataDir, 'cards.fallback.json');

class SyncImportError extends Error {
  constructor(message, { status = 'error', cause } = {}) {
    super(message, { cause });
    this.name = 'SyncImportError';
    this.status = status;
  }
}

await fs.mkdir(dataDir, { recursive: true });
const config = normalizeConfig(JSON.parse(stripBom(await fs.readFile(configPath, 'utf8'))), path.dirname(configPath));
const previousState = (await readJsonMaybe(statePath)) ?? {};

try {
  await writeState({
    ...previousState,
    status: 'starting',
    last_attempt_at: new Date().toISOString(),
    source: 'xiaoheihe',
    error_summary: '',
  });

  const source = await resolveCollectorSource(config);
  const manifest = source.manifestPath ? await readJsonMaybe(source.manifestPath) : null;
  const snapshot = JSON.parse(stripBom(await fs.readFile(source.snapshotPath, 'utf8')));
  validateCollectorSnapshot(snapshot);

  const payload = convertSnapshot(snapshot);
  const syncedAt = payload.updated_at || new Date().toISOString();
  const manifestStatus = String(manifest?.status ?? '').trim().toLowerCase();
  const importedStatus = manifestStatus && manifestStatus !== 'ok' ? 'partial_success' : 'success';
  const importedSummary = manifestStatus && manifestStatus !== 'ok'
    ? `Imported collector snapshot while collector manifest status is '${manifestStatus}'.`
    : '';

  await writeJsonAtomic(cardsPath, payload);
  await writeJsonAtomic(fallbackPath, payload);
  await writeState({
    ...previousState,
    status: importedStatus,
    last_attempt_at: syncedAt,
    last_success_at: syncedAt,
    source: 'xiaoheihe',
    card_count: payload.cards.length,
    error_summary: importedSummary,
  });
  if (config.mod_dir) {
    await mirrorProjectDataToMod(config.mod_dir);
  }
} catch (error) {
  await writeState({
    ...previousState,
    status: classifyError(error),
    last_attempt_at: new Date().toISOString(),
    source: 'xiaoheihe',
    error_summary: summarizeError(error),
  });
  if (config.mod_dir) {
    await mirrorProjectDataToMod(config.mod_dir);
  }
  console.error(error);
  process.exit(1);
}

function getArgValue(flag) {
  const index = argv.indexOf(flag);
  return index >= 0 && index + 1 < argv.length ? argv[index + 1] : null;
}

function normalizeConfig(config, configDir) {
  const next = { ...config };

  for (const key of ['game_dir', 'mod_dir', 'collector_repo_dir', 'collector_output_dir', 'collector_snapshot_path', 'collector_manifest_path']) {
    if (typeof next[key] === 'string' && next[key].trim().length > 0 && !path.isAbsolute(next[key])) {
      next[key] = path.resolve(configDir, next[key]);
    }
  }

  return next;
}

async function resolveCollectorSource(config) {
  const candidates = buildSourceCandidates(config);
  const manifestStatuses = [];

  for (const candidate of candidates) {
    if (await exists(candidate.snapshotPath)) {
      return candidate;
    }

    if (candidate.manifestPath && await exists(candidate.manifestPath)) {
      const manifest = await readJsonMaybe(candidate.manifestPath);
      const status = String(manifest?.status ?? '').trim().toLowerCase();
      if (status) {
        manifestStatuses.push(status);
      }
    }
  }

  const message = candidates.length > 0
    ? `Collector snapshot not found. Checked: ${candidates.map(candidate => candidate.snapshotPath).join('; ')}`
    : 'Collector snapshot not configured.';
  throw new SyncImportError(message, {
    status: manifestStatuses.includes('login') || manifestStatuses.includes('relogin') ? 'login' : 'source_missing',
  });
}

function buildSourceCandidates(config) {
  const candidates = [];
  const seen = new Set();

  const pushCandidate = (snapshotPath, manifestPath) => {
    if (!snapshotPath) {
      return;
    }

    const normalizedSnapshot = path.resolve(snapshotPath);
    if (seen.has(normalizedSnapshot)) {
      return;
    }

    seen.add(normalizedSnapshot);
    candidates.push({
      snapshotPath: normalizedSnapshot,
      manifestPath: manifestPath ? path.resolve(manifestPath) : path.join(path.dirname(normalizedSnapshot), 'manifest.json'),
    });
  };

  if (config.collector_snapshot_path) {
    pushCandidate(config.collector_snapshot_path, config.collector_manifest_path ?? null);
  }

  if (config.collector_output_dir) {
    pushCandidate(
      path.join(config.collector_output_dir, 'cards.snapshot.json'),
      path.join(config.collector_output_dir, 'manifest.json'),
    );
  }

  if (config.collector_repo_dir) {
    pushCandidate(
      path.join(config.collector_repo_dir, 'output', 'xhh', 'cards.snapshot.json'),
      path.join(config.collector_repo_dir, 'output', 'xhh', 'manifest.json'),
    );
  }

  const siblingRepoDir = path.resolve(projectRoot, '..', 'Fetch-STS2_Card-Stats');
  pushCandidate(
    path.join(siblingRepoDir, 'output', 'xhh', 'cards.snapshot.json'),
    path.join(siblingRepoDir, 'output', 'xhh', 'manifest.json'),
  );

  if (process.env.XHH_COLLECTOR_OUTPUT) {
    pushCandidate(process.env.XHH_COLLECTOR_OUTPUT, null);
  }

  return candidates;
}

function validateCollectorSnapshot(snapshot) {
  if (!snapshot || !Array.isArray(snapshot.cards)) {
    throw new SyncImportError('Collector snapshot must contain a cards array.', {
      status: 'schema_error',
    });
  }

  if (!Array.isArray(snapshot.categories)) {
    throw new SyncImportError('Collector snapshot must contain categories.', {
      status: 'schema_error',
    });
  }

  if (snapshot.exportedCardCount != null && snapshot.exportedCardCount !== snapshot.cards.length) {
    throw new SyncImportError(
      `Collector snapshot exportedCardCount (${snapshot.exportedCardCount}) does not match cards.length (${snapshot.cards.length}).`,
      {
        status: 'schema_error',
      },
    );
  }
}

function convertSnapshot(snapshot) {
  const syncedAt = snapshot.syncedAt || new Date().toISOString();
  return {
    source: snapshot.source || 'xiaoheihe',
    game: snapshot.game || 'slay_the_spire_2',
    updated_at: syncedAt,
    categories: Array.isArray(snapshot.categories) ? snapshot.categories : [],
    cards: (snapshot.cards || []).map((card) => convertCard(card, syncedAt)).filter(Boolean),
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

async function writeJsonAtomic(targetPath, value) {
  await fs.mkdir(path.dirname(targetPath), { recursive: true });
  const tempPath = `${targetPath}.tmp`;
  await fs.writeFile(tempPath, JSON.stringify(value, null, 2), 'utf8');
  await fs.rename(tempPath, targetPath);
}

async function mirrorProjectDataToMod(modDir) {
  await fs.mkdir(modDir, { recursive: true });

  const liveSource = await exists(cardsPath) ? cardsPath : (await exists(fallbackPath) ? fallbackPath : null);
  if (liveSource) {
    await fs.copyFile(liveSource, path.join(modDir, 'cards.cache'));
  }

  const hasNewManifest = await exists(path.join(modDir, 'HeyboxCardStatsOverlay.json'));
  if (!hasNewManifest) {
    return;
  }

  for (const legacyName of ['cards.json', 'cards.fallback.json', 'cards.sample.json', 'sync_state.json', 'mod_manifest.json']) {
    const legacyPath = path.join(modDir, legacyName);
    if (await exists(legacyPath)) {
      await fs.rm(legacyPath, { force: true });
    }
  }
}

async function readJsonMaybe(filePath) {
  try {
    return JSON.parse(stripBom(await fs.readFile(filePath, 'utf8')));
  } catch {
    return null;
  }
}

async function writeState(nextState) {
  const merged = {
    last_attempt_at: nextState.last_attempt_at ?? new Date().toISOString(),
    last_success_at: nextState.last_success_at ?? previousState.last_success_at ?? null,
    status: nextState.status ?? previousState.status ?? 'unknown',
    card_count: nextState.card_count ?? previousState.card_count ?? 0,
    source: nextState.source ?? previousState.source ?? 'xiaoheihe',
    error_summary: nextState.error_summary ?? '',
  };
  await writeJsonAtomic(statePath, merged);
}

function classifyError(error) {
  if (error instanceof SyncImportError) {
    if (error.status === 'login' || error.status === 'relogin') {
      return 'login_required';
    }

    if (error.status === 'source_missing') {
      return 'source_missing';
    }
  }

  const message = summarizeError(error).toLowerCase();
  if (message.includes('login')) {
    return 'login_required';
  }

  if (message.includes('not found')) {
    return 'source_missing';
  }

  return 'error';
}

function summarizeError(error) {
  return error instanceof Error ? error.message : String(error);
}

async function exists(filePath) {
  try {
    await fs.access(filePath);
    return true;
  } catch {
    return false;
  }
}

function stripBom(value) {
  return typeof value === 'string' ? value.replace(/^\uFEFF/, '') : value;
}
