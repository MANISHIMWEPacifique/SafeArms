const { query } = require('../config/database');
const logger = require('../utils/logger');

const parsePositiveInt = (value, fallback) => {
    const parsed = Number.parseInt(value, 10);
    return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
};

const SYSTEM_SETTINGS_CACHE_TTL_MS = parsePositiveInt(
    process.env.SYSTEM_SETTINGS_CACHE_TTL_MS || process.env.SETTINGS_CACHE_TTL_MS,
    30000
);

const settingsCache = {
    values: new Map(),
    cachedAt: 0
};

const isCacheFresh = () => {
    if (settingsCache.cachedAt <= 0) {
        return false;
    }

    return Date.now() - settingsCache.cachedAt <= SYSTEM_SETTINGS_CACHE_TTL_MS;
};

const refreshSystemSettingsCache = async () => {
    const result = await query('SELECT setting_key, setting_value FROM system_settings');
    const nextValues = new Map();

    for (const row of result.rows) {
        nextValues.set(row.setting_key, row.setting_value);
    }

    settingsCache.values = nextValues;
    settingsCache.cachedAt = Date.now();
    return nextValues;
};

const ensureSystemSettingsCache = async ({ forceRefresh = false } = {}) => {
    if (!forceRefresh && isCacheFresh()) {
        return settingsCache.values;
    }

    try {
        return await refreshSystemSettingsCache();
    } catch (error) {
        logger.error('Error refreshing system settings cache:', error);

        if (settingsCache.values.size > 0) {
            return settingsCache.values;
        }

        return new Map();
    }
};

const getSystemSettings = async (keys = [], { forceRefresh = false } = {}) => {
    const cacheValues = await ensureSystemSettingsCache({ forceRefresh });
    const keyList = Array.isArray(keys) ? keys.filter(Boolean) : [];

    if (keyList.length === 0) {
        return Object.fromEntries(cacheValues);
    }

    const selected = {};
    for (const key of keyList) {
        if (cacheValues.has(key)) {
            selected[key] = cacheValues.get(key);
        }
    }

    return selected;
};

const getSystemSetting = async (key, fallbackValue = undefined) => {
    if (!key) return fallbackValue;

    const settings = await getSystemSettings([key]);
    return Object.prototype.hasOwnProperty.call(settings, key)
        ? settings[key]
        : fallbackValue;
};

const mergeSystemSettingsCache = (partialSettings = {}) => {
    if (!partialSettings || typeof partialSettings !== 'object') {
        return;
    }

    for (const [key, value] of Object.entries(partialSettings)) {
        if (typeof key === 'string' && key.trim().length > 0) {
            settingsCache.values.set(key, value);
        }
    }

    settingsCache.cachedAt = Date.now();
};

const clearSystemSettingsCache = () => {
    settingsCache.values = new Map();
    settingsCache.cachedAt = 0;
};

module.exports = {
    SYSTEM_SETTINGS_CACHE_TTL_MS,
    getSystemSetting,
    getSystemSettings,
    mergeSystemSettingsCache,
    clearSystemSettingsCache,
    refreshSystemSettingsCache
};
