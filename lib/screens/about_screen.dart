import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tentang Aplikasi'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 32),
            // Logo
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.2),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                Icons.local_hospital_rounded,
                size: 64,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 24),
            
            // App Name
            Text(
              'Jember Health Maps',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Versi 1.0.0',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.outline,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 32),

            // Description Card
            Card(
              elevation: 0,
              color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      'Aplikasi Pemetaan Fasilitas Kesehatan ini dirancang untuk memudahkan masyarakat Jember dalam menemukan, melacak rute, dan melihat informasi detail mengenai Puskesmas, Rumah Sakit, Klinik, dan layanan kesehatan lainnya secara real-time.',
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    Text(
                      'Dikembangkan Oleh:',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colors.outline,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Kaka Patria',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ujian Kompetensi Keahlian (UKK)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 48),
            
            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.flutter_dash, color: colors.outline, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Built with Flutter',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.outline,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
