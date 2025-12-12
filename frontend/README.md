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
├── models/                   # Data models (10 models)
├── services/                 # API services (11 services)
├── providers/                # State management (5 providers)
├── screens/                  # UI screens (17 screens)
├── widgets/                  # Reusable widgets (11 widgets)
└── utils/                    # Utilities (3 utils)
```

## Features

- Email-based OTP authentication
- Role-based dashboards (4 roles)
- Firearm registry management
- Custody tracking
- ML anomaly detection visualization
- Workflow approvals
- Ballistic profile management

## Empty Files Notice

⚠️ **All files in this frontend are currently empty placeholders.**

These files have been created with the correct structure and naming conventions.
You can now implement your own UI design in each file.

## Next Steps

1. Implement authentication screens (`login_screen.dart`, `otp_screen.dart`)
2. Build role-based dashboards
3. Create management screens for CRUD operations
4. Design reusable widgets
5. Implement state management with providers
6. Connect to backend API

## Backend API

The backend API runs on `http://localhost:3000`

Update `lib/config/api_config.dart` with the correct API endpoint.

## License

Rwanda National Police - Final Year Project
