enum LifecycleRequestType {
  loss,
  destruction,
  procurement,
}

extension LifecycleRequestTypeX on LifecycleRequestType {
  String get key {
    switch (this) {
      case LifecycleRequestType.loss:
        return 'loss';
      case LifecycleRequestType.destruction:
        return 'destruction';
      case LifecycleRequestType.procurement:
        return 'procurement';
    }
  }

  String get label {
    switch (this) {
      case LifecycleRequestType.loss:
        return 'Loss Report';
      case LifecycleRequestType.destruction:
        return 'Destruction Request';
      case LifecycleRequestType.procurement:
        return 'Procurement Request';
    }
  }

  String get listPath {
    switch (this) {
      case LifecycleRequestType.loss:
        return 'loss';
      case LifecycleRequestType.destruction:
        return 'destruction';
      case LifecycleRequestType.procurement:
        return 'procurement';
    }
  }

  String get approvalPath {
    switch (this) {
      case LifecycleRequestType.loss:
        return 'loss-reports';
      case LifecycleRequestType.destruction:
        return 'destruction-requests';
      case LifecycleRequestType.procurement:
        return 'procurement-requests';
    }
  }

  String get idField {
    switch (this) {
      case LifecycleRequestType.loss:
        return 'loss_id';
      case LifecycleRequestType.destruction:
        return 'destruction_id';
      case LifecycleRequestType.procurement:
        return 'procurement_id';
    }
  }

  static LifecycleRequestType fromKey(String key) {
    switch (key) {
      case 'loss':
        return LifecycleRequestType.loss;
      case 'destruction':
        return LifecycleRequestType.destruction;
      case 'procurement':
        return LifecycleRequestType.procurement;
      default:
        throw ArgumentError('Unknown lifecycle request type: $key');
    }
  }
}

String lifecycleRequestId(
  Map<String, dynamic> request,
  LifecycleRequestType type,
) {
  return request[type.idField]?.toString() ?? '';
}

bool isPendingLifecycleRequest(Map<String, dynamic> request) {
  return (request['status']?.toString().toLowerCase() ?? 'pending') ==
      'pending';
}
