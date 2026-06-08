require('dotenv').config();

const baseUrl = (process.env.API_BASE_URL || 'http://localhost:3000').replace(/\/$/, '');
const defaultToken = process.env.REPORT_SMOKE_TOKEN;

const scenarios = [
    {
        name: 'HQ firearm history',
        type: 'firearm_history',
        token: process.env.HQ_REPORT_SMOKE_TOKEN || defaultToken,
        expectedKeys: ['firearms', 'custody_records', 'unit_history', 'anomalies']
    },
    {
        name: 'HQ ballistic summary',
        type: 'ballistic_summary',
        token: process.env.HQ_REPORT_SMOKE_TOKEN || defaultToken,
        expectedKeys: ['profiles', 'investigator_activities', 'recent_custody_logs']
    },
    {
        name: 'HQ anomaly summary',
        type: 'anomaly_summary',
        token: process.env.HQ_REPORT_SMOKE_TOKEN || defaultToken,
        expectedKeys: ['anomalies', 'anomaly_groups', 'summary']
    },
    {
        name: 'Admin user activity',
        type: 'user_activity',
        token: process.env.ADMIN_REPORT_SMOKE_TOKEN || defaultToken,
        expectedKeys: ['activities']
    }
];

const assert = (condition, message) => {
    if (!condition) {
        throw new Error(message);
    }
};

const runScenario = async (scenario) => {
    assert(scenario.token, `Missing token for ${scenario.name}`);

    const url = new URL('/api/reports/generate', baseUrl);
    url.searchParams.set('type', scenario.type);
    url.searchParams.set('limit', '5');

    const response = await fetch(url, {
        headers: {
            Authorization: `Bearer ${scenario.token}`,
            Accept: 'application/json'
        }
    });

    const payload = await response.json().catch(() => ({}));
    assert(response.ok, `${scenario.name} failed: ${response.status} ${payload.message || ''}`);
    assert(payload.success === true, `${scenario.name} did not return success=true`);
    assert(payload.data && typeof payload.data === 'object', `${scenario.name} did not return data object`);

    for (const key of scenario.expectedKeys) {
        assert(
            Object.prototype.hasOwnProperty.call(payload.data, key),
            `${scenario.name} missing data.${key}`
        );
    }

    console.log(`ok - ${scenario.name}`);
};

const main = async () => {
    for (const scenario of scenarios) {
        await runScenario(scenario);
    }
};

main().catch(error => {
    console.error(error.message);
    process.exit(1);
});
