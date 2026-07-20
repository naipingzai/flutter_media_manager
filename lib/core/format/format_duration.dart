/// Utility functions for formatting time durations.
class FormatDuration {
  /// Format a duration in milliseconds to a human-readable string.
  ///
  /// Examples:
  /// - 42000 → '00:42'
  /// - 3661000 → '1:01:01'
  static String formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }
}
