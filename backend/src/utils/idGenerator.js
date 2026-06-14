const logger = require('./logger');

const MISSING_SEQUENCE_CODES = new Set(['42P01', '42704']);

const isMissingSequenceError = (error) => (
    error && MISSING_SEQUENCE_CODES.has(String(error.code || '').toUpperCase())
);

const nextIdFromSequence = async (client, sequenceName, prefix, padLength) => {
    const result = await client.query(
        `WITH next_value AS (
            SELECT nextval($2::regclass)::TEXT AS value
        )
        SELECT $1 ||
            CASE
                WHEN LENGTH(value) >= $3 THEN value
                ELSE LPAD(value, $3, '0')
            END AS next_id
        FROM next_value`,
        [prefix, sequenceName, padLength]
    );
    return result.rows[0].next_id;
};

const nextIdFromMaxFallback = async (client, {
    tableName,
    idColumn,
    prefix,
    substringStart,
    padLength,
    advisoryLockKey
}) => {
    await client.query('SELECT pg_advisory_xact_lock($1)', [advisoryLockKey]);

    const result = await client.query(
        `WITH next_value AS (
            SELECT CAST(COALESCE(MAX(CAST(SUBSTRING(${idColumn} FROM ${substringStart}) AS INTEGER)), 0) + 1 AS TEXT) AS value
            FROM ${tableName}
            WHERE ${idColumn} ~ $3
        )
        SELECT $1 ||
            CASE
                WHEN LENGTH(value) >= $2 THEN value
                ELSE LPAD(value, $2, '0')
            END AS next_id
        FROM next_value`,
        [prefix, padLength, `^${prefix}[0-9]+$`]
    );

    return result.rows[0].next_id;
};

const nextPrefixedId = async (client, options) => {
    const {
        sequenceName,
        prefix,
        padLength
    } = options;

    try {
        return await nextIdFromSequence(client, sequenceName, prefix, padLength);
    } catch (error) {
        if (!isMissingSequenceError(error)) {
            throw error;
        }

        logger.warn(`ID sequence ${sequenceName} is missing; using locked MAX fallback`);
        return nextIdFromMaxFallback(client, options);
    }
};

const nextFirearmId = (client) => nextPrefixedId(client, {
    sequenceName: 'firearms_id_seq',
    tableName: 'firearms',
    idColumn: 'firearm_id',
    prefix: 'FA-',
    substringStart: 4,
    padLength: 3,
    advisoryLockKey: 957401
});

const nextBallisticProfileId = (client) => nextPrefixedId(client, {
    sequenceName: 'ballistic_profiles_id_seq',
    tableName: 'ballistic_profiles',
    idColumn: 'ballistic_id',
    prefix: 'BP-',
    substringStart: 4,
    padLength: 3,
    advisoryLockKey: 957402
});

const nextAnomalyId = (client) => nextPrefixedId(client, {
    sequenceName: 'anomalies_id_seq',
    tableName: 'anomalies',
    idColumn: 'anomaly_id',
    prefix: 'ANOM-',
    substringStart: 6,
    padLength: 3,
    advisoryLockKey: 947215
});

const nextInvestigationId = (client) => nextPrefixedId(client, {
    sequenceName: 'anomaly_investigations_id_seq',
    tableName: 'anomaly_investigations',
    idColumn: 'investigation_id',
    prefix: 'INV-',
    substringStart: 5,
    padLength: 3,
    advisoryLockKey: 947214
});

module.exports = {
    nextFirearmId,
    nextBallisticProfileId,
    nextAnomalyId,
    nextInvestigationId
};
