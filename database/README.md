# SafeArms Database

## Overview
PostgreSQL database for SafeArms Police Firearm Control Platform.

**Note:** This is a consolidated schema for demonstration purposes. No migrations needed - just run the schema and seed script.

## Requirements
- PostgreSQL 14 or higher

## Quick Setup

### 1. Create Database
```bash
# Connect to PostgreSQL
psql -U postgres

# Create database and user
CREATE DATABASE safearms;
CREATE USER safearms_user WITH PASSWORD 'secure_password123';
GRANT ALL PRIVILEGES ON DATABASE safearms TO safearms_user;
\q
```

### 2. Import Schema
```bash
psql -U safearms_user -d safearms -f schema.sql
```

### 3. Seed Demo Data
From the `backend` directory:
```bash
npm run seed
# Or: node src/scripts/seedDatabase.js
```

This will create demo users, units, officers, firearms, and ballistic profiles with user-friendly IDs.

## User-Friendly IDs

The database uses readable IDs instead of UUIDs for better demonstration:

| Entity   | ID Format     | Example      |
|----------|---------------|--------------|
| Units    | `UNIT-XXX`    | `UNIT-HQ`, `UNIT-NYA` |
| Users    | `USR-XXX`     | `USR-001`    |
| Officers | `OFF-XXX`     | `OFF-001`    |
| Firearms | `FA-XXX`      | `FA-001`     |
| Ballistic| `BP-XXX`      | `BP-001`     |

## Firearms Unit Assignment

**IMPORTANT:** Each firearm is assigned to a specific unit via `assigned_unit_id`. Station commanders can ONLY see firearms assigned to their unit.

| Unit ID   | Unit Name                  | Firearms          |
|-----------|----------------------------|-------------------|
| UNIT-HQ   | RNP Headquarters          | FA-011, FA-012    |
| UNIT-NYA  | Nyamirambo Police Station | FA-001, FA-002, FA-003 |
| UNIT-KIM  | Kimironko Police Station  | FA-004, FA-005, FA-006 |
| UNIT-REM  | Remera Police Station     | FA-007, FA-008    |
| UNIT-KIC  | Kicukiro Police Station   | FA-009, FA-010    |

## Database Structure

### Core Tables (5)
- `units` - Police units/stations  
- `users` - System users with RBAC
- `officers` - Personnel registry
- `firearms` - Firearm registry
- `ballistic_profiles` - Forensic ballistic data

### Custody & Movement (1)
- `custody_records` - Firearm assignment/return tracking with ML features

### ML System (4)
- `ml_training_features` - Feature vectors for training
- `ml_model_metadata` - Model versions and parameters
- `anomalies` - Detected anomalies with severity classification
- `anomaly_investigations` - Investigation outcomes

### Workflow (3)
- `loss_reports` - Lost/stolen firearm reports
- `destruction_requests` - Firearm disposal requests
- `procurement_requests` - New firearm acquisition requests

### Audit (1)
- `audit_logs` - Complete system audit trail

### Materialized Views (2)
- `officer_behavior_profile` - Officer custody statistics
- `firearm_usage_profile` - Firearm exchange statistics

## Default Credentials

After seeding:
- **Username:** admin
- **Password:** Admin@123
- **Email:** admin@rnp.gov.rw

⚠️ **IMPORTANT:** Change the admin password immediately after first login!

## Maintenance

### Refresh Materialized Views
```sql
REFRESH MATERIALIZED VIEW CONCURRENTLY officer_behavior_profile;
REFRESH MATERIALIZED VIEW CONCURRENTLY firearm_usage_profile;
```

### Database Backup
```bash
pg_dump -U safearms_user safearms > backup_$(date +%Y%m%d).sql
```

### Restore from Backup
```bash
psql -U safearms_user -d safearms < backup_20231215.sql
```

## Performance Optimization

The schema includes:
- ✅ Comprehensive indexes on all foreign keys and search fields
- ✅ Materialized views for ML query performance
- ✅ Triggers for automatic feature extraction
- ✅ Connection pooling support (configured in backend)

## Security Features

- ✅ Row-level security ready (can be enabled per table)
- ✅ Password hashing (bcrypt in application layer)
- ✅ Audit logging on all operations
- ✅ Check constraints on enums and values
- ✅ Foreign key integrity

## Troubleshooting

### Permission Errors
```sql
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO safearms_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO safearms_user;
```

### UUID Extension Missing
```sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
```

### Check Database Connection
```bash
psql -U safearms_user -d safearms -c "SELECT NOW();"
```
