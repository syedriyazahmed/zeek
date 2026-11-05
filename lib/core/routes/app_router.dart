import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/authentication/presentation/login_screen.dart';
import '../../features/authentication/providers/auth_provider.dart';
import '../../features/debug/firebase_check_screen.dart';
import '../../shared/layouts/responsive_shell.dart';

// Placeholder / Full screens for routes
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/pos/presentation/pos_screen.dart';
import '../../features/inventory/presentation/inventory_screen.dart';
import '../../features/sales/presentation/sales_screen.dart';
import '../../features/accounts/presentation/accounts_screen.dart';
import '../../features/stock_sold/presentation/stock_sold_screen.dart';
import '../../features/non_oil/presentation/non_oil_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/pos',
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final isLoading = authState.isLoading;
      final isLoggedIn = authState.asData?.value != null;
      final isLoggingIn = state.uri.path == '/login';
      final isFirebaseCheck = state.uri.path == '/firebase-check';

      if (isLoading) return null;

      if (!isLoggedIn) {
        if (isFirebaseCheck) return null;
        return isLoggingIn ? null : '/login';
      }

      if (isLoggingIn) {
        return '/pos';
      }

      // Role-based protection
      final user = authState.asData!.value!;
      if (user.isEmployee) {
        if (state.uri.path.startsWith('/settings') ||
            state.uri.path.startsWith('/reports')) {
          return '/pos';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/firebase-check',
        builder: (context, state) => const FirebaseCheckScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return ResponsiveShell(
            currentPath: state.uri.path,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/pos',
            builder: (context, state) => const PosScreen(),
          ),
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/inventory',
            builder: (context, state) => const InventoryScreen(),
          ),
          GoRoute(
            path: '/sales',
            builder: (context, state) => const SalesScreen(),
          ),
          GoRoute(
            path: '/accounts',
            builder: (context, state) => const AccountsScreen(),
          ),
          GoRoute(
            path: '/stock-sold',
            builder: (context, state) => const StockSoldScreen(),
          ),
          GoRoute(
            path: '/non-oil',
            builder: (context, state) => const NonOilScreen(),
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportsScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});
