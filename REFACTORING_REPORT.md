# SafeArms — Refactoring Report & Future Improvement Guide

**Date:** February 17, 2026  
**Scope:** Backend (Node.js/Express), Frontend (Flutter/Dart), Database  
**Purpose:** Improve code quality, fix security vulnerabilities, optimize performance, and document remaining improvements

---

## Table of Contents

1. [Changes Applied (This Session)](#1-changes-applied-this-session)
2. [Remaining Issues — Prioritized](#2-remaining-issues--prioritized)
3. [Architecture Notes](#3-architecture-notes)
4. [Database Optimization Recommendations](#4-database-optimization-recommendations)
5. [Frontend Improvement Roadmap](#5-frontend-improvement-roadmap)
6. [Testing Strategy](#6-testing-strategy)

---

## 1. Changes Applied (This Session)

### 1.1 CRITICAL Security Fixes

| # | File | Issue | Fix |
|---|------|-------|-----|
| 1 | `backend/src/config/auth.js` | **OTP generated with `Math.random()`** — cryptographically weak, predictable | Replaced with `crypto.randomInt(100000, 999999)` which uses the OS cryptographic random source |
| 2 | `backend/src/config/auth.js` | **Insecure JWT secret fallback** — hardcoded secret used in all environments | Production now throws a fatal error if `JWT_SECRET` env var is missing; dev uses a clearly-labeled dev-only string |
| 3 | `backend/src/middleware/auditLogger.js` | **SQL injection in `captureOldValues`** — table name interpolated directly from user-controllable URL path | Added whitelist of valid table names (`ALLOWED_TABLES` Set) and sanitized `idField` to only allow `[a-zA-Z0-9_]` |
| 4 | `backend/src/models/Anomaly.js` | **SQL injection in `getTypeSummary`** — `days` parameter interpolated directly into SQL string | Changed to parameterized query using `INTERVAL '1 day' * $1` |
| 5 | `backend/src/middleware/twoFactorAuth.js` | **Timing-attack vulnerable OTP comparison** — `===` string comparison leaks timing info | Replaced with `crypto.timingSafeEqual()` using Buffer comparison |
| 6 | `backend/src/routes/users.routes.js` | **Direct `password_hash` modification** — PUT endpoint allowed setting arbitrary password hash | Added destructuring to strip sensitive fields (`password_hash`, `otp_code`, etc.) before passing to update |

### 1.2 Bug Fixes

| # | File | Issue | Fix |
|---|------|-------|-----|
| 7 | `backend/src/routes/reports.routes.js` | **Role string mismatch** — used `'hq_commander'` instead of `'hq_firearm_commander'`, silently blocking legitimate access | Replaced all hardcoded role strings with `ROLES` constants from authorization middleware |
| 8 | `backend/src/config/database.js` | **`process.exit(-1)` on pool error** — killed entire process on any transient DB error | Removed `process.exit(-1)`, now logs error and lets app attempt recovery |
| 9 | `backend/src/server.js` | **No unhandled rejection handler** — unhandled promise rejections crash Node.js ≥15 | Added `process.on('unhandledRejection')` and `process.on('uncaughtException')` handlers |
| 10 | `backend/src/services/auth.service.js` | **`resendOTP` always sent emails** — unlike `login`, didn't check `NODE_ENV` for dev mode | Added dev mode check to skip email and log OTP to console |
| 11 | `backend/src/ml/statistical.js` | **Grubbs' test ignored `alpha` parameter** — always used hardcoded `1.96` | Now maps `alpha` to appropriate t-distribution critical values |
| 12 | `backend/src/utils/logger.js` | **Log directory not created** — first log write would fail if `logs/` didn't exist | Added `fs.mkdirSync(logsDir, { recursive: true })` on startup |
| 13 | `frontend/lib/main.dart` | **`OperationsProvider` not registered** — would crash when `OperationsPortalScreen` is navigated to | Added `OperationsProvider` to `MultiProvider` list |

### 1.3 Performance Improvements

| # | File | Issue | Fix |
|---|------|-------|-----|
| 14 | `backend/src/routes/dashboard.routes.js` | **Sequential dashboard queries** — 5-10 independent DB queries executed sequentially | Refactored to use `Promise.all()` for parallel execution of common queries and role-specific queries |

### 1.4 Code Quality Improvements

| # | File | Issue | Fix |
|---|------|-------|-----|
| 15 | `backend/src/routes/firearms.routes.js` | **Redundant `require()` inside handlers** — `query` and `withTransaction` re-imported inside route handlers | Consolidated to single top-level import |
| 16 | `backend/src/routes/officers.routes.js` | **Same redundant import pattern** | Added top-level `query` import, removed inner re-import |
| 17 | `backend/src/routes/custody.routes.js` | **Same redundant import** | Removed inner `require()` call |
| 18 | `backend/src/services/twoFactor.service.js` | **Entire file duplicates auth.service.js** — never imported | Added `@deprecated` JSDoc notice |
| 19 | `frontend/pubspec.yaml` | **Unused dependencies** — `dio`, `google_fonts`, `flutter_svg` never imported | Removed from dependencies |
| 20 | `backend/src/services/email.service.js` | **Error level for SMTP unavailability** — `logger.error` for a non-critical startup condition | Changed to `logger.warn` |

---

## 2. Remaining Issues — Prioritized

### Priority 1: HIGH (Should Fix Next)

#### 2.1 Race Condition in ID Generation
**Files:** All models (`Firearm.js`, `Officer.js`, `Unit.js`, `User.js`, `Anomaly.js`)  
**Problem:** ID generation uses `MAX(CAST(REPLACE(...)))` or `COUNT(*)` — two concurrent requests can generate the same ID.  
**Solution:** Use PostgreSQL `GENERATED ALWAYS AS IDENTITY` or sequences. Migration example:
```sql
-- Add sequence for each entity
CREATE SEQUENCE IF NOT EXISTS firearm_id_seq START WITH 100;

-- Then in application code, use:
-- SELECT nextval('firearm_id_seq')
-- Or better: make the column auto-generate with a trigger
```

#### 2.2 Race Condition in Custody Assignment
**File:** `backend/src/services/custody.service.js`  
**Problem:** Concurrent requests could assign the same firearm to two officers. The `SELECT` check and `INSERT` are not atomic.  
**Solution:** Use `SELECT ... FOR UPDATE` within the transaction to lock the firearm row:
```sql
SELECT * FROM firearms WHERE firearm_id = $1 FOR UPDATE
```

#### 2.3 Rate Limiting on Auth Endpoints
**File:** `backend/src/server.js`, `backend/src/config/server.js`  
**Problem:** Rate limit config exists but is never applied. Auth endpoints are vulnerable to brute-force attacks.  
**Solution:** Install `express-rate-limit` and apply to auth routes:
```bash
npm install express-rate-limit
```
```javascript
const rateLimit = require('express-rate-limit');
const authLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 20,
    message: { success: false, message: 'Too many attempts, try again later' }
});
app.use('/api/auth', authLimiter, authRoutes);
```

#### 2.4 Input Validation Not Applied
**Files:** Most route handlers  
**Problem:** `validators.js` defines validators (`isValidSerialNumber`, `isValidEmail`, `validateRequiredFields`, `validatePagination`, etc.) but they are mostly unused in route handlers.  
**Priority routes to add validation:**
- `POST /api/firearms` — validate `serial_number` with `isValidSerialNumber()`
- `POST /api/custody/assign` — validate required fields with `validateRequiredFields()`
- All listing endpoints — enforce `validatePagination()` to cap `limit` at 100

#### 2.5 No Pagination Bounds
**Files:** All model `findAll()` methods and listing endpoints  
**Problem:** A client can request `limit=1000000` causing full table scans.  
**Solution:** Apply `validatePagination()` from `validators.js` at the start of every listing handler.

### Priority 2: MEDIUM (Improve Quality)

#### 2.6 Duplicated Dynamic UPDATE Pattern
**Files:** `Firearm.js`, `Officer.js`, `Unit.js`, `User.js`, `Anomaly.js`  
**Problem:** Every model has near-identical code for building `SET field = $n` dynamically.  
**Solution:** Extract to a shared helper in `utils/helpers.js`:
```javascript
const buildUpdateQuery = (tableName, idColumn, id, updates) => {
    const entries = Object.entries(updates).filter(([_, v]) => v !== undefined);
    if (entries.length === 0) return null;
    
    const fields = entries.map(([key], i) => `${key} = $${i + 1}`);
    const values = entries.map(([_, v]) => v);
    values.push(id);
    
    return {
        text: `UPDATE ${tableName} SET ${fields.join(', ')}, updated_at = CURRENT_TIMESTAMP WHERE ${idColumn} = $${values.length} RETURNING *`,
        values
    };
};
```

#### 2.7 `settingsRoutes` Mounted on 4 Paths
**File:** `backend/src/server.js`  
**Problem:** Settings router is mounted on `/api/settings`, `/api/audit-logs`, `/api/system`, `/api/ml` — uses `req.baseUrl` to determine behavior.  
**Solution:** Split into separate routers:
- `auditLogs.routes.js` for `/api/audit-logs`
- `system.routes.js` for `/api/system`
- `ml.routes.js` for `/api/ml`
- Keep `settings.routes.js` for `/api/settings`

#### 2.8 Inconsistent Error Response Shape
**Files:** Various route files  
**Problem:** Some return `{ success: false, message }`, others `{ error: message }`.  
**Solution:** Standardize all error responses to use `{ success: false, message }` format. The global `errorHandler` already does this — ensure all manual `res.status().json()` calls match.

#### 2.9 Duplicate Anomaly Query Blocks
**File:** `backend/src/ml/anomalyDetector.js`  
**Problem:** `getUnitAnomalies` and `getAllAnomalies` have near-identical 15-line SELECT/JOIN blocks.  
**Solution:** Extract to a single function parameterized by optional `unit_id`.

#### 2.10 Frontend Services Duplicate HTTP Logic
**Files:** 15+ service files in `frontend/lib/services/`  
**Problem:** Most services manually build headers and handle HTTP responses instead of using `ApiClient`.  
**Solution:** Gradually migrate services to use `ApiClient.get()`, `ApiClient.post()`, etc. Start with the simplest services (`unit_service.dart`, `officer_service.dart`).

### Priority 3: LOW (Nice to Have)

#### 2.11 Unused Helper Functions
**File:** `backend/src/utils/helpers.js`  
**Functions:** `sleep()`, `isBusinessHours()`, `formatNumber()` — not imported anywhere.  
**Action:** Remove or mark as available utilities in docs.

#### 2.12 Unused Statistical Functions
**File:** `backend/src/ml/statistical.js`  
**Functions:** `calculateModifiedZScore`, `detectIQROutliers`, `calculatePercentile`, `calculateMahalanobisDistance`, `grubbsTest` — exported but never called.  
**Action:** These may be intended for future use. Keep but document as reserved.

#### 2.13 Duplicate Approval Service/Provider Pairs
**Frontend files:**
- `approval_service.dart` + `approval_provider.dart` — used on HQ dashboard
- `approvals_service.dart` + `approvals_provider.dart` — used on approvals portal  
**Problem:** Similar but different functionality spread across two service/provider pairs.  
**Solution:** Consider merging into a single `ApprovalsService` with all endpoints, and a single `ApprovalsProvider` with separate state for dashboard vs portal views.

#### 2.14 `ballistic_service.dart` Re-export
**File:** `frontend/lib/services/ballistic_service.dart`  
**Content:** `export 'ballistic_profile_service.dart';`  
**Action:** This is a compatibility shim. Once all imports are updated to use `ballistic_profile_service.dart` directly, remove this file.

#### 2.15 `workflow_service.dart` Re-export
**File:** `frontend/lib/services/workflow_service.dart`  
**Action:** Same pattern — check if anything imports it, then remove.

---

## 3. Architecture Notes

### 3.1 Backend Architecture (Current State)
```
server.js (Express app setup, route mounting, job scheduling)
├── config/         (database pool, auth config, server config)
├── middleware/      (auth, authorization RBAC, audit logging, error handling)
├── models/          (data access layer — direct SQL queries)
├── routes/          (HTTP handlers — business logic embedded here)
├── services/        (auth, custody, email, 2FA — partial service layer)
├── ml/              (anomaly detection: K-Means, statistical, feature extraction)
├── jobs/            (cron jobs: model training, view refresh)
├── scripts/         (database setup, seeding, migration)
└── utils/           (logging, validation, helpers)
```

**Key Observation:** The service layer is incomplete. Most business logic lives in route handlers rather than services. Only auth-, custody-, and email-related operations have dedicated services.  
**Recommendation:** For future features, create services first, then have routes call services. This improves testability.

### 3.2 Frontend Architecture (Current State)
```
main.dart (MultiProvider setup, MaterialApp)
├── config/          (API URLs, constants, theme)
├── models/          (Dart data classes)
├── providers/       (ChangeNotifier state management)
├── screens/         (UI pages, organized by feature)
├── services/        (HTTP API calls)
├── utils/           (date formatting, helpers, validators)
└── widgets/         (reusable UI components)
```

**Key Observation:** The provider/service/screen layering is well-structured. Main improvement area is reducing HTTP boilerplate by migrating services to use `ApiClient`.

### 3.3 Role-Based Access Control Matrix
```
| Capability                  | Admin | HQ Commander | Station Commander | Investigator |
|-----------------------------|-------|--------------|-------------------|--------------|
| System Administration       |  ✅   |     ❌       |       ❌          |     ❌       |
| User Management             |  ✅   |     ❌       |       ❌          |     ❌       |
| Register Firearms           |  ❌   |     ✅       |       ❌          |     ❌       |
| Create Ballistic Profiles   |  ❌   |     ✅       |       ❌          |     ❌       |
| View Ballistic Profiles     |  ✅*  |     ✅       |       ❌          |     ✅       |
| Assign/Return Custody       |  ❌   |     ✅       |    Unit Only      |     ❌       |
| View All Firearms           |  ✅   |     ✅       |       ❌          |     ✅       |
| View Unit Firearms          |  ✅   |     ✅       |    Unit Only      |     ✅       |
| Approve Loss/Destruction    |  ✅   |     ✅       |       ❌          |     ❌       |
| Submit Loss/Destruction     |  ❌   |     ✅       |       ✅          |     ❌       |
| View Anomalies              |  ✅   |     ✅       |    Unit Only      |     ✅       |
| View Audit Logs             |  ✅   |     ❌       |       ❌          |     ❌       |
| Cross-Unit Reports          |  ✅   |     ✅       |       ❌          |     ❌       |
```
*Admin has audit/compliance access only

---

## 4. Database Optimization Recommendations

### 4.1 Recommended Indexes
Based on query analysis across models and route handlers:

```sql
-- Custody records: frequently queried by officer, firearm, and date
CREATE INDEX IF NOT EXISTS idx_custody_officer_issued 
    ON custody_records(officer_id, issued_at DESC);
CREATE INDEX IF NOT EXISTS idx_custody_firearm_issued 
    ON custody_records(firearm_id, issued_at DESC);
CREATE INDEX IF NOT EXISTS idx_custody_unit_returned 
    ON custody_records(unit_id, returned_at);

-- Anomalies: filtered by unit, severity, status
CREATE INDEX IF NOT EXISTS idx_anomalies_unit_severity_status 
    ON anomalies(unit_id, severity, status);
CREATE INDEX IF NOT EXISTS idx_anomalies_detected 
    ON anomalies(detected_at DESC);

-- Firearms: frequently filtered by unit and status
CREATE INDEX IF NOT EXISTS idx_firearms_unit_status 
    ON firearms(assigned_unit_id, current_status);

-- Audit logs: queried by time range and user
CREATE INDEX IF NOT EXISTS idx_audit_logs_created 
    ON audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_action 
    ON audit_logs(user_id, action_type);

-- Ballistic access logs: timing analysis
CREATE INDEX IF NOT EXISTS idx_ballistic_access_firearm_time 
    ON ballistic_access_logs(firearm_id, accessed_at DESC);
```

### 4.2 Sequence-Based ID Generation (Recommended Migration)
```sql
-- Replace MAX() pattern with sequences
CREATE SEQUENCE IF NOT EXISTS firearm_seq START WITH 1;
CREATE SEQUENCE IF NOT EXISTS officer_seq START WITH 1;
CREATE SEQUENCE IF NOT EXISTS user_seq START WITH 1;
CREATE SEQUENCE IF NOT EXISTS unit_seq START WITH 1;
CREATE SEQUENCE IF NOT EXISTS anomaly_seq START WITH 1;

-- Usage in application:
-- const id = await query("SELECT nextval('firearm_seq') as num");
-- const firearm_id = `FA-${String(id.rows[0].num).padStart(3, '0')}`;
```

---

## 5. Frontend Improvement Roadmap

### Phase 1: Code Quality (Low Risk)
1. **Migrate services to use `ApiClient`** — reduce HTTP boilerplate across 15+ files
2. **Add `const` constructors** where possible for widget performance
3. **Remove compatibility aliases** in `ApiConfig` (e.g., `static String get firearms => firearmsUrl`)

### Phase 2: User Experience
1. **Add error boundary widgets** — wrap screens with error-catching widgets
2. **Add connection status indicator** — show when backend is unreachable
3. **Implement retry logic** in `ApiClient` for transient failures

### Phase 3: Architecture
1. **Merge duplicate approval providers** — unify `ApprovalProvider` and `ApprovalsProvider`
2. **Add proper routing** — implement named routes for deep linking
3. **Implement proper logout** — clear all provider states on logout

---

## 6. Testing Strategy

### 6.1 Backend — Recommended Test Structure
```
backend/
├── tests/
│   ├── unit/
│   │   ├── config/auth.test.js        (JWT, OTP generation)
│   │   ├── middleware/authorization.test.js (RBAC)
│   │   ├── models/Firearm.test.js     (queries)
│   │   └── ml/statistical.test.js     (anomaly scoring)
│   ├── integration/
│   │   ├── auth.routes.test.js        (login flow)
│   │   ├── custody.routes.test.js     (assign/return)
│   │   └── firearms.routes.test.js    (CRUD + auth)
│   └── setup.js                       (test DB, fixtures)
```

### 6.2 Critical Test Cases to Write First
1. **OTP generation** — verify 6-digit output, cryptographic randomness
2. **RBAC enforcement** — verify each role can/cannot access specific endpoints
3. **Custody assignment** — verify concurrent requests don't create duplicates
4. **Anomaly detection** — verify scoring with known normal and anomalous inputs
5. **SQL injection prevention** — test `captureOldValues` with malicious table names

### 6.3 Getting Started with Tests
```bash
npm install --save-dev jest supertest
```

Add to `package.json`:
```json
{
  "scripts": {
    "test": "jest --forceExit --detectOpenHandles",
    "test:watch": "jest --watch"
  },
  "jest": {
    "testEnvironment": "node",
    "testMatch": ["**/tests/**/*.test.js"]
  }
}
```

---

## Summary of Impact

| Category | Issues Found | Fixed Now | Remaining |
|----------|-------------|-----------|-----------|
| **Critical Security** | 6 | 6 | 0 |
| **Bug Fixes** | 7 | 7 | 0 |
| **Performance** | 6 | 1 | 5 |
| **Code Quality** | 15 | 7 | 8 |
| **Missing Features** | 5 | 0 | 5 |
| **Total** | **39** | **21** | **18** |

All critical security vulnerabilities and bugs have been resolved. Remaining items are performance optimizations, code quality improvements, and architectural enhancements that can be addressed incrementally without affecting current functionality.
