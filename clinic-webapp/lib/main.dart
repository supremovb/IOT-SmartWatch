import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'constants/app_colors.dart';
import 'providers/auth_provider.dart';
import 'providers/app_provider.dart';
import 'auth/login_screen.dart';
import 'auth/signup_screen.dart';
import 'auth/forgot_password_screen.dart';
import 'auth/reset_password_screen.dart';
import 'screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // MUST check recovery indicators BEFORE Supabase.initialize()
  // because initialize() processes the hash fragment and cleans the URL,
  // consuming the access_token & type=recovery before we can read them.
  final href = html.window.location.href;
  final isRecoveryFromUrl =
      href.contains('type=recovery') || href.contains('recovery=true');
  final isRecoveryFromStorage =
      html.window.sessionStorage['pending_recovery'] == 'true';
  if (isRecoveryFromStorage) {
    html.window.sessionStorage.remove('pending_recovery');
  }
  final isRecoveryLink = isRecoveryFromUrl || isRecoveryFromStorage;

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.implicit,
    ),
  );

  AuthProvider.pendingRecovery = isRecoveryLink;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AppProvider()),
      ],
      child: Consumer<AppProvider>(
        builder: (context, appProvider, _) => MaterialApp(
        title: 'Dominican Smart Watch',
        debugShowCheckedModeBanner: false,
        themeMode: appProvider.darkMode ? ThemeMode.dark : ThemeMode.light,
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            brightness: Brightness.dark,
          ),
          textTheme: GoogleFonts.interTextTheme(ThemeData(brightness: Brightness.dark).textTheme),
          scaffoldBackgroundColor: const Color(0xFF121212),
          appBarTheme: AppBarTheme(
            elevation: 0,
            centerTitle: false,
            titleTextStyle: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          cardTheme: CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            brightness: Brightness.light,
          ),
          textTheme: GoogleFonts.interTextTheme(),
          scaffoldBackgroundColor: AppColors.background,
          appBarTheme: AppBarTheme(
            backgroundColor: AppColors.surface,
            elevation: 0,
            centerTitle: false,
            titleTextStyle: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          cardTheme: CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            color: AppColors.surface,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
        home: Consumer<AuthProvider>(
          builder: (context, authProvider, _) {
            if (authProvider.isInitializing) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }
            if (authProvider.isPasswordRecovery) {
              return const ResetPasswordScreen();
            }
            if (authProvider.isLoggedIn) {
              return const MainScreen();
            } else {
              return const LoginScreen();
            }
          },
        ),
        onGenerateRoute: (settings) {
          // Auth routes
          if (settings.name == '/login') {
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => const LoginScreen(),
            );
          }
          if (settings.name == '/signup') {
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => const SignupScreen(),
            );
          }
          if (settings.name == '/forgot-password') {
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => const ForgotPasswordScreen(),
            );
          }
          if (settings.name == '/reset-password') {
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => const ResetPasswordScreen(),
            );
          }

          // All app routes go through MainScreen with the route passed in
          const appRoutes = {
            '/dashboard', '/patients', '/alerts',
            '/reports', '/devices', '/settings', '/messages', '/users',
          };
          final route = settings.name ?? '/dashboard';
          if (appRoutes.contains(route)) {
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => Consumer<AuthProvider>(
                builder: (context, auth, _) {
                  if (!auth.isLoggedIn && !auth.isInitializing) {
                    return const LoginScreen();
                  }
                  return MainScreen(initialRoute: route);
                },
              ),
            );
          }

          // Default fallback — must also check for recovery/auth state
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => Consumer<AuthProvider>(
              builder: (context, auth, _) {
                if (auth.isInitializing) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                if (auth.isPasswordRecovery) {
                  return const ResetPasswordScreen();
                }
                if (auth.isLoggedIn) {
                  return const MainScreen();
                }
                return const LoginScreen();
              },
            ),
          );
        },
      ),
        ),
    );
  }
}
