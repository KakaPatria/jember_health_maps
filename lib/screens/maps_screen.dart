import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Haversine;
import 'package:provider/provider.dart';
import '../models/faskes.dart';
import '../providers/app_provider.dart';
import '../utils/haversine.dart';
import '../widgets/faskes_marker_icon.dart';
import 'faskes_detail_screen.dart';

/// Center of Jember
const LatLng _jemberCenter = LatLng(-8.1845, 113.6680);
const double _defaultZoom = 12.0;

class MapsScreen extends StatefulWidget {
  const MapsScreen({super.key});

  @override
  State<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends State<MapsScreen> {
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _locateUser();
    });
  }

  Future<void> _locateUser() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final success = await provider.fetchUserLocation();
    if (success && mounted && provider.userLatLng != null) {
      _mapController.move(provider.userLatLng!, 13.0);
    }
  }

  void _centerOnUser() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    if (provider.userLatLng != null) {
      _mapController.move(provider.userLatLng!, 15.0);
    } else {
      final success = await provider.fetchUserLocation();
      if (success && mounted && provider.userLatLng != null) {
        _mapController.move(provider.userLatLng!, 15.0);
      }
    }
  }

  List<Marker> _buildFaskesMarkers(
      List<Faskes> faskesList, BuildContext context) {
    return faskesList.map((f) {
      return Marker(
        point: LatLng(f.latitude, f.longitude),
        width: 40,
        height: 40,
        alignment: Alignment.topCenter,
        child: GestureDetector(
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => _FaskesMarkerInfo(faskes: f),
            );
          },
          child: FaskesMarkerIcon.getIcon(f.jenis, size: 40),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        // Build all markers in one list
        final List<Marker> markers = [];

        // User location marker
        if (provider.userLatLng != null) {
          markers.add(
            Marker(
              point: provider.userLatLng!,
              width: 40,
              height: 40,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha(200),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: const Icon(
                  Icons.navigation,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          );
        }

        // Route destination marker
        if (provider.routePoints.length > 1) {
          markers.add(
            Marker(
              point: provider.routePoints.last,
              width: 40,
              height: 40,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(200),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: const Icon(
                  Icons.location_on,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          );
        }

        // Facility markers
        markers.addAll(_buildFaskesMarkers(provider.filteredFaskes, context));

        return Scaffold(
          appBar: AppBar(
            title: const Text('Peta Faskes Jember'),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.my_location),
                tooltip: 'Lokasi Saya',
                onPressed: _centerOnUser,
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: _locateUser,
              ),
            ],
          ),
          body: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _jemberCenter,
                  initialZoom: _defaultZoom,
                  minZoom: 10,
                  maxZoom: 18,
                  onTap: (_, _) => provider.clearRoute(),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                    userAgentPackageName: 'com.example.jember_health_maps',
                  ),

                  // Route polyline
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

                  // All markers
                  MarkerLayer(markers: markers),
                ],
              ),

              // Route info card
              if (provider.routePoints.isNotEmpty)
                Positioned(
                  top: 8,
                  left: 16,
                  right: 16,
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.route, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Jarak: ${Haversine.formatDistance(provider.routeDistanceKm)}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Estimasi: ${Haversine.estimasiWaktu(provider.routeDistanceKm)}',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => provider.clearRoute(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Loading indicator for route
              if (provider.isLoadingRoute)
                const Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
            ],
          ),
          floatingActionButton: FloatingActionButton.small(
            onPressed: _centerOnUser,
            tooltip: 'Pusat ke lokasi saya',
            child: const Icon(Icons.my_location),
          ),
        );
      },
    );
  }
}

class _FaskesMarkerInfo extends StatelessWidget {
  final Faskes faskes;
  const _FaskesMarkerInfo({required this.faskes});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Gradient
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colors.primary, colors.primary.withValues(alpha: 0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: FaskesMarkerIcon.getIcon(faskes.jenis, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            faskes.nama,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              faskes.jenis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    if (faskes.alamatLengkap.isNotEmpty) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colors.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.location_on_rounded, size: 20, color: colors.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                faskes.alamatLengkap.replaceAll('\n', ''),
                                style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (faskes.telepon.isNotEmpty) ...[
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.phone_rounded, size: 20, color: Colors.green),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              faskes.telepon,
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: BorderSide(color: colors.primary.withValues(alpha: 0.5)),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => FaskesDetailScreen(faskesId: faskes.id!),
                                ),
                              );
                            },
                            icon: const Icon(Icons.info_outline_rounded),
                            label: const Text('Detail Lengkap'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              final provider = Provider.of<AppProvider>(context, listen: false);
                              if (provider.userLatLng != null) {
                                provider.fetchRoute(
                                  origin: provider.userLatLng!,
                                  destination: LatLng(faskes.latitude, faskes.longitude),
                                );
                              }
                            },
                            icon: const Icon(Icons.directions_rounded),
                            label: const Text('Mulai Rute'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
