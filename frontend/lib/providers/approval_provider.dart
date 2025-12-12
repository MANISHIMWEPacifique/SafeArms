// Approval Provider
// State management for approval workflow

import 'package:flutter/foundation.dart';
import '../services/approval_service.dart';

class ApprovalProvider with ChangeNotifier {
  final ApprovalService _approvalService = ApprovalService();

  Map<String, dynamic>? _pendingApprovals;
  bool _isLoading = false;
  String? _error;

  Map<String, dynamic>? get pendingApprovals => _pendingApprovals;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Load pending approvals
  Future<void> loadPendingApprovals() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _pendingApprovals = await _approvalService.getPendingApprovals();
      _error = null;
    } catch (e) {
      _error = e.toString();
      _pendingApprovals = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Process loss report
  Future<bool> processLossReport(
    String id,
    String status,
    String reviewNotes,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _approvalService.processLossReport(id, status, reviewNotes);
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Process destruction request
  Future<bool> processDestructionRequest(
    String id,
    String status,
    String reviewNotes,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _approvalService.processDestructionRequest(id, status, reviewNotes);
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Process procurement request
  Future<bool> processProcurementRequest(
    String id,
    String status,
    String reviewNotes,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _approvalService.processProcurementRequest(id, status, reviewNotes);
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
