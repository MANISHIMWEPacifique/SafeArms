# SafeArms Backend API

## Overview
Node.js/Express REST API for SafeArms platform with ML.js-powered anomaly detection.

## Stack
- **Runtime:** Node.js 18+
- **Framework:** Express.js
- **Database:** PostgreSQL
- **Authentication:** JWT + Email-based OTP
- **ML Engine:** ML.js (K-Means + Statistical Outliers)

## Installation

```bash
npm install
```

## Configuration

Create `.env` file with:
```env
DB_HOST=localhost
DB_PORT=5432
DB_NAME=safearms
DB_USER=safearms_user
DB_PASSWORD=secure_password123

NODE_ENV=development
PORT=3000

JWT_SECRET=your_secret_min_32_characters
JWT_EXPIRES_IN=24h

OTP_EXPIRES_IN=300

SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your_email@gmail.com
SMTP_PASSWORD=your_app_password

ML_ANOMALY_THRESHOLD=0.35
ML_CRITICAL_THRESHOLD=0.85
```

## Run

```bash
# Development
npm run dev

# Production
npm start
```

## API Structure

- `POST /api/auth/login` - Login
- `POST /api/auth/verify-otp` - Verify email OTP
- `GET /api/firearms` - List firearms
- `POST /api/custody/assign` - Assign custody
- `GET /api/anomalies` - List anomalies

## ML Anomaly Detection

The system automatically detects suspicious custody patterns using:
- K-Means clustering (6 clusters)
- Statistical outlier detection (z-scores)
- Ensemble scoring

Anomalies are classified as: CRITICAL, HIGH, MEDIUM, LOW
