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
      child: Consumer<AppState>(
        builder: (context, appState, _) {
          return MultiBlocProvider(
            // Key ensures Bloc is recreated when mode changes
            key: ValueKey(appState.mode), 
            providers: [
              BlocProvider(create: (context) => BottomNavBloc()),
              BlocProvider(create: (context) => ProfileBloc()),
              if (appState.mode == AppMode.server)
                BlocProvider(create: (context) => ServerBloc()),
              if (appState.mode == AppMode.client)
                BlocProvider(create: (context) => VerifierBloc()),
            ],
            child: RepositoryProvider.value(
              value: appState.mode ?? AppMode.server, // Fallback safe
              child: MaterialApp(
                title: 'Luminara Photobooth',
                debugShowCheckedModeBanner: false,
                scrollBehavior: AppScrollBehavior(),
                theme: LightTheme(AppColors.primary).theme,
                // If mode not selected, show selection page, otherwise start splash
                home: appState.hasMode ? const SplashScreen() : const ModeSelectionPage(),
                onGenerateRoute: routes,
              ),
            ),
          );
        },
      ),
    );
  }
}