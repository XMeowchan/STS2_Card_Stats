const DEFAULT_CONFIG = {
  uploadUrl: 'http://127.0.0.1:8765/upload',
  outputMode: 'upload',
  autoCloseTab: true,
  withDetails: true,
  detailLimit: '',
  categories: '',
};

const form = document.getElementById('settings-form');
const statusNode = document.getElementById('status');
const uploadUrl = document.getElementById('uploadUrl');
const outputMode = document.getElementById('outputMode');
const autoCloseTab = document.getElementById('autoCloseTab');
const withDetails = document.getElementById('withDetails');
const detailLimit = document.getElementById('detailLimit');
const categories = document.getElementById('categories');

async function loadSettings() {
  const saved = await chrome.storage.local.get(Object.keys(DEFAULT_CONFIG));
  const config = { ...DEFAULT_CONFIG, ...saved };

  uploadUrl.value = config.uploadUrl;
  outputMode.value = config.outputMode;
  autoCloseTab.checked = Boolean(config.autoCloseTab);
  withDetails.checked = Boolean(config.withDetails);
  detailLimit.value = config.detailLimit;
  categories.value = config.categories;
}

form.addEventListener('submit', async (event) => {
  event.preventDefault();

  await chrome.storage.local.set({
    uploadUrl: uploadUrl.value.trim(),
    outputMode: outputMode.value,
    autoCloseTab: autoCloseTab.checked,
    withDetails: withDetails.checked,
    detailLimit: detailLimit.value.trim(),
    categories: categories.value.trim(),
  });

  statusNode.textContent = 'Saved.';
  setTimeout(() => {
    statusNode.textContent = '';
  }, 1500);
});

loadSettings().catch((error) => {
  statusNode.textContent = `Failed to load settings: ${error.message}`;
});
