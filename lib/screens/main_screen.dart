import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

import 'dashboard_screen.dart';
import 'maps_screen.dart';
import 'faskes_list_screen.dart';
import 'nearest_faskes_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final List<Widget> _screens = const [
    DashboardScreen(),
    MapsScreen(),
    FaskesListScreen(),
    NearestFaskesScreen(),
    ProfileScreen(),
  ];

  bool _showOnlineBanner = false;
  Timer? _bannerTimer;
  late AppProvider _provider;
  bool _lastInternetState = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider = Provider.of<AppProvider>(context, listen: false);
      _lastInternetState = _provider.hasInternet;
      _provider.addListener(_onProviderChange);
    });
  }

  void _onProviderChange() {
    final hasInternet = _provider.hasInternet;
    if (!_lastInternetState && hasInternet) {
      // Transisi dari offline ke online
      if (mounted) {
        setState(() {
          _showOnlineBanner = true;
        });
        _bannerTimer?.cancel();
        _bannerTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _showOnlineBanner = false;
            });
          }
        });
      }
    } else if (_lastInternetState && !hasInternet) {
      // Transisi dari online ke offline, matikan banner hijau jika sedang tayang
      if (mounted && _showOnlineBanner) {
        setState(() {
          _showOnlineBanner = false;
        });
      }
    }
    _lastInternetState = hasInternet;
  }

  @override
  void dispose() {
    _provider.removeListener(_onProviderChange);
    _bannerTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: provider.mainTabIndex,
            children: _screens,
          ),
          
          // Banner Offline (Merah)
          if (!provider.hasInternet)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.red.shade600.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: const [
                    Icon(Icons.wifi_off_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tidak ada koneksi internet. Peta & rute mungkin gagal dimuat.',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          // Banner Online Restored (Hijau)
          else if (_showOnlineBanner)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.green.shade600.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: const [
                    Icon(Icons.wifi_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Koneksi internet kembali terhubung!',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),

      bottomNavigationBar: NavigationBar(
        selectedIndex: provider.mainTabIndex,
        onDestinationSelected: (index) {
          provider.setMainTabIndex(index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Peta',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Faskes',
          ),
          NavigationDestination(
            icon: Icon(Icons.near_me_outlined),
            selectedIcon: Icon(Icons.near_me),
            label: 'Terdekat',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outlined),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
