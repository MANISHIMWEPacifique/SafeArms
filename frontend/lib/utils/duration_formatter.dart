String formatOperationalDuration(Duration duration) {
  final totalMinutes = duration.inMinutes.abs();
  final days = totalMinutes ~/ (24 * 60);
  final hours = (totalMinutes % (24 * 60)) ~/ 60;
  final minutes = totalMinutes % 60;

  final parts = <String>[];
  if (days > 0) {
    parts.add(_unit(days, 'day'));
  }
  if (hours > 0) {
    parts.add(_unit(hours, 'hour'));
  }
  if (minutes > 0 || parts.isEmpty) {
    parts.add(_unit(minutes, 'minute'));
  }

  return parts.take(2).join(' ');
}

String _unit(int value, String label) {
  return '$value $label${value == 1 ? '' : 's'}';
}
