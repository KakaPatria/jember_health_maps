import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Haversine;
import 'package:provider/provider.dart';
import '../database/database_helper.dart';
import '../models/faskes.dart';
import '../providers/app_provider.dart';
import '../utils/haversine.dart';
import '../widgets/faskes_marker_icon.dart';

class FaskesDetailScreen extends StatefulWidget {
  final int faskesId;
  const FaskesDetailScreen({super.key, required this.faskesId});

  @override
  State<FaskesDetailScreen> createState() => _FaskesDetailScreenState();
}

class _FaskesDetailScreenState extends State<FaskesDetailScreen> {
  Faskes? _faskes;
  bool _isLoading = true;

  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _loadFaskes();
  }

  Future<void> _loadFaskes() async {
    final faskes =
        await DatabaseHelper.instance.getFaskesById(widget.faskesId);
    if (mounted) {
      setState(() {
        _faskes = faskes;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Faskes')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_faskes == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Faskes')),
        body: const Center(child: Text('Data tidak ditemukan')),
      );
    }

    final faskes = _faskes!;
    final provider = Provider.of<AppProvider>(context, listen: false);
    double? distance;
    if (provider.userPosition != null) {
      distance = Haversine.distanceKm(
        lat1: provider.userPosition!.latitude,
        lon1: provider.userPosition!.longitude,
        lat2: faskes.latitude,
        lon2: faskes.longitude,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Faskes'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mini map
            SizedBox(
              height: 200,
              width: double.infinity,
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: LatLng(faskes.latitude, faskes.longitude),
                  initialZoom: 15,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                    userAgentPackageName: 'com.example.jember_health_maps',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(faskes.latitude, faskes.longitude),
                        width: 36,
                        height: 36,
                        child: FaskesMarkerIcon.getIcon(faskes.jenis),
                      ),
                      if (provider.userLatLng != null)
                        Marker(
                          point: provider.userLatLng!,
                          width: 30,
                          height: 30,
                          child: StreamBuilder<MapEvent>(
                            stream: _mapController.mapEventStream,
                            builder: (context, _) {
                              double mapRot = 0.0;
                              try {
                                mapRot = _mapController.camera.rotation;
                              } catch (_) {}
                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue.withAlpha(200),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 3),
                                ),
                                child: AnimatedRotation(
                                  turns: ((provider.compassHeading ?? provider.userPosition?.heading ?? 0.0) + mapRot) / 360.0,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOut,
                                  child: const Icon(
                                    Icons.navigation,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                  if (provider.routePoints.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: provider.routePoints,
                          color: colors.primary,
                          strokeWidth: 4,
                        ),
                      ],
                    ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nama & jenis
                  Row(
                    children: [
                      FaskesMarkerIcon.getIcon(faskes.jenis, size: 40),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              faskes.nama,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: colors.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                faskes.jenis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Distance
                  if (distance != null)
                    Card(
                      elevation: 0,
                      color: colors.tertiaryContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.near_me,
                                color: colors.onTertiaryContainer),
                            const SizedBox(width: 12),
                            Text(
                              '${Haversine.formatDistance(distance)} dari lokasi Anda',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colors.onTertiaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Info items
                  _InfoItem(
                    icon: Icons.location_on_outlined,
                    label: 'Alamat',
                    value: faskes.alamatLengkap.replaceAll('', '').replaceAll('\n', ' ').trim(),
                  ),
                  _InfoItem(
                    icon: Icons.map_outlined,
                    label: 'Alamat Singkat',
                    value: faskes.alamat,
                  ),
                  if (faskes.telepon.isNotEmpty)
                    _InfoItem(
                      icon: Icons.phone_outlined,
                      label: 'Telepon',
                      value: faskes.telepon,
                      trailing: IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 20, color: Colors.grey),
                        tooltip: 'Salin Nomor',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: faskes.telepon));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Nomor berhasil disalin!')),
                          );
                        },
                      ),
                    ),
                  _InfoItem(
                    icon: Icons.pin_drop_outlined,
                    label: 'Koordinat',
                    value:
                        '${faskes.latitude.toStringAsFixed(6)}, ${faskes.longitude.toStringAsFixed(6)}',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    if (provider.userLatLng != null) {
                      provider.fetchRoute(
                        origin: provider.userLatLng!,
                        destination:
                            LatLng(faskes.latitude, faskes.longitude),
                      );
                      
                      // Switch to Map tab
                      provider.setMainTabIndex(1);
                      
                      // Pop back to main screen
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    }
                  },
                  icon: const Icon(Icons.route),
                  label: const Text('Tampilkan Rute'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.outline),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 2),
                Text(value, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
