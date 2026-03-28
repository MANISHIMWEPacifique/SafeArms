bool isAuthFailureError(Object error) {
  final text = error.toString().toLowerCase();

  return text.contains('apiexception(401)') ||
      text.contains('access denied. no token provided') ||
      text.contains('authentication required') ||
      text.contains('not authenticated') ||
      text.contains('token expired') ||
      text.contains('invalid token');
}
