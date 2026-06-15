import 'package:flutter/material.dart';

class FaskesMarkerIcon {
  static Widget getIcon(String jenis, {double size = 36}) {
    Color color;
    IconData icon;

    switch (jenis.toLowerCase()) {
      case 'rumah sakit':
        color = const Color(0xFFE53935);
        icon = Icons.local_hospital;
        break;
      case 'puskesmas':
        color = const Color(0xFF00897B);
        icon = Icons.medical_services;
        break;
      case 'klinik':
        color = const Color(0xFFFF8F00);
        icon = Icons.health_and_safety;
        break;
      case 'apotek':
        color = const Color(0xFF3949AB);
        icon = Icons.store;
        break;
      case 'laboratorium':
        color = const Color(0xFF8E24AA);
        icon = Icons.science;
        break;
      default:
        color = const Color(0xFF546E7A);
        icon = Icons.place;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(77),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: size * 0.6,
      ),
    );
  }
}
