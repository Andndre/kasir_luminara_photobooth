import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:luminara_photobooth/core/core.dart';
import 'package:luminara_photobooth/features/settings/settings.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:luminara_photobooth/core/preferences/app_state.dart';
import 'package:luminara_photobooth/core/preferences/settings_preferences.dart';
import 'package:provider/provider.dart';

part 'settings_profile_section.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Status Midtrans dipegang oleh _MidtransMenu supaya toggle-nya tidak
  // merebuild seluruh halaman setelan.

  void _showExitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Keluar dari Aplikasi'),
          content: const Text('Apakah Anda yakin ingin keluar dari aplikasi?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                SystemNavigator.pop();
              },
              style: TextButton.styleFrom(foregroundColor: AppTokens.danger),
              child: const Text('Keluar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Setelan')),
      body: SafeArea(
        child: SingleChildScrollView(
          primary: true,
          padding: const EdgeInsets.fromLTRB(
            Dimens.dp20,
            Dimens.dp8,
            Dimens.dp20,
            Dimens.dp32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _ProfileSection(),
              const SizedBox(height: Dimens.dp24),

              const _SettingGroup(
                title: 'Perangkat',
                children: [_PrinterMenu(), _MidtransMenu()],
              ),
              const SizedBox(height: Dimens.dp20),

              _SettingGroup(
                title: 'Tampilan',
                children: [
                  ItemMenuSetting(
                    title: 'Mode Gelap',
                    icon: Icons.dark_mode_outlined,
                    trailing: Switch(
                      value:
                          context.watch<AppState>().themeMode == ThemeMode.dark,
                      onChanged: (value) {
                        context.read<AppState>().setThemeMode(
                          value ? ThemeMode.dark : ThemeMode.light,
                        );
                      },
                    ),
                    onTap: () {
                      final current = context.read<AppState>().themeMode;
                      context.read<AppState>().setThemeMode(
                        current == ThemeMode.light
                            ? ThemeMode.dark
                            : ThemeMode.light,
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: Dimens.dp20),

              _SettingGroup(
                title: 'Data & Info',
                children: [
                  ItemMenuSetting(
                    title: 'Backup & Restore',
                    icon: Icons.backup_outlined,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BackupPage()),
                    ),
                  ),
                  ItemMenuSetting(
                    title: 'Logs',
                    icon: AppIcons.logs,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LogsPage()),
                    ),
                  ),
                  ItemMenuSetting(
                    title: 'Kebijakan Privasi',
                    icon: AppIcons.verified,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyPage(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Dimens.dp24),

              TextButton(
                key: ValueKey('exit_button_${theme.brightness.name}'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                onPressed: () => _showExitDialog(context),
                child: const Text('Keluar Aplikasi'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grup setelan: judul eyebrow di LUAR kartu, isinya di dalam satu kartu
/// dengan pemisah tipis. Menggantikan daftar telanjang tanpa batas grup.
class _SettingGroup extends StatelessWidget {
  const _SettingGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: Dimens.dp4, bottom: Dimens.dp8),
          child: EyebrowText(title),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Divider(height: 1, indent: 52, color: surfaces.border),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Dipisah jadi widget sendiri supaya [_SettingGroup] bisa const.
class _PrinterMenu extends StatelessWidget {
  const _PrinterMenu();

  @override
  Widget build(BuildContext context) {
    return ItemMenuSetting(
      title: 'Printer',
      icon: Icons.print_outlined,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PrinterPage()),
      ),
    );
  }
}

class _MidtransMenu extends StatefulWidget {
  const _MidtransMenu();

  @override
  State<_MidtransMenu> createState() => _MidtransMenuState();
}

class _MidtransMenuState extends State<_MidtransMenu> {
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    SettingsPreferences.isMidtransEnabled().then((v) {
      if (mounted) setState(() => _enabled = v);
    });
  }

  Future<void> _toggle(bool value) async {
    await SettingsPreferences.setMidtransEnabled(value);
    if (mounted) setState(() => _enabled = value);
  }

  @override
  Widget build(BuildContext context) {
    return ItemMenuSetting(
      title: 'Pembayaran Online',
      subtitle: _enabled ? 'Midtrans aktif' : 'Hanya tunai & transfer manual',
      icon: Icons.payment_outlined,
      trailing: Switch(value: _enabled, onChanged: _toggle),
      onTap: () => _toggle(!_enabled),
    );
  }
}
