class MapConfig {
  static const String tileUrl = String.fromEnvironment(
    'MAP_TILE_URL',
    defaultValue: 'https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
  );

  static const String attribution = String.fromEnvironment(
    'MAP_ATTRIBUTION',
    defaultValue: '© OpenStreetMap contributors · © CARTO',
  );

  static const String userAgent = String.fromEnvironment(
    'MAP_USER_AGENT',
    defaultValue: 'vn.sharee.mobile',
  );

  static bool get isDemoTiles =>
      tileUrl.contains('tile.openstreetmap.org') || tileUrl.contains('cartocdn.com');
}
