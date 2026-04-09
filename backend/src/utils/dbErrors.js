const TRANSIENT_DB_ERROR_CODES = new Set([
    'ENOTFOUND',
    'EAI_AGAIN',
    'ETIMEDOUT',
    'ECONNRESET',
    'ECONNREFUSED',
    'EHOSTUNREACH',
    '08000',
    '08001',
    '08003',
    '08004',
    '08006',
    '57P01',
    '57P02',
    '57P03',
    '53300',
    '57014'
]);

const TRANSIENT_DB_MESSAGE_SNIPPETS = [
    'query read timeout',
    'getaddrinfo enotfound',
    'connection terminated unexpectedly',
    'could not connect to server',
    'too many clients already',
    'timeout expired'
];

const hasTransientDatabaseMessage = (message) => {
    if (!message) return false;

    const normalizedMessage = String(message).toLowerCase();
    return TRANSIENT_DB_MESSAGE_SNIPPETS.some((snippet) => normalizedMessage.includes(snippet));
};

const isTransientDatabaseError = (error) => {
    if (!error) return false;

    const code = String(error.code || '').toUpperCase();
    if (TRANSIENT_DB_ERROR_CODES.has(code)) {
        return true;
    }

    return hasTransientDatabaseMessage(error.message);
};

module.exports = {
    TRANSIENT_DB_ERROR_CODES,
    hasTransientDatabaseMessage,
    isTransientDatabaseError
};
