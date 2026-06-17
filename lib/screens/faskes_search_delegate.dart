import 'package:flutter/material.dart';
import '../models/faskes.dart';
import '../providers/app_provider.dart';

class FaskesSearchDelegate extends SearchDelegate<Faskes?> {
  final AppProvider provider;

  FaskesSearchDelegate(this.provider) : super(
    searchFieldLabel: 'Cari fasilitas kesehatan...',
    keyboardType: TextInputType.text,
  );

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return _buildHistorySuggestions();
    }
    return _buildSearchResults();
  }

  Widget _buildHistorySuggestions() {
    final history = provider.searchHistory;
    
    if (history.isEmpty) {
      return const Center(
        child: Text(
          'Ketik nama rumah sakit, puskesmas,\natau lokasi untuk mencari.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Riwayat Pencarian',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              TextButton(
                onPressed: () => provider.clearSearchHistory(),
                child: const Text('Hapus', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: history.length,
            itemBuilder: (context, index) {
              final item = history[index];
              return ListTile(
                leading: const Icon(Icons.history, color: Colors.grey),
                title: Text(item),
                trailing: const Icon(Icons.north_west, size: 16, color: Colors.grey),
                onTap: () {
                  query = item;
                  showResults(context);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    String q = query.toLowerCase();
    
    // Translate abbreviations for better search results
    q = q.replaceAll(RegExp(r'\bpkm\b'), 'puskesmas');
    q = q.replaceAll(RegExp(r'\brs\b'), 'rumah sakit');
    q = q.replaceAll(RegExp(r'\blab\b'), 'laboratorium');

    final results = provider.allFaskes.where((f) {
      return f.nama.toLowerCase().contains(q) ||
             f.jenis.toLowerCase().contains(q) ||
             f.alamat.toLowerCase().contains(q) ||
             f.alamatLengkap.toLowerCase().contains(q);
    }).toList();

    // Sort search results by distance if location is available
    if (provider.userLatLng != null) {
      results.sort((a, b) => (a.distance ?? double.infinity).compareTo(b.distance ?? double.infinity));
    }

    if (results.isEmpty) {
      return Center(
        child: Text('Tidak ditemukan fasilitas kesehatan\ndengan kata kunci "$query"'),
      );
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final faskes = results[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: _getColor(faskes.jenis).withValues(alpha: 0.2),
            child: Icon(_getIcon(faskes.jenis), color: _getColor(faskes.jenis)),
          ),
          title: Text(faskes.nama, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(faskes.jenis),
          onTap: () {
            provider.addSearchHistory(query.isEmpty ? faskes.nama : query);
            close(context, faskes);
          },
        );
      },
    );
  }

  Color _getColor(String jenis) {
    switch (jenis) {
      case 'Rumah Sakit':
        return Colors.red;
      case 'Puskesmas':
        return Colors.blue;
      case 'Klinik':
        return Colors.orange;
      case 'Apotek':
        return Colors.green;
      case 'Laboratorium':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getIcon(String jenis) {
    switch (jenis) {
      case 'Rumah Sakit':
        return Icons.local_hospital;
      case 'Puskesmas':
        return Icons.medical_services;
      case 'Klinik':
        return Icons.health_and_safety;
      case 'Apotek':
        return Icons.local_pharmacy;
      case 'Laboratorium':
        return Icons.science;
      default:
        return Icons.place;
    }
  }
}
