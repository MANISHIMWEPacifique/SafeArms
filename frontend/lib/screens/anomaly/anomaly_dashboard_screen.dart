// Anomaly Dashboard Screen
// View and investigate ML-detected anomalies

import 'package:flutter/material.dart';
import 'anomaly_detection_screen.dart';

/// Redirects to the main [AnomalyDetectionScreen].
/// Kept for navigation compatibility.
class AnomalyDashboardScreen extends StatelessWidget {
  const AnomalyDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AnomalyDetectionScreen();
  }
}
