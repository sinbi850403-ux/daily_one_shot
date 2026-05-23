import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../app_scope.dart';
import '../../data/database.dart';
import '../viewer/photo_viewer_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List<Entry> _entries = [];
  bool _loading = true;
  final _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final scope = AppScope.of(context);
    final all = await scope.repo.listAll();
    if (!mounted) return;
    setState(() {
      _entries = all.where((e) => e.latitude != null && e.longitude != null).toList();
      _loading = false;
    });
  }

  Future<void> _openEntry(Entry entry) async {
    final scope = AppScope.of(context);
    final file = await scope.storage.originalFile(entry.photoPath);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PhotoViewerScreen(
          entry: entry,
          file: file,
          heroTag: 'map-${entry.date.toIso8601String()}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('지도')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.map_outlined, size: 64, color: cs.outline),
                      const SizedBox(height: 16),
                      Text('위치 정보가 있는 기록이 없어요',
                          style: TextStyle(color: cs.onSurfaceVariant)),
                      const SizedBox(height: 8),
                      Text('앱에서 기록 저장 시 위치 권한을 허용하면\n지도에 표시됩니다',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 13, color: cs.onSurfaceVariant)),
                    ],
                  ),
                )
              : FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: LatLng(
                      _entries.first.latitude!,
                      _entries.first.longitude!,
                    ),
                    initialZoom: 10,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.dailyoneshot.daily_one_shot',
                    ),
                    MarkerLayer(
                      markers: _entries.map((e) {
                        return Marker(
                          point: LatLng(e.latitude!, e.longitude!),
                          width: 44,
                          height: 44,
                          child: GestureDetector(
                            onTap: () => _openEntry(e),
                            child: _PhotoMarker(entry: e),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
    );
  }
}

class _PhotoMarker extends StatelessWidget {
  const _PhotoMarker({required this.entry});
  final Entry entry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final scope = AppScope.of(context);

    return FutureBuilder<File>(
      future: scope.storage.originalFile(entry.photoPath),
      builder: (ctx, snap) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: cs.primary, width: 2.5),
            color: cs.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipOval(
            child: snap.data != null
                ? Image.file(snap.data!, fit: BoxFit.cover,
                    width: 40, height: 40)
                : Icon(Icons.photo, color: cs.primary, size: 22),
          ),
        );
      },
    );
  }
}
