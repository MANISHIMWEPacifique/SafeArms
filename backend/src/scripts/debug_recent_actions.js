const { query } = require('../config/database');

async function debugRecentActions() {
    try {
        console.log("Debugging Recent Actions...");

        // 1. Check total count in audit_logs
        const countResult = await query('SELECT COUNT(*) FROM audit_logs');
        console.log(`Total audit_logs count: ${countResult.rows[0].count}`);

        // 2. Check count of successful logs
        const successCount = await query('SELECT COUNT(*) FROM audit_logs WHERE success = true');
        console.log(`Successful audit_logs count: ${successCount.rows[0].count}`);

        // 3. Run the exact query used in the dashboard route
        // Simulating admin user (no unit filter)
        const recentQueryResult = await query(`
            SELECT 
                al.log_id, al.action_type, al.table_name,
                al.record_id, al.created_at, al.success,
                u.full_name as actor_name,
                COALESCE(
                    al.new_values->>'subject_name',
                    al.new_values->>'subject_type',
                    al.table_name
                ) as subject_description
            FROM audit_logs al
            LEFT JOIN users u ON al.user_id = u.user_id
            WHERE al.success = true
            ORDER BY al.created_at DESC
            LIMIT 10
        `);

        console.log("\nRecent Activities Query Result:");
        console.table(recentQueryResult.rows);

        if (recentQueryResult.rows.length === 0) {
            console.log("⚠️ No recent activities found with the dashboard query!");
            
            // 4. Check if there are any logs at all without the join
            const rawLogs = await query('SELECT * FROM audit_logs ORDER BY created_at DESC LIMIT 5');
            console.log("\nRaw Audit Logs (Latest 5):");
            console.table(rawLogs.rows);
        }

    } catch (error) {
        console.error("Error during debugging:", error);
    }
}

debugRecentActions();
