import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/faskes_card.dart';
import 'faskes_detail_screen.dart';

class NearestFaskesScreen extends StatefulWidget {
  const NearestFaskesScreen({super.key});

  @override
  State<NearestFaskesScreen> createState() => _NearestFaskesScreenState();
}

class _NearestFaskesScreenState extends State<NearestFaskesScreen> {
  String _filterJenis = 'Semua';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNearest();
    });
  }

  Future<void> _loadNearest() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final located = await provider.fetchUserLocation();
    if (located) {
      provider.computeNearestFaskes(filterJenis: _filterJenis);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Faskes Terdekat'),
            centerTitle: true,
          ),
          body: Column(
            children: [
              // Filter chips
              Container(
                height: 48,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    'Semua',
                    'Favorit',
                    'Rumah Sakit',
                    'Puskesmas',
                    'Klinik',
                    'Apotek',
                    'Laboratorium',
                  ].map((filter) {
                    final isSelected = _filterJenis == filter;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FilterChip(
                        label: Text(filter),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() => _filterJenis = filter);
                          provider.computeNearestFaskes(
                              filterJenis: filter);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),

              // Lokasi tidak ditemukan
              if (provider.userPosition == null)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_off,
                            size: 64, color: colors.outline),
                        const SizedBox(height: 16),
                        Text(
                          'Aktifkan lokasi untuk melihat\nfasilitas terdekat',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colors.outline,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _loadNearest,
                          icon: const Icon(Icons.my_location),
                          label: const Text('Aktifkan Lokasi'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (provider.nearestFaskes.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off,
                            size: 64, color: colors.outline),
                        const SizedBox(height: 16),
                        Text(
                          'Tidak ada fasilitas ditemukan',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colors.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadNearest,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: provider.nearestFaskes.length,
                      itemBuilder: (_, index) {
                        final faskes = provider.nearestFaskes[index];
                        final distance = faskes.distance ?? 0;
                        return FaskesCard(
                          faskes: faskes,
                          distance: distance,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    FaskesDetailScreen(faskesId: faskes.id!),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
