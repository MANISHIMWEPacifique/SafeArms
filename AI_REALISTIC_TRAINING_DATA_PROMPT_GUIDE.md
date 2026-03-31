# AI Prompt Guide: Realistic Synthetic Training Data

## Purpose
Use this guide when asking AI to generate realistic, synthetic custody data for SafeArms anomaly model training.

Important:
- Generate synthetic data only.
- Do not use real names, real incidents, or confidential records.
- The Admin Settings "Generate data" action is intentionally not used.
- Off-hours activity (night/weekend) is normal in 24/7 security operations and must not be treated as a standalone anomaly.

## 1) Collect valid IDs first
Before prompting AI, collect valid IDs from your database so generated rows pass foreign-key checks.

```sql
-- Units
SELECT unit_id FROM units WHERE is_active = true ORDER BY unit_id;

-- Officers
SELECT officer_id, unit_id FROM officers WHERE is_active = true ORDER BY officer_id;

-- Firearms that can appear in custody records
SELECT firearm_id, assigned_unit_id, current_status
FROM firearms
WHERE is_active = true
ORDER BY firearm_id;

-- Users who can issue/receive custody (admin/commanders)
SELECT user_id, role FROM users ORDER BY user_id;
```

Copy the results and provide them to AI in the prompt.

## 2) Use this prompt template with AI
Copy and edit this prompt when you want a new batch.

```text
Generate PostgreSQL SQL for SafeArms synthetic custody training data.
Return SQL only (no explanation).

Context:
- This is synthetic data for model training only.
- Must look operationally realistic for police custody workflows.
- Keep IDs within VARCHAR(20).

Use ONLY these IDs:
- unit_id list: <PASTE_UNIT_IDS>
- officer_id list with their unit_id: <PASTE_OFFICER_MAP>
- firearm_id list with assigned_unit_id: <PASTE_FIREARM_MAP>
- issued_by / returned_to user_id list: <PASTE_ALLOWED_USER_IDS>

Schema/constraints for custody_records:
- custody_id (VARCHAR(20), unique)
- firearm_id (FK)
- officer_id (FK)
- unit_id (FK)
- custody_type IN ('permanent','temporary','personal_long_term')
- issued_at TIMESTAMP
- issued_by (FK users.user_id)
- expected_return_date DATE (optional)
- returned_at TIMESTAMP (optional)
- returned_to (FK users.user_id, optional)
- return_condition IN ('good','fair','needs_maintenance','damaged') (optional)
- assignment_reason TEXT
- notes TEXT
- custody_duration_seconds INTEGER
- issue_hour INTEGER (0-23)
- issue_day_of_week INTEGER (0-6, PostgreSQL DOW)
- is_night_issue BOOLEAN
- is_weekend_issue BOOLEAN

Data quality requirements:
- Generate exactly <TOTAL_ROWS> rows.
- Baseline normal operations: 80-90% of rows.
- Controlled anomaly patterns: 10-20% of rows.
- Cover at least 3 units.
- Include weekday, weekend, and night activity.
- Do not create anomaly cases where the only risk signal is off-hours timing.
- Ensure realistic shift times and return durations.
- Ensure custody_duration_seconds matches (returned_at - issued_at).
- Ensure is_night_issue and is_weekend_issue match issued_at.
- Use ON CONFLICT (custody_id) DO NOTHING.

Required anomaly patterns:
1) Excessive same-firearm transfers in one day (>6)
2) Very short custody (<1 hour)
3) Very long custody (>12 hours)
4) Officer handling too many different firearms in one shift
5) Cross-unit movement edge cases

Output format requirements:
- One SQL script wrapped in:
  BEGIN;
  ALTER TABLE custody_records DISABLE TRIGGER trg_update_firearm_status;
  INSERT INTO custody_records (...) VALUES (...), (...), ... ON CONFLICT (custody_id) DO NOTHING;
  ALTER TABLE custody_records ENABLE TRIGGER trg_update_firearm_status;
  COMMIT;

ID convention:
- Use custody_id pattern like CUS-AI2603-0001 (must stay <= 20 chars).
- Keep timestamps within range: <START_DATE> to <END_DATE>.
```

## 3) Save and execute
Save AI output to:
- `database/training/training_ai_generated.sql`

Execute it:

```bash
psql -U <db_user> -d <db_name> -f database/training/training_ai_generated.sql
```

## 4) Extract features and train
After inserting synthetic custody rows:

```bash
cd backend
node src/scripts/populateTrainingFeatures.js
node src/scripts/trainModel.js
```

You can also train from Admin Settings using "Train model".

## 5) Quick validation checklist
Run these checks after load:

```sql
-- Total rows inserted for this AI batch prefix
SELECT COUNT(*) FROM custody_records WHERE custody_id LIKE 'CUS-AI%';

-- Duration consistency check
SELECT custody_id
FROM custody_records
WHERE custody_id LIKE 'CUS-AI%'
  AND returned_at IS NOT NULL
  AND ABS(custody_duration_seconds - EXTRACT(EPOCH FROM (returned_at - issued_at))::int) > 60;

-- Night flag consistency check
SELECT custody_id
FROM custody_records
WHERE custody_id LIKE 'CUS-AI%'
  AND ((issue_hour >= 22 OR issue_hour < 6) <> is_night_issue);

-- Weekend flag consistency check
SELECT custody_id
FROM custody_records
WHERE custody_id LIKE 'CUS-AI%'
  AND ((issue_day_of_week IN (0,6)) <> is_weekend_issue);
```

If any check returns rows, regenerate or correct the SQL before training.
