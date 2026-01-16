import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:luminara_photobooth/core/core.dart';
import 'package:luminara_photobooth/features/settings/pages/logs/logs.dart';
import 'package:luminara_photobooth/features/settings/pages/printer/page.dart';
import 'package:luminara_photobooth/features/settings/pages/privacy_policy/page.dart';
import 'package:luminara_photobooth/features/settings/settings.dart';
import 'package:luminara_photobooth/model/log.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:luminara_photobooth/core/preferences/app_state.dart';
import 'package:luminara_photobooth/core/preferences/settings_preferences.dart';
import 'package:provider/provider.dart';

part 'sections/profile_section.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  bool _isMidtransEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final enabled = await SettingsPreferences.isMidtransEnabled();
    setState(() {
      _isMidtransEnabled = enabled;
    });
  }

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
              style: TextButton.styleFrom(foregroundColor: Colors.red),
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
      appBar: AppBar(
        title: const Text('Lainnya'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          primary: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _ProfileSection(),
              const SizedBox(height: Dimens.dp8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(Dimens.dp16),
                    child: RegularText.semiBold('Pengaturan Perangkat'),
                  ),
                  ItemMenuSetting(
                    title: 'Printer',
                    icon: Icons.print,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PrinterPage(),
                        ),
                      );
                    },
                  ),
                  ItemMenuSetting(
                    title: 'Metode Pembayaran',
                    icon: Icons.payment,
                    trailing: Switch(
                      value: _isMidtransEnabled,
                      onChanged: (value) async {
                        await SettingsPreferences.setMidtransEnabled(value);
                        setState(() {
                          _isMidtransEnabled = value;
                        });
                      },
                    ),
                    onTap: () async {
                      final newValue = !_isMidtransEnabled;
                      await SettingsPreferences.setMidtransEnabled(newValue);
                      setState(() {
                        _isMidtransEnabled = newValue;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: Dimens.dp8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(Dimens.dp16),
                    child: RegularText.semiBold('Tampilan'),
                  ),
                  ItemMenuSetting(
                    title: 'Mode Gelap',
                    icon: Icons.dark_mode,
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
              const SizedBox(height: Dimens.dp8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(Dimens.dp16),
                    child: RegularText.semiBold('Info Lainnya'),
                  ),
                  ItemMenuSetting(
                    title: 'Kebijakan Privasi',
                    icon: AppIcons.verified,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PrivacyPolicyPage(),
                        ),
                      );
                    },
                  ),
                  ItemMenuSetting(
                    title: 'Logs',
                    icon: AppIcons.logs,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LogsPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(Dimens.dp16),
                child: OutlinedButton(
                  key: ValueKey('exit_button_${theme.brightness.name}'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    side: BorderSide(color: theme.colorScheme.error),
                  ),
                  onPressed: () {
                    _showExitDialog(context);
                  },
                  child: const Text('Keluar Aplikasi'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
