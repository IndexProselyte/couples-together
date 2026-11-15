import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme_notifier.dart';
import 'design_tokens.dart';
import 'pages/login_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/chat_page.dart';
import 'pages/timeline_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Load persisted theme settings.
  final prefs = await SharedPreferences.getInstance();
  themeIsHers.value  = prefs.getBool('theme_is_hers') ?? true;
  themeDarkMode.value = prefs.getBool('dark_mode') ?? false;
  themeIsHers.addListener(()  => prefs.setBool('theme_is_hers', themeIsHers.value));
  themeDarkMode.addListener(() => prefs.setBool('dark_mode', themeDarkMode.value));

  runApp(const CouplesApp());
}

class CouplesApp extends StatelessWidget {
  const CouplesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: themeIsHers,
      builder: (_, isHers, __) {
        return ValueListenableBuilder<bool>(
          valueListenable: themeDarkMode,
          builder: (_, isDark, __) {
            final themeData = AppThemeData(isHers: isHers, isDark: isDark);
            return AppThemeScope(
              data: themeData,
              child: MaterialApp(
                title: 'Together',
                theme: appTheme(isHers: isHers, isDark: isDark),
                debugShowCheckedModeBanner: false,
                initialRoute: '/',
                routes: {
                  '/': (_) => const LoginPage(),
                  '/home': (_) => const AppShell(),
                },
              ),
            );
          },
        );
      },
    );
  }
}

// ── Shared page route with fade + slide-up transition ─────────────────────────

class AppFadeSlideRoute<T> extends PageRouteBuilder<T> {
  AppFadeSlideRoute({required Widget page})
      : super(
          transitionDuration: const Duration(milliseconds: 280),
          reverseTransitionDuration: const Duration(milliseconds: 220),
          pageBuilder: (_, __, ___) => page,
          transitionsBuilder: (_, anim, __, child) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
              child: child,
            ),
          ),
        );
}

// ── App Shell (bottom nav host) ───────────────────────────────────────────────

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  static final List<Widget> _pages = [
    const DashboardPage(),
    const ChatPage(),
    const TimelinePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeScope.of(context).background,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        child: KeyedSubtree(
          key: ValueKey(_currentIndex),
          child: _pages[_currentIndex],
        ),
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

// ── Bottom Navigation ─────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.currentIndex, required this.onTap});
  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = [
    (icon: Icons.home_rounded,         label: 'Home'),
    (icon: Icons.chat_bubble_rounded,  label: 'Chat'),
    (icon: Icons.auto_stories_rounded, label: 'Timeline'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);

    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(top: BorderSide(color: t.border, width: 1.0)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items.length, (i) {
              final active = i == currentIndex;
              return GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: active ? t.primaryPale : Colors.transparent,
                    borderRadius: AppRadius.navBar,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: active
                              ? t.surfaceMain
                              : Colors.transparent,
                          borderRadius: const BorderRadius.all(
                              Radius.circular(AppRadius.sm)),
                        ),
                        child: Icon(
                          _items[i].icon,
                          size: 20,
                          color: active ? t.primary : t.textFaint,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _items[i].label,
                        style: AppTextStyles.navLabel.copyWith(
                          color: active ? t.primary : t.textFaint,
                          fontWeight: active
                              ? FontWeight.w500
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
