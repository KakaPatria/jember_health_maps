import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../providers/app_provider.dart';
import 'edit_profile_screen.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final user = provider.currentUser;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Profil'),
            centerTitle: true,
          ),
          body: user == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.account_circle,
                          size: 80, color: colors.outline),
                      const SizedBox(height: 16),
                      Text(
                        'Anda belum masuk',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.login),
                        label: const Text('Masuk / Daftar'),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Avatar
                    Center(
                      child: CircleAvatar(
                        radius: 48,
                        backgroundColor: colors.primaryContainer,
                        backgroundImage: user.profilePicture != null
                            ? (kIsWeb
                                ? NetworkImage(user.profilePicture!)
                                : FileImage(File(user.profilePicture!))) as ImageProvider
                            : null,
                        child: user.profilePicture == null
                            ? Text(
                                user.nama.isNotEmpty
                                    ? user.nama[0].toUpperCase()
                                    : 'U',
                                style: theme.textTheme.displaySmall?.copyWith(
                                  color: colors.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        user.nama,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Center(
                      child: Text(
                        user.email,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.outline,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Info cards
                    Card(
                      elevation: 0,
                      color: colors.surfaceContainerHighest,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _ProfileItem(
                            icon: Icons.person_outline,
                            label: 'Nama',
                            value: user.nama,
                          ),
                          const Divider(height: 1, indent: 56),
                          _ProfileItem(
                            icon: Icons.email_outlined,
                            label: 'Email',
                            value: user.email,
                          ),
                          const Divider(height: 1, indent: 56),
                          _ProfileItem(
                            icon: Icons.phone_outlined,
                            label: 'Telepon',
                            value: user.telepon,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Edit profile button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  EditProfileScreen(user: user),
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit Profil'),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Logout button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: TextButton.icon(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Konfirmasi'),
                              content:
                                  const Text('Apakah Anda yakin ingin keluar?'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Batal'),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.pop(context, true),
                                  child: const Text('Keluar'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await provider.logoutUser();
                            if (!context.mounted) return;
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
                            );
                          }
                        },
                        icon: Icon(Icons.logout, color: colors.error),
                        label: Text(
                          'Keluar',
                          style: TextStyle(color: colors.error),
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

class _ProfileItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
      subtitle: Text(
        value,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
