import http from 'node:http';
import process from 'node:process';

import {
  buildManifest,
  buildSnapshotMeta,
  computeFileSha256,
  DEFAULT_METRICS_AVAILABLE,
  DEFAULT_OUTPUT_PATH,
  ensureOutputDirectory,
  SCHEMA_VERSION,
  validateSnapshot,
  writeJson,
} from './xhh-collector-common.mjs';

function createDefaultOptions() {
  return {
    outputPath: DEFAULT_OUTPUT_PATH,
    port: 8765,
    keepOpen: false,
    help: false,
  };
}

function parseArgs(argv, seedOptions = createDefaultOptions()) {
  const options = { ...seedOptions };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];

    if (arg === '--help' || arg === '-h') {
      options.help = true;
      continue;
    }

    if (arg === '--output' && argv[index + 1]) {
      options.outputPath = argv[index + 1].trim();
      index += 1;
      continue;
    }

    if (arg === '--port' && argv[index + 1]) {
      const parsed = Number.parseInt(argv[index + 1], 10);
      options.port = Number.isInteger(parsed) && parsed > 0 ? parsed : options.port;
      index += 1;
      continue;
    }

    if (arg === '--keep-open') {
      options.keepOpen = true;
      continue;
    }

    throw new Error(`Unknown argument: ${arg}`);
  }

  return options;
}

function printUsage() {
  console.log(`JSON upload receiver\n\nUsage:\n  node tools/json-upload-receiver.mjs [options]\n\nOptions:\n  --output <file>   Snapshot path to write\n  --port <n>        Local port to listen on (default: 8765)\n  --keep-open       Keep the receiver alive after a successful upload\n  --help            Show this message\n`);
}

function extractSnapshot(payload) {
  if (payload?.snapshot && typeof payload.snapshot === 'object') {
    return payload.snapshot;
  }
  return payload;
}

async function writeArtifacts(options, snapshot) {
  validateSnapshot(snapshot);

  const paths = await ensureOutputDirectory(options.outputPath);
  await writeJson(paths.snapshotPath, {
    schemaVersion: snapshot.schemaVersion ?? SCHEMA_VERSION,
    ...snapshot,
  });
  const sha256 = await computeFileSha256(paths.snapshotPath);
  const attemptAt = new Date().toISOString();
  const manifest = buildManifest({
    status: 'ok',
    stage: 'extension-upload',
    attemptAt,
    lastGoodSnapshotAt: snapshot.syncedAt ?? attemptAt,
    snapshotMeta: buildSnapshotMeta({
      snapshotPath: paths.snapshotPath,
      sha256,
      snapshot,
    }),
    runtime: {
      transport: 'extension-upload',
      port: options.port,
    },
    metricsAvailable: DEFAULT_METRICS_AVAILABLE,
  });
  await writeJson(paths.manifestPath, manifest);
  return { paths, manifest };
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  if (options.help) {
    printUsage();
    return;
  }

  const paths = await ensureOutputDirectory(options.outputPath);

  const server = http.createServer(async (req, res) => {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') {
      res.writeHead(204);
      res.end();
      return;
    }

    if (req.method !== 'POST' || req.url !== '/upload') {
      res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
      res.end('Not Found');
      return;
    }

    const chunks = [];
    req.on('data', (chunk) => chunks.push(chunk));

    req.on('end', async () => {
      try {
        const body = Buffer.concat(chunks).toString('utf8');
        const payload = JSON.parse(body);
        const snapshot = extractSnapshot(payload);
        const { paths: writtenPaths } = await writeArtifacts(options, snapshot);

        res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
        res.end(JSON.stringify({
          status: 'ok',
          snapshotPath: writtenPaths.snapshotPath,
          manifestPath: writtenPaths.manifestPath,
        }));

        if (!options.keepOpen) {
          server.close(() => {
            process.exit(0);
          });
        }
      } catch (error) {
        res.writeHead(500, { 'Content-Type': 'application/json; charset=utf-8' });
        res.end(JSON.stringify({ status: 'error', message: String(error.message ?? error) }));
      }
    });
  });

  server.listen(options.port, '127.0.0.1', () => {
    console.log(`json-upload-receiver listening on http://127.0.0.1:${options.port}/upload`);
    console.log(`snapshotPath=${paths.snapshotPath}`);
    console.log(`manifestPath=${paths.manifestPath}`);
  });
}

await main();
