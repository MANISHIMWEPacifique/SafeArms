const assert = require('assert');

const databasePath = require.resolve('../config/database');
const capturedQueries = [];

require.cache[databasePath] = {
    id: databasePath,
    filename: databasePath,
    loaded: true,
    exports: {
        query: async (sql, params = []) => {
            capturedQueries.push({ sql, params });
            if (/COUNT\s*\(\s*DISTINCT\s+bp\.ballistic_id\s*\)/i.test(sql)) {
                return { rows: [{ total: '0' }] };
            }
            return { rows: [] };
        },
        withTransaction: async (callback) => callback({ query: async () => ({ rows: [] }) })
    }
};

const BallisticProfile = require('../models/BallisticProfile');

const captureSearch = async (params) => {
    capturedQueries.length = 0;
    await BallisticProfile.search(params);
    return capturedQueries.map((entry) => ({
        sql: entry.sql.replace(/\s+/g, ' ').trim(),
        params: entry.params
    }));
};

const countQuery = (queries) => queries.find((entry) => /COUNT\s*\(\s*DISTINCT\s+bp\.ballistic_id\s*\)/i.test(entry.sql));

const run = async () => {
    let queries = await captureSearch({ caliber: '7.62' });
    let count = countQuery(queries);
    assert(count, 'Expected a count query for caliber search');
    assert.deepStrictEqual(count.params, ['7.62%', '762%']);
    assert(!count.params.some((param) => String(param).startsWith('%')), 'Search params must not use leading wildcards');

    queries = await captureSearch({ caliber: '9mm' });
    count = countQuery(queries);
    assert.deepStrictEqual(count.params, ['9mm%', '9mm%']);

    queries = await captureSearch({ caliber: '9' });
    count = countQuery(queries);
    assert.deepStrictEqual(count.params, ['9%', '9%']);

    queries = await captureSearch({ search: 'AK-47', firing_pin: 'does-not-match' });
    count = countQuery(queries);
    assert(count.sql.includes('ILIKE $1'), 'General search should use case-insensitive prefix matching');
    assert(count.sql.includes('ILIKE $3'), 'Firing pin search should use case-insensitive prefix matching');
    assert(/\)\s+AND\s+\(\(/.test(count.sql), 'Independent criteria must be joined with AND');
    assert.deepStrictEqual(count.params, ['does-not-match%', 'doesnotmatch%', 'AK-47%', 'ak47%']);

    queries = await captureSearch({ search: 'ak-47' });
    count = countQuery(queries);
    assert(count.sql.includes('ILIKE $1'), 'Raw search must remain case-insensitive');
    assert.deepStrictEqual(count.params, ['ak-47%', 'ak47%']);

    queries = await captureSearch({ breech_face: 'Semi-circular' });
    count = countQuery(queries);
    assert(count.sql.includes('bp.ejector_marks'), 'Breech face search must include ejector marks');
    assert(count.sql.includes('bp.extractor_marks'), 'Breech face search must include extractor marks');
    assert.deepStrictEqual(count.params, ['Semi-circular%', 'semicircular%']);

    console.log('Forensic search narrowing regression checks passed.');
};

run().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
