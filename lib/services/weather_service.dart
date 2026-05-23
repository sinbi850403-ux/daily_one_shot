import 'dart:io';

import 'package:geolocator/geolocator.dart';

class WeatherResult {
  const WeatherResult({
    required this.label,
    required this.latitude,
    required this.longitude,
  });
  final String label;     // e.g. "맑음 22°C"
  final double latitude;
  final double longitude;
}

class WeatherService {
  WeatherService._();
  static final instance = WeatherService._();

  /// GPS + wttr.in 으로 날씨 문자열 반환.
  /// 권한 거부 또는 네트워크 오류 시 null 반환.
  Future<WeatherResult?> fetch() async {
    try {
      final pos = await _getPosition();
      if (pos == null) return null;

      final lat = pos.latitude.toStringAsFixed(4);
      final lon = pos.longitude.toStringAsFixed(4);
      final uri = Uri.parse(
          'https://wttr.in/$lat,$lon?format=%C|%t&lang=ko&m');

      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 6);
      final req = await client.getUrl(uri);
      req.headers.set('User-Agent', 'daily-one-shot/1.0');
      final res = await req.close();
      final body =
          await res.transform(const SystemEncoding().decoder).join();
      client.close();

      if (res.statusCode != 200) return null;

      // body 예시: "Sunny|+22 °C" 또는 "맑음|+22 °C"
      final parts = body.trim().split('|');
      if (parts.length < 2) return null;
      final condition = parts[0].trim();
      final temp = parts[1].trim().replaceAll(' ', '');
      final label = '$condition $temp';

      return WeatherResult(
        label: label,
        latitude: pos.latitude,
        longitude: pos.longitude,
      );
    } catch (_) {
      return null;
    }
  }

  Future<Position?> _getPosition() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (_) {
      return null;
    }
  }
}
