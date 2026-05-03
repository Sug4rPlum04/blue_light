String resolveDisplayName(
  Map<String, dynamic> data, {
  required String userId,
  String fallback = 'User',
}) {
  final String username = (data['username'] as String?)?.trim() ?? '';
  if (username.isNotEmpty) {
    return username;
  }

  final String shortId = userId.length >= 6
      ? userId.substring(0, 6)
      : userId.trim();
  if (shortId.isNotEmpty) {
    return '$fallback $shortId';
  }
  return fallback;
}
