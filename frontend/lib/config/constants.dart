// Application Constants
// Contains constant values used throughout the application

class AppConstants {
  // Application info
  static const String appName = 'SafeArms';
  static const String appVersion = '1.0.0';
  static const String appDescription =
      'Police Firearm Control and Investigation Support Platform';
  static const String organization = 'Rwanda National Police';

  // User roles
  static const String roleAdmin = 'admin';
  static const String roleHqCommander = 'hq_firearm_commander';
  static const String roleStationCommander = 'station_commander';
  static const String roleInvestigator = 'investigator';

  // Role display labels
  static const Map<String, String> roleLabels = {
    roleAdmin: 'System Administrator',
    roleHqCommander: 'HQ Firearm Commander',
    roleStationCommander: 'Station Commander',
    roleInvestigator: 'Investigator',
  };

  // Firearm statuses
  static const String statusAvailable = 'available';
  static const String statusInCustody = 'in_custody';
  static const String statusMaintenance = 'maintenance';
  static const String statusLost = 'lost';
  static const String statusStolen = 'stolen';
  static const String statusDestroyed = 'destroyed';
  static const String statusUnassigned = 'unassigned';

  // Firearm types
  static const List<String> firearmTypes = [
    'pistol',
    'rifle',
    'shotgun',
    'submachine_gun',
    'other',
  ];

  // Custody types
  static const List<String> custodyTypes = [
    'permanent',
    'temporary',
    'personal_long_term',
  ];

  // Anomaly severities
  static const String severityCritical = 'critical';
  static const String severityHigh = 'high';
  static const String severityMedium = 'medium';
  static const String severityLow = 'low';

  // Anomaly statuses
  static const String anomalyOpen = 'open';
  static const String anomalyInvestigating = 'investigating';
  static const String anomalyResolved = 'resolved';
  static const String anomalyFalsePositive = 'false_positive';

  // Pagination defaults
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // OTP settings
  static const int otpLength = 6;
  static const int otpExpirySeconds = 300;
}
