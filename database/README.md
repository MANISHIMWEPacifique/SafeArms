# SafeArms Database

## Overview
PostgreSQL database for SafeArms Police Firearm Control Platform.

## Requirements
- PostgreSQL 14 or higher
- UUID extension (uuid-ossp)

## Setup Instructions

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

### 3. Generate Admin Password Hash
Before importing seed data, generate the password hash:

```javascript
// Run in Node.js
const bcrypt = require('bcrypt');
bcrypt.hash('Admin@123', 10).then(hash => {
    console.log('Replace password_hash in seed_data.sql with:');
    console.log(hash);
});
```

Update `seed_data.sql` with the generated hash, then import:

```bash
psql -U safearms_user -d safearms -f seed_data.sql
```

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
