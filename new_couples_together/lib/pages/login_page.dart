import 'package:flutter/material.dart';
import '../app_theme_notifier.dart';
import '../design_tokens.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  bool _obscure = true;
  late AnimationController _heartAnim;
  late Animation<double> _heartScale;

  @override
  void initState() {
    super.initState();
    _heartAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _heartScale = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _heartAnim, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _heartAnim.dispose();
    super.dispose();
  }

  void _enter() {
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: t.background,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: t.isDark
                ? (t.isHers
                    ? const [Color(0xFF1F1220), Color(0xFF18202E), Color(0xFF1E1420)]
                    : const [Color(0xFF18202E), Color(0xFF1F1220), Color(0xFF181E2A)])
                : (t.isHers
                    ? const [Color(0xFFFEF0F5), Color(0xFFF0F7FF), Color(0xFFFDF8F5)]
                    : const [Color(0xFFEFF6FF), Color(0xFFFDF0F7), Color(0xFFF5F9FF)]),
            stops: const [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            reverse: true,
            padding: EdgeInsets.only(bottom: bottom),
            child: SizedBox(
              height: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
              child: Column(
                children: [
                  const Spacer(flex: 3),

                  // ── "For you" headline ─────────────────────────────────────
                  Text(
                    'For you',
                    style: TextStyle(
                      fontFamily: 'Aktura',
                      fontSize: 52,
                      fontWeight: FontWeight.w400,
                      color: t.primary,
                      letterSpacing: 1.5,
                      height: 1.0,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── Pulsing heart ──────────────────────────────────────────
                  ScaleTransition(
                    scale: _heartScale,
                    child: Text(
                      '♡',
                      style: TextStyle(fontSize: 22, color: t.primaryLight),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── His / Hers toggle ──────────────────────────────────────
                  _HerHisToggle(isHers: t.isHers),

                  const Spacer(flex: 2),

                  // ── Password field + lock button ───────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Container(
                      decoration: BoxDecoration(
                        color: t.surface,
                        borderRadius: AppRadius.shell,
                        border: Border.all(color: t.primaryMid.withValues(alpha: 0.4)),
                        boxShadow: AppShadows.widget,
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              obscureText: _obscure,
                              onSubmitted: (_) => _enter(),
                              style: TextStyle(
                                fontFamily: AppTextStyles.fontFamily,
                                fontSize: 14,
                                color: AppColors.textPrimary,
                                letterSpacing: _obscure ? 4 : 0,
                              ),
                              decoration: InputDecoration(
                                hintText: 'secret…',
                                hintStyle: AppTextStyles.inputHint
                                    .copyWith(letterSpacing: 0),
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                                suffixIcon: GestureDetector(
                                  onTap: () =>
                                      setState(() => _obscure = !_obscure),
                                  child: Icon(
                                    _obscure
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                    size: 16,
                                    color: AppColors.textFaint,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Lock button
                          GestureDetector(
                            onTap: _enter,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: t.primary,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: t.primary.withValues(alpha: 0.30),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Text('🔒',
                                    style: TextStyle(fontSize: 17)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(flex: 3),

                  // ── Footer ─────────────────────────────────────────────────
                  Text(
                    'just for us ♥',
                    style: AppTextStyles.widgetSince
                        .copyWith(color: AppColors.textFaint),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
          // ── Dark mode toggle (top-right) ───────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: ValueListenableBuilder<bool>(
              valueListenable: themeDarkMode,
              builder: (_, isDark, __) => GestureDetector(
                onTap: () => themeDarkMode.value = !isDark,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isDark
                        ? t.primary.withValues(alpha: 0.18)
                        : t.surface.withValues(alpha: 0.75),
                    shape: BoxShape.circle,
                    border: Border.fromBorderSide(
                        BorderSide(color: t.border, width: 1)),
                  ),
                  child: Icon(
                    isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    size: 16,
                    color: isDark ? t.primary : t.textMuted,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── His / Hers toggle ─────────────────────────────────────────────────────────

class _HerHisToggle extends StatelessWidget {
  const _HerHisToggle({required this.isHers});
  final bool isHers;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.chip,
        border: AppBorders.defaultBorder,
        boxShadow: AppShadows.card,
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleChip(
            label: '♀  hers',
            active: isHers,
            activeColor: AppColors.pinkDeep,
            activePale: AppColors.pinkPale,
            onTap: () => themeIsHers.value = true,
          ),
          const SizedBox(width: 3),
          _ToggleChip(
            label: 'his  ♂',
            active: !isHers,
            activeColor: AppColors.blueDeep,
            activePale: AppColors.bluePale,
            onTap: () => themeIsHers.value = false,
          ),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.active,
    required this.activeColor,
    required this.activePale,
    required this.onTap,
  });
  final String label;
  final bool active;
  final Color activeColor;
  final Color activePale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: active ? activeColor : Colors.transparent,
          borderRadius: AppRadius.chip,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppTextStyles.fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: active ? Colors.white : AppColors.textMuted,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}
