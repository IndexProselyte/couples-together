import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:confetti/confetti.dart';
import '../app_theme_notifier.dart';
import '../design_tokens.dart';
import '../main.dart';
import 'settings_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Mood _yourMood = Mood.happy;
  Mood _herMood = Mood.inLove;

  DateTime _startDate = DateUtils.dateOnly(DateTime.now());
  late ConfettiController _confettiController;
  List<String> _customQuotes = [];

  static const _milestones = {100, 200, 365, 500, 1000};

  int get _dayCount => DateTime.now().difference(_startDate).inDays;

  String get _sinceLabel {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec',
    ];
    return 'since ${_startDate.day} ${months[_startDate.month - 1]} ${_startDate.year}';
  }

  String get _monthsDaysLabel {
    final now = DateTime.now();
    int months =
        (now.year - _startDate.year) * 12 + now.month - _startDate.month;
    int days = now.day - _startDate.day;
    if (days < 0) {
      months--;
      days += DateTime(now.year, now.month, 0).day;
    }
    if (months <= 0) return '$_dayCount days';
    if (days == 0) return '$months months';
    return '$months months & $days days';
  }

  String? get _milestoneBadge {
    const labels = {
      100: '100 days ✦',
      200: '200 days ✦',
      365: '1 year together ✦',
      500: '500 days ✦',
      1000: '1000 days ✦',
    };
    return labels[_dayCount];
  }

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 4));
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('relationship_start');
    if (saved != null) {
      setState(() => _startDate = DateTime.parse(saved));
    }
    final rawQuotes = prefs.getString(kCustomQuotesKey);
    if (rawQuotes != null) {
      setState(() => _customQuotes = List<String>.from(jsonDecode(rawQuotes) as List));
    }
    // Fire confetti once per milestone day
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year)).inDays;
    final lastConfetti = prefs.getInt('last_confetti_day') ?? -1;
    if (_milestones.contains(_dayCount) && dayOfYear != lastConfetti) {
      await prefs.setInt('last_confetti_day', dayOfYear);
      _confettiController.play();
    }
    _updateWidget();
  }

  Future<void> _updateWidget() async {
    try {
      await HomeWidget.saveWidgetData<String>('days', _dayCount.toString());
      await HomeWidget.saveWidgetData<String>('mood', _yourMood.label);
      final prefs = await SharedPreferences.getInstance();
      final imagePath = prefs.getString(kCouplePicKey);
      if (imagePath != null) {
        await HomeWidget.saveWidgetData<String>('image_path', imagePath);
      }
      await HomeWidget.updateWidget(
        qualifiedAndroidName:
            'com.example.new_couples_together.CouplesWidgetProvider',
      );
    } catch (_) {
      // Widget update is non-critical; silently ignore failures.
    }
  }

  Future<void> _pickStartDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && context.mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('relationship_start', picked.toIso8601String());
      setState(() => _startDate = picked);
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);
    return Stack(
      children: [
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(t),
                const SizedBox(height: 16),
                _DayCounterCard(
                  dayCount: _dayCount,
                  sinceLabel: _sinceLabel,
                  monthsDaysLabel: _monthsDaysLabel,
                  milestoneBadge: _milestoneBadge,
                  onLongPress: () => _pickStartDate(context),
                ),
                const SizedBox(height: 16),
                _MoodShowcase(
                  yourMood: _yourMood,
                  herMood: _herMood,
                  onYourMoodTap: () => _showMoodPicker(context, true),
                  onHerMoodTap: () => _showMoodPicker(context, false),
                ),
                const SizedBox(height: 16),
                _DailyQuoteCard(customQuotes: _customQuotes),
                const SizedBox(height: 16),
                const _TodayJournalCard(),
                const SizedBox(height: 16),
                const Expanded(child: _NotificationBuilder()),
              ],
            ),
          ),
        ),
        // Confetti overlay — fires on milestone days
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            numberOfParticles: 30,
            gravity: 0.15,
            emissionFrequency: 0.05,
            colors: const [
              Color(0xFFE8A0BF),
              Color(0xFFB0C4DE),
              Color(0xFFF7C5D8),
              Color(0xFF9BB5D6),
              Color(0xFFFFD6E7),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(AppThemeData t) {
    return Row(
      children: [
        Text(
          'Together ♥',
          style: AppTextStyles.pageTitle.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: t.primary,
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            AppFadeSlideRoute(page: const SettingsPage()),
          ).then((_) => _loadPrefs()),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: t.primaryPale,
              shape: BoxShape.circle,
              border: Border.fromBorderSide(
                  BorderSide(color: t.border, width: 1)),
            ),
            child: Icon(Icons.settings_outlined,
                size: 16, color: t.textMuted),
          ),
        ),
      ],
    );
  }

  void _showMoodPicker(BuildContext context, bool isYou) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppThemeScope.of(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      barrierColor: AppColors.pinkDeep.withValues(alpha: 0.15),
      builder: (_) => _MoodPickerSheet(
        isYou: isYou,
        currentMood: isYou ? _yourMood : _herMood,
        onSelect: (mood) {
          setState(() => isYou ? _yourMood = mood : _herMood = mood);
          _updateWidget();
          Navigator.pop(context);
        },
      ),
    );
  }
}

