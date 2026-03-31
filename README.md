# SafeArms - Police Firearm Control and Investigation Support Platform

## Overview
SafeArms is a centralized digital platform for the Rwanda National Police to manage firearm accountability, custody tracking, ballistic profiling, and ML-powered anomaly detection.

## Technology Stack
- **Backend:** Node.js + Express + PostgreSQL + ML.js
- **Frontend:** Flutter Web + Desktop
- **Database:** PostgreSQL 14+
- **ML Engine:** ML.js (K-Means clustering + statistical outliers)

## Features
- ✅ Dual-level firearm registration (HQ → Station)
- ✅ Email-based two-factor authentication (OTP)
- ✅ Password reset & change flow with OTP verification
- ✅ Custody management (permanent, temporary, personal long-term)
- ✅ ML-powered anomaly detection with auto-refresh monitoring
- ✅ Ballistic profile storage for investigation support
- ✅ Approval workflows (loss, destruction, procurement)
- ✅ Role-based access control (4 roles)
- ✅ Comprehensive audit logging
- ✅ PDF report export (firearm history, custody timeline, ballistic summary, anomaly, user activity, audit log)
- ✅ Forensic investigation search (single-field search, incident date, paginated results)
- ✅ Report generation for all 3 role-based dashboards (Investigator, HQ Commander, Admin)
- ✅ Copy serial number to clipboard from firearm registry

## System Architecture

```
SafeArms Platform
├── Backend (Node.js/Express)
│   ├── REST API
│   ├── JWT Authentication + Email OTP
│   ├── ML.js Anomaly Detection
│   ├── Report Generation Engine (6 report types)
│   └── PostgreSQL Database
├── Frontend (Flutter Web/Desktop)
│   ├── Role-based Dashboards (Admin, HQ, Station, Investigator)
│   ├── Management Screens
│   ├── Anomaly Investigation & Monitoring
│   ├── PDF Report Export (pdf + printing packages)
│   ├── Forensic Search with Pagination
│   └── Password Reset/Change Flow
└── Database (PostgreSQL)
    ├── Core Tables (firearms, custody, officers)
    ├── ML Tables (features, models, anomalies)
    └── Workflow Tables (approvals, reports)
```

## Quick Start

### Prerequisites
- Node.js 18+
- PostgreSQL 14+
- Flutter 3.0+
- npm or yarn

### 1. Database Setup
```bash
# Create database and user
psql -U postgres
CREATE DATABASE safearms;
CREATE USER safearms_user WITH PASSWORD 'secure_password123';
GRANT ALL PRIVILEGES ON DATABASE safearms TO safearms_user;
\q

# Import schema and seed data
psql -U safearms_user -d safearms -f database/schema.sql
psql -U safearms_user -d safearms -f database/seed_data.sql
```

### 2. Backend Setup
```bash
cd backend
npm install
cp .env.example .env  # Configure your environment
npm run dev
```

Backend runs on: http://localhost:3000

### 3. Frontend Setup
```bash
cd frontend
flutter pub get
flutter run -d chrome
```

## Default Credentials
- **Username:** admin
- **Password:** Admin@123
- **Email:** admin@rnp.gov.rw (for OTP codes)

⚠️ **Change default password immediately after first login**

## User Roles

| Role | Permissions |
|------|-------------|
| **Admin** | Full system access, user management, system configuration |
| **HQ Firearm Commander** | National oversight, HQ registration, approvals, nationwide anomaly monitoring |
| **Station Commander** | Unit-level management, custody operations, local anomaly monitoring |
| **Investigator** | Read-only investigation support, ballistic search, cross-unit tracking |

## API Endpoints

### Authentication
- `POST /api/auth/login` - Login with credentials
- `POST /api/auth/verify-otp` - Verify email OTP
- `POST /api/auth/resend-otp` - Resend OTP code
- `POST /api/auth/logout` - Logout
- `POST /api/auth/change-password` - Change password

### Core Resources
- `/api/users` - User management
- `/api/units` - Police units
- `/api/officers` - Personnel registry
- `/api/firearms` - Firearm registry
- `/api/ballistic` - Ballistic profiles
- `/api/custody` - Custody operations
- `/api/anomalies` - Anomaly management
- `/api/approvals` - Workflow approvals
- `/api/reports` - Reports and analytics
- `/api/reports/generate` - Report generation (firearm_history, custody_timeline, ballistic_summary, anomaly_summary, user_activity, audit_log)
- `/api/dashboard` - Dashboard data

## ML Anomaly Detection

SafeArms uses **ML.js** for unsupervised anomaly detection on firearm custody patterns.

