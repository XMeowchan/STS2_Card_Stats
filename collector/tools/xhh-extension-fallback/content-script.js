(() => {
  const PAGE_SOURCE = 'xhh-extension-page';
  let injected = false;

  function injectBridge() {
    if (injected) {
      return;
    }

    const script = document.createElement('script');
    script.src = chrome.runtime.getURL('injected-page.js');
    script.dataset.xhhExtensionBridge = '1';
    (document.documentElement || document.head || document.body).appendChild(script);
    script.remove();
    injected = true;
  }

  injectBridge();

  window.addEventListener('message', (event) => {
    if (event.source !== window) {
      return;
    }

    const data = event.data;
    if (!data || data.source !== PAGE_SOURCE) {
      return;
    }

    chrome.runtime.sendMessage({
      type: data.type,
      payload: data.payload,
    }).catch((error) => {
      console.error('[xhh-extension] failed to relay message', error);
    });
  });

  chrome.runtime.onMessage.addListener((message) => {
    if (message?.type !== 'xhh-extension:run') {
      return;
    }

    injectBridge();
    window.postMessage({
      source: 'xhh-extension-content',
      type: 'xhh-extension:run',
      payload: message.config,
    }, '*');
  });
})();
