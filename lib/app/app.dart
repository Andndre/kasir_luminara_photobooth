import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kasir/app/routes.dart';
import 'package:kasir/core/core.dart';
import 'package:kasir/core/constants/app_mode.dart';
import 'package:kasir/features/home/blocs/blocs.dart';
import 'package:kasir/features/settings/settings.dart';
import 'package:kasir/features/server/blocs/server_bloc.dart';
import 'package:kasir/features/verifier/blocs/verifier_bloc.dart';
import 'package:kasir/core/preferences/scroll_behavior.dart';
import 'package:kasir/features/mode_selection/mode_selection_page.dart';
import 'package:kasir/core/preferences/app_state.dart';
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
                BlocProvider(create: (context) => ServerBloc()..add(StartServer())),
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