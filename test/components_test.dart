import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luminara_photobooth/core/domain/transaction_status.dart';
import 'package:luminara_photobooth/core/components/surface/surface.dart';
import 'package:luminara_photobooth/core/preferences/theme/app_theme.dart';

/// Smoke test: komponen bersama harus render tanpa exception di kedua tema.
/// Menangkap overflow dan constraint error tanpa perlu build aplikasi.
void main() {
  Future<void> pumpIn(
    WidgetTester tester,
    Brightness brightness,
    Widget child,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(brightness),
        home: Scaffold(
          body: Center(child: SizedBox(width: 360, child: child)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    final mode = brightness == Brightness.dark ? 'dark' : 'light';

    testWidgets('AppCard render di $mode', (tester) async {
      await pumpIn(tester, brightness, const AppCard(child: Text('isi kartu')));
      expect(tester.takeException(), isNull);
      expect(find.text('isi kartu'), findsOneWidget);
    });

    testWidgets('HeroPanel render di $mode', (tester) async {
      await pumpIn(
        tester,
        brightness,
        const HeroPanel(
          label: 'Total Pemasukan',
          value: 'Rp 1.250.000',
          meta: '12 transaksi',
          icon: Icons.storefront_rounded,
        ),
      );
      expect(tester.takeException(), isNull);
      // Eyebrow selalu uppercase.
      expect(find.text('TOTAL PEMASUKAN'), findsOneWidget);
      expect(find.text('Rp 1.250.000'), findsOneWidget);
    });

    testWidgets('StatusBadge semua status render di $mode', (tester) async {
      await pumpIn(
        tester,
        brightness,
        Wrap(
          children: [
            for (final status in TransactionStatus.values) StatusBadge(status),
            // Nilai tak dikenal dari DB lama jangan bikin crash — jatuh ke PAID.
            StatusBadge(TransactionStatus.fromDb('ENTAH')),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('PAID'), findsNWidgets(2));
      expect(find.text('COMPLETED'), findsOneWidget);
    });

    testWidgets('PackageMonogram render di $mode', (tester) async {
      await pumpIn(
        tester,
        brightness,
        const Row(
          children: [
            PackageMonogram('Self Photo 15 Menit'),
            PackageMonogram('Wide Angle Photo'),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('SP'), findsOneWidget);
      expect(find.text('WA'), findsOneWidget);
    });
  }

  testWidgets('AppCard yang bisa ditap memanggil onTap', (tester) async {
    var tapped = false;
    await pumpIn(
      tester,
      Brightness.light,
      AppCard(onTap: () => tapped = true, child: const Text('tap')),
    );
    await tester.tap(find.text('tap'));
    expect(tapped, isTrue);
  });

  testWidgets('Teks panjang di HeroPanel tidak overflow', (tester) async {
    await pumpIn(
      tester,
      Brightness.light,
      const SizedBox(
        width: 200,
        child: HeroPanel(
          label: 'Total Pemasukan Sepanjang Bulan Berjalan',
          value: 'Rp 1.250.000.000',
          meta: 'Ini baris meta yang sengaja dibuat sangat panjang sekali',
          icon: Icons.storefront_rounded,
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
