const DATABASE_URL = 'https://www.xiaoheihe.cn/game/slay_the_spire/database_v2/card_database';
const DEFAULT_CONFIG = {
  uploadUrl: 'http://127.0.0.1:8765/upload',
  outputMode: 'upload',
  autoCloseTab: true,
  withDetails: true,
  detailLimit: '',
  categories: '',
};

chrome.runtime.onInstalled.addListener(async () => {
  const current = await chrome.storage.local.get(Object.keys(DEFAULT_CONFIG));
  await chrome.storage.local.set({ ...DEFAULT_CONFIG, ...current });
});

chrome.action.onClicked.addListener(async () => {
  await runCollection();
});

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message?.type === 'xhh-extension:collector-log') {
    console.log('[xhh-extension]', message.payload);
    return;
  }

  if (message?.type !== 'xhh-extension:collector-result') {
    return;
  }

  handleCollectorResult(message.payload, sender)
    .then((result) => sendResponse({ ok: true, result }))
    .catch((error) => sendResponse({ ok: false, error: error.message }));
  return true;
});

async function runCollection() {
  await setBadge('RUN', '#1d4ed8');
  const config = await loadConfig();
  const tab = await ensureCollectorTab();
  await sendRunMessage(tab.id, config);
}

async function loadConfig() {
  const current = await chrome.storage.local.get(Object.keys(DEFAULT_CONFIG));
  return { ...DEFAULT_CONFIG, ...current };
}

async function ensureCollectorTab() {
  const existingTabs = await chrome.tabs.query({ url: ['https://www.xiaoheihe.cn/*'] });
  const existing = existingTabs.find((tab) => tab.url?.startsWith(DATABASE_URL));
  if (existing?.id) {
    await chrome.tabs.update(existing.id, { active: true, url: DATABASE_URL });
    return waitForTabReady(existing.id);
  }

  const created = await chrome.tabs.create({ url: DATABASE_URL, active: true });
  return waitForTabReady(created.id);
}

function waitForTabReady(tabId) {
  return new Promise((resolve, reject) => {
    const timeout = setTimeout(() => {
      cleanup();
      reject(new Error(`Timed out waiting for tab ${tabId} to finish loading.`));
    }, 30_000);

    const listener = (updatedTabId, changeInfo, tab) => {
      if (updatedTabId === tabId && changeInfo.status === 'complete') {
        cleanup();
        resolve(tab);
      }
    };

    const cleanup = () => {
      clearTimeout(timeout);
      chrome.tabs.onUpdated.removeListener(listener);
    };

    chrome.tabs.onUpdated.addListener(listener);
  });
}

async function sendRunMessage(tabId, config) {
  for (let attempt = 0; attempt < 6; attempt += 1) {
    try {
      await chrome.tabs.sendMessage(tabId, {
        type: 'xhh-extension:run',
        config,
      });
      return;
    } catch (error) {
      if (attempt === 5) {
        await setBadge('ERR', '#b91c1c');
        throw error;
      }
      await sleep(500);
    }
  }
}

async function handleCollectorResult(payload, sender) {
  const config = await loadConfig();

  if (!payload?.ok) {
    await setBadge('ERR', '#b91c1c');
    console.error('[xhh-extension] collector failed', payload?.error);
    return { status: 'error', error: payload?.error ?? null };
  }

  let result;
  if (config.outputMode === 'upload') {
    try {
      result = await uploadSnapshot(config.uploadUrl, payload.snapshot);
      await setBadge('UP', '#15803d');
    } catch (error) {
      console.warn('[xhh-extension] upload failed, falling back to download', error);
      await downloadSnapshot(payload.snapshot);
      result = {
        status: 'downloaded-fallback',
        error: error.message,
      };
      await setBadge('DL', '#854d0e');
    }
  } else {
    await downloadSnapshot(payload.snapshot);
    result = { status: 'downloaded' };
    await setBadge('DL', '#854d0e');
  }

  await chrome.storage.local.set({
    lastRunAt: new Date().toISOString(),
    lastResult: result,
  });

  if (config.autoCloseTab && sender?.tab?.id) {
    await chrome.tabs.remove(sender.tab.id).catch(() => {});
  }

  return result;
}

async function uploadSnapshot(uploadUrl, snapshot) {
  const response = await fetch(uploadUrl, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
    },
    body: JSON.stringify(snapshot),
  });

  if (!response.ok) {
    throw new Error(`Upload failed with HTTP ${response.status}`);
  }

  return response.json().catch(() => ({ status: 'uploaded' }));
}

async function downloadSnapshot(snapshot) {
  const blob = new Blob([JSON.stringify(snapshot, null, 2)], {
    type: 'application/json',
  });
  const url = URL.createObjectURL(blob);

  try {
    await chrome.downloads.download({
      url,
      filename: `xhh/cards.snapshot.${Date.now()}.json`,
      saveAs: true,
    });
  } finally {
    setTimeout(() => URL.revokeObjectURL(url), 1_000);
  }
}

async function setBadge(text, color) {
  await chrome.action.setBadgeText({ text });
  await chrome.action.setBadgeBackgroundColor({ color });
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
