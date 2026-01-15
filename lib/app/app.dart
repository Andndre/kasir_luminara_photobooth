import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luminara_photobooth/app/routes.dart';
import 'package:luminara_photobooth/core/core.dart';
import 'package:luminara_photobooth/core/constants/app_mode.dart';
import 'package:luminara_photobooth/features/home/blocs/blocs.dart';
import 'package:luminara_photobooth/features/settings/settings.dart';
import 'package:luminara_photobooth/features/server/blocs/server_bloc.dart';
import 'package:luminara_photobooth/features/verifier/blocs/verifier_bloc.dart';
import 'package:luminara_photobooth/core/preferences/scroll_behavior.dart';
import 'package:luminara_photobooth/features/mode_selection/mode_selection_page.dart';
import 'package:luminara_photobooth/core/preferences/app_state.dart';
import 'package:provider/provider.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (context) => BottomNavBloc()),
          BlocProvider(create: (context) => ProfileBloc()),
          BlocProvider(create: (context) => ServerBloc()),
          BlocProvider(create: (context) => VerifierBloc()..add(InitializeVerifier())),
        ],
        child: Consumer<AppState>(
          builder: (context, appState, _) {
            return MaterialApp(
              title: 'Luminara Photobooth',
              debugShowCheckedModeBanner: false,
              scrollBehavior: AppScrollBehavior(),
              theme: LightTheme(AppColors.primary).theme,
              darkTheme: DarkTheme(AppColors.primary).theme,
              themeMode: appState.themeMode,
              onGenerateRoute: routes,
              // STABLE TREE: Blocs are now preserved above.
              builder: (context, child) {
                return RepositoryProvider<AppMode>.value(
                  value: appState.mode ?? AppMode.server,
                  child: child!,
                );
              },
              home: appState.hasMode ? const SplashScreen() : const ModeSelectionPage(),
            );
          },
        ),
      ),
    );
  }
}