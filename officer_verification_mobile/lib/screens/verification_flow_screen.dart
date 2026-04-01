import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../models/approval_request.dart';
import '../services/verification_api_service.dart';
import '../theme/app_colors.dart';
import 'decision_confirmation_screen.dart';
import 'incoming_request_screen.dart';
import 'pin_entry_screen.dart';
import 'splash_screen.dart';
import 'success_screen.dart';

enum _FlowStage { splash, pin, incoming, confirm, success }

class VerificationFlowScreen extends StatefulWidget {
  const VerificationFlowScreen({super.key});

  

  @override
  State<VerificationFlowScreen> createState() => _VerificationFlowScreenState();
}

class _VerificationFlowScreenState extends State<VerificationFlowScreen> {
  _FlowStage _stage = _FlowStage.splash;
  VerificationDecision _decision = VerificationDecision.approve;
  bool _isSubmitting = false;
  bool _isLoadingPending = false;
  String? _pendingError;

  late final VerificationApiService _apiService;
  final bool _useMockFlow = ApiConfig.useMockFlow;

  ApprovalRequest? _request;

  @override
  void initState() {
    super.initState();
    _apiService = VerificationApiService();
    if (_useMockFlow) {
      _request = ApprovalRequest.sample();
    }
  }

  @override
  void dispose() {
    _apiService.dispose();
    super.dispose();
  }

  Future<void> _handlePinVerified() async {
    if (_useMockFlow) {
      setState(() => _stage = _FlowStage.incoming);
      return;
    }

    setState(() => _stage = _FlowStage.incoming);
    await _loadPendingRequest();
  }

  Future<void> _loadPendingRequest() async {
    if (!ApiConfig.hasDeviceCredentials) {
      setState(() {
        _isLoadingPending = false;
        _request = null;
        _pendingError =
            'Missing SAFEARMS_OFFICER_ID / SAFEARMS_DEVICE_KEY / SAFEARMS_DEVICE_TOKEN.';
      });
      return;
    }

    setState(() {
      _isLoadingPending = true;
      _pendingError = null;
      _request = null;
    });

    try {
      final requests = await _apiService.fetchPendingRequests(
        officerId: ApiConfig.officerId,
        deviceKey: ApiConfig.deviceKey,
        deviceToken: ApiConfig.deviceToken,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingPending = false;
        _request = requests.isEmpty ? null : requests.first;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingPending = false;
        _pendingError = error.toString();
      });
    }
  }

  Future<void> _submitDecision(String? reason) async {
    final request = _request;
    if (request == null) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (_useMockFlow) {
        await Future<void>.delayed(const Duration(milliseconds: 900));
      } else {
        await _apiService.submitDecision(
          verificationId: request.requestId,
          officerId: ApiConfig.officerId,
          deviceKey: ApiConfig.deviceKey,
          deviceToken: ApiConfig.deviceToken,
          challengeCode: request.challengeCode,
          decision: _decision == VerificationDecision.approve ? 'approve' : 'reject',
          reason: reason,
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(error.toString()),
          ),
        );
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
      _stage = _FlowStage.success;
    });
  }

  Future<void> _onSuccessDone() async {
    if (_useMockFlow) {
      setState(() => _stage = _FlowStage.incoming);
      return;
    }

    setState(() => _stage = _FlowStage.incoming);
    await _loadPendingRequest();
  }

  Widget _buildIncomingState(BuildContext context) {
    if (_isLoadingPending) {
      return _buildStateCard(
        title: 'Checking requests',
        subtitle: 'Fetching pending verification requests from SafeArms API.',
        child: const CircularProgressIndicator(color: AppColors.accentBlue),
      );
    }

    if (_pendingError != null) {
      return _buildStateCard(
        title: 'Unable to load requests',
        subtitle: _pendingError!,
        child: FilledButton.icon(
          onPressed: _loadPendingRequest,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      );
    }

    if (_request == null) {
      return _buildStateCard(
        title: 'No pending request',
        subtitle: 'There is no active custody verification request for this officer.',
        child: FilledButton.icon(
          onPressed: _loadPendingRequest,
          icon: const Icon(Icons.sync),
          label: const Text('Check Again'),
        ),
      );
    }

    return IncomingRequestScreen(
      request: _request!,
      onApprove: () {
        setState(() {
          _decision = VerificationDecision.approve;
          _stage = _FlowStage.confirm;
        });
      },
      onReject: () {
        setState(() {
          _decision = VerificationDecision.reject;
          _stage = _FlowStage.confirm;
        });
      },
      onDismiss: () {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text('Request dismissed temporarily.'),
              duration: Duration(seconds: 2),
            ),
          );
      },
    );
  }

  Widget _buildStateCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return ColoredBox(
      color: AppColors.background,
      child: SafeArea(
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 22),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 18),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget body;

    switch (_stage) {
      case _FlowStage.splash:
        body = SplashScreen(
          onFinished: () {
            setState(() => _stage = _FlowStage.pin);
          },
        );
        break;
      case _FlowStage.pin:
        body = PinEntryScreen(
          onVerified: _handlePinVerified,
        );
        break;
      case _FlowStage.incoming:
        body = _buildIncomingState(context);
        break;
      case _FlowStage.confirm:
        if (_request == null) {
          body = _buildStateCard(
            title: 'No active request',
            subtitle: 'Load a pending request before confirming a decision.',
            child: FilledButton.icon(
              onPressed: _loadPendingRequest,
              icon: const Icon(Icons.sync),
              label: const Text('Load Request'),
            ),
          );
          break;
        }

        body = DecisionConfirmationScreen(
          request: _request!,
          decision: _decision,
          isSubmitting: _isSubmitting,
          onCancel: () {
            setState(() => _stage = _FlowStage.incoming);
          },
          onConfirm: _submitDecision,
        );
        break;
      case _FlowStage.success:
        body = SuccessScreen(
          request: _request ?? ApprovalRequest.sample(),
          approved: _decision == VerificationDecision.approve,
          onDone: _onSuccessDone,
        );
        break;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: body,
      ),
    );
  }
}
