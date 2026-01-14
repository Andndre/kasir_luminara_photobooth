import 'package:flutter/material.dart';
import 'package:luminara_photobooth/core/core.dart';
import 'package:luminara_photobooth/features/home/home.dart';
import 'package:luminara_photobooth/features/home/pages/pages.dart';

Route<dynamic> routes(settings) {
  switch (settings.name) {
    case MainPage.routeName:
      return MaterialPageRoute(builder: (context) => const MainPage());
    default:
      return MaterialPageRoute(
        builder: (context) {
          return const Scaffold(
            body: Center(
              child: RegularText('Page Not Found', textAlign: TextAlign.center),
            ),
          );
        },
      );
  }
}