// ── Day Counter ───────────────────────────────────────────────────────────────

class _DayCounterCard extends StatefulWidget {
  const _DayCounterCard({
    required this.dayCount,
    required this.sinceLabel,
    required this.monthsDaysLabel,
    required this.onLongPress,
    this.milestoneBadge,
  });
  final int dayCount;
  final String sinceLabel;
  final String monthsDaysLabel;
  final String? milestoneBadge;
  final VoidCallback onLongPress;

  @override
  State<_DayCounterCard> createState() => _DayCounterCardState();
}

class _DayCounterCardState extends State<_DayCounterCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<int> _countAnim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _countAnim = IntTween(begin: 0, end: widget.dayCount).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic),
    );
    _anim.forward();
  }

  @override
  void didUpdateWidget(_DayCounterCard old) {
    super.didUpdateWidget(old);
    if (old.dayCount != widget.dayCount) {
      _countAnim = IntTween(begin: 0, end: widget.dayCount).animate(
        CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic),
      );
      _anim.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);
    return GestureDetector(
      onLongPress: widget.onLongPress,
      child: Container(
        decoration: BoxDecoration(
          gradient: t.gradientCard,
          borderRadius: AppRadius.card,
          border: Border.all(color: t.border),
          boxShadow: AppShadows.card,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _countAnim,
              builder: (_, __) =>
                  Text('${_countAnim.value}', style: AppTextStyles.dayCounter),
            ),
            const SizedBox(height: 6),
            Text('days together', style: AppTextStyles.counterSub),
            const SizedBox(height: 4),
            Text(widget.sinceLabel, style: AppTextStyles.widgetSince),
            const SizedBox(height: 2),
            Text(
              widget.monthsDaysLabel,
              style: AppTextStyles.widgetSince.copyWith(
                color: t.primaryLight,
                fontStyle: FontStyle.italic,
              ),
            ),
            if (widget.milestoneBadge != null) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: t.primaryPale,
                  borderRadius: AppRadius.chip,
                  border: Border.all(color: t.primaryMid),
                ),
                child: Text(
                  widget.milestoneBadge!,
                  style: TextStyle(
                    fontFamily: AppTextStyles.fontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: t.primary,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Mood Showcase ─────────────────────────────────────────────────────────────

class _MoodShowcase extends StatelessWidget {
  const _MoodShowcase({
    required this.yourMood,
    required this.herMood,
    required this.onYourMoodTap,
    required this.onHerMoodTap,
  });
  final Mood yourMood;
  final Mood herMood;
  final VoidCallback onYourMoodTap;
  final VoidCallback onHerMoodTap;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _MoodCircle(mood: yourMood, isYou: true, onTap: onYourMoodTap),
        const SizedBox(width: 20),
        Text('♥', style: TextStyle(fontSize: 18, color: t.primaryLight)),
        const SizedBox(width: 20),
        _MoodCircle(mood: herMood, isYou: false, onTap: onHerMoodTap),
      ],
    );
  }
}

