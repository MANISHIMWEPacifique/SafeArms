# SafeArms Frontend

Flutter web/desktop application for SafeArms Police Firearm Control Platform.

## Getting Started

### Prerequisites
- Flutter SDK 3.0 or higher
- Dart SDK 3.0 or higher

### Installation

```bash
# Navigate to frontend directory
cd frontend

# Get dependencies
flutter pub get

# Run on Chrome (web)
flutter run -d chrome

# Build for web
flutter build web
```

## Project Structure

```
lib/
├── main.dart                 # Application entry point
├── config/                   # Configurations
├── models/                   # Data models
├── services/                 # API services
├── providers/                # State management
├── screens/                  # UI screens
├── widgets/                  # Reusable widgets
└── utils/                    # Utilities
```

## Features

- Email-based OTP authentication
- Role-based dashboards (4 roles)
- Firearm registry management
- Custody tracking
- ML anomaly detection visualization
- Workflow approvals
- Ballistic profile management

## Backend API

The backend API runs on `http://localhost:3000`

Update `lib/config/api_config.dart` with the correct API endpoint.

For hosted builds, set any reachable backend URL (Render is optional):

```bash
flutter build web --dart-define=API_BASE_URL=https://your-hosted-backend-domain
```

## License

Rwanda National Police - Final Year Project
