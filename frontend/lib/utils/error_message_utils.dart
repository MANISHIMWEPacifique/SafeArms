String userFacingErrorMessage(Object error) {
  var message = error.toString().trim();

  const prefixes = [
    'Exception: Error updating user: ',
    'Exception: Error creating user: ',
    'Exception: Error resetting password: ',
    'Exception: Error deleting user: ',
    'Exception: ',
  ];

  var changed = true;
  while (changed) {
    changed = false;
    for (final prefix in prefixes) {
      if (message.startsWith(prefix)) {
        message = message.substring(prefix.length).trim();
        changed = true;
      }
    }
  }

  final apiMatch =
      RegExp(r'ApiException\(\d+\):\s*([^\[]+)').firstMatch(message);
  if (apiMatch != null) {
    return apiMatch.group(1)!.trim();
  }

  return message.isEmpty ? 'Operation failed' : message;
}
