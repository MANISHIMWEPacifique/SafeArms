// Approvals Provider - State management for HQ approval workflow
// SafeArms Frontend

import 'package:flutter/foundation.dart';
import '../services/approvals_service.dart';
import '../utils/auth_error_utils.dart';

class ApprovalsProvider with ChangeNotifier {
  final ApprovalsService _approvalsService = ApprovalsService();

  // State
  List<Map<String, dynamic>> _pendingLossReports = [];
  List<Map<String, dynamic>> _pendingDestructionRequests = [];
  List<Map<String, dynamic>> _pendingProcurementRequests = [];
  Map<String, dynamic>? _selectedRequest;
  Map<String, dynamic> _stats = {};

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // Filters
  String _lossReportPriority = 'all';
  String _destructionPriority = 'all';
  String _procurementPriority = 'all';
  String _unitFilter = 'all';

  // Getters
  List<Map<String, dynamic>> get pendingLossReports => _pendingLossReports;
  List<Map<String, dynamic>> get pendingDestructionRequests =>
      _pendingDestructionRequests;
  List<Map<String, dynamic>> get pendingProcurementRequests =>
      _pendingProcurementRequests;
  Map<String, dynamic>? get selectedRequest => _selectedRequest;
  Map<String, dynamic> get stats => _stats;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  // Load pending loss reports
  Future<void> loadPendingLossReports() async {
    _isLoading = true;
    notifyListeners();

    try {
      _pendingLossReports = await _approvalsService.getPendingLossReports(
        priority: _lossReportPriority != 'all' ? _lossReportPriority : null,
        unit: _unitFilter != 'all' ? _unitFilter : null,
      );
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Approve loss report
  Future<bool> approveLossReport({
    required String reportId,
    String? approvalNotes,
    List<String>? followUpActions,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final success = await _approvalsService.approveLossReport(
        reportId: reportId,
        approvalNotes: approvalNotes,
        followUpActions: followUpActions,
      );

      if (success) {
        _successMessage = 'Loss report approved successfully';
        await loadPendingLossReports();
        await loadStats();
      }

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Reject loss report
  Future<bool> rejectLossReport({
    required String reportId,
    required String rejectionReason,
    required String feedback,
    List<String>? requiredActions,
    String? resubmissionPriority,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final success = await _approvalsService.rejectLossReport(
        reportId: reportId,
        rejectionReason: rejectionReason,
        feedback: feedback,
        requiredActions: requiredActions,
        resubmissionPriority: resubmissionPriority,
      );

      if (success) {
        _successMessage = 'Loss report rejected. Station commander notified.';
        await loadPendingLossReports();
        await loadStats();
      }

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Load pending destruction requests
  Future<void> loadPendingDestructionRequests() async {
    _isLoading = true;
    notifyListeners();

    try {
      _pendingDestructionRequests =
          await _approvalsService.getPendingDestructionRequests(
        priority: _destructionPriority != 'all' ? _destructionPriority : null,
        unit: _unitFilter != 'all' ? _unitFilter : null,
      );
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Approve destruction request
  Future<bool> approveDestruction({
    required String requestId,
    String? approvalNotes,
    DateTime? scheduledDate,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final success = await _approvalsService.approveDestruction(
        requestId: requestId,
        approvalNotes: approvalNotes,
        scheduledDate: scheduledDate,
      );

      if (success) {
        _successMessage = 'Destruction request approved';
        await loadPendingDestructionRequests();
        await loadStats();
      }

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Reject destruction request
  Future<bool> rejectDestruction({
    required String requestId,
    required String rejectionReason,
    required String feedback,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final success = await _approvalsService.rejectDestruction(
        requestId: requestId,
        rejectionReason: rejectionReason,
        feedback: feedback,
      );

      if (success) {
        _successMessage = 'Destruction request rejected';
        await loadPendingDestructionRequests();
        await loadStats();
      }

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Load pending procurement requests
  Future<void> loadPendingProcurementRequests() async {
    _isLoading = true;
    notifyListeners();

    try {
      _pendingProcurementRequests =
          await _approvalsService.getPendingProcurementRequests(
        priority: _procurementPriority != 'all' ? _procurementPriority : null,
        unit: _unitFilter != 'all' ? _unitFilter : null,
      );
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Approve procurement request
  Future<bool> approveProcurement({
    required String requestId,
    String? approvalNotes,
    double? approvedAmount,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final success = await _approvalsService.approveProcurement(
        requestId: requestId,
        approvalNotes: approvalNotes,
        approvedAmount: approvedAmount,
      );

      if (success) {
        _successMessage = 'Procurement request approved';
        await loadPendingProcurementRequests();
        await loadStats();
      }

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Reject procurement request
  Future<bool> rejectProcurement({
    required String requestId,
    required String rejectionReason,
    required String feedback,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final success = await _approvalsService.rejectProcurement(
        requestId: requestId,
        rejectionReason: rejectionReason,
        feedback: feedback,
      );

      if (success) {
        _successMessage = 'Procurement request rejected';
        await loadPendingProcurementRequests();
        await loadStats();
      }

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Generic update requests status
  Future<bool> updateRequestStatus(
      dynamic requestIdDynamic, String type, String status) async {
    final requestId = requestIdDynamic.toString();
    if (status == 'approved') {
      if (type == 'loss') {
        return await approveLossReport(
            reportId: requestId,
            approvalNotes: 'Approved directly from list view');
      } else if (type == 'destruction') {
        return await approveDestruction(
            requestId: requestId,
            approvalNotes: 'Approved directly from list view');
      } else if (type == 'procurement') {
        return await approveProcurement(
            requestId: requestId,
            approvalNotes: 'Approved directly from list view');
      }
    } else if (status == 'rejected') {
      if (type == 'loss') {
        return await rejectLossReport(
          reportId: requestId,
          rejectionReason: 'Rejected from list view',
          feedback: 'No detailed feedback provided.',
        );
      } else if (type == 'destruction') {
        return await rejectDestruction(
          requestId: requestId,
          rejectionReason: 'Rejected from list view',
          feedback: 'No detailed feedback provided.',
        );
      } else if (type == 'procurement') {
        return await rejectProcurement(
          requestId: requestId,
          rejectionReason: 'Rejected from list view',
          feedback: 'No detailed feedback provided.',
        );
      }
    }
    return false;
  }

  // Load statistics
  Future<void> loadStats() async {
    try {
      _stats = await _approvalsService.getApprovalStats();
      notifyListeners();
    } catch (e) {
      if (isAuthFailureError(e)) {
        _stats = {};
        notifyListeners();
        return;
      }

      debugPrint('Error loading approval stats: $e');
    }
  }

  // Select request for review
  void selectRequest(Map<String, dynamic> request) {
    _selectedRequest = request;
    notifyListeners();
  }

  void clearSelectedRequest() {
    _selectedRequest = null;
    notifyListeners();
  }

  // Set filters
  void setLossReportPriority(String priority) {
    _lossReportPriority = priority;
    notifyListeners();
    loadPendingLossReports();
  }

  void setDestructionPriority(String priority) {
    _destructionPriority = priority;
    notifyListeners();
    loadPendingDestructionRequests();
  }

  void setProcurementPriority(String priority) {
    _procurementPriority = priority;
    notifyListeners();
    loadPendingProcurementRequests();
  }

  void setUnitFilter(String unit) {
    _unitFilter = unit;
    // Single notify + reload all tabs in parallel (each will notify on completion)
    _reloadAll();
  }

  /// Reload all tabs concurrently — notifies once at start, once at end.
  Future<void> _reloadAll() async {
    _isLoading = true;
    notifyListeners();
    try {
      await Future.wait([
        _loadLossReportsSilent(),
        _loadDestructionSilent(),
        _loadProcurementSilent(),
      ]);
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadLossReportsSilent() async {
    try {
      _pendingLossReports = await _approvalsService.getPendingLossReports(
        priority: _lossReportPriority != 'all' ? _lossReportPriority : null,
        unit: _unitFilter != 'all' ? _unitFilter : null,
      );
    } catch (e) {
      _errorMessage = e.toString();
    }
  }

  Future<void> _loadDestructionSilent() async {
    try {
      _pendingDestructionRequests =
          await _approvalsService.getPendingDestructionRequests(
        priority: _destructionPriority != 'all' ? _destructionPriority : null,
        unit: _unitFilter != 'all' ? _unitFilter : null,
      );
    } catch (e) {
      _errorMessage = e.toString();
    }
  }

  Future<void> _loadProcurementSilent() async {
    try {
      _pendingProcurementRequests =
          await _approvalsService.getPendingProcurementRequests(
        priority: _procurementPriority != 'all' ? _procurementPriority : null,
        unit: _unitFilter != 'all' ? _unitFilter : null,
      );
    } catch (e) {
      _errorMessage = e.toString();
    }
  }

  // Clear messages
  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }
}
