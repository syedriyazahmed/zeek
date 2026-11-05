import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/date_formatter.dart';
import '../../features/authentication/providers/auth_provider.dart';
import '../../services/firebase/firebase_service.dart';

class ResponsiveShell extends ConsumerWidget {
  final Widget child;
  final String currentPath;

  const ResponsiveShell({
    super.key,
    required this.child,
    required this.currentPath,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= AppConstants.mobileBreakpoint;
    final authState = ref.watch(authStateProvider);
    final user = authState.asData?.value;

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            // Left Desktop Sidebar
            _buildDesktopSidebar(context, ref, user),
            // Right Main Content + Top Navigation Bar
            Expanded(
              child: Column(
                children: [
                  _buildOfflineBanner(),
                  _buildDesktopTopBar(context, ref, user),
                  const Divider(height: 1, thickness: 1, color: AppColors.border),
                  Expanded(
                    child: Container(
                      color: AppColors.background,
                      child: child,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      // Mobile Layout
      return Scaffold(
        appBar: _buildMobileAppBar(context, ref, user),
        body: Column(
          children: [
            _buildOfflineBanner(),
            Expanded(
              child: Container(
                color: AppColors.background,
                child: child,
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildMobileBottomNav(context, ref, user),
      );
    }
  }

  // --- Offline / Local Mode Banner ---
  Widget _buildOfflineBanner() {
    if (FirebaseService.instance.isInitialized) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFFFFFBEB), // Amber-50
      child: Row(
        children: [
          const Icon(Icons.cloud_off, size: 18, color: Color(0xFFD97706)),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Offline / Local Mode Active: Local in-memory cache only (not synced with Firebase)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF92400E),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFFDE68A),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'LOCAL MODE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF78350F),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Desktop Top Bar ---
  Widget _buildDesktopTopBar(BuildContext context, WidgetRef ref, dynamic user) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      color: Colors.white,
      child: Row(
        children: [
          // Current Date
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(
                  DateFormatter.formatDate(DateTime.now()),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // User Role Pill
          if (user != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: user.isAdmin ? AppColors.primaryContainer : AppColors.onlineBlueLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: user.isAdmin ? AppColors.primary : AppColors.onlineBlue,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    user.isAdmin ? Icons.admin_panel_settings : Icons.badge_outlined,
                    size: 14,
                    color: user.isAdmin ? AppColors.primaryDark : AppColors.onlineBlue,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    user.isAdmin ? 'ADMIN' : 'STAFF',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: user.isAdmin ? AppColors.primaryDark : AppColors.onlineBlue,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Profile Info
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  user.displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  user.email,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            // Firebase Live Test Screen
            IconButton(
              icon: const Icon(Icons.cloud_sync, color: AppColors.primary),
              tooltip: 'Test Firebase Connection',
              onPressed: () => context.push('/firebase-check'),
            ),
            // Logout
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: AppColors.danger),
              tooltip: 'Logout',
              onPressed: () => _confirmLogout(context, ref),
            ),
          ],
        ],
      ),
    );
  }

  // --- Desktop Sidebar ---
  Widget _buildDesktopSidebar(BuildContext context, WidgetRef ref, dynamic user) {
    final isAdmin = user?.isAdmin ?? false;

    return Container(
      width: 260,
      color: AppColors.sidebarBg,
      child: Column(
        children: [
          // Logo & Shop Name
          Container(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withAlpha(76),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.spa_rounded, color: Colors.white, size: 26),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AL-ABEER',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Text(
                        'Perfumes & Athar',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFF1E293B)),
          const SizedBox(height: 12),

          // Navigation Links
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildSidebarItem(
                  context,
                  icon: Icons.point_of_sale_rounded,
                  label: 'Point of Sale (POS)',
                  route: '/pos',
                  isHighlight: true,
                ),
                _buildSidebarItem(
                  context,
                  icon: Icons.dashboard_outlined,
                  label: 'Dashboard',
                  route: '/dashboard',
                ),
                _buildSidebarItem(
                  context,
                  icon: Icons.water_drop_outlined,
                  label: 'Oil Inventory',
                  route: '/inventory',
                ),
                _buildSidebarItem(
                  context,
                  icon: Icons.inventory_2_outlined,
                  label: 'Non-Oil Products',
                  route: '/non-oil',
                ),
                _buildSidebarItem(
                  context,
                  icon: Icons.receipt_long_outlined,
                  label: 'Sales History',
                  route: '/sales',
                ),
                _buildSidebarItem(
                  context,
                  icon: Icons.trending_up_rounded,
                  label: 'Stock Sold Report',
                  route: '/stock-sold',
                ),
                if (isAdmin) ...[
                  _buildSidebarItem(
                    context,
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Accounts & Expenses',
                    route: '/accounts',
                  ),
                  _buildSidebarItem(
                    context,
                    icon: Icons.bar_chart_rounded,
                    label: 'Analytics & Reports',
                    route: '/reports',
                  ),
                  _buildSidebarItem(
                    context,
                    icon: Icons.settings_outlined,
                    label: 'Shop Settings',
                    route: '/settings',
                  ),
                ],
              ],
            ),
          ),

          // Footer version
          Container(
            padding: const EdgeInsets.all(16),
            child: const Text(
              'v1.0.0 • Production Build',
              style: TextStyle(color: Color(0xFF475569), fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String route,
    bool isHighlight = false,
  }) {
    final isSelected = currentPath == route;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: isSelected
            ? (isHighlight ? AppColors.primary : const Color(0xFF1E293B))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            if (currentPath != route) {
              context.go(route);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                if (isHighlight && !isSelected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Mobile Top App Bar ---
  PreferredSizeWidget _buildMobileAppBar(BuildContext context, WidgetRef ref, dynamic user) {
    return AppBar(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.spa_rounded, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AL-ABEER',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              Text(
                'Perfumes & Athar',
                style: TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
      actions: [
        if (user != null)
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: user.isAdmin ? AppColors.primaryContainer : AppColors.onlineBlueLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              user.isAdmin ? 'ADMIN' : 'STAFF',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: user.isAdmin ? AppColors.primaryDark : AppColors.onlineBlue,
              ),
            ),
          ),
        IconButton(
          icon: const Icon(Icons.cloud_sync, size: 20, color: AppColors.primary),
          tooltip: 'Test Firebase Connection',
          onPressed: () => context.push('/firebase-check'),
        ),
        IconButton(
          icon: const Icon(Icons.logout_rounded, size: 20, color: AppColors.danger),
          onPressed: () => _confirmLogout(context, ref),
        ),
      ],
    );
  }

  // --- Mobile Bottom Navigation ---
  Widget _buildMobileBottomNav(BuildContext context, WidgetRef ref, dynamic user) {
    final isAdmin = user?.isAdmin ?? false;

    int getSelectedIndex() {
      if (currentPath == '/pos') return 0;
      if (currentPath == '/inventory') return 1;
      if (currentPath == '/sales') return 2;
      if (currentPath == '/accounts') return 3;
      return 4; // 'More'
    }

    return NavigationBar(
      selectedIndex: getSelectedIndex(),
      backgroundColor: Colors.white,
      indicatorColor: AppColors.primaryContainer,
      elevation: 8,
      onDestinationSelected: (index) {
        switch (index) {
          case 0:
            context.go('/pos');
            break;
          case 1:
            context.go('/inventory');
            break;
          case 2:
            context.go('/sales');
            break;
          case 3:
            if (isAdmin) {
              context.go('/accounts');
            } else {
              context.go('/stock-sold');
            }
            break;
          case 4:
            _showMobileMoreSheet(context, ref, isAdmin);
            break;
        }
      },
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.point_of_sale_outlined),
          selectedIcon: Icon(Icons.point_of_sale, color: AppColors.primary),
          label: 'POS',
        ),
        const NavigationDestination(
          icon: Icon(Icons.water_drop_outlined),
          selectedIcon: Icon(Icons.water_drop, color: AppColors.primary),
          label: 'Inventory',
        ),
        const NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long, color: AppColors.primary),
          label: 'Sales',
        ),
        NavigationDestination(
          icon: Icon(isAdmin ? Icons.account_balance_wallet_outlined : Icons.trending_up),
          selectedIcon: Icon(isAdmin ? Icons.account_balance_wallet : Icons.trending_up, color: AppColors.primary),
          label: isAdmin ? 'Accounts' : 'Stock Sold',
        ),
        const NavigationDestination(
          icon: Icon(Icons.menu_rounded),
          selectedIcon: Icon(Icons.menu_rounded, color: AppColors.primary),
          label: 'More',
        ),
      ],
    );
  }

  void _showMobileMoreSheet(BuildContext context, WidgetRef ref, bool isAdmin) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'More Options',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.dashboard_outlined),
                  title: const Text('Dashboard'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.go('/dashboard');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: const Text('Non-Oil Products'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.go('/non-oil');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.trending_up_rounded),
                  title: const Text('Stock Sold Report'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.go('/stock-sold');
                  },
                ),
                if (isAdmin) ...[
                  ListTile(
                    leading: const Icon(Icons.bar_chart_rounded),
                    title: const Text('Reports & Analytics'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      context.go('/reports');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: const Text('Shop Settings'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      context.go('/settings');
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to end your current session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await ref.read(authStateProvider.notifier).signOut();
              if (context.mounted) {
                context.go('/login');
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