### Detection Methods
1. **K-Means Clustering** (6 clusters)
2. **Statistical Outlier Detection** (z-score analysis)
3. **Ensemble Scoring** (weighted combination)

### Detected Anomalies
- ⚠️ Rapid firearm exchanges (< 1 hour between custody changes)
- ⚠️ Ballistic-access timing anomalies around custody changes
- ⚠️ Excessive custody frequency
- ⚠️ Extended custody durations
- ⚠️ Cross-unit irregular movements
- ⚠️ Shift misalignment patterns

Note: Off-hours activity (night/weekend) is treated as normal 24/7 security operations and is not a standalone anomaly signal.

### Severity Levels
- 🔴 **CRITICAL** (score ≥ 0.85) - Immediate HQ attention
- 🟠 **HIGH** (score ≥ 0.70) - Urgent review required
- 🟡 **MEDIUM** (score ≥ 0.50) - Monitor closely
- 🔵 **LOW** (score ≥ 0.35) - Informational

## Project Structure

```
safearms/
├── backend/              # Node.js API server
│   ├── src/
│   │   ├── config/      # Database, auth, server config
│   │   ├── middleware/  # Auth, RBAC, error handling
│   │   ├── models/      # Database models
│   │   ├── routes/      # API routes & handlers
│   │   ├── services/    # Business logic
│   │   ├── ml/          # ML.js anomaly detection
│   │   ├── jobs/        # Cron jobs
│   │   ├── scripts/     # DB setup, seeding, migration
│   │   └── utils/       # Utilities
│   └── logs/           # Application logs
├── frontend/            # Flutter application
│   ├── lib/
│   │   ├── config/     # API config, theme, constants
│   │   ├── models/     # Data models
│   │   ├── services/   # API clients
│   │   ├── providers/  # State management (Provider)
│   │   ├── screens/    # 20+ screens (auth, dashboards, management, workflows, anomaly, forensic)
│   │   ├── widgets/    # Reusable widgets
│   │   └── utils/      # Utilities (validators, helpers, PDF generator)
│   └── assets/         # Images, icons
└── database/            # SQL scripts
    ├── schema.sql      # Database schema
    ├── seed_data_new.sql # Seed data
    └── migrations/     # Schema migrations
```

## Environment Variables

Create `.env` file in root and backend directory:

```env
# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=safearms
DB_USER=safearms_user
DB_PASSWORD=secure_password123

# Server
NODE_ENV=development
PORT=3000

# JWT
JWT_SECRET=your_super_secret_jwt_key_min_32_chars
JWT_EXPIRES_IN=24h

# Email OTP
OTP_EXPIRES_IN=300
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your_email@gmail.com
SMTP_PASSWORD=your_app_password

# ML Engine
ML_ANOMALY_THRESHOLD=0.35
ML_CRITICAL_THRESHOLD=0.85
```

## Development Workflow

### Day 1-2: Foundation
- ✅ Database schema setup
- ✅ User authentication with email OTP
- ✅ Role-based access control

### Day 3-4: Core CRUD
- ✅ Units, users, officers, firearms management

### Day 5-6: Custody System
- ✅ Custody assignment/return
- ✅ Real-time status updates

### Day 7-8: ML Anomaly Detection
- ✅ Feature extraction
- ✅ Model training
- ✅ Real-time detection

### Day 9-10: Workflows
- ✅ Loss/destruction/procurement approvals

### Day 11-12: Frontend
- ✅ All 17 screens
- ✅ State management
- ✅ Charts and visualizations

### Day 13-14: Testing & Polish
- ✅ End-to-end testing
- ✅ Bug fixes
- ✅ Demo preparation

## Testing

### Backend Tests
```bash
cd backend
npm test
```

### API Testing
Use the provided Postman collection or:
```bash
# Login
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"Admin@123"}'

# Verify OTP (check email for code)
curl -X POST http://localhost:3000/api/auth/verify-otp \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","otp":"123456"}'
```

## Security Features
- 🔒 JWT-based authentication
- 🔒 Email-based OTP (6-digit codes)
- 🔒 Password hashing (bcrypt)
- 🔒 Role-based access control
- 🔒 Audit logging on all operations
- 🔒 SQL injection prevention (parameterized queries)
- 🔒 XSS protection (helmet.js)
- 🔒 CORS configuration
- 🔒 Rate limiting on authentication endpoints

## License
This project is developed for Rwanda National Police internal use only.

## Contributors
- **Project Type:** Final Year Project
- **Institution:** [University Name]
- **Department:** Computer Science / Software Engineering

## Support
For technical support or issues, contact: support@safearms.rnp.gov.rw
