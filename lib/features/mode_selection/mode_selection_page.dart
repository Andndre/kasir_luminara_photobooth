import 'package:flutter/material.dart';
import 'package:kasir/core/constants/app_mode.dart';
import 'package:kasir/core/core.dart';
import 'package:kasir/core/preferences/app_state.dart';
import 'package:provider/provider.dart';

class ModeSelectionPage extends StatelessWidget {
  const ModeSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Select Mode',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 48),
              _ModeCard(
                title: 'SERVER (KASIR)',
                icon: Icons.computer,
                description: 'Manage transactions, print receipts, and host local server.',
                onTap: () {
                  context.read<AppState>().setMode(AppMode.server);
                },
              ),
              const SizedBox(height: 24),
              _ModeCard(
                title: 'CLIENT (VERIFIER)',
                icon: Icons.qr_code_scanner,
                description: 'Scan tickets and verify entry.',
                onTap: () {
                  context.read<AppState>().setMode(AppMode.client);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String description;
  final VoidCallback onTap;

  const _ModeCard({
    required this.title,
    required this.icon,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(icon, size: 48, color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
