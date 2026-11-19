class MapConfig {
  static const String tileUrl = String.fromEnvironment(
    'MAP_TILE_URL',
    defaultValue:
        'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Base/MapServer/tile/{z}/{y}/{x}',
  );

  static const String attribution = String.fromEnvironment(
    'MAP_ATTRIBUTION',
    defaultValue: 'Esri · HERE · Garmin · © OpenStreetMap contributors',
  );

  static const String userAgent = String.fromEnvironment(
    'MAP_USER_AGENT',
    defaultValue: 'vn.sharee.mobile',
  );

  static bool get isDemoTiles =>
      tileUrl.contains('tile.openstreetmap.org') || tileUrl.contains('arcgisonline.com');
}
