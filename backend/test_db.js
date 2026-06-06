const { query } = require('./src/config/database');
const Anomaly = require('./src/models/Anomaly');

async function test() {
  try {
    const results = await Anomaly.searchForInvestigation({});
    console.log(`Results: ${results.length}`);
    if (results.length > 0) {
      console.log(results[0].anomaly_id);
    }
    process.exit(0);
  } catch (e) {
    console.error('Error:', e);
    process.exit(1);
  }
}
test();