class _MoodCircle extends StatelessWidget {
  const _MoodCircle(
      {required this.mood, required this.isYou, required this.onTap});
  final Mood mood;
  final bool isYou;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);
    final bg   = isYou ? t.youCircleBg   : t.partnerCircleBg;
    final ring = isYou ? t.youCircleRing : t.partnerCircleRing;
    final label = isYou ? 'You' : t.partnerLabel;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: Border.all(color: ring, width: 2.0),
            ),
            child: Center(
              child: Text(
                mood.emoji,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: t.textSecondary,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text('$label · ${mood.label}', style: AppTextStyles.moodLabel),
        ],
      ),
    );
  }
}

class _MoodPickerSheet extends StatelessWidget {
  const _MoodPickerSheet({
    required this.isYou,
    required this.currentMood,
    required this.onSelect,
  });
  final bool isYou;
  final Mood currentMood;
  final ValueChanged<Mood> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);
    final bg   = isYou ? t.youCircleBg   : t.partnerCircleBg;
    final ring = isYou ? t.youCircleRing : t.partnerCircleRing;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isYou
                ? 'How are you feeling?'
                : 'How is ${t.partnerLabel.toLowerCase()} feeling?',
            style: AppTextStyles.pageTitle,
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.1,
            children: Mood.values.map((m) {
              final selected = m == currentMood;
              return GestureDetector(
                onTap: () => onSelect(m),
                child: Container(
                  decoration: BoxDecoration(
                    color: selected ? bg : t.surfaceBlush,
                    borderRadius: AppRadius.card,
                    border: Border.all(
                      color: selected ? ring : t.border,
                      width: selected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        m.emoji,
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: t.textSecondary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(m.label, style: AppTextStyles.moodLabel),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Notification Builder ──────────────────────────────────────────────────────

class _NotificationBuilder extends StatefulWidget {
  const _NotificationBuilder();

  @override
  State<_NotificationBuilder> createState() => _NotificationBuilderState();
}

class _NotificationBuilderState extends State<_NotificationBuilder> {
  final _controller = TextEditingController();
  final _picker = ImagePicker();
  int _selectedTime = 0;
  final _times = ['Now', 'In 1h', 'Tonight', 'Tomorrow', 'Schedule'];

  bool _imageEnabled = false;
  String? _pickedImagePath;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85, maxWidth: 1280);
    if (file != null) setState(() => _pickedImagePath = file.path);
  }

  void _clearImage() => setState(() => _pickedImagePath = null);

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);
    final preview = _controller.text.isEmpty
        ? '🌸 Your message will appear here…'
        : '🌸 ${_controller.text}';

    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: AppRadius.shell,
        border: Border.all(color: t.border),
        boxShadow: AppShadows.card,
      ),
      padding: AppSpacing.shellPadding,
      // SingleChildScrollView keeps content inside the fixed Expanded height.
      // The card does not grow — internal content scrolls if needed.
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('NOTIFICATION BUILDER', style: AppTextStyles.sectionLabel),
            const SizedBox(height: 10),

            // ── Message field ───────────────────────────────────────────────
            TextField(
              controller: _controller,
              onChanged: (_) => setState(() {}),
              style: TextStyle(
                  fontFamily: AppTextStyles.fontFamily,
                  fontSize: 13,
                  color: t.textPrimary),
              decoration: InputDecoration(
                hintText: 'Write a message…',
                filled: true,
                fillColor: t.surfaceBlush,
                border: OutlineInputBorder(
                  borderRadius: AppRadius.inputField,
                  borderSide: BorderSide(color: t.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppRadius.inputField,
                  borderSide: BorderSide(color: t.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadius.inputField,
                  borderSide:
                      BorderSide(color: t.primaryMid, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                hintStyle: AppTextStyles.inputHint.copyWith(color: t.textMuted),
              ),
            ),

            const SizedBox(height: 10),

            // ── Image toggle row ────────────────────────────────────────────
            Row(
              children: [
                Icon(Icons.image_outlined,
                    size: 14, color: t.textMuted),
                const SizedBox(width: 6),
                Text('Attach image',
                    style: AppTextStyles.inputHint.copyWith(fontSize: 11)),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() {
                    _imageEnabled = !_imageEnabled;
                    if (!_imageEnabled) _pickedImagePath = null;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 36,
                    height: 20,
                    decoration: BoxDecoration(
                      color: _imageEnabled ? t.primary : t.border,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 200),
                      alignment: _imageEnabled
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        width: 16,
                        height: 16,
                        margin:
                            const EdgeInsets.symmetric(horizontal: 2),
                        decoration: const BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // ── Compact image slot (enabled only) ───────────────────────────
            if (_imageEnabled) ...[
              const SizedBox(height: 8),
              Container(
                height: 52,
                decoration: BoxDecoration(
                  color: t.surfaceBlush,
                  borderRadius: AppRadius.card,
                  border: Border.all(color: t.border),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    // Thumbnail or add-icon
                    GestureDetector(
                      onTap: _pickedImagePath == null ? _pickImage : null,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: _pickedImagePath != null
                                ? Image.file(
                                    File(_pickedImagePath!),
                                    width: 36,
                                    height: 36,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    width: 36,
                                    height: 36,
                                    color: t.primaryPale,
                                    child: Icon(
                                        Icons.add_photo_alternate_rounded,
                                        color: t.primaryMid,
                                        size: 18),
                                  ),
                          ),
                          if (_pickedImagePath != null)
                            Positioned(
                              top: -4,
                              right: -4,
                              child: GestureDetector(
                                onTap: _clearImage,
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                      color: t.primary,
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.close,
                                      size: 10, color: Colors.white),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Label / change button
                    Expanded(
                      child: _pickedImagePath == null
                          ? GestureDetector(
                              onTap: _pickImage,
                              child: Text('Tap to add image',
                                  style: AppTextStyles.inputHint
                                      .copyWith(color: t.primaryMid)),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text('Image attached',
                                    style: AppTextStyles.cardTitle
                                        .copyWith(fontSize: 11)),
                                const SizedBox(height: 2),
                                GestureDetector(
                                  onTap: _pickImage,
                                  child: Text('Change',
                                      style: AppTextStyles.fileMeta
                                          .copyWith(
                                              color: AppColors.blueDeep,),),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 10),

            // ── Time chips ──────────────────────────────────────────────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_times.length, (i) {
                  final active = i == _selectedTime;
                  return Padding(
                    padding: EdgeInsets.only(
                        right: i < _times.length - 1 ? 6 : 0),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTime = i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: active
                              ? t.primary
                              : t.surfaceCream,
                          borderRadius: AppRadius.chip,
                          border: active
                              ? null
                              : Border.all(color: t.borderCream),
                        ),
                        child: Text(
                          _times[i],
                          style: TextStyle(
                            fontFamily: AppTextStyles.fontFamily,
                            fontSize: 10,
                            color: active
                                ? Colors.white
                                : t.textMuted,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 10),

            // ── Preview bar ─────────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: t.pinkPale,
                borderRadius: AppRadius.notifPreviewLeft,
                border: const Border(
                  left: BorderSide(color: AppColors.pinkMid, width: 3.0),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                      child: Text(preview, style: AppTextStyles.cardDesc)),
                  if (_imageEnabled && _pickedImagePath != null) ...[
                    const SizedBox(width: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.file(File(_pickedImagePath!),
                          width: 28, height: 28, fit: BoxFit.cover),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ── Send button ─────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                child: const Text('Send Notification'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Daily Quote Card ──────────────────────────────────────────────────────────

class _DailyQuoteCard extends StatefulWidget {
  const _DailyQuoteCard({required this.customQuotes});
  final List<String> customQuotes;

  @override
  State<_DailyQuoteCard> createState() => _DailyQuoteCardState();
}

class _DailyQuoteCardState extends State<_DailyQuoteCard> {
  static const _quotes = [
    'Every love story is beautiful, but ours is my favourite.',
    'You are my today and all of my tomorrows.',
    'In you, I\'ve found the love of my life and my closest, truest friend.',
    'I love you not only for what you are, but for what I am when I am with you.',
    'You make my heart smile.',
    'I fall in love with you a little more every single day.',
    'Home is wherever I\'m with you.',
    'You are the best thing that has ever been mine.',
    'I choose you. And I\'ll choose you, over and over and over.',
    'Whatever our souls are made of, yours and mine are the same.',
    'You are my sun, my moon, and all my stars.',
    'Every day I discover more and more beautiful things in you.',
    'I look at you and see the rest of my life.',
    'You are my favourite notification.',
    'The best thing to hold onto in life is each other.',
    'You complete my sentences and my world.',
    'I love you more than coffee — and that is saying something.',
    'My favourite place is inside your hug.',
    'You are the poem I never knew how to write.',
    'With you, even ordinary moments feel extraordinary.',
    'I would choose you in a hundred lifetimes.',
    'You turn my world into something beautiful.',
    'You are the reason I believe in love.',
    'Together is my favourite place to be.',
    'You are enough. You are so much more than enough.',
    'My heart is wherever you are.',
    'Being deeply loved gives you strength; loving deeply gives you courage.',
    'You had me at hello.',
    'I am yours. Don\'t give myself back to me.',
    'Love is not finding someone to live with — it\'s finding someone you can\'t live without.',
  ];

  late int _index;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year)).inDays;
    _index = dayOfYear % _quotes.length;
  }

  void _refresh(int total) => setState(() => _index = (_index + 1) % total);

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);
    final allQuotes = [...widget.customQuotes, ..._quotes];
    final quote = allQuotes[_index % allQuotes.length];
    return GestureDetector(
      onTap: () => _refresh(allQuotes.length),
      child: Container(
        decoration: BoxDecoration(
          gradient: t.gradientCard,
          borderRadius: AppRadius.card,
          border: Border.all(color: t.border),
          boxShadow: AppShadows.card,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('♡', style: TextStyle(fontSize: 15, color: t.primaryLight)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                quote,
                style: TextStyle(
                  fontFamily: 'Aktura',
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: t.textPrimary,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Today Journal ─────────────────────────────────────────────────────────────

class _TodayJournalCard extends StatefulWidget {
  const _TodayJournalCard();

  @override
  State<_TodayJournalCard> createState() => _TodayJournalCardState();
}

class _TodayJournalCardState extends State<_TodayJournalCard> {
  final _controller = TextEditingController();
  bool _expanded = false;
  Timer? _saveTimer;

  String get _todayKey {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _loadToday();
  }

  Future<void> _loadToday() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('daily_notes');
    if (raw != null) {
      final list = List<Map<String, dynamic>>.from(
          (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)));
      final entry = list.where((e) => e['date'] == _todayKey).firstOrNull;
      if (entry != null && mounted) {
        _controller.text = entry['text'] as String? ?? '';
      }
    }
  }

  Future<void> _save(String text) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('daily_notes');
    final List<Map<String, dynamic>> list = raw != null
        ? List<Map<String, dynamic>>.from(
            (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)))
        : [];
    final idx = list.indexWhere((e) => e['date'] == _todayKey);
    final entry = {'date': _todayKey, 'text': text};
    if (idx >= 0) {
      list[idx] = entry;
    } else {
      list.add(entry);
    }
    await prefs.setString('daily_notes', jsonEncode(list));
  }

  void _onChanged(String text) {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), () => _save(text));
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);
    return GestureDetector(
      onTap: () {
        if (!_expanded) setState(() => _expanded = true);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: t.surfaceBlush,
          borderRadius: AppRadius.card,
          border: Border.all(color: t.border),
          boxShadow: AppShadows.card,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text('✦', style: TextStyle(fontSize: 10, color: t.primaryLight)),
                const SizedBox(width: 6),
                Text('TODAY', style: AppTextStyles.sectionLabel),
                const Spacer(),
                if (_expanded)
                  GestureDetector(
                    onTap: () => setState(() => _expanded = false),
                    child: Icon(Icons.expand_less_rounded,
                        size: 16, color: t.textFaint),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              onChanged: _onChanged,
              maxLines: _expanded ? null : 2,
              minLines: 1,
              style: TextStyle(
                fontFamily: AppTextStyles.fontFamily,
                fontSize: 13,
                color: t.textPrimary,
                height: 1.5,
              ),
              decoration: InputDecoration(
                hintText: 'what are you feeling today?',
                hintStyle: AppTextStyles.inputHint.copyWith(color: t.textMuted),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
