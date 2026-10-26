import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/animations/emil_spring_button.dart';
import '../../core/constants/app_colors.dart';
import '../analytics/presentation/analytics_screen.dart';
import '../budgeting/presentation/budgeting_screen.dart';
import '../dashboard/presentation/dashboard_screen.dart';
import '../quick_entry/presentation/quick_entry_sheet.dart';
import '../settings/presentation/settings_screen.dart';

class MainNavScreen extends StatefulWidget {
  const MainNavScreen({super.key});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    DashboardScreen(),
    BudgetingScreen(),
    AnalyticsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      // IndexedStack menjaga setiap tab tetap hidup, jadi posisi scroll dan state
      // tidak hilang saat berpindah tab. Efek fade tetap ada lewat AnimatedOpacity.
      body: IndexedStack(
        index: _currentIndex,
        children: [
          for (var i = 0; i < _pages.length; i++)
            AnimatedOpacity(
              opacity: i == _currentIndex ? 1.0 : 0.0,
              duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 200),
              curve: Curves.easeOutQuad,
              child: _pages[i],
            ),
        ],
      ),
      // Central Floating Quick Entry Button dengan efek Emil Spring Taktil
      floatingActionButton: EmilSpringButton(
        onTap: () {
          QuickEntrySheet.show(context);
        },
        pressScale: 0.88,
        child: const FloatingActionButton(
          onPressed: null, // Dikendalikan oleh EmilSpringButton
          backgroundColor: AppColors.gojekGreen,
          foregroundColor: Colors.white,
          elevation: 3,
          shape: CircleBorder(),
          child: Icon(LucideIcons.plus, size: 28),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: const Border(top: BorderSide(color: AppColors.border, width: 1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: BottomAppBar(
            color: AppColors.surface,
            elevation: 0,
            notchMargin: 8,
            shape: const CircularNotchedRectangle(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, LucideIcons.home, 'Beranda'),
                _buildNavItem(1, LucideIcons.pieChart, 'Anggaran'),
                const SizedBox(width: 48), // Space for centered FAB
                _buildNavItem(2, LucideIcons.barChart2, 'Analisis'),
                _buildNavItem(3, LucideIcons.settings, 'Pengaturan'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return EmilSpringButton(
      onTap: () {
        setState(() => _currentIndex = index);
      },
      pressScale: 0.92,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: (isSelected && !reduceMotion) ? 1.14 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: Icon(
                icon,
                size: 21,
                color: isSelected ? AppColors.gojekGreen : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.gojekGreen : AppColors.textSecondary,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
