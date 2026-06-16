import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/faskes_card.dart';
import 'faskes_detail_screen.dart';

class FaskesListScreen extends StatefulWidget {
  const FaskesListScreen({super.key});

  @override
  State<FaskesListScreen> createState() => _FaskesListScreenState();
}

class _FaskesListScreenState extends State<FaskesListScreen> {
  final _searchController = TextEditingController();
  bool _showFilter = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Daftar Faskes'),
            centerTitle: true,
            actions: [
              IconButton(
                icon: Icon(_showFilter ? Icons.filter_list_off : Icons.filter_list),
                onPressed: () => setState(() => _showFilter = !_showFilter),
              ),
            ],
          ),
          body: Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari fasilitas kesehatan...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              provider.setSearch('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: colors.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) => provider.setSearch(value),
                ),
              ),

              // Filter chips
              if (_showFilter)
                Container(
                  height: 48,
                  margin: const EdgeInsets.symmetric(vertical: 4),
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
                      final isSelected = provider.selectedFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FilterChip(
                          label: Text(filter),
                          selected: isSelected,
                          onSelected: (_) => provider.setFilter(filter),
                        ),
                      );
                    }).toList(),
                  ),
                ),

              // List
              Expanded(
                child: provider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : provider.filteredFaskes.isEmpty
                        ? Center(
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
                          )
                        : RefreshIndicator(
                            onRefresh: () => provider.loadAllFaskes(),
                            child: ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: provider.filteredFaskes.length,
                              itemBuilder: (_, index) {
                                final faskes = provider.filteredFaskes[index];
                                return FaskesCard(
                                  faskes: faskes,
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => FaskesDetailScreen(
                                            faskesId: faskes.id!),
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
