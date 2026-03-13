(() => {
  const DATABASE_URL = 'https://www.xiaoheihe.cn/game/slay_the_spire/database_v2/card_database';
  const LIST_ROUTE = '/game/slaythespire/v2/card/list';
  const DETAIL_ROUTE = '/game/slaythespire/v2/card/detail';
  const PAGE_SIZE = 100;
  const state = {
    running: false,
  };

  window.addEventListener('message', (event) => {
    if (event.source !== window) {
      return;
    }

    const data = event.data;
    if (!data || data.source !== 'xhh-extension-content' || data.type !== 'xhh-extension:run') {
      return;
    }

    if (state.running) {
      emit('xhh-extension:collector-log', { message: 'collector already running' });
      return;
    }

    state.running = true;
    collectSnapshot(data.payload)
      .then((snapshot) => {
        emit('xhh-extension:collector-result', {
          ok: true,
          snapshot,
        });
      })
      .catch((error) => {
        emit('xhh-extension:collector-result', {
          ok: false,
          error: {
            message: error.message,
            status: error.status ?? 'error',
            stage: error.stage ?? 'full-sync',
          },
        });
      })
      .finally(() => {
        state.running = false;
      });
  });

  function emit(type, payload) {
    window.postMessage({
      source: 'xhh-extension-page',
      type,
      payload,
    }, '*');
  }

  function sleep(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  function createError(message, status, stage) {
    const error = new Error(message);
    error.status = status;
    error.stage = stage;
    return error;
  }

  function normalizeNumber(value) {
    if (value === '' || value == null) {
      return null;
    }

    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  }

  function md5(input) {
    const string = unescape(encodeURIComponent(input));

    function rotateLeft(value, shift) {
      return (value << shift) | (value >>> (32 - shift));
    }

    function addUnsigned(x, y) {
      const x4 = x & 0x40000000;
      const y4 = y & 0x40000000;
      const x8 = x & 0x80000000;
      const y8 = y & 0x80000000;
      const result = (x & 0x3fffffff) + (y & 0x3fffffff);

      if (x4 & y4) {
        return result ^ 0x80000000 ^ x8 ^ y8;
      }
      if (x4 | y4) {
        if (result & 0x40000000) {
          return result ^ 0xc0000000 ^ x8 ^ y8;
        }
        return result ^ 0x40000000 ^ x8 ^ y8;
      }
      return result ^ x8 ^ y8;
    }

    function f(x, y, z) {
      return (x & y) | ((~x) & z);
    }

    function g(x, y, z) {
      return (x & z) | (y & (~z));
    }

    function h(x, y, z) {
      return x ^ y ^ z;
    }

    function i(x, y, z) {
      return y ^ (x | (~z));
    }

    function ff(a, b, c, d, x, s, ac) {
      a = addUnsigned(a, addUnsigned(addUnsigned(f(b, c, d), x), ac));
      return addUnsigned(rotateLeft(a, s), b);
    }

    function gg(a, b, c, d, x, s, ac) {
      a = addUnsigned(a, addUnsigned(addUnsigned(g(b, c, d), x), ac));
      return addUnsigned(rotateLeft(a, s), b);
    }

    function hh(a, b, c, d, x, s, ac) {
      a = addUnsigned(a, addUnsigned(addUnsigned(h(b, c, d), x), ac));
      return addUnsigned(rotateLeft(a, s), b);
    }

    function ii(a, b, c, d, x, s, ac) {
      a = addUnsigned(a, addUnsigned(addUnsigned(i(b, c, d), x), ac));
      return addUnsigned(rotateLeft(a, s), b);
    }

    function convertToWordArray(text) {
      const messageLength = text.length;
      const numberOfWordsTemp1 = messageLength + 8;
      const numberOfWordsTemp2 = (numberOfWordsTemp1 - (numberOfWordsTemp1 % 64)) / 64;
      const numberOfWords = (numberOfWordsTemp2 + 1) * 16;
      const wordArray = new Array(numberOfWords - 1);
      let byteCount = 0;

      while (byteCount < messageLength) {
        const wordCount = (byteCount - (byteCount % 4)) / 4;
        const bytePosition = (byteCount % 4) * 8;
        wordArray[wordCount] = wordArray[wordCount] || 0;
        wordArray[wordCount] |= text.charCodeAt(byteCount) << bytePosition;
        byteCount += 1;
      }

      const wordCount = (byteCount - (byteCount % 4)) / 4;
      const bytePosition = (byteCount % 4) * 8;
      wordArray[wordCount] = wordArray[wordCount] || 0;
      wordArray[wordCount] |= 0x80 << bytePosition;
      wordArray[numberOfWords - 2] = messageLength << 3;
      wordArray[numberOfWords - 1] = messageLength >>> 29;
      return wordArray;
    }

    function wordToHex(value) {
      let output = '';
      for (let index = 0; index <= 3; index += 1) {
        const byte = (value >>> (index * 8)) & 255;
        output += `0${byte.toString(16)}`.slice(-2);
      }
      return output;
    }

    const x = convertToWordArray(string);
    let a = 0x67452301;
    let b = 0xefcdab89;
    let c = 0x98badcfe;
    let d = 0x10325476;

    for (let k = 0; k < x.length; k += 16) {
      const aa = a;
      const bb = b;
      const cc = c;
      const dd = d;

      a = ff(a, b, c, d, x[k + 0], 7, 0xd76aa478);
      d = ff(d, a, b, c, x[k + 1], 12, 0xe8c7b756);
      c = ff(c, d, a, b, x[k + 2], 17, 0x242070db);
      b = ff(b, c, d, a, x[k + 3], 22, 0xc1bdceee);
      a = ff(a, b, c, d, x[k + 4], 7, 0xf57c0faf);
      d = ff(d, a, b, c, x[k + 5], 12, 0x4787c62a);
      c = ff(c, d, a, b, x[k + 6], 17, 0xa8304613);
      b = ff(b, c, d, a, x[k + 7], 22, 0xfd469501);
      a = ff(a, b, c, d, x[k + 8], 7, 0x698098d8);
      d = ff(d, a, b, c, x[k + 9], 12, 0x8b44f7af);
      c = ff(c, d, a, b, x[k + 10], 17, 0xffff5bb1);
      b = ff(b, c, d, a, x[k + 11], 22, 0x895cd7be);
      a = ff(a, b, c, d, x[k + 12], 7, 0x6b901122);
      d = ff(d, a, b, c, x[k + 13], 12, 0xfd987193);
      c = ff(c, d, a, b, x[k + 14], 17, 0xa679438e);
      b = ff(b, c, d, a, x[k + 15], 22, 0x49b40821);

      a = gg(a, b, c, d, x[k + 1], 5, 0xf61e2562);
      d = gg(d, a, b, c, x[k + 6], 9, 0xc040b340);
      c = gg(c, d, a, b, x[k + 11], 14, 0x265e5a51);
      b = gg(b, c, d, a, x[k + 0], 20, 0xe9b6c7aa);
      a = gg(a, b, c, d, x[k + 5], 5, 0xd62f105d);
      d = gg(d, a, b, c, x[k + 10], 9, 0x02441453);
      c = gg(c, d, a, b, x[k + 15], 14, 0xd8a1e681);
      b = gg(b, c, d, a, x[k + 4], 20, 0xe7d3fbc8);
      a = gg(a, b, c, d, x[k + 9], 5, 0x21e1cde6);
      d = gg(d, a, b, c, x[k + 14], 9, 0xc33707d6);
      c = gg(c, d, a, b, x[k + 3], 14, 0xf4d50d87);
      b = gg(b, c, d, a, x[k + 8], 20, 0x455a14ed);
      a = gg(a, b, c, d, x[k + 13], 5, 0xa9e3e905);
      d = gg(d, a, b, c, x[k + 2], 9, 0xfcefa3f8);
      c = gg(c, d, a, b, x[k + 7], 14, 0x676f02d9);
      b = gg(b, c, d, a, x[k + 12], 20, 0x8d2a4c8a);

      a = hh(a, b, c, d, x[k + 5], 4, 0xfffa3942);
      d = hh(d, a, b, c, x[k + 8], 11, 0x8771f681);
      c = hh(c, d, a, b, x[k + 11], 16, 0x6d9d6122);
      b = hh(b, c, d, a, x[k + 14], 23, 0xfde5380c);
      a = hh(a, b, c, d, x[k + 1], 4, 0xa4beea44);
      d = hh(d, a, b, c, x[k + 4], 11, 0x4bdecfa9);
      c = hh(c, d, a, b, x[k + 7], 16, 0xf6bb4b60);
      b = hh(b, c, d, a, x[k + 10], 23, 0xbebfbc70);
      a = hh(a, b, c, d, x[k + 13], 4, 0x289b7ec6);
      d = hh(d, a, b, c, x[k + 0], 11, 0xeaa127fa);
      c = hh(c, d, a, b, x[k + 3], 16, 0xd4ef3085);
      b = hh(b, c, d, a, x[k + 6], 23, 0x04881d05);
      a = hh(a, b, c, d, x[k + 9], 4, 0xd9d4d039);
      d = hh(d, a, b, c, x[k + 12], 11, 0xe6db99e5);
      c = hh(c, d, a, b, x[k + 15], 16, 0x1fa27cf8);
      b = hh(b, c, d, a, x[k + 2], 23, 0xc4ac5665);

      a = ii(a, b, c, d, x[k + 0], 6, 0xf4292244);
      d = ii(d, a, b, c, x[k + 7], 10, 0x432aff97);
      c = ii(c, d, a, b, x[k + 14], 15, 0xab9423a7);
      b = ii(b, c, d, a, x[k + 5], 21, 0xfc93a039);
      a = ii(a, b, c, d, x[k + 12], 6, 0x655b59c3);
      d = ii(d, a, b, c, x[k + 3], 10, 0x8f0ccc92);
      c = ii(c, d, a, b, x[k + 10], 15, 0xffeff47d);
      b = ii(b, c, d, a, x[k + 1], 21, 0x85845dd1);
      a = ii(a, b, c, d, x[k + 8], 6, 0x6fa87e4f);
      d = ii(d, a, b, c, x[k + 15], 10, 0xfe2ce6e0);
      c = ii(c, d, a, b, x[k + 6], 15, 0xa3014314);
      b = ii(b, c, d, a, x[k + 13], 21, 0x4e0811a1);
      a = ii(a, b, c, d, x[k + 4], 6, 0xf7537e82);
      d = ii(d, a, b, c, x[k + 11], 10, 0xbd3af235);
      c = ii(c, d, a, b, x[k + 2], 15, 0x2ad7d2bb);
      b = ii(b, c, d, a, x[k + 9], 21, 0xeb86d391);

      a = addUnsigned(a, aa);
      b = addUnsigned(b, bb);
      c = addUnsigned(c, cc);
      d = addUnsigned(d, dd);
    }

    return `${wordToHex(a)}${wordToHex(b)}${wordToHex(c)}${wordToHex(d)}`.toLowerCase();
  }

  function x1(value) {
    return (value & 128) ? (((value << 1) ^ 27) & 255) : (value << 1);
  }

  function x2(value) {
    return x1(value) ^ value;
  }

  function x3(value) {
    return x2(x1(value));
  }

  function x4(value) {
    return x3(x2(x1(value)));
  }

  function xe(value) {
    return x4(value) ^ x3(value) ^ x2(value);
  }

  function xx(input) {
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
  }

  function xt6(text, alphabet, endIndex) {
    const sub = alphabet.slice(0, endIndex);
    let output = '';
    for (const char of text) {
      output += sub[char.charCodeAt(0) % sub.length];
    }
    return output;
  }

  function xt4(text, alphabet) {
    let output = '';
    for (const char of text) {
      output += alphabet[char.charCodeAt(0) % alphabet.length];
    }
    return output;
  }

  function combineStrings(parts) {
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
  }

  function makeConfig(payload) {
    const config = payload ?? {};
    const detailLimit = Number.parseInt(config.detailLimit, 10);
    return {
      withDetails: config.withDetails !== false,
      detailLimit: Number.isInteger(detailLimit) && detailLimit > 0 ? detailLimit : null,
      categories: typeof config.categories === 'string'
        ? config.categories.split(',').map((value) => value.trim()).filter(Boolean)
        : Array.isArray(config.categories)
          ? config.categories.filter(Boolean)
          : null,
    };
  }

  function assertOkPayload(payload, label, stage) {
    const status = payload?.status ?? 'unknown';
    if (status === 'ok') {
      return;
    }
    throw createError(`${label} returned status ${status}.`, status, stage);
  }

  async function apiGet(route, params) {
    const ALPHABET = 'AB45STUVWZEFGJ6CH01D237IXYPQRKLMN89';
    const API_BASE = 'https://api.xiaoheihe.cn';
    const timestamp = Math.floor(Date.now() / 1000);
    const nonce = md5(`${timestamp}${Date.now()}${Math.random()}${navigator.userAgent}${location.host}`).toUpperCase();
    const normalizedPath = `/${route.split('/').filter(Boolean).join('/')}/`;
    const mixed = combineStrings([
      xt6(String(timestamp + 1), ALPHABET, -2),
      xt4(normalizedPath, ALPHABET),
      xt4(nonce, ALPHABET),
    ]).slice(0, 20);
    const digest = md5(mixed);
    const checksum = String(
      xx(digest.slice(-6).split('').map((char) => char.charCodeAt(0)))
        .reduce((sum, value) => sum + value, 0) % 100,
    ).padStart(2, '0');
    const hkey = `${xt6(digest.slice(0, 5), ALPHABET, -4)}${checksum}`;

    const query = new URLSearchParams({
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
      ...params,
    });

    const response = await fetch(`${API_BASE}${route}?${query.toString()}`, {
      credentials: 'include',
    });
    const text = await response.text();
    return JSON.parse(text);
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

  function getCategories(probe, forcedCategories) {
    if (forcedCategories?.length) {
      return forcedCategories;
    }

    const categoryFilter = probe.result?.filter_list?.find((item) => item.key === 'card_category');
    const values = (categoryFilter?.filter_items ?? []).map((item) => item.value).filter(Boolean);
    if (values.length === 0) {
      throw createError('No categories returned by card/list.', 'schema-error', 'full-sync');
    }
    return values;
  }

  async function fetchCategoryCardStats(category) {
    const items = [];
    let offset = 0;

    while (true) {
      const payload = await apiGet(LIST_ROUTE, {
        offset,
        limit: PAGE_SIZE,
        q: '',
        card_category: category,
        card_type: '',
        card_rarity: '',
        sort_by: 'win_rate',
        sort_order: 1,
      });

      assertOkPayload(payload, `card/list for category ${category}`, 'full-sync');
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

  async function fetchCardDetail(cardId) {
    const payload = await apiGet(DETAIL_ROUTE, { card_id: cardId });
    assertOkPayload(payload, `card/detail for ${cardId}`, 'full-sync');
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

  async function collectSnapshot(rawConfig) {
    const config = makeConfig(rawConfig);

    if (!location.href.startsWith(DATABASE_URL)) {
      throw createError(`Collector must run on ${DATABASE_URL}.`, 'config-error', 'probe');
    }

    const probe = await apiGet(LIST_ROUTE, buildProbeParams());
    assertOkPayload(probe, 'card/list probe', 'probe');
    const categories = getCategories(probe, config.categories);

    emit('xhh-extension:collector-log', { message: 'categories', categories });

    const rawByCategory = {};
    const allStats = [];

    for (const category of categories) {
      const categoryStats = await fetchCategoryCardStats(category);
      rawByCategory[category] = categoryStats;
      allStats.push(...categoryStats.map((item) => ({ ...item, __category: category })));
      await sleep(150);
    }

    const dedupedStats = dedupeStatsByCardId(allStats);
    let detailTargets = dedupedStats;
    if (config.detailLimit) {
      detailTargets = dedupedStats.slice(0, config.detailLimit);
    }

    const cards = [];
    if (!config.withDetails) {
      for (const stat of dedupedStats) {
        cards.push(mergeCardData(stat, null));
      }
    } else {
      for (let index = 0; index < detailTargets.length; index += 1) {
        const stat = detailTargets[index];
        emit('xhh-extension:collector-log', {
          message: 'detail',
          index: index + 1,
          total: detailTargets.length,
          cardId: stat.card_id,
        });
        const detail = await fetchCardDetail(stat.card_id);
        cards.push(mergeCardData(stat, detail));
        await sleep(120);
      }
    }

    return {
      schemaVersion: 1,
      source: 'xiaoheihe',
      game: 'slay_the_spire_2',
      syncedAt: new Date().toISOString(),
      syncMode: 'extension-fallback',
      databaseUrl: DATABASE_URL,
      categories,
      filters: probe.result?.filter_list ?? [],
      withDetails: config.withDetails,
      detailLimit: config.detailLimit,
      totalStatsCount: dedupedStats.length,
      exportedCardCount: cards.length,
      cards,
      rawByCategory,
    };
  }
})();
