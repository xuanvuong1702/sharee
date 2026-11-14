class MapConfig {
  static const String tileUrl = String.fromEnvironment(
    'MAP_TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );

  static const String attribution = String.fromEnvironment(
    'MAP_ATTRIBUTION',
    defaultValue: '© OpenStreetMap contributors',
  );

  static const String userAgent = String.fromEnvironment(
    'MAP_USER_AGENT',
    defaultValue: 'vn.sharee.mobile',
  );

  static bool get isDemoTiles => tileUrl.contains('tile.openstreetmap.org');
}
