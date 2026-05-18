require('dotenv').config();
const { query } = require('./src/config/database');
const { execSync } = require('child_process');

// Helpers for targeted anomalies
function dateAddHours(date, hours) {
    return new Date(date.getTime() + hours * 3600000);
}

function randRange(min, max) {
    return Math.random() * (max - min) + min;
}

const toSqlDate = (d) => d ? d.toISOString() : null;

async function runSeedAndTrain() {
    try {
        console.log('Fetching active firearms and officers...');
        // Only use weapons that are assigned to units natively.
        const firearmsRes = await query('SELECT * FROM firearms WHERE is_active = true AND assigned_unit_id IS NOT NULL');
        const officersRes = await query('SELECT * FROM officers WHERE is_active = true AND unit_id IS NOT NULL');
        const usersRes = await query('SELECT * FROM users LIMIT 1');
        
        let firearms = firearmsRes.rows;
        let officers = officersRes.rows;
        const issuer = usersRes.rows[0];
        
        if (!firearms.length || !officers.length || !issuer) {
            console.error('Not enough data to seed custody records.');
            process.exit(1);
        }
        
        // Group by units. We enforce that a firearm is only checked out by an officer of the SAME unit.
        const officersByUnit = {};
        officers.forEach(o => {
            if (!officersByUnit[o.unit_id]) officersByUnit[o.unit_id] = [];
            officersByUnit[o.unit_id].push(o);
        });

        // Filter firearms to only use ones where we have officers in that unit
        firearms = firearms.filter(f => officersByUnit[f.assigned_unit_id] && officersByUnit[f.assigned_unit_id].length > 0);

        if (!firearms.length) {
            console.error('No firearms matching officer units!');
            process.exit(1);
        }

        console.log(`Using ${firearms.length} matched firearms. Issued by ${issuer.user_id}`);
        
        // Let's wipe out older custody to start fresh.
        console.log('Clearing old ML-seeded custody records...');
        await query(`DELETE FROM ml_training_features WHERE custody_record_id LIKE 'CSD-%'`);
        await query(`DELETE FROM anomalies WHERE custody_record_id LIKE 'CSD-%'`).catch(() => {});
        await query(`DELETE FROM custody_records WHERE custody_id LIKE 'CSD-%'`);

        let count = 0;
        const insertPromises = [];
        
        // Simulation window: Last 21 days
        const simStart = new Date();
        simStart.setDate(simStart.getDate() - 21);
        simStart.setHours(0,0,0,0);
        
        const custodyRecordsToInsert = [];

        // BASELINE GENERATOR
        // Iterate through days, generate 85-90% normal records
        console.log('Generating Baseline / Normal records...');
        for(let day = 0; day <= 21; day++) {
             let currentDay = new Date(simStart.getTime());
             currentDay.setDate(currentDay.getDate() + day);
             
             // 10-15 random interactions across the units per day
             for(let i=0; i<15; i++) {
                 const firearm = firearms[Math.floor(Math.random() * firearms.length)];
                 const unitOfficers = officersByUnit[firearm.assigned_unit_id];
                 const officer = unitOfficers[Math.floor(Math.random() * unitOfficers.length)];

                 // Standard shift start between 6am and 9am
                 let issueTime = new Date(currentDay.getTime());
                 issueTime.setHours(Math.floor(randRange(6, 9)), Math.floor(randRange(0, 59)), 0);

                 // Normal duration: 8 to 12 hours
                 let durationH = randRange(8, 12);
                 let returnTime = dateAddHours(issueTime, durationH);

                 custodyRecordsToInsert.push({
                     firearm_id: firearm.firearm_id,
                     officer_id: officer.officer_id,
                     unit_id: firearm.assigned_unit_id,
                     custody_type: 'temporary',
                     issued_at: issueTime,
                     returned_at: returnTime,
                     is_anomaly: false
                 });
             }
        }

        // ANOMALY GENERATOR (10-15%)
        console.log('Generating Explicit Anomalies...');
        
        // Setup Anomaly 1: Excessive Transfers > 6 in a day (Same Firearm)
        const anomalyFirearm1 = firearms[0];
        const a1Officers = officersByUnit[anomalyFirearm1.assigned_unit_id];
        let a1Date = new Date(simStart.getTime());
        a1Date.setDate(a1Date.getDate() + 5);
        for(let t=0; t<8; t++) {
             let issueTime = new Date(a1Date.getTime());
             issueTime.setHours(6 + t, 0, 0); // one every hour
             let returnTime = dateAddHours(issueTime, 0.5); // returned 30 mins later
             custodyRecordsToInsert.push({
                 firearm_id: anomalyFirearm1.firearm_id,
                 officer_id: a1Officers[t % a1Officers.length].officer_id,
                 unit_id: anomalyFirearm1.assigned_unit_id,
                 custody_type: 'temporary',
                 issued_at: issueTime,
                 returned_at: returnTime,
                 is_anomaly: true
             });
        }

        // Setup Anomaly 2: Extreme Custody Durations (< 2 hr and > 48 hr)
        const anomalyFirearm2 = firearms[1];
        const a2Officers = officersByUnit[anomalyFirearm2.assigned_unit_id];
        let a2Date = new Date(simStart.getTime());
        a2Date.setDate(a2Date.getDate() + 10);
        // Short
        custodyRecordsToInsert.push({
            firearm_id: anomalyFirearm2.firearm_id,
            officer_id: a2Officers[0].officer_id,
            unit_id: anomalyFirearm2.assigned_unit_id,
            custody_type: 'temporary',
            issued_at: dateAddHours(a2Date, 8),
            returned_at: dateAddHours(a2Date, 8.5), // 30 min duration
            is_anomaly: true
        });
        // Long
        custodyRecordsToInsert.push({
            firearm_id: anomalyFirearm2.firearm_id,
            officer_id: a2Officers[1].officer_id,
            unit_id: anomalyFirearm2.assigned_unit_id,
            custody_type: 'temporary',
            issued_at: dateAddHours(a2Date, 8),
            returned_at: dateAddHours(a2Date, 60), // 52 hours later
            is_anomaly: true
        });

        // Setup Anomaly 3: High Officer Rotation (>3 per shift)
        const anomalyOfficer = officers[0];
        let anomalyUnitFirearms = firearms.filter(f => f.assigned_unit_id === anomalyOfficer.unit_id);
        let a3Date = new Date(simStart.getTime());
        a3Date.setDate(a3Date.getDate() + 15);
        if(anomalyUnitFirearms.length >= 4) {
            for(let r=0; r<5; r++) {
               let issueTime = new Date(a3Date.getTime());
               issueTime.setHours(7 + r * 2, 0, 0); // 7am, 9am, 11am...
               let returnTime = dateAddHours(issueTime, 1);
               custodyRecordsToInsert.push({
                    firearm_id: anomalyUnitFirearms[r % anomalyUnitFirearms.length].firearm_id,
                    officer_id: anomalyOfficer.officer_id,
                    unit_id: anomalyOfficer.unit_id,
                    custody_type: 'temporary',
                    issued_at: issueTime,
                    returned_at: returnTime,
                    is_anomaly: true
               });
            }
        }

        // Insert All
        console.log(`Writing ${custodyRecordsToInsert.length} records to DB...`);
        for (let idx = 0; idx < custodyRecordsToInsert.length; idx++) {
            let cr = custodyRecordsToInsert[idx];
            let shortStamp = ('000000' + idx).slice(-6);
            let custodyId = `CSD-ML-${shortStamp}`;
            let expectedReturnDate = dateAddHours(cr.issued_at, 12);
            
            // Generate durations natively
            const durationSec = Math.floor((cr.returned_at - cr.issued_at)/1000);
            
            const sql = `
                INSERT INTO custody_records (
                    custody_id, firearm_id, officer_id, unit_id, custody_type, 
                    issued_at, issued_by, expected_return_date, returned_at, returned_to, 
                    return_condition, assignment_reason, custody_duration_seconds
                ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
            `;
            
            const values = [
                custodyId, cr.firearm_id, cr.officer_id, cr.unit_id, cr.custody_type, 
                toSqlDate(cr.issued_at), issuer.user_id, toSqlDate(expectedReturnDate), toSqlDate(cr.returned_at),
                issuer.user_id, 'good', cr.is_anomaly ? 'Anomaly Injection' : 'Routine patrol',
                durationSec
            ];
            
            await query(sql, values);
            count++;
        }

        console.log(`Successfully generated and inserted ${count} intelligent seed records.`);
        
        console.log('Generating ML features...');
        execSync('node src/scripts/populateTrainingFeatures.js', { stdio: 'inherit' });
        
        console.log('Training ML model step skipped for manual trigger...');
        // execSync('node src/scripts/trainModel.js', { stdio: 'inherit' });
        
        console.log('PROCESS SUCCESS: Custody records seeded and features generated.');
        process.exit(0);
    } catch (e) {
        console.error('Error during execution: ', e);
        process.exit(1);
    }
}

runSeedAndTrain();
