import 'dart:convert';
import 'dart:io';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../app_theme_notifier.dart';
import '../design_tokens.dart';
import '../main.dart';

// ── Font / weight constants for StyleBar ──────────────────────────────────────

const _kFonts = [
  ('Default', null),
  ('Aktura', 'Aktura'),
  ('Array', 'Array'),
  ('Array Wide', 'Array Wide'),
  ('Mono', 'JetBrains Mono'),
];

const _kWeights = [
  ('L', 300),
  ('R', 400),
  ('M', 500),
  ('SB', 600),
  ('B', 700),
];

// ── FontWeight helper ──────────────────────────────────────────────────────────

FontWeight _fontWeightFromInt(int? w) {
  switch (w) {
    case 100: return FontWeight.w100;
    case 200: return FontWeight.w200;
    case 300: return FontWeight.w300;
    case 400: return FontWeight.w400;
    case 500: return FontWeight.w500;
    case 600: return FontWeight.w600;
    case 700: return FontWeight.w700;
    case 800: return FontWeight.w800;
    case 900: return FontWeight.w900;
    default:  return FontWeight.w400;
  }
}

// ── Immutable block types (stored in events) ──────────────────────────────────

abstract class EventBlock {
  const EventBlock();
}

class TextBlock extends EventBlock {
  const TextBlock(this.text, {
    this.isCensored = false,
    this.fontFamily,
    this.fontWeight,
    this.fontSize,
  });
  final String text;
  final bool isCensored;
  final String? fontFamily;
  final int? fontWeight;
  final double? fontSize;
}

class ImageBlock extends EventBlock {
  const ImageBlock(this.path, {
    this.isCensored = false,
    this.title,
    this.titleFontFamily,
    this.titleFontWeight,
    this.titleFontSize,
    this.height,
  });
  final String path;
  final bool isCensored;
  final String? title;
  final String? titleFontFamily;
  final int? titleFontWeight;
  final double? titleFontSize;
  final double? height;
}

enum CollageLayout { bigLeft, bigRight, bigTop }

class CollageBlock extends EventBlock {
  const CollageBlock({
    required this.paths,
    this.layout = CollageLayout.bigLeft,
    this.isCensored = false,
    this.title,
    this.titleFontFamily,
    this.titleFontWeight,
    this.titleFontSize,
    this.height,
  });
  final List<String> paths;
  final CollageLayout layout;
  final bool isCensored;
  final String? title;
  final String? titleFontFamily;
  final int? titleFontWeight;
  final double? titleFontSize;
  final double? height;
}

class VideoBlock extends EventBlock {
  const VideoBlock(this.path, {
    this.isCensored = false,
    this.height,
  });
  final String path;
  final bool isCensored;
  final double? height;
}

// ── Mutable builder blocks (used only inside _NewEventSheet) ──────────────────

abstract class _BuilderBlock {
  static int _counter = 0;
  _BuilderBlock() : id = _BuilderBlock._counter++;
  final int id;
  bool isCensored = false;
  double? height; // null = auto; set by vertical resize handle
}

class _BuilderTextBlock extends _BuilderBlock {
  _BuilderTextBlock({String text = ''})
      : ctrl = TextEditingController(text: text);
  final TextEditingController ctrl;
  String? fontFamily;
  int fontWeight = 400;
  double fontSize = 12.0;
  void dispose() => ctrl.dispose();
}

class _BuilderImageBlock extends _BuilderBlock {
  _BuilderImageBlock()
      : path = _demoImg,
        titleCtrl = TextEditingController() {
    height = 140.0;
  }
  String path;
  final TextEditingController titleCtrl;
  String? titleFontFamily;
  int titleFontWeight = 500;
  double titleFontSize = 13.0;
  void dispose() => titleCtrl.dispose();
}

class _BuilderCollageBlock extends _BuilderBlock {
  _BuilderCollageBlock()
      : paths = List.filled(3, _demoImg),
        layout = CollageLayout.bigLeft,
        titleCtrl = TextEditingController() {
    height = 180.0;
  }
  List<String> paths;
  CollageLayout layout;
  final TextEditingController titleCtrl;
  String? titleFontFamily;
  int titleFontWeight = 500;
  double titleFontSize = 13.0;
  void dispose() => titleCtrl.dispose();
}

class _BuilderVideoBlock extends _BuilderBlock {
  _BuilderVideoBlock({this.path = ''}) {
    height = 160.0;
  }
  String path;
}

// ── Row-based layout model ────────────────────────────────────────────────────

class _BuilderRow {
  _BuilderRow(this.blocks)
      : widths = List.generate(blocks.length, (_) => 1.0 / blocks.length);

  List<_BuilderBlock> blocks;
  List<double> widths; // proportions per block, always sum to 1.0

  bool get canExpand =>
      blocks.length < 3 &&
      !blocks.any((b) => b is _BuilderCollageBlock || b is _BuilderVideoBlock);

  void adjustDivider(int divIdx, double deltaFraction) {
    final l = widths[divIdx] + deltaFraction;
    final r = widths[divIdx + 1] - deltaFraction;
    if (l < 0.15 || r < 0.15) return;
    widths[divIdx] = l;
    widths[divIdx + 1] = r;
  }
}

// ── Event model ───────────────────────────────────────────────────────────────

class _Event {
  _Event({
    required this.title,
    required this.date,
    List<EventBlock> blocks = const [],
    List<EventRow>? rows,
    List<String>? tags,
    this.location,
  }) : rows = rows ?? blocks.map(EventRow.single).toList(),
       tags = tags ?? [];

  final String title;
  final DateTime date;
  final List<EventRow> rows;
  List<String> tags;
  String? location;
  Color? dotColor;
  Color? lineColor;
  Color? cardColor;
  List<EventSticker> stickers = [];

  // Flat access for backward-compatible checks (hasCensored, etc.)
  List<EventBlock> get blocks => rows.expand((r) => r.blocks).toList();

  String get formattedDate {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day.toString().padLeft(2, '0')} '
        '${months[date.month - 1]} ${date.year}';
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'date': date.millisecondsSinceEpoch,
        'rows': rows.map((r) => r.toJson()).toList(),
        if (stickers.isNotEmpty) 'stickers': stickers.map((s) => s.toJson()).toList(),
        // ignore: deprecated_member_use
        if (dotColor != null) 'dotColor': dotColor!.value,
        // ignore: deprecated_member_use
        if (lineColor != null) 'lineColor': lineColor!.value,
        // ignore: deprecated_member_use
        if (cardColor != null) 'cardColor': cardColor!.value,
        if (tags.isNotEmpty) 'tags': tags,
        if (location != null) 'location': location,
      };

  static _Event fromJson(Map<String, dynamic> j) {
    // Support both old format ('blocks' flat list) and new format ('rows')
    final List<EventRow> eventRows;
    if (j['rows'] != null) {
      eventRows = (j['rows'] as List)
          .map((r) => EventRow.fromJson(r as Map<String, dynamic>))
          .toList();
    } else {
      eventRows = (j['blocks'] as List)
          .map((b) => EventRow.single(_blockFromJson(b as Map<String, dynamic>)))
          .toList();
    }
    final e = _Event(
      title: j['title'] as String,
      date: DateTime.fromMillisecondsSinceEpoch(j['date'] as int),
      rows: eventRows,
    );
    if (j['dotColor'] != null) e.dotColor = Color(j['dotColor'] as int);
    if (j['lineColor'] != null) e.lineColor = Color(j['lineColor'] as int);
    if (j['cardColor'] != null) e.cardColor = Color(j['cardColor'] as int);
    if (j['stickers'] != null) {
      e.stickers = (j['stickers'] as List)
          .map((s) => EventSticker.fromJson(s as Map<String, dynamic>))
          .toList();
    }
    if (j['tags'] != null) {
      e.tags = List<String>.from(j['tags'] as List);
    }
    if (j['location'] != null) {
      e.location = j['location'] as String;
    }
    return e;
  }
}

Map<String, dynamic> _blockToJson(EventBlock b) {
  if (b is TextBlock) {
    return {
      'type': 'text',
      'text': b.text,
      'censored': b.isCensored,
      if (b.fontFamily != null) 'fontFamily': b.fontFamily,
      if (b.fontWeight != null) 'fontWeight': b.fontWeight,
      if (b.fontSize != null) 'fontSize': b.fontSize,
    };
  }
  if (b is ImageBlock) {
    return {
      'type': 'image',
      'path': b.path,
      'censored': b.isCensored,
      if (b.title != null) 'title': b.title,
      if (b.titleFontFamily != null) 'titleFontFamily': b.titleFontFamily,
      if (b.titleFontWeight != null) 'titleFontWeight': b.titleFontWeight,
      if (b.titleFontSize != null) 'titleFontSize': b.titleFontSize,
    };
  }
  if (b is CollageBlock) {
    return {
      'type': 'collage',
      'paths': b.paths,
      'layout': b.layout.name,
      'censored': b.isCensored,
      if (b.title != null) 'title': b.title,
      if (b.titleFontFamily != null) 'titleFontFamily': b.titleFontFamily,
      if (b.titleFontWeight != null) 'titleFontWeight': b.titleFontWeight,
      if (b.titleFontSize != null) 'titleFontSize': b.titleFontSize,
    };
  }
  if (b is VideoBlock) {
    return {
      'type': 'video',
      'path': b.path,
      'censored': b.isCensored,
      if (b.height != null) 'height': b.height,
    };
  }
  throw StateError('Unknown block type');
}

EventBlock _blockFromJson(Map<String, dynamic> j) {
  final censored = (j['censored'] as bool?) ?? false;
  if (j['type'] == 'text') {
    return TextBlock(
      j['text'] as String,
      isCensored: censored,
      fontFamily: j['fontFamily'] as String?,
      fontWeight: j['fontWeight'] as int?,
      fontSize: (j['fontSize'] as num?)?.toDouble(),
    );
  }
  if (j['type'] == 'image') {
    return ImageBlock(
      j['path'] as String,
      isCensored: censored,
      title: j['title'] as String?,
      titleFontFamily: j['titleFontFamily'] as String?,
      titleFontWeight: j['titleFontWeight'] as int?,
      titleFontSize: (j['titleFontSize'] as num?)?.toDouble(),
    );
  }
  if (j['type'] == 'collage') {
    return CollageBlock(
      paths: List<String>.from(j['paths'] as List),
      layout: CollageLayout.values.firstWhere(
        (e) => e.name == j['layout'],
        orElse: () => CollageLayout.bigLeft,
      ),
      isCensored: censored,
      title: j['title'] as String?,
      titleFontFamily: j['titleFontFamily'] as String?,
      titleFontWeight: j['titleFontWeight'] as int?,
      titleFontSize: (j['titleFontSize'] as num?)?.toDouble(),
    );
  }
  if (j['type'] == 'video') {
    return VideoBlock(
      j['path'] as String,
      isCensored: censored,
      height: (j['height'] as num?)?.toDouble(),
    );
  }
  throw StateError('Unknown block type: ${j['type']}');
}

// ── Sticker assets ────────────────────────────────────────────────────────────

const _kHamsterStickers = [
  'assets/stickers/hamster/0-1.thumb128.png',
  'assets/stickers/hamster/1-1.thumb128.png',
  'assets/stickers/hamster/2-1.thumb128.png',
  'assets/stickers/hamster/3-1.thumb128.png',
  'assets/stickers/hamster/4-1.thumb128.png',
  'assets/stickers/hamster/5-1.thumb128.png',
  'assets/stickers/hamster/6-1.thumb128.png',
  'assets/stickers/hamster/7-1.thumb128.png',
  'assets/stickers/hamster/8-1.thumb128.png',
  'assets/stickers/hamster/9-1.thumb128.png',
  'assets/stickers/hamster/10-1.thumb128.png',
  'assets/stickers/hamster/11-1.thumb128.png',
  'assets/stickers/hamster/12-1.thumb128.png',
  'assets/stickers/hamster/13-1.thumb128.png',
  'assets/stickers/hamster/14-1.thumb128.png',
  'assets/stickers/hamster/15-1.thumb128.png',
  'assets/stickers/hamster/16-1.thumb128.png',
  'assets/stickers/hamster/17-1.thumb128.png',
  'assets/stickers/hamster/18-1.thumb128.png',
  'assets/stickers/hamster/15.thumb128.webp',
  'assets/stickers/hamster/26.thumb128.webp',
  'assets/stickers/hamster/27.thumb128.webp',
  'assets/stickers/hamster/30.thumb128.webp',
  'assets/stickers/hamster/37.thumb128.webp',
  'assets/stickers/hamster/40.thumb128.webp',
  'assets/stickers/hamster/61.thumb128.webp',
  'assets/stickers/hamster/66.thumb128.webp',
  'assets/stickers/hamster/101.thumb128.webp',
];

class EventSticker {
  const EventSticker({required this.path, required this.x, required this.y, this.size = 64.0});
  final String path;
  final double x, y, size;
  Map<String, dynamic> toJson() => {'path': path, 'x': x, 'y': y, 'size': size};
  static EventSticker fromJson(Map<String, dynamic> j) => EventSticker(
    path: j['path'] as String,
    x: (j['x'] as num).toDouble(),
    y: (j['y'] as num).toDouble(),
    size: (j['size'] as num?)?.toDouble() ?? 64.0,
  );
}

class EventRow {
  const EventRow({required this.blocks, required this.widths});
  final List<EventBlock> blocks;
  final List<double> widths; // proportional widths, sum to 1.0

  factory EventRow.single(EventBlock block) =>
      EventRow(blocks: [block], widths: const [1.0]);

  Map<String, dynamic> toJson() => {
        'blocks': blocks.map(_blockToJson).toList(),
        'widths': widths,
      };

  static EventRow fromJson(Map<String, dynamic> j) => EventRow(
        blocks: (j['blocks'] as List)
            .map((b) => _blockFromJson(b as Map<String, dynamic>))
            .toList(),
        widths: (j['widths'] as List)
            .map((w) => (w as num).toDouble())
            .toList(),
      );
}

class _StickerPlacement {
  _StickerPlacement({required this.path, required this.position});
  final String path;
  Offset position;
  double size = 64.0;
}

// ── Color palettes ────────────────────────────────────────────────────────────

const _spineColorPalette = <Color>[
  AppColors.pinkDeep,
  AppColors.pinkMid,
  AppColors.blueDeep,
  AppColors.blueMid,
  Color(0xFF9B7FA6),
  Color(0xFF6B8E7F),
  Color(0xFFE8986A),
  Color(0xFFE8A0A0),
  Color(0xFF6B7A8D),
  AppColors.creamDeep,
];

const _cardColorPalette = <Color>[
  AppColors.surface,
  AppColors.surfaceBlush,
  AppColors.surfaceBlue,
  AppColors.surfaceCream,
  Color(0xFFF0FFF8),
  Color(0xFFFFF8E8),
  Color(0xFFF5F0FF),
  Color(0xFFE8F5FF),
];

const _cardColorPaletteDark = <Color>[
  Color(0xFF251B22), // dkSurface
  Color(0xFF2E1F2A), // dkSurfaceBlush
  Color(0xFF1C2535), // dkSurfaceBlue
  Color(0xFF26201A), // dkSurfaceCream
  Color(0xFF1E2535), // dark blue-grey
  Color(0xFF2A1E15), // dark warm brown
  Color(0xFF1F1520), // deep purple-black
  Color(0xFF1A2030), // cool dark blue
];

// ── Default spine colors (fallback when no custom color) ──────────────────────

const _dotFill   = [AppColors.pinkMid,  AppColors.blueMid,  AppColors.creamMid];
const _dotBorder = [AppColors.pinkDeep, AppColors.blueDeep, AppColors.creamDeep];

List<Color> _cardBg(AppThemeData t) => [
  t.surface,
  t.isDark ? const Color(0xFF1E2535) : const Color(0xFFF8FBFF),
  t.isDark ? const Color(0xFF2A1E15) : const Color(0xFFFEFAF5),
];

List<Color> _cardBorderColor(AppThemeData t) =>
    [t.border, t.borderBlue, t.borderCream];

LinearGradient _lineGradient(int colorIndex, Color? custom) {
  if (custom != null) {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [custom, custom.withValues(alpha: 0.35)],
    );
  }
  const gradients = <LinearGradient>[
    AppColors.gradientTimelinePinkBlue,
    AppColors.gradientTimelineBlueC,
    LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [AppColors.creamMid, AppColors.creamLight],
    ),
  ];
  return gradients[colorIndex];
}

double _lineHeight(DateTime a, DateTime b) =>
    (b.difference(a).inDays / 30.0 * 40).clamp(60.0, 200.0);

// ── Page ──────────────────────────────────────────────────────────────────────

class TimelinePage extends StatefulWidget {
  const TimelinePage({super.key});

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> {
  List<_Event> _events = [];
  int? _expandedIndex;
  String? _coverImagePath;
  bool _searchActive = false;
  String _searchQuery = '';
  String? _selectedTag;
  int? _selectedYear;
  final _searchController = TextEditingController();
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadCache();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = await _TimelineCache.load();
    final cover = prefs.getString('timeline_cover');
    if (!mounted) return;
    setState(() {
      _events = cached;
      _coverImagePath = cover;
    });
  }

  List<String> get _allTags {
    final tags = <String>{};
    for (final e in _events) { tags.addAll(e.tags); }
    return tags.toList()..sort();
  }

  List<int> get _allYears {
    return _events.map((e) => e.date.year).toSet().toList()..sort();
  }

  List<_Event> get _filteredEvents {
    var events = _events;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      events = events.where((e) =>
        e.title.toLowerCase().contains(q) ||
        e.blocks.any((b) => b is TextBlock && b.text.toLowerCase().contains(q))
      ).toList();
    }
    if (_selectedTag != null) {
      events = events.where((e) => e.tags.contains(_selectedTag)).toList();
    }
    if (_selectedYear != null) {
      events = events.where((e) => e.date.year == _selectedYear).toList();
    }
    return events;
  }

  Future<void> _pickCoverImage() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 90, maxWidth: 1200);
    if (file == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('timeline_cover', file.path);
    setState(() => _coverImagePath = file.path);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);
    final allTags = _allTags;
    final allYears = _allYears;
    final filtered = _filteredEvents;

    return Scaffold(
      backgroundColor: t.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: t.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              titlePadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              title: Text(
                'Our Timeline',
                style: AppTextStyles.pageTitle.copyWith(color: t.textPrimary, fontSize: 14),
              ),
              background: GestureDetector(
                onLongPress: _pickCoverImage,
                child: _CoverHero(imagePath: _coverImagePath, background: t.background, gradientCard: t.gradientCard, primaryLight: t.primaryLight, textMuted: t.textMuted),
              ),
            ),
            actions: [
              IconButton(
                onPressed: () => setState(() {
                  _searchActive = !_searchActive;
                  if (!_searchActive) {
                    _searchQuery = '';
                    _searchController.clear();
                  }
                }),
                icon: Icon(
                  _searchActive ? Icons.search_off_rounded : Icons.search_rounded,
                  color: _searchActive ? t.primary : t.textMuted,
                  size: 20,
                ),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_searchActive) ...[
                    _TimelineSearchBar(
                      controller: _searchController,
                      onChanged: (q) => setState(() => _searchQuery = q),
                      onClose: () => setState(() {
                        _searchActive = false;
                        _searchQuery = '';
                        _searchController.clear();
                      }),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (allYears.length > 1) ...[
                    _YearCarousel(
                      years: allYears,
                      selected: _selectedYear,
                      onSelect: (y) => setState(() => _selectedYear = _selectedYear == y ? null : y),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (allTags.isNotEmpty) ...[
                    _TagFilterBar(
                      tags: allTags,
                      selected: _selectedTag,
                      onSelect: (tag) => setState(() => _selectedTag = _selectedTag == tag ? null : tag),
                    ),
                    const SizedBox(height: 10),
                  ],
                  _NewEventButton(onAdd: _addEvent),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  _searchQuery.isNotEmpty || _selectedTag != null || _selectedYear != null
                      ? 'No memories match your filter'
                      : 'No memories yet',
                  style: AppTextStyles.cardDesc.copyWith(color: t.textFaint),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final event = filtered[i];
                    final originalIdx = _events.indexOf(event);
                    final isLast = i == filtered.length - 1;
                    final lh = isLast ? 0.0 : _lineHeight(filtered[i].date, filtered[i + 1].date);
                    return _TimelineItem(
                      key: ValueKey(event.title + originalIdx.toString()),
                      event: event,
                      colorIndex: originalIdx % 3,
                      isLast: isLast,
                      lineHeight: lh,
                      expanded: _expandedIndex == originalIdx,
                      onTap: () => setState(() =>
                          _expandedIndex = _expandedIndex == originalIdx ? null : originalIdx),
                      onColorEdit: () => _editEventColor(originalIdx),
                      onLongPress: () => _showEventMenu(originalIdx),
                    );
                  },
                  childCount: filtered.length,
                ),
              ),
            ),
        ],
      ),
    );
  }


  void _addEvent(_Event event) {
    setState(() {
      _events
        ..add(event)
        ..sort((a, b) => a.date.compareTo(b.date));
      _expandedIndex = null;
    });
    _TimelineCache.save(_events);
  }

  Future<void> _editEventColor(int index) async {
    final event = _events[index];
    await showDialog<void>(
      context: context,
      builder: (_) => _ColorPickerDialog(
        initialDotColor: event.dotColor ?? _dotFill[index % 3],
        initialLineColor: event.lineColor,
        onChanged: (dot, line) => setState(() {
          event.dotColor = dot;
          event.lineColor = line;
        }),
      ),
    );
    _TimelineCache.save(_events);
  }

  Future<void> _showEventMenu(int index) async {
    final event = _events[index];
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppThemeScope.of(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      barrierColor: AppColors.pinkDeep.withValues(alpha: 0.15),
      builder: (ctx) => _EventContextSheet(
        onEdit: () async {
          Navigator.pop(ctx);
          final updated = await Navigator.push<_Event>(
            context,
            AppFadeSlideRoute(page: _NewEventPage(editEvent: event)),
          );
          if (updated != null) _replaceEvent(index, updated);
        },
        onDuplicate: () {
          Navigator.pop(ctx);
          _duplicateEvent(index);
        },
        onDelete: () {
          Navigator.pop(ctx);
          _confirmDeleteEvent(index);
        },
        onColor: () {
          Navigator.pop(ctx);
          _editEventColor(index);
        },
      ),
    );
  }

  void _replaceEvent(int index, _Event updated) {
    updated.dotColor = _events[index].dotColor;
    updated.lineColor = _events[index].lineColor;
    setState(() {
      _events[index] = updated;
      _events.sort((a, b) => a.date.compareTo(b.date));
      _expandedIndex = null;
    });
    _TimelineCache.save(_events);
  }

  void _duplicateEvent(int index) {
    final src = _events[index];
    final copy = _Event(
      title: '${src.title} (copy)',
      date: src.date,
      rows: src.rows,
      tags: List<String>.from(src.tags),
      location: src.location,
    );
    copy.cardColor = src.cardColor;
    setState(() {
      _events
        ..add(copy)
        ..sort((a, b) => a.date.compareTo(b.date));
      _expandedIndex = null;
    });
    _TimelineCache.save(_events);
  }

  Future<void> _confirmDeleteEvent(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: AppColors.pinkDeep.withValues(alpha: 0.15),
      builder: (ctx) => AlertDialog(
        backgroundColor: AppThemeScope.of(context).surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
        title: Text(
          'Delete memory?',
          style: AppTextStyles.cardTitle.copyWith(color: AppThemeScope.of(context).textPrimary),
        ),
        content: Text(
          'This cannot be undone.',
          style: AppTextStyles.cardDesc,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(fontFamily: AppTextStyles.fontFamily, color: AppThemeScope.of(context).textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(fontFamily: AppTextStyles.fontFamily, color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() {
        _events.removeAt(index);
        _expandedIndex = null;
      });
      _TimelineCache.save(_events);
    }
  }
}

// ── New Event Button ──────────────────────────────────────────────────────────

class _NewEventButton extends StatelessWidget {
  const _NewEventButton({required this.onAdd});
  final ValueChanged<_Event> onAdd;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);
    return GestureDetector(
      onTap: () async {
        final event = await Navigator.push<_Event>(
          context,
          AppFadeSlideRoute(page: const _NewEventPage()),
        );
        if (event != null) onAdd(event);
      },
      child: Container(
        decoration: BoxDecoration(color: t.pinkPale, borderRadius: AppRadius.card),
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: AppBorders.dashedColor,
            strokeWidth: AppBorders.dashedWidth,
            radius: AppRadius.md,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DashedCircle(size: 28),
                const SizedBox(width: 10),
                const Text(
                  'Add a new memory…',
                  style: TextStyle(
                    fontFamily: AppTextStyles.fontFamily,
                    fontSize: 12,
                    color: AppColors.pinkMid,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedCircle extends StatelessWidget {
  const _DashedCircle({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _DashedCirclePainter(color: AppBorders.dashedColor),
      child: SizedBox(
        width: size,
        height: size,
        child: const Center(
          child: Icon(Icons.add, size: 14, color: AppColors.pinkMid),
        ),
      ),
    );
  }
}

// ── Timeline Item ─────────────────────────────────────────────────────────────

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    super.key,
    required this.event,
    required this.colorIndex,
    required this.isLast,
    required this.lineHeight,
    required this.expanded,
    required this.onTap,
    required this.onColorEdit,
    required this.onLongPress,
  });

  final _Event event;
  final int colorIndex;
  final bool isLast;
  final double lineHeight;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback onColorEdit;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: AppSpacing.timelineSpineWidth,
          child: _TimelineSpine(
            event: event,
            colorIndex: colorIndex,
            isLast: isLast,
            lineHeight: lineHeight,
            onColorEdit: onColorEdit,
          ),
        ),
        SizedBox(width: AppSpacing.timelineGap),
        Expanded(
          child: _TimelineCard(
            event: event,
            colorIndex: colorIndex,
            expanded: expanded,
            onTap: onTap,
            onLongPress: onLongPress,
          ),
        ),
      ],
    );
  }
}

class _TimelineSpine extends StatelessWidget {
  const _TimelineSpine({
    required this.event,
    required this.colorIndex,
    required this.isLast,
    required this.lineHeight,
    required this.onColorEdit,
  });

  final _Event event;
  final int colorIndex;
  final bool isLast;
  final double lineHeight;
  final VoidCallback onColorEdit;

  @override
  Widget build(BuildContext context) {
    final dotFill = event.dotColor ?? _dotFill[colorIndex];
    final dotBorderColor = event.dotColor != null
        ? Color.lerp(event.dotColor!, Colors.black, 0.25)!
        : _dotBorder[colorIndex];
    final gradient = _lineGradient(colorIndex, event.lineColor);

    return Column(
      children: [
        GestureDetector(
          onLongPress: onColorEdit,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dotFill,
              border: Border.all(color: dotBorderColor, width: 2),
            ),
          ),
        ),
        if (!isLast)
          Container(
            width: 2,
            height: lineHeight,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
      ],
    );
  }
}

// ── Timeline Card ─────────────────────────────────────────────────────────────

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({
    required this.event,
    required this.colorIndex,
    required this.expanded,
    required this.onTap,
    required this.onLongPress,
  });

  final _Event event;
  final int colorIndex;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);
    final bgColor = event.cardColor ?? _cardBg(t)[colorIndex];
    final borderColor = event.cardColor != null
        ? event.cardColor!.withValues(alpha: 0.4)
        : _cardBorderColor(t)[colorIndex];
    final hasCensored = event.blocks.any((b) =>
        (b is TextBlock && b.isCensored) ||
        (b is ImageBlock && b.isCensored) ||
        (b is CollageBlock && b.isCensored) ||
        (b is VideoBlock && b.isCensored));

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: AppRadius.card,
          border: Border.all(color: borderColor),
          boxShadow: AppShadows.card,
        ),
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(event.formattedDate, style: AppTextStyles.timelineDate),
                if (event.location != null && event.location!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: t.surfaceCream,
                      borderRadius: AppRadius.chip,
                      border: Border.all(color: t.borderCream),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_on_rounded, size: 9, color: t.textFaint),
                        const SizedBox(width: 2),
                        Text(
                          event.location!,
                          style: AppTextStyles.widgetSince.copyWith(
                            color: t.textFaint,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Expanded(child: Text(event.title, style: AppTextStyles.cardTitle.copyWith(color: t.textPrimary))),
                if (hasCensored)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(Icons.lock_outline_rounded,
                        size: 12, color: t.textFaint),
                  ),
                if (event.blocks.whereType<ImageBlock>().isNotEmpty ||
                    event.blocks.whereType<CollageBlock>().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(Icons.photo_library_rounded,
                        size: 13, color: t.textFaint),
                  ),
                if (event.blocks.whereType<VideoBlock>().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(Icons.videocam_rounded,
                        size: 13, color: t.textFaint),
                  ),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: t.textFaint,
                ),
              ],
            ),
            if (expanded) ...[
              const SizedBox(height: 8),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _buildExpandedContent(context: context, onFold: onTap),
                  ),
                  ...event.stickers.map((s) => Positioned(
                    left: s.x,
                    top: s.y,
                    child: IgnorePointer(
                      child: Image.asset(s.path, width: s.size, height: s.size, fit: BoxFit.contain),
                    ),
                  )),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Renders a single EventBlock as a display widget (used for both single and multi-block rows)
  Widget _renderBlock(BuildContext context, EventBlock block, VoidCallback onFold, AppThemeData t) {
    if (block is TextBlock) {
      if (block.text.isEmpty) return const SizedBox.shrink();
      final tw = Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          block.text,
          style: AppTextStyles.cardDesc.copyWith(
            fontFamily: block.fontFamily,
            fontWeight: block.fontWeight != null
                ? _fontWeightFromInt(block.fontWeight)
                : null,
            fontSize: block.fontSize,
            overflow: TextOverflow.ellipsis,
          ),
          softWrap: true,
          maxLines: 10,
        ),
      );
      return block.isCensored ? _RevealableContent(child: tw) : tw;
    }
    if (block is ImageBlock) {
      final img = _AssetImage(path: block.path);
      final imgWidget = block.isCensored
          ? _RevealableContent(onRevealedTap: onFold, child: img)
          : GestureDetector(
              onTap: () => _showFullImage(context, block.path),
              child: img,
            );
      if (block.title != null && block.title!.isNotEmpty) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                block.title!,
                style: TextStyle(
                  fontFamily: block.titleFontFamily ?? AppTextStyles.fontFamily,
                  fontWeight: _fontWeightFromInt(block.titleFontWeight),
                  fontSize: block.titleFontSize ?? 13,
                  color: t.textPrimary,
                  overflow: TextOverflow.ellipsis,
                ),
                maxLines: 2,
              ),
            ),
            imgWidget,
            const SizedBox(height: 6),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [imgWidget, const SizedBox(height: 6)],
      );
    }
    if (block is CollageBlock) {
      Widget? titleWidget;
      if (block.title != null && block.title!.isNotEmpty) {
        titleWidget = Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            block.title!,
            style: TextStyle(
              fontFamily: block.titleFontFamily ?? AppTextStyles.fontFamily,
              fontWeight: _fontWeightFromInt(block.titleFontWeight),
              fontSize: block.titleFontSize ?? 13,
              color: t.textPrimary,
              overflow: TextOverflow.ellipsis,
            ),
            maxLines: 2,
          ),
        );
      }
      final uncensored = _buildCollageLayout(
        paths: block.paths,
        layout: block.layout,
        height: block.height ?? 120,
        onTapImage: (path) => _showFullImage(context, path),
      );
      final collageWidget = block.isCensored
          ? _RevealableContent(onRevealedTap: onFold, child: uncensored)
          : uncensored;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (titleWidget != null) titleWidget,
          collageWidget,
          const SizedBox(height: 6),
        ],
      );
    }
    if (block is VideoBlock) {
      return _VideoBlockWidget(
        videoPath: block.path,
        isCensored: block.isCensored,
        height: block.height,
        onFold: onFold,
      );
    }
    return const SizedBox.shrink();
  }

  List<Widget> _buildExpandedContent({required BuildContext context, required VoidCallback onFold}) {
    final t = AppThemeScope.of(context);
    final widgets = <Widget>[];
    // Buffer for consecutive untitled single-image blocks (auto-grouped into _MixedImageRow)
    final runImages = <ImageBlock>[];

    void flushImages() {
      if (runImages.isEmpty) return;
      widgets.add(_MixedImageRow(blocks: List.from(runImages), onFold: onFold));
      widgets.add(const SizedBox(height: 6));
      runImages.clear();
    }

    for (final row in event.rows) {
      if (row.blocks.length > 1) {
        // Multi-block row: render side-by-side with saved proportional widths
        flushImages();
        widgets.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < row.blocks.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Flexible(
                  flex: (row.widths[i] * 100).round().clamp(1, 100),
                  child: _renderBlock(context, row.blocks[i], onFold, t),
                ),
              ],
            ],
          ),
        );
      } else if (row.blocks.length == 1) {
        final block = row.blocks.first;
        // Auto-group consecutive untitled images into _MixedImageRow
        if (block is ImageBlock &&
            (block.title == null || block.title!.isEmpty)) {
          runImages.add(block);
          if (runImages.length == 3) flushImages();
        } else {
          flushImages();
          widgets.add(_renderBlock(context, block, onFold, t));
        }
      }
    }
    flushImages();
    return widgets;
  }
}

// ── Collage layout renderer (shared between builder and read view) ─────────────

Widget _buildCollageLayout({
  required List<String> paths,
  required CollageLayout layout,
  required double height,
  bool censored = false,
  void Function(String path)? onTapImage,
}) {
  Widget imageSlot(String path, {BorderRadius? borderRadius}) {
    final img = ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: ColoredBox(
        color: AppColors.surfaceCream,
        child: Image.asset(
          path,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => const Center(
            child: Icon(Icons.broken_image_rounded,
                color: AppColors.pinkMid, size: 18),
          ),
        ),
      ),
    );
    if (censored) {
      return Stack(
        fit: StackFit.expand,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10, tileMode: TileMode.decal),
            child: img,
          ),
          const Center(
            child: Icon(Icons.lock_rounded, color: Colors.white, size: 18),
          ),
        ],
      );
    }
    if (onTapImage != null) {
      return GestureDetector(
        onTap: () => onTapImage(path),
        child: img,
      );
    }
    return img;
  }

  Widget content;

  if (layout == CollageLayout.bigLeft) {
    // [  big (60%)  | small1 ]
    //               | small2 ]
    final p0 = paths.isNotEmpty ? paths[0] : _demoImg;
    final p1 = paths.length > 1 ? paths[1] : _demoImg;
    final p2 = paths.length > 2 ? paths[2] : _demoImg;
    content = Row(
      children: [
        Flexible(
          flex: 60,
          child: SizedBox(
            height: height,
            child: imageSlot(p0,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  bottomLeft: Radius.circular(6),
                )),
          ),
        ),
        const SizedBox(width: 2),
        Flexible(
          flex: 40,
          child: SizedBox(
            height: height,
            child: Column(
              children: [
                Expanded(
                  child: imageSlot(p1,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(6),
                      )),
                ),
                const SizedBox(height: 2),
                Expanded(
                  child: imageSlot(p2,
                      borderRadius: const BorderRadius.only(
                        bottomRight: Radius.circular(6),
                      )),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  } else if (layout == CollageLayout.bigRight) {
    // [ small1 |  big (60%)  ]
    // [ small2 |             ]
    final p0 = paths.isNotEmpty ? paths[0] : _demoImg;
    final p1 = paths.length > 1 ? paths[1] : _demoImg;
    final p2 = paths.length > 2 ? paths[2] : _demoImg;
    content = Row(
      children: [
        Flexible(
          flex: 40,
          child: SizedBox(
            height: height,
            child: Column(
              children: [
                Expanded(
                  child: imageSlot(p0,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(6),
                      )),
                ),
                const SizedBox(height: 2),
                Expanded(
                  child: imageSlot(p1,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(6),
                      )),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 2),
        Flexible(
          flex: 60,
          child: SizedBox(
            height: height,
            child: imageSlot(p2,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(6),
                  bottomRight: Radius.circular(6),
                )),
          ),
        ),
      ],
    );
  } else {
    // bigTop:  [    big (full width)   ]
    //          [ small1  |  small2     ]
    final p0 = paths.isNotEmpty ? paths[0] : _demoImg;
    final p1 = paths.length > 1 ? paths[1] : _demoImg;
    final p2 = paths.length > 2 ? paths[2] : _demoImg;
    content = Column(
      children: [
        Flexible(
          flex: 60,
          child: SizedBox(
            width: double.infinity,
            child: imageSlot(p0,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(6),
                )),
          ),
        ),
        const SizedBox(height: 2),
        Flexible(
          flex: 40,
          child: Row(
            children: [
              Expanded(
                child: imageSlot(p1,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(6),
                    )),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: imageSlot(p2,
                    borderRadius: const BorderRadius.only(
                      bottomRight: Radius.circular(6),
                    )),
              ),
            ],
          ),
        ),
      ],
    );
  }

  return ClipRRect(
    borderRadius: AppRadius.timelineImage,
    child: SizedBox(height: height, child: content),
  );
}


// ── Full-image viewer ─────────────────────────────────────────────────────────

void _showFullImage(BuildContext context, String path) {
  final t = AppThemeScope.of(context);
  showDialog(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          ClipRRect(
            borderRadius: AppRadius.card,
            child: Image.asset(path, fit: BoxFit.contain),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: t.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close_rounded,
                    size: 16, color: t.textPrimary),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ── Mixed image row (handles censored images individually) ────────────────────

class _MixedImageRow extends StatelessWidget {
  const _MixedImageRow({required this.blocks, required this.onFold});
  final List<ImageBlock> blocks;
  final VoidCallback onFold;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: blocks.asMap().entries.map((entry) {
        final i = entry.key;
        final block = entry.value;
        final img = _AssetImage(path: block.path);
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < blocks.length - 1 ? 4 : 0),
            child: block.isCensored
                ? _RevealableContent(onRevealedTap: onFold, child: img)
                : GestureDetector(
                    onTap: () => _showFullImage(context, block.path),
                    child: img,
                  ),
          ),
        );
      }).toList(),
    );
  }

}

// ── Video block widget (display in timeline card) ─────────────────────────────

class _VideoBlockWidget extends StatefulWidget {
  const _VideoBlockWidget({
    required this.videoPath,
    this.isCensored = false,
    this.height,
    required this.onFold,
  });
  final String videoPath;
  final bool isCensored;
  final double? height;
  final VoidCallback onFold;

  @override
  State<_VideoBlockWidget> createState() => _VideoBlockWidgetState();
}

class _VideoBlockWidgetState extends State<_VideoBlockWidget> {
  VideoPlayerController? _ctrl;
  bool _initialized = false;

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_ctrl == null) {
      final ctrl = VideoPlayerController.file(File(widget.videoPath));
      await ctrl.initialize();
      if (!mounted) return;
      ctrl.addListener(() { if (mounted) setState(() {}); });
      setState(() { _ctrl = ctrl; _initialized = true; });
      ctrl.play();
    } else if (_ctrl!.value.isPlaying) {
      _ctrl!.pause();
    } else {
      _ctrl!.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);
    final h = widget.height ?? 160.0;

    Widget content;
    if (_initialized && _ctrl != null && _ctrl!.value.isInitialized) {
      final isPlaying = _ctrl!.value.isPlaying;
      content = GestureDetector(
        onTap: _togglePlay,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              height: h,
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: _ctrl!.value.size.width,
                  height: _ctrl!.value.size.height,
                  child: VideoPlayer(_ctrl!),
                ),
              ),
            ),
            if (!isPlaying)
              Container(
                width: 44, height: 44,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
              ),
          ],
        ),
      );
    } else {
      content = GestureDetector(
        onTap: _togglePlay,
        child: Container(
          height: h,
          decoration: BoxDecoration(
            color: t.surfaceBlue,
            borderRadius: AppRadius.timelineImage,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: const BoxDecoration(
                    color: Colors.black26,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
                ),
                const SizedBox(height: 6),
                Text(
                  'tap to play',
                  style: AppTextStyles.sectionLabel.copyWith(
                    color: t.textFaint, fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final clipped = ClipRRect(
      borderRadius: AppRadius.timelineImage,
      child: content,
    );

    if (widget.isCensored) {
      return _RevealableContent(onRevealedTap: widget.onFold, child: clipped);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [clipped, const SizedBox(height: 6)],
    );
  }
}

class _AssetImage extends StatelessWidget {
  const _AssetImage({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);
    return ClipRRect(
      borderRadius: AppRadius.timelineImage,
      child: Image.asset(
        path,
        width: double.infinity,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Container(
          height: 80,
          decoration: BoxDecoration(
            color: t.surfaceCream,
            borderRadius: AppRadius.timelineImage,
          ),
          child: Icon(Icons.broken_image_rounded,
              color: t.textFaint, size: 20),
        ),
      ),
    );
  }
}

// ── Revealable content (blurred until tapped) ─────────────────────────────────

class _RevealableContent extends StatefulWidget {
  const _RevealableContent({required this.child, this.onRevealedTap});
  final Widget child;
  /// Called when the content is tapped *after* being revealed.
  /// If null, the tap is passed up to the nearest ancestor GestureDetector.
  final VoidCallback? onRevealedTap;

  @override
  State<_RevealableContent> createState() => _RevealableContentState();
}

class _RevealableContentState extends State<_RevealableContent> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);
    return GestureDetector(
      onTap: _revealed
          ? widget.onRevealedTap   // null → bubbles up, non-null → explicit action
          : () => setState(() => _revealed = true),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: _revealed
            ? KeyedSubtree(key: const ValueKey('clear'), child: widget.child)
            : KeyedSubtree(
                key: const ValueKey('blurred'),
                child: Stack(
                  children: [
                    ClipRect(
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(
                            sigmaX: 11, sigmaY: 11, tileMode: TileMode.decal),
                        child: widget.child,
                      ),
                    ),
                    Positioned.fill(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.75),
                            borderRadius: AppRadius.chip,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.visibility_off_rounded,
                                  size: 11, color: t.textMuted),
                              const SizedBox(width: 4),
                              Text(
                                'tap to reveal',
                                style: AppTextStyles.sectionLabel
                                    .copyWith(fontSize: 9, letterSpacing: 0.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

// ── Color Picker Dialog ───────────────────────────────────────────────────────

class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({
    required this.initialDotColor,
    required this.initialLineColor,
    required this.onChanged,
  });

  final Color initialDotColor;
  final Color? initialLineColor;
  final void Function(Color? dot, Color? line) onChanged;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late Color? _dotColor;
  late Color? _lineColor;

  @override
  void initState() {
    super.initState();
    _dotColor = widget.initialDotColor;
    _lineColor = widget.initialLineColor;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
      backgroundColor: t.surface,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.palette_outlined, size: 16, color: AppColors.pinkMid),
              const SizedBox(width: 8),
              Text('Edit Colors', style: AppTextStyles.cardTitle),
            ]),
            const SizedBox(height: 16),
            Text('DOT COLOR', style: AppTextStyles.sectionLabel),
            const SizedBox(height: 8),
            _ColorSwatch(
              palette: _spineColorPalette,
              selected: _dotColor,
              onSelect: (c) {
                setState(() => _dotColor = c);
                widget.onChanged(_dotColor, _lineColor);
              },
              allowNone: false,
            ),
            const SizedBox(height: 14),
            Text('LINE COLOR', style: AppTextStyles.sectionLabel),
            const SizedBox(height: 6),
            _ColorSwatch(
              palette: _spineColorPalette,
              selected: _lineColor,
              onSelect: (c) {
                setState(() => _lineColor = c);
                widget.onChanged(_dotColor, _lineColor);
              },
              allowNone: true,
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done',
                    style: TextStyle(
                      fontFamily: AppTextStyles.fontFamily,
                      color: AppColors.pinkDeep,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.palette,
    required this.selected,
    required this.onSelect,
    required this.allowNone,
  });

  final List<Color> palette;
  final Color? selected;
  final ValueChanged<Color?> onSelect;
  final bool allowNone;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (allowNone)
          GestureDetector(
            onTap: () => onSelect(null),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: t.surfaceCream,
                border: Border.all(
                  color: selected == null ? AppColors.pinkDeep : t.border,
                  width: selected == null ? 2.5 : 1,
                ),
              ),
              child: selected == null
                  ? Icon(Icons.close_rounded, size: 13, color: t.textMuted)
                  : null,
            ),
          ),
        ...palette.map((c) {
          final isSelected = selected == c;
          return GestureDetector(
            onTap: () => onSelect(c),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c,
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.transparent,
                  width: 2.5,
                ),
                boxShadow: isSelected
                    ? [BoxShadow(color: c.withValues(alpha: 0.55), blurRadius: 6)]
                    : null,
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                  : null,
            ),
          );
        }),
      ],
    );
  }
}

// ── New Event Page ────────────────────────────────────────────────────────────

class _NewEventPage extends StatefulWidget {
  const _NewEventPage({this.editEvent});
  final _Event? editEvent;

  @override
  State<_NewEventPage> createState() => _NewEventPageState();
}

class _NewEventPageState extends State<_NewEventPage> {
  final _titleCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  final List<_BuilderRow> _rows = [];
  final List<String> _tags = [];
  Color? _cardColor;
  bool _isDragOver = false;
  final List<_StickerPlacement> _stickers = [];
  bool _stickerTrayOpen = false;
  final GlobalKey _canvasKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.editEvent != null) _initFromEvent(widget.editEvent!);
  }

  void _initFromEvent(_Event event) {
    _titleCtrl.text = event.title;
    _selectedDate = event.date;
    _cardColor = event.cardColor;
    _tags.addAll(event.tags);
    if (event.location != null) _locationCtrl.text = event.location!;
    for (final row in event.rows) {
      final builderBlocks = row.blocks.map<_BuilderBlock>((block) {
        if (block is TextBlock) {
          final b = _BuilderTextBlock(text: block.text);
          b.isCensored = block.isCensored;
          if (block.fontFamily != null) b.fontFamily = block.fontFamily;
          b.fontWeight = block.fontWeight ?? 400;
          b.fontSize = block.fontSize ?? 12.0;
          return b;
        } else if (block is ImageBlock) {
          final b = _BuilderImageBlock();
          b.path = block.path;
          b.isCensored = block.isCensored;
          if (block.title != null) b.titleCtrl.text = block.title!;
          if (block.titleFontFamily != null) b.titleFontFamily = block.titleFontFamily;
          b.titleFontWeight = block.titleFontWeight ?? 500;
          b.titleFontSize = block.titleFontSize ?? 13.0;
          if (block.height != null) b.height = block.height;
          return b;
        } else if (block is CollageBlock) {
          final b = _BuilderCollageBlock();
          b.paths = List<String>.from(block.paths);
          b.layout = block.layout;
          b.isCensored = block.isCensored;
          if (block.title != null) b.titleCtrl.text = block.title!;
          if (block.titleFontFamily != null) b.titleFontFamily = block.titleFontFamily;
          b.titleFontWeight = block.titleFontWeight ?? 500;
          b.titleFontSize = block.titleFontSize ?? 13.0;
          if (block.height != null) b.height = block.height;
          return b;
        } else if (block is VideoBlock) {
          final b = _BuilderVideoBlock(path: block.path);
          b.isCensored = block.isCensored;
          if (block.height != null) b.height = block.height;
          return b;
        }
        return _BuilderTextBlock();
      }).toList();
      final bRow = _BuilderRow(builderBlocks);
      for (int i = 0; i < row.widths.length && i < bRow.widths.length; i++) {
        bRow.widths[i] = row.widths[i];
      }
      _rows.add(bRow);
    }
    for (final s in event.stickers) {
      _stickers.add(_StickerPlacement(path: s.path, position: Offset(s.x, s.y))..size = s.size);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _tagCtrl.dispose();
    _locationCtrl.dispose();
    for (final row in _rows) {
      for (final b in row.blocks) {
        if (b is _BuilderTextBlock) b.dispose();
        if (b is _BuilderImageBlock) b.dispose();
        if (b is _BuilderCollageBlock) b.dispose();
        // _BuilderVideoBlock has no controllers to dispose
      }
    }
    super.dispose();
  }

  void _addBlock(String type) {
    setState(() {
      _BuilderBlock block;
      if (type == 'text') {
        block = _BuilderTextBlock();
      } else if (type == 'collage') {
        block = _BuilderCollageBlock();
      } else if (type == 'video') {
        block = _BuilderVideoBlock();
      } else {
        block = _BuilderImageBlock();
      }
      _rows.add(_BuilderRow([block]));
    });
  }

  void _addToRow(int rowIdx, String type) {
    if (!_rows[rowIdx].canExpand) return;
    setState(() {
      _BuilderBlock block;
      if (type == 'text') {
        block = _BuilderTextBlock();
      } else {
        block = _BuilderImageBlock();
      }
      final row = _rows[rowIdx];
      row.blocks.add(block);
      row.widths = List.generate(row.blocks.length, (_) => 1.0 / row.blocks.length);
    });
  }

  void _removeFromRow(int rowIdx, int blockIdx) {
    final row = _rows[rowIdx];
    final b = row.blocks[blockIdx];
    if (b is _BuilderTextBlock) b.dispose();
    if (b is _BuilderImageBlock) b.dispose();
    if (b is _BuilderCollageBlock) b.dispose();
    setState(() {
      row.blocks.removeAt(blockIdx);
      if (row.blocks.isEmpty) {
        _rows.removeAt(rowIdx);
      } else {
        row.widths = List.generate(row.blocks.length, (_) => 1.0 / row.blocks.length);
      }
    });
  }

  void _moveRow(int from, int to) {
    if (to < 0 || to >= _rows.length) return;
    setState(() {
      final r = _rows.removeAt(from);
      _rows.insert(to, r);
    });
  }

  void _toggleCensorInRow(int rowIdx, int blockIdx) {
    setState(() => _rows[rowIdx].blocks[blockIdx].isCensored =
        !_rows[rowIdx].blocks[blockIdx].isCensored);
  }

  void _adjustDivider(int rowIdx, int divIdx, double deltaFx) {
    setState(() => _rows[rowIdx].adjustDivider(divIdx, deltaFx));
  }

  void _updateCollageLayout(int rowIdx, int blockIdx, CollageLayout layout) {
    final block = _rows[rowIdx].blocks[blockIdx];
    if (block is _BuilderCollageBlock) {
      setState(() => block.layout = layout);
    }
  }

  void _setFontFamily(int rowIdx, int blockIdx, String? family) {
    setState(() {
      final b = _rows[rowIdx].blocks[blockIdx];
      if (b is _BuilderTextBlock) {
        b.fontFamily = family;
      } else if (b is _BuilderImageBlock) {
        b.titleFontFamily = family;
      } else if (b is _BuilderCollageBlock) {
        b.titleFontFamily = family;
      }
    });
  }

  void _setFontWeight(int rowIdx, int blockIdx, int weight) {
    setState(() {
      final b = _rows[rowIdx].blocks[blockIdx];
      if (b is _BuilderTextBlock) {
        b.fontWeight = weight;
      } else if (b is _BuilderImageBlock) {
        b.titleFontWeight = weight;
      } else if (b is _BuilderCollageBlock) {
        b.titleFontWeight = weight;
      }
    });
  }

  void _setFontSize(int rowIdx, int blockIdx, double size) {
    setState(() {
      final b = _rows[rowIdx].blocks[blockIdx];
      if (b is _BuilderTextBlock) {
        b.fontSize = size.clamp(10.0, 28.0);
      } else if (b is _BuilderImageBlock) {
        b.titleFontSize = size.clamp(10.0, 22.0);
      } else if (b is _BuilderCollageBlock) {
        b.titleFontSize = size.clamp(10.0, 22.0);
      }
    });
  }

  // Renders a single builder block in display style (used for preview)
  Widget _renderBuilderBlock(BuildContext context, _BuilderBlock b, AppThemeData t) {
    if (b is _BuilderTextBlock) {
      final text = b.ctrl.text.trim();
      if (text.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: AppTextStyles.cardDesc.copyWith(
            fontFamily: b.fontFamily,
            fontWeight: _fontWeightFromInt(b.fontWeight),
            fontSize: b.fontSize,
          ),
          softWrap: true,
          maxLines: 10,
        ),
      );
    }
    if (b is _BuilderImageBlock) {
      final img = ClipRRect(
        borderRadius: AppRadius.timelineImage,
        child: Image.asset(b.path, width: double.infinity, height: b.height, fit: BoxFit.contain),
      );
      if (b.titleCtrl.text.trim().isNotEmpty) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                b.titleCtrl.text.trim(),
                style: TextStyle(
                  fontFamily: b.titleFontFamily ?? AppTextStyles.fontFamily,
                  fontWeight: _fontWeightFromInt(b.titleFontWeight),
                  fontSize: b.titleFontSize,
                  color: t.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            img,
            const SizedBox(height: 6),
          ],
        );
      }
      return Column(children: [img, const SizedBox(height: 6)]);
    }
    if (b is _BuilderCollageBlock) {
      final collage = _buildCollageLayout(
        paths: b.paths,
        layout: b.layout,
        height: b.height ?? 180,
      );
      if (b.titleCtrl.text.trim().isNotEmpty) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                b.titleCtrl.text.trim(),
                style: TextStyle(
                  fontFamily: b.titleFontFamily ?? AppTextStyles.fontFamily,
                  fontWeight: _fontWeightFromInt(b.titleFontWeight),
                  fontSize: b.titleFontSize,
                  color: t.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            collage,
            const SizedBox(height: 6),
          ],
        );
      }
      return Column(children: [collage, const SizedBox(height: 6)]);
    }
    if (b is _BuilderVideoBlock) {
      final hasVideo = b.path.isNotEmpty && File(b.path).existsSync();
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: ClipRRect(
          borderRadius: AppRadius.timelineImage,
          child: Container(
            height: b.height ?? 160.0,
            color: t.surfaceBlue,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.videocam_rounded, size: 24, color: Colors.white54),
                  const SizedBox(height: 4),
                  Text(
                    hasVideo ? b.path.split('/').last : 'No video',
                    style: AppTextStyles.sectionLabel.copyWith(
                      color: t.textFaint, fontSize: 8,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  // Renders current blocks in the same layout as _buildExpandedContent
  // so sticker positions recorded here match the timeline card exactly.
  List<Widget> _buildPreviewContent(BuildContext context) {
    final t = AppThemeScope.of(context);
    final widgets = <Widget>[];
    for (final row in _rows) {
      if (row.blocks.length > 1) {
        widgets.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < row.blocks.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Flexible(
                  flex: (row.widths[i] * 100).round().clamp(1, 100),
                  child: _renderBuilderBlock(context, row.blocks[i], t),
                ),
              ],
            ],
          ),
        );
      } else if (row.blocks.isNotEmpty) {
        widgets.add(_renderBuilderBlock(context, row.blocks.first, t));
      }
    }
    return widgets;
  }

  void _setBlockHeight(int rowIdx, int blockIdx, double delta) {
    setState(() {
      final b = _rows[rowIdx].blocks[blockIdx];
      final isText = b is _BuilderTextBlock;
      final minH = isText ? 50.0 : 60.0;
      final current = b.height ?? (isText ? 80.0 : 140.0);
      b.height = (current + delta).clamp(minH, 600.0);
    });
  }

  Future<void> _pickDate() async {
    final t = AppThemeScope.of(context);
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.pinkDeep,
            onPrimary: Colors.white,
            surface: t.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _save() {
    if (_titleCtrl.text.trim().isEmpty) return;
    // Build EventRows preserving side-by-side layout
    final eventRows = <EventRow>[];
    for (final row in _rows) {
      final rowBlocks = <EventBlock>[];
      for (final b in row.blocks) {
        if (b is _BuilderTextBlock) {
          rowBlocks.add(TextBlock(
            b.ctrl.text.trim(),
            isCensored: b.isCensored,
            fontFamily: b.fontFamily,
            fontWeight: b.fontWeight,
            fontSize: b.fontSize,
          ));
        } else if (b is _BuilderImageBlock) {
          rowBlocks.add(ImageBlock(
            b.path,
            isCensored: b.isCensored,
            title: b.titleCtrl.text.trim().isEmpty ? null : b.titleCtrl.text.trim(),
            titleFontFamily: b.titleFontFamily,
            titleFontWeight: b.titleFontWeight,
            titleFontSize: b.titleFontSize,
            height: b.height,
          ));
        } else if (b is _BuilderCollageBlock) {
          rowBlocks.add(CollageBlock(
            paths: List<String>.from(b.paths),
            layout: b.layout,
            isCensored: b.isCensored,
            title: b.titleCtrl.text.trim().isEmpty ? null : b.titleCtrl.text.trim(),
            titleFontFamily: b.titleFontFamily,
            titleFontWeight: b.titleFontWeight,
            titleFontSize: b.titleFontSize,
            height: b.height,
          ));
        } else if (b is _BuilderVideoBlock && b.path.isNotEmpty) {
          rowBlocks.add(VideoBlock(
            b.path,
            isCensored: b.isCensored,
            height: b.height,
          ));
        }
      }
      if (rowBlocks.isNotEmpty) {
        eventRows.add(EventRow(
          blocks: rowBlocks,
          widths: List<double>.from(row.widths),
        ));
      }
    }

    final event = _Event(
      title: _titleCtrl.text.trim(),
      date: _selectedDate,
      rows: eventRows,
      tags: List<String>.from(_tags),
      location: _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
    );
    event.cardColor = _cardColor;
    event.stickers = _stickers
        .map((s) => EventSticker(path: s.path, x: s.position.dx, y: s.position.dy, size: s.size))
        .toList();
    Navigator.pop(context, event);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final dateLabel =
        '${_selectedDate.day} ${months[_selectedDate.month - 1]} ${_selectedDate.year}';

    return Scaffold(
      backgroundColor: t.background,
      // ── Header bar ──────────────────────────────────────────────────────────
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Container(
          color: t.surface,
          child: SafeArea(
            bottom: false,
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: t.border)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close_rounded, size: 22, color: t.textMuted),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('New Memory ✦', style: AppTextStyles.pageTitle),
                  ),
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Save', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      // ── Scrollable body ─────────────────────────────────────────────────────
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            _SheetInputField(ctrl: _titleCtrl, hint: 'Title…'),
            const SizedBox(height: 10),

            // Date picker
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: t.surfaceBlush,
                  borderRadius: AppRadius.inputField,
                  border: Border.all(color: t.border),
                ),
                child: Row(children: [
                  Icon(Icons.calendar_today_rounded, size: 14, color: t.textMuted),
                  const SizedBox(width: 8),
                  Text(dateLabel,
                      style: AppTextStyles.timelineDate.copyWith(fontSize: 12)),
                ]),
              ),
            ),
            const SizedBox(height: 12),

            // Tags
            Text('TAGS', style: AppTextStyles.sectionLabel),
            const SizedBox(height: 6),
            _TagInputRow(
              tags: _tags,
              controller: _tagCtrl,
              onAdd: (tag) {
                if (tag.isNotEmpty && !_tags.contains(tag)) {
                  setState(() => _tags.add(tag));
                  _tagCtrl.clear();
                }
              },
              onRemove: (tag) => setState(() => _tags.remove(tag)),
            ),
            const SizedBox(height: 12),

            // Location
            _SheetInputField(
              ctrl: _locationCtrl,
              hint: '📍 Location (optional)…',
            ),
            const SizedBox(height: 12),

            // Card background color
            Row(children: [
              Text('CARD COLOR', style: AppTextStyles.sectionLabel),
              const SizedBox(width: 8),
              _CardColorPicker(
                selected: _cardColor,
                onSelect: (c) => setState(() => _cardColor = c),
              ),
            ]),
            const SizedBox(height: 12),

            // Content label
            Row(children: [
              Text('CONTENT', style: AppTextStyles.sectionLabel),
              const SizedBox(width: 6),
              Text('— triple-tap any block header to censor',
                  style: AppTextStyles.sectionLabel
                      .copyWith(color: t.textFaint, fontSize: 9)),
            ]),
            const SizedBox(height: 8),

            // Drop zone (grows freely on full page)
            DragTarget<String>(
              onWillAcceptWithDetails: (d) {
                if (d.data.startsWith('sticker:')) return false;
                setState(() => _isDragOver = true);
                return true;
              },
              onLeave: (_) => setState(() => _isDragOver = false),
              onAcceptWithDetails: (details) {
                setState(() => _isDragOver = false);
                _addBlock(details.data);
              },
              builder: (context, _, __) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  constraints: const BoxConstraints(minHeight: 120),
                  decoration: BoxDecoration(
                    color: _cardColor ??
                        (_isDragOver ? AppColors.pinkPale : t.surfaceBlush),
                    borderRadius: AppRadius.card,
                    border: Border.all(
                      color: _isDragOver ? AppColors.pinkMid : t.border,
                      width: _isDragOver ? 1.5 : 1.0,
                    ),
                  ),
                  child: _rows.isEmpty
                      ? _EmptyDropZone(isDragOver: _isDragOver)
                      : _RowList(
                          rows: _rows,
                          onRemoveFromRow: _removeFromRow,
                          onMoveRow: _moveRow,
                          onCensorToggle: _toggleCensorInRow,
                          onAdjustDivider: _adjustDivider,
                          onAddToRow: _addToRow,
                          onUpdateCollageLayout: _updateCollageLayout,
                          onFontFamilyChanged: _setFontFamily,
                          onFontWeightChanged: _setFontWeight,
                          onFontSizeChanged: _setFontSize,
                          onBlockHeightChanged: _setBlockHeight,
                          onVideoUpdated: () => setState(() {}),
                        ),
                );
              },
            ),
            const SizedBox(height: 14),

            // Palette
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  _PaletteChip(
                    label: 'Text',
                    icon: Icons.text_fields_rounded,
                    type: 'text',
                    onTap: () => _addBlock('text'),
                  ),
                  const SizedBox(width: 8),
                  _PaletteChip(
                    label: 'Image',
                    icon: Icons.image_rounded,
                    type: 'image',
                    onTap: () => _addBlock('image'),
                  ),
                  const SizedBox(width: 8),
                  _PaletteChip(
                    label: 'Collage',
                    icon: Icons.auto_awesome_mosaic_rounded,
                    type: 'collage',
                    onTap: () => _addBlock('collage'),
                  ),
                  const SizedBox(width: 8),
                  _PaletteChip(
                    label: 'Video',
                    icon: Icons.videocam_rounded,
                    type: 'video',
                    onTap: () => _addBlock('video'),
                  ),
                  const Spacer(),

                ]),
              ],
            ),

            // ── Sticker preview (matches timeline card layout exactly) ──────
            if (_rows.isNotEmpty) ...[
              const SizedBox(height: 14),
              Row(children: [
                Text('STICKER PLACEMENT', style: AppTextStyles.sectionLabel),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '— drop stickers here',
                    style: AppTextStyles.sectionLabel.copyWith(
                        color: t.textFaint, fontSize: 9),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
              const SizedBox(height: 6),
              DragTarget<String>(
                onWillAcceptWithDetails: (d) => d.data.startsWith('sticker:'),
                onAcceptWithDetails: (details) {
                  final path = details.data.substring('sticker:'.length);
                  final box = _canvasKey.currentContext
                      ?.findRenderObject() as RenderBox?;
                  if (box != null) {
                    const sz = 64.0;
                    final local = box.globalToLocal(details.offset);
                    setState(() => _stickers.add(_StickerPlacement(
                      path: path,
                      position: Offset(local.dx - sz / 2, local.dy - sz / 2),
                    )));
                  }
                },
                builder: (context, candidateData, __) {
                  final isOver = candidateData.isNotEmpty;
                  return Container(
                    key: _canvasKey,
                    decoration: BoxDecoration(
                      color: _cardColor ??
                          (isOver ? AppColors.pinkPale : t.surfaceBlush),
                      borderRadius: AppRadius.card,
                      border: Border.all(
                        color: isOver ? AppColors.pinkMid : t.border,
                        width: isOver ? 1.5 : 1.0,
                      ),
                    ),
                    padding: AppSpacing.cardPadding,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _buildPreviewContent(context),
                        ),
                        ..._stickers.asMap().entries.map((entry) =>
                          _PlacedStickerWidget(
                            placement: entry.value,
                            onMoved: (pos) =>
                                setState(() => entry.value.position = pos),
                            onRemoved: () =>
                                setState(() => _stickers.removeAt(entry.key)),
                          )),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
          // ── Floating sticker button ─────────────────────────────────────
          Positioned(
            right: 16,
            bottom: _stickerTrayOpen ? 206 : 16,
            child: GestureDetector(
              onTap: () => setState(() => _stickerTrayOpen = !_stickerTrayOpen),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _stickerTrayOpen ? AppColors.pinkDeep : AppColors.pinkMid,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.pinkDeep.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    '+ :D',
                    style: TextStyle(
                      fontFamily: AppTextStyles.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
          _StickerTray(
            open: _stickerTrayOpen,
            onClose: () => setState(() => _stickerTrayOpen = false),
            onDragStarted: () => setState(() => _stickerTrayOpen = false),
          ),
        ],
      ),
    );
  }
}

// ── Row list (replaces _BlockList) ────────────────────────────────────────────

class _RowList extends StatelessWidget {
  const _RowList({
    required this.rows,
    required this.onRemoveFromRow,
    required this.onMoveRow,
    required this.onCensorToggle,
    required this.onAdjustDivider,
    required this.onAddToRow,
    required this.onUpdateCollageLayout,
    required this.onFontFamilyChanged,
    required this.onFontWeightChanged,
    required this.onFontSizeChanged,
    required this.onBlockHeightChanged,
    this.onVideoUpdated,
  });

  final List<_BuilderRow> rows;
  final void Function(int rowIdx, int blockIdx) onRemoveFromRow;
  final void Function(int from, int to) onMoveRow;
  final void Function(int rowIdx, int blockIdx) onCensorToggle;
  final void Function(int rowIdx, int divIdx, double deltaFx) onAdjustDivider;
  final void Function(int rowIdx, String type) onAddToRow;
  final void Function(int rowIdx, int blockIdx, CollageLayout layout) onUpdateCollageLayout;
  final void Function(int rowIdx, int blockIdx, String? family) onFontFamilyChanged;
  final void Function(int rowIdx, int blockIdx, int weight) onFontWeightChanged;
  final void Function(int rowIdx, int blockIdx, double size) onFontSizeChanged;
  final void Function(int rowIdx, int blockIdx, double delta) onBlockHeightChanged;
  final VoidCallback? onVideoUpdated;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(rows.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _RowItem(
              row: rows[i],
              rowIdx: i,
              isFirst: i == 0,
              isLast: i == rows.length - 1,
              onRemoveFromRow: (blockIdx) => onRemoveFromRow(i, blockIdx),
              onMoveUp: i > 0 ? () => onMoveRow(i, i - 1) : null,
              onMoveDown: i < rows.length - 1 ? () => onMoveRow(i, i + 1) : null,
              onCensorToggle: (blockIdx) => onCensorToggle(i, blockIdx),
              onAdjustDivider: (divIdx, deltaFx) => onAdjustDivider(i, divIdx, deltaFx),
              onAddToRow: (type) => onAddToRow(i, type),
              onUpdateCollageLayout: (blockIdx, layout) =>
                  onUpdateCollageLayout(i, blockIdx, layout),
              onFontFamilyChanged: (blockIdx, family) => onFontFamilyChanged(i, blockIdx, family),
              onFontWeightChanged: (blockIdx, weight) => onFontWeightChanged(i, blockIdx, weight),
              onFontSizeChanged: (blockIdx, size) => onFontSizeChanged(i, blockIdx, size),
              onBlockHeightChanged: (blockIdx, delta) => onBlockHeightChanged(i, blockIdx, delta),
              onVideoUpdated: onVideoUpdated,
            ),
          );
        }),
      ),
    );
  }
}

// ── Row item ──────────────────────────────────────────────────────────────────

class _RowItem extends StatelessWidget {
  const _RowItem({
    required this.row,
    required this.rowIdx,
    required this.isFirst,
    required this.isLast,
    required this.onRemoveFromRow,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onCensorToggle,
    required this.onAdjustDivider,
    required this.onAddToRow,
    required this.onUpdateCollageLayout,
    required this.onFontFamilyChanged,
    required this.onFontWeightChanged,
    required this.onFontSizeChanged,
    required this.onBlockHeightChanged,
    this.onVideoUpdated,
  });

  final _BuilderRow row;
  final int rowIdx;
  final bool isFirst;
  final bool isLast;
  final void Function(int blockIdx) onRemoveFromRow;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final void Function(int blockIdx) onCensorToggle;
  final void Function(int divIdx, double deltaFx) onAdjustDivider;
  final void Function(String type) onAddToRow;
  final void Function(int blockIdx, CollageLayout layout) onUpdateCollageLayout;
  final void Function(int blockIdx, String? family) onFontFamilyChanged;
  final void Function(int blockIdx, int weight) onFontWeightChanged;
  final void Function(int blockIdx, double size) onFontSizeChanged;
  final void Function(int blockIdx, double delta) onBlockHeightChanged;
  final VoidCallback? onVideoUpdated;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);

    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: AppRadius.timelineImage,
        border: Border.all(color: t.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Row header ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: t.surfaceBlush,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.sm),
                topRight: Radius.circular(AppRadius.sm),
              ),
            ),
            child: Row(
              children: [
                // Move up/down
                _MoveBtn(icon: Icons.arrow_upward_rounded, onTap: onMoveUp),
                const SizedBox(width: 3),
                _MoveBtn(icon: Icons.arrow_downward_rounded, onTap: onMoveDown),
                const SizedBox(width: 6),
                Text(
                  'ROW',
                  style: AppTextStyles.sectionLabel.copyWith(fontSize: 8),
                ),
                const Spacer(),
                // Add block to row (if canExpand)
                if (row.canExpand) ...[
                  _AddToRowButton(onAdd: onAddToRow),
                  const SizedBox(width: 6),
                ],
                // Delete row
                GestureDetector(
                  onTap: () {
                    // Remove all blocks in row
                    for (int i = row.blocks.length - 1; i >= 0; i--) {
                      onRemoveFromRow(i);
                    }
                  },
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: AppColors.pinkPale,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded,
                        size: 11, color: AppColors.pinkDeep),
                  ),
                ),
              ],
            ),
          ),

          // ── Row content: blocks with drag dividers ─────────────
          LayoutBuilder(
            builder: (context, constraints) {
              final rowWidth = constraints.maxWidth;
              final children = <Widget>[];
              for (int i = 0; i < row.blocks.length; i++) {
                final block = row.blocks[i];
                final flexVal = (row.widths[i] * 100).round();
                children.add(
                  Flexible(
                    flex: flexVal,
                    child: _BlockCell(
                      block: block,
                      blockIdx: i,
                      onRemove: () => onRemoveFromRow(i),
                      onCensorToggle: () => onCensorToggle(i),
                      onUpdateCollageLayout: (layout) =>
                          onUpdateCollageLayout(i, layout),
                      onFontFamilyChanged: (family) => onFontFamilyChanged(i, family),
                      onFontWeightChanged: (weight) => onFontWeightChanged(i, weight),
                      onFontSizeChanged: (size) => onFontSizeChanged(i, size),
                      onBlockHeightChanged: (delta) => onBlockHeightChanged(i, delta),
                      onVideoUpdated: onVideoUpdated,
                    ),
                  ),
                );
                // Add resize divider between blocks
                if (i < row.blocks.length - 1) {
                  final capturedI = i;
                  children.add(
                    _ResizeDivider(
                      onDrag: (dx, _) {
                        if (rowWidth > 0) {
                          onAdjustDivider(capturedI, dx / rowWidth);
                        }
                      },
                    ),
                  );
                }
              }
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Add-to-row button (small popup) ──────────────────────────────────────────

class _AddToRowButton extends StatelessWidget {
  const _AddToRowButton({required this.onAdd});
  final void Function(String type) onAdd;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);
    return GestureDetector(
      onTap: () async {
        final result = await showMenu<String>(
          context: context,
          position: RelativeRect.fromLTRB(
            MediaQuery.of(context).size.width - 80,
            0, 0, 0,
          ),
          items: [
            PopupMenuItem(
              value: 'text',
              height: 32,
              child: Row(children: [
                Icon(Icons.text_fields_rounded, size: 13, color: t.textMuted),
                const SizedBox(width: 6),
                Text('Text', style: AppTextStyles.sectionLabel),
              ]),
            ),
            PopupMenuItem(
              value: 'image',
              height: 32,
              child: Row(children: [
                Icon(Icons.image_rounded, size: 13, color: t.textMuted),
                const SizedBox(width: 6),
                Text('Image', style: AppTextStyles.sectionLabel),
              ]),
            ),
          ],
          color: t.surface,
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
        );
        if (result != null) onAdd(result);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.pinkPale,
          borderRadius: AppRadius.chip,
          border: Border.all(color: t.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, size: 10, color: AppColors.pinkMid),
            const SizedBox(width: 3),
            Text('add',
                style: AppTextStyles.sectionLabel
                    .copyWith(fontSize: 8, color: AppColors.pinkMid)),
          ],
        ),
      ),
    );
  }
}

// ── Block cell (single block inside a row) ────────────────────────────────────

class _BlockCell extends StatelessWidget {
  const _BlockCell({
    required this.block,
    required this.blockIdx,
    required this.onRemove,
    required this.onCensorToggle,
    required this.onUpdateCollageLayout,
    this.onFontFamilyChanged,
    this.onFontWeightChanged,
    this.onFontSizeChanged,
    this.onBlockHeightChanged,
    this.onVideoUpdated,
  });

  final _BuilderBlock block;
  final int blockIdx;
  final VoidCallback onRemove;
  final VoidCallback onCensorToggle;
  final void Function(CollageLayout) onUpdateCollageLayout;
  final void Function(String? fontFamily)? onFontFamilyChanged;
  final void Function(int weight)? onFontWeightChanged;
  final void Function(double size)? onFontSizeChanged;
  final void Function(double delta)? onBlockHeightChanged;
  final VoidCallback? onVideoUpdated;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);
    final isCensored = block.isCensored;
    final isText = block is _BuilderTextBlock;
    final isCollage = block is _BuilderCollageBlock;
    final isVideo = block is _BuilderVideoBlock;

    IconData typeIcon;
    String typeLabel;
    if (isText) {
      typeIcon = Icons.text_fields_rounded;
      typeLabel = 'TEXT';
    } else if (isCollage) {
      typeIcon = Icons.auto_awesome_mosaic_rounded;
      typeLabel = 'COLLAGE';
    } else if (isVideo) {
      typeIcon = Icons.videocam_rounded;
      typeLabel = 'VIDEO';
    } else {
      typeIcon = Icons.image_rounded;
      typeLabel = 'IMAGE';
    }

    // Determine current style values for the StyleBar
    String? currentFontFamily;
    int currentFontWeight;
    double currentFontSize;
    bool isTitle = false;

    if (block is _BuilderTextBlock) {
      final b = block as _BuilderTextBlock;
      currentFontFamily = b.fontFamily;
      currentFontWeight = b.fontWeight;
      currentFontSize = b.fontSize;
      isTitle = false;
    } else if (block is _BuilderImageBlock) {
      final b = block as _BuilderImageBlock;
      currentFontFamily = b.titleFontFamily;
      currentFontWeight = b.titleFontWeight;
      currentFontSize = b.titleFontSize;
      isTitle = true;
    } else if (block is _BuilderCollageBlock) {
      final b = block as _BuilderCollageBlock;
      currentFontFamily = b.titleFontFamily;
      currentFontWeight = b.titleFontWeight;
      currentFontSize = b.titleFontSize;
      isTitle = true;
    } else {
      currentFontFamily = null;
      currentFontWeight = 400;
      currentFontSize = 12.0;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Cell header (triple-tap to censor) ───────────────────
        _TripleTapDetector(
          onTripleTap: onCensorToggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: isCensored ? AppColors.pinkPale : t.surfaceBlush,
            ),
            child: Row(
              children: [
                Icon(typeIcon,
                    size: 10,
                    color: isCensored ? AppColors.pinkDeep : t.textMuted),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    typeLabel,
                    style: AppTextStyles.sectionLabel.copyWith(
                      fontSize: 8,
                      color: isCensored ? AppColors.pinkDeep : t.textFaint,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isCensored) ...[
                  const Icon(Icons.lock_rounded, size: 9, color: AppColors.pinkDeep),
                  const SizedBox(width: 2),
                ],
                GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(
                      color: AppColors.pinkPale,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded,
                        size: 9, color: AppColors.pinkDeep),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Style bar ──────────────────────────────────────────────
        if (!isVideo)
          _StyleBar(
            fontFamily: currentFontFamily,
            fontWeight: currentFontWeight,
            fontSize: currentFontSize,
            maxFontSize: isTitle ? 22.0 : 28.0,
            onFontFamily: (f) => onFontFamilyChanged?.call(f),
            onFontWeight: (w) => onFontWeightChanged?.call(w),
            onFontSize: (s) => onFontSizeChanged?.call(s),
          ),

        // ── Cell content ─────────────────────────────────────────
        if (block is _BuilderTextBlock)
          _TextContent(
            block: block as _BuilderTextBlock,
            censored: isCensored,
            height: block.height,
          )
        else if (block is _BuilderCollageBlock)
          _CollageBuilderContent(
            block: block as _BuilderCollageBlock,
            censored: isCensored,
            onLayoutChanged: onUpdateCollageLayout,
          )
        else if (block is _BuilderImageBlock)
          _ImageContent(
            block: block as _BuilderImageBlock,
            censored: isCensored,
            height: block.height,
          )
        else if (block is _BuilderVideoBlock)
          _VideoBuilderContent(
            block: block as _BuilderVideoBlock,
            censored: isCensored,
            onUpdated: onVideoUpdated ?? () {},
          ),

        // ── Vertical resize handle ───────────────────────────────
        if (onBlockHeightChanged != null)
          _VerticalResizeHandle(
            onDrag: (dy) => onBlockHeightChanged!.call(dy),
          ),
      ],
    );
  }
}

// ── Style Bar ─────────────────────────────────────────────────────────────────

class _StyleBar extends StatelessWidget {
  const _StyleBar({
    required this.fontFamily,
    required this.fontWeight,
    required this.fontSize,
    required this.maxFontSize,
    required this.onFontFamily,
    required this.onFontWeight,
    required this.onFontSize,
  });

  final String? fontFamily;
  final int fontWeight;
  final double fontSize;
  final double maxFontSize;
  final void Function(String?) onFontFamily;
  final void Function(int) onFontWeight;
  final void Function(double) onFontSize;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);

    final sizeLabel = fontSize == fontSize.roundToDouble()
        ? fontSize.toInt().toString()
        : fontSize.toStringAsFixed(1);

    final canDecrease = fontSize > 10.0;
    final canIncrease = fontSize < maxFontSize;

    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: t.surfaceBlush,
        border: Border(top: BorderSide(color: t.border)),
      ),
      child: Row(
        children: [
          // Font chips
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: _kFonts.map((entry) {
                  final label = entry.$1;
                  final family = entry.$2;
                  final isSelected = fontFamily == family;
                  return GestureDetector(
                    onTap: () => onFontFamily(family),
                    child: Container(
                      width: 36,
                      height: 22,
                      margin: const EdgeInsets.only(right: 3),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.pinkPale : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                        border: isSelected
                            ? Border.all(color: AppColors.pinkMid)
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        label,
                        style: TextStyle(
                          fontFamily: family ?? AppTextStyles.fontFamily,
                          fontSize: 9,
                          color: isSelected ? AppColors.pinkDeep : t.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Weight pills
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: _kWeights.map((entry) {
                final label = entry.$1;
                final weight = entry.$2;
                final isSelected = fontWeight == weight;
                return GestureDetector(
                  onTap: () => onFontWeight(weight),
                  child: Container(
                    width: 24,
                    height: 18,
                    margin: const EdgeInsets.only(right: 2),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.pinkMid : Colors.transparent,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      style: TextStyle(
                        fontFamily: AppTextStyles.fontFamily,
                        fontSize: 8,
                        color: isSelected ? Colors.white : t.textFaint,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Font size stepper
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: canDecrease ? () => onFontSize(fontSize - 1) : null,
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: Center(
                      child: Text(
                        '–',
                        style: TextStyle(
                          fontFamily: AppTextStyles.fontFamily,
                          fontSize: 13,
                          color: canDecrease ? t.textMuted : t.textFaint,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 22,
                  child: Center(
                    child: Text(
                      sizeLabel,
                      style: TextStyle(
                        fontFamily: AppTextStyles.fontFamily,
                        fontSize: 9,
                        color: t.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: canIncrease ? () => onFontSize(fontSize + 1) : null,
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: Center(
                      child: Text(
                        '+',
                        style: TextStyle(
                          fontFamily: AppTextStyles.fontFamily,
                          fontSize: 13,
                          color: canIncrease ? t.textMuted : t.textFaint,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Resize divider (vertical drag handle between two blocks) ─────────────────

class _ResizeDivider extends StatefulWidget {
  const _ResizeDivider({required this.onDrag});
  final void Function(double deltaFraction, double rowWidth) onDrag;

  @override
  State<_ResizeDivider> createState() => _ResizeDividerState();
}

class _ResizeDividerState extends State<_ResizeDivider> {
  bool _active = false;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);
    return GestureDetector(
      onHorizontalDragStart: (_) => setState(() => _active = true),
      onHorizontalDragEnd: (_) => setState(() => _active = false),
      onHorizontalDragUpdate: (d) {
        widget.onDrag(d.delta.dx, 0);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: _active ? 14 : 10,
        color: Colors.transparent,
        child: Center(
          child: Container(
            width: 2,
            decoration: BoxDecoration(
              color: _active ? AppColors.pinkMid : t.border,
              borderRadius: BorderRadius.circular(1),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.drag_handle_rounded,
                    size: 12,
                    color: _active ? AppColors.pinkMid : t.textFaint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Collage builder content ───────────────────────────────────────────────────

class _CollageBuilderContent extends StatelessWidget {
  const _CollageBuilderContent({
    required this.block,
    required this.censored,
    required this.onLayoutChanged,
  });

  final _BuilderCollageBlock block;
  final bool censored;
  final void Function(CollageLayout) onLayoutChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title field
        TextField(
          controller: block.titleCtrl,
          maxLines: 1,
          style: TextStyle(
            fontFamily: block.titleFontFamily ?? AppTextStyles.fontFamily,
            fontWeight: _fontWeightFromInt(block.titleFontWeight),
            fontSize: block.titleFontSize,
            color: t.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'Add a title…',
            hintStyle: TextStyle(
                fontFamily: AppTextStyles.fontFamily,
                fontSize: 11,
                color: t.textFaint),
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
          ),
        ),
        // Collage preview
        Padding(
          padding: const EdgeInsets.all(6),
          child: _buildCollageLayout(
            paths: block.paths,
            layout: block.layout,
            height: block.height ?? 180,
            censored: censored,
          ),
        ),
        // Layout selector
        Padding(
          padding: const EdgeInsets.only(left: 6, right: 6, bottom: 6),
          child: Row(
            children: [
              Text('Layout:',
                  style: AppTextStyles.sectionLabel.copyWith(fontSize: 8)),
              const SizedBox(width: 6),
              _LayoutIconBtn(
                layout: CollageLayout.bigLeft,
                selected: block.layout == CollageLayout.bigLeft,
                onTap: () => onLayoutChanged(CollageLayout.bigLeft),
              ),
              const SizedBox(width: 4),
              _LayoutIconBtn(
                layout: CollageLayout.bigRight,
                selected: block.layout == CollageLayout.bigRight,
                onTap: () => onLayoutChanged(CollageLayout.bigRight),
              ),
              const SizedBox(width: 4),
              _LayoutIconBtn(
                layout: CollageLayout.bigTop,
                selected: block.layout == CollageLayout.bigTop,
                onTap: () => onLayoutChanged(CollageLayout.bigTop),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Layout icon button ────────────────────────────────────────────────────────

class _LayoutIconBtn extends StatelessWidget {
  const _LayoutIconBtn({
    required this.layout,
    required this.selected,
    required this.onTap,
  });

  final CollageLayout layout;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 20,
        decoration: BoxDecoration(
          color: selected ? AppColors.pinkPale : t.surface,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: selected ? AppColors.pinkMid : t.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: CustomPaint(
          painter: _LayoutIconPainter(layout: layout, active: selected),
        ),
      ),
    );
  }
}

class _LayoutIconPainter extends CustomPainter {
  const _LayoutIconPainter({required this.layout, required this.active});
  final CollageLayout layout;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = active ? AppColors.pinkMid : AppColors.textFaint
      ..style = PaintingStyle.fill;
    const p = 2.0; // padding
    final w = size.width - p * 2;
    final h = size.height - p * 2;

    if (layout == CollageLayout.bigLeft) {
      // Big left (60%), two small on right
      final bigW = w * 0.6;
      final smallW = w - bigW - 1;
      final smallH = (h - 1) / 2;
      canvas.drawRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(p, p, bigW, h), const Radius.circular(1)), fillPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(p + bigW + 1, p, smallW, smallH), const Radius.circular(1)), fillPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(p + bigW + 1, p + smallH + 1, smallW, smallH), const Radius.circular(1)), fillPaint);
    } else if (layout == CollageLayout.bigRight) {
      // Two small on left, big right (60%)
      final bigW = w * 0.6;
      final smallW = w - bigW - 1;
      final smallH = (h - 1) / 2;
      canvas.drawRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(p, p, smallW, smallH), const Radius.circular(1)), fillPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(p, p + smallH + 1, smallW, smallH), const Radius.circular(1)), fillPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(p + smallW + 1, p, bigW, h), const Radius.circular(1)), fillPaint);
    } else {
      // bigTop: full-width top, two small below
      final bigH = h * 0.6;
      final smallH = h - bigH - 1;
      final smallW = (w - 1) / 2;
      canvas.drawRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(p, p, w, bigH), const Radius.circular(1)), fillPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(p, p + bigH + 1, smallW, smallH), const Radius.circular(1)), fillPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(p + smallW + 1, p + bigH + 1, smallW, smallH), const Radius.circular(1)), fillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LayoutIconPainter oldDelegate) =>
      oldDelegate.layout != layout || oldDelegate.active != active;
}

// ── Card color picker (compact inline swatch row) ─────────────────────────────

class _CardColorPicker extends StatelessWidget {
  const _CardColorPicker({required this.selected, required this.onSelect});
  final Color? selected;
  final ValueChanged<Color?> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // "None" swatch
          GestureDetector(
            onTap: () => onSelect(null),
            child: Container(
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: t.surfaceCream,
                border: Border.all(
                  color: selected == null ? AppColors.pinkDeep : t.border,
                  width: selected == null ? 2 : 1,
                ),
              ),
              child: selected == null
                  ? Icon(Icons.close_rounded, size: 11, color: t.textMuted)
                  : null,
            ),
          ),
          ...(t.isDark ? _cardColorPaletteDark : _cardColorPalette).map((c) {
            final isSelected = selected == c;
            return GestureDetector(
              onTap: () => onSelect(c),
              child: Container(
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c,
                  border: Border.all(
                    color: isSelected ? AppColors.pinkDeep : t.border,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 4)]
                      : null,
                ),
                child: isSelected
                    ? const Icon(Icons.check_rounded, size: 11, color: AppColors.pinkDeep)
                    : null,
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Empty drop zone ───────────────────────────────────────────────────────────

class _EmptyDropZone extends StatelessWidget {
  const _EmptyDropZone({required this.isDragOver});
  final bool isDragOver;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isDragOver ? Icons.add_circle_outline_rounded : Icons.drag_indicator_rounded,
              size: 22,
              color: isDragOver ? AppColors.pinkMid : t.textFaint,
            ),
            const SizedBox(height: 6),
            Text(
              isDragOver ? 'Release to add' : 'Drop widgets here…',
              style: AppTextStyles.inputHint.copyWith(
                color: isDragOver ? AppColors.pinkMid : t.textFaint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Palette chip ──────────────────────────────────────────────────────────────

class _PaletteChip extends StatelessWidget {
  const _PaletteChip({
    required this.label,
    required this.icon,
    required this.type,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final String type;
  final VoidCallback onTap;

  Widget _chip(BuildContext context, {bool dragging = false, double opacity = 1.0}) {
    final t = AppThemeScope.of(context);
    return Opacity(
      opacity: opacity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: dragging ? AppColors.pinkDeep : AppColors.pinkPale,
          borderRadius: AppRadius.chip,
          border: Border.all(
              color: dragging ? Colors.transparent : t.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14,
                color: dragging ? Colors.white : AppColors.pinkMid),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontFamily: AppTextStyles.fontFamily,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.pinkMid,
              ).copyWith(color: dragging ? Colors.white : AppColors.pinkMid),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LongPressDraggable<String>(
      data: type,
      delay: const Duration(milliseconds: 200),
      feedback: Material(color: Colors.transparent, child: _chip(context, dragging: true)),
      childWhenDragging: _chip(context, opacity: 0.4),
      child: GestureDetector(onTap: onTap, child: _chip(context)),
    );
  }
}

// ── Vertical resize handle ────────────────────────────────────────────────────

class _VerticalResizeHandle extends StatefulWidget {
  const _VerticalResizeHandle({required this.onDrag});
  final void Function(double dy) onDrag;

  @override
  State<_VerticalResizeHandle> createState() => _VerticalResizeHandleState();
}

class _VerticalResizeHandleState extends State<_VerticalResizeHandle> {
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (_) => setState(() => _dragging = true),
      onVerticalDragUpdate: (d) => widget.onDrag(d.delta.dy),
      onVerticalDragEnd: (_) => setState(() => _dragging = false),
      child: Container(
        height: 18,
        color: _dragging ? AppColors.pinkPale : Colors.transparent,
        alignment: Alignment.center,
        child: Container(
          width: 36,
          height: 3,
          decoration: BoxDecoration(
            color: _dragging
                ? AppColors.pinkDeep
                : AppColors.pinkMid.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

// ── Text content ──────────────────────────────────────────────────────────────

class _TextContent extends StatelessWidget {
  const _TextContent({required this.block, required this.censored, this.height});
  final _BuilderTextBlock block;
  final bool censored;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);
    final field = TextField(
      controller: block.ctrl,
      maxLines: null,
      minLines: 2,
      style: TextStyle(
        fontFamily: block.fontFamily ?? AppTextStyles.fontFamily,
        fontWeight: _fontWeightFromInt(block.fontWeight),
        fontSize: block.fontSize,
        color: censored ? t.textMuted : t.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: 'Write something…',
        hintStyle: TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          fontSize: 12,
          color: t.textFaint,
        ),
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
    );

    final content = !censored
        ? field
        : Stack(
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: field,
        ),
        Positioned.fill(
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.all(8),
            child: Text('content hidden',
                style: AppTextStyles.sectionLabel
                    .copyWith(color: AppColors.pinkMid, fontSize: 9)),
          ),
        ),
      ],
    );
    return height != null
        ? SizedBox(height: height, child: content)
        : content;
  }
}

// ── Image content ─────────────────────────────────────────────────────────────

class _ImageContent extends StatelessWidget {
  const _ImageContent({required this.block, required this.censored, this.height});
  final _BuilderImageBlock block;
  final bool censored;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);

    // Title field
    final titleField = TextField(
      controller: block.titleCtrl,
      maxLines: 1,
      style: TextStyle(
        fontFamily: block.titleFontFamily ?? AppTextStyles.fontFamily,
        fontWeight: _fontWeightFromInt(block.titleFontWeight),
        fontSize: block.titleFontSize,
        color: t.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: 'Add a title…',
        hintStyle: TextStyle(
            fontFamily: AppTextStyles.fontFamily,
            fontSize: 11,
            color: t.textFaint),
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        isDense: true,
        contentPadding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      ),
    );

    final imgWidget = Image.asset(
      block.path,
      width: double.infinity,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Container(
        height: height ?? 80,
        color: t.surfaceCream,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_rounded,
                color: AppColors.pinkMid, size: 22),
            SizedBox(height: 4),
            Text('Tap to pick',
                style: TextStyle(
                  fontFamily: AppTextStyles.fontFamily,
                  fontSize: 9,
                  color: AppColors.pinkMid,
                )),
          ],
        ),
      ),
    );

    final img = ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(AppRadius.sm),
        bottomRight: Radius.circular(AppRadius.sm),
      ),
      child: imgWidget,
    );

    if (!censored) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [titleField, img],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        titleField,
        Stack(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(AppRadius.sm),
                bottomRight: Radius.circular(AppRadius.sm),
              ),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10, tileMode: TileMode.decal),
                child: img,
              ),
            ),
            const Positioned.fill(
              child: Center(
                child: Icon(Icons.lock_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Video builder content ─────────────────────────────────────────────────────

class _VideoBuilderContent extends StatefulWidget {
  const _VideoBuilderContent({
    required this.block,
    required this.censored,
    required this.onUpdated,
  });
  final _BuilderVideoBlock block;
  final bool censored;
  final VoidCallback onUpdated;

  @override
  State<_VideoBuilderContent> createState() => _VideoBuilderContentState();
}

class _VideoBuilderContentState extends State<_VideoBuilderContent> {
  bool _picking = false;

  Future<void> _pickVideo() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final picker = ImagePicker();
      final file = await picker.pickVideo(source: ImageSource.gallery);
      if (file != null) {
        widget.block.path = file.path;
        widget.onUpdated();
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);
    final h = widget.block.height ?? 160.0;
    final hasVideo = widget.block.path.isNotEmpty &&
        File(widget.block.path).existsSync();

    Widget content;
    if (hasVideo) {
      content = Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: h,
            color: t.surfaceBlue,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.videocam_rounded, size: 28, color: Colors.white54),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      widget.block.path.split('/').last,
                      style: AppTextStyles.sectionLabel.copyWith(
                        color: t.textFaint, fontSize: 8,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 6, right: 6,
            child: GestureDetector(
              onTap: _pickVideo,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: AppRadius.chip,
                ),
                child: Text(
                  'Change',
                  style: AppTextStyles.sectionLabel.copyWith(
                    color: Colors.white, fontSize: 8,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      content = GestureDetector(
        onTap: _pickVideo,
        child: Container(
          height: h,
          color: t.surfaceBlush,
          child: Center(
            child: _picking
                ? const CircularProgressIndicator(
                    color: AppColors.pinkMid, strokeWidth: 2)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.videocam_rounded,
                          size: 28, color: AppColors.pinkMid),
                      const SizedBox(height: 6),
                      Text(
                        'Tap to pick video',
                        style: AppTextStyles.sectionLabel
                            .copyWith(color: AppColors.pinkMid),
                      ),
                    ],
                  ),
          ),
        ),
      );
    }

    if (widget.censored) {
      content = Stack(
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(
                sigmaX: 10, sigmaY: 10, tileMode: TileMode.decal),
            child: content,
          ),
          const Positioned.fill(
            child: Center(
              child: Icon(Icons.lock_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      );
    }

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(AppRadius.sm),
        bottomRight: Radius.circular(AppRadius.sm),
      ),
      child: SizedBox(height: h, child: content),
    );
  }
}

// ── Triple-tap detector ───────────────────────────────────────────────────────

class _TripleTapDetector extends StatefulWidget {
  const _TripleTapDetector({
    required this.onTripleTap,
    required this.child,
  });

  final VoidCallback onTripleTap;
  final Widget child;

  @override
  State<_TripleTapDetector> createState() => _TripleTapDetectorState();
}

class _TripleTapDetectorState extends State<_TripleTapDetector> {
  int _count = 0;
  DateTime? _lastTap;

  void _onTap() {
    final now = DateTime.now();
    if (_lastTap != null &&
        now.difference(_lastTap!).inMilliseconds > 700) {
      _count = 0;
    }
    _lastTap = now;
    _count++;
    if (_count >= 3) {
      _count = 0;
      _lastTap = null;
      widget.onTripleTap();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      behavior: HitTestBehavior.opaque,
      child: widget.child,
    );
  }
}

// ── Placed sticker widget ─────────────────────────────────────────────────────

class _PlacedStickerWidget extends StatefulWidget {
  const _PlacedStickerWidget({
    required this.placement,
    required this.onMoved,
    required this.onRemoved,
  });
  final _StickerPlacement placement;
  final void Function(Offset) onMoved;
  final VoidCallback onRemoved;

  @override
  State<_PlacedStickerWidget> createState() => _PlacedStickerWidgetState();
}

class _PlacedStickerWidgetState extends State<_PlacedStickerWidget> {
  bool _showDelete = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.placement;
    return Positioned(
      left: s.position.dx,
      top: s.position.dy,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _showDelete = !_showDelete),
        onPanUpdate: (d) => widget.onMoved(s.position + d.delta),
        onPanEnd: (_) => setState(() => _showDelete = false),
        child: SizedBox(
          width: s.size,
          height: s.size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Image.asset(s.path, width: s.size, height: s.size, fit: BoxFit.contain),
              if (_showDelete)
                Positioned(
                  top: -8,
                  right: -8,
                  child: GestureDetector(
                    onTap: widget.onRemoved,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: AppColors.pinkDeep,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sticker tray ──────────────────────────────────────────────────────────────

class _StickerTray extends StatelessWidget {
  const _StickerTray({
    required this.open,
    required this.onClose,
    required this.onDragStarted,
  });
  final bool open;
  final VoidCallback onClose;
  final VoidCallback onDragStarted;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      bottom: open ? 0 : -190,
      left: 0,
      right: 0,
      child: Container(
        height: 190,
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          border: Border(top: BorderSide(color: t.border)),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          children: [
            GestureDetector(
              onTap: onClose,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Container(
                  width: 36,
                  height: 3,
                  decoration: BoxDecoration(
                    color: t.textFaint,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            Text('Hamster Stickers', style: AppTextStyles.sectionLabel.copyWith(fontSize: 10)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _kHamsterStickers.length,
                itemBuilder: (_, i) {
                  final path = _kHamsterStickers[i];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: LongPressDraggable<String>(
                      data: 'sticker:$path',
                      delay: const Duration(milliseconds: 80),
                      onDragStarted: onDragStarted,
                      feedback: Material(
                        color: Colors.transparent,
                        child: Image.asset(path, width: 72, height: 72, fit: BoxFit.contain),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.3,
                        child: Image.asset(path, width: 56, height: 56, fit: BoxFit.contain),
                      ),
                      child: Image.asset(path, width: 56, height: 56, fit: BoxFit.contain),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// ── Move button ───────────────────────────────────────────────────────────────

class _MoveBtn extends StatelessWidget {
  const _MoveBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: enabled ? t.surfaceBlush : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: enabled ? t.border : Colors.transparent,
          ),
        ),
        child: Icon(icon,
            size: 11,
            color: enabled ? t.textMuted : t.textFaint),
      ),
    );
  }
}

// ── Input field helper ────────────────────────────────────────────────────────

class _SheetInputField extends StatelessWidget {
  const _SheetInputField({required this.ctrl, required this.hint});
  final TextEditingController ctrl;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);
    return TextField(
      controller: ctrl,
      maxLines: 1,
      style: TextStyle(
        fontFamily: AppTextStyles.fontFamily,
        fontSize: 13,
        color: t.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
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
          borderSide: const BorderSide(color: AppColors.pinkMid, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        hintStyle: AppTextStyles.inputHint,
      ),
    );
  }
}

// ── Custom painters ───────────────────────────────────────────────────────────

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.radius,
  });
  final Color color;
  final double strokeWidth;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    final rRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(strokeWidth / 2, strokeWidth / 2,
          size.width - strokeWidth, size.height - strokeWidth),
      Radius.circular(radius),
    );
    const dashLen = 5.0;
    const gapLen = 4.0;
    final path = Path()..addRRect(rRect);
    for (final m in path.computeMetrics()) {
      double dist = 0;
      bool draw = true;
      while (dist < m.length) {
        final len = draw ? dashLen : gapLen;
        if (draw) canvas.drawPath(m.extractPath(dist, dist + len), paint);
        dist += len;
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 1;
    const dashCount = 12;
    const dashAngle = (2 * 3.14159) / dashCount;
    const gapFraction = 0.4;
    for (int i = 0; i < dashCount; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * dashAngle,
        dashAngle * (1 - gapFraction),
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Cover Hero ────────────────────────────────────────────────────────────────

class _CoverHero extends StatelessWidget {
  const _CoverHero({
    required this.imagePath,
    required this.background,
    required this.gradientCard,
    required this.primaryLight,
    required this.textMuted,
  });
  final String? imagePath;
  final Color background;
  final LinearGradient gradientCard;
  final Color primaryLight;
  final Color textMuted;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (imagePath != null && File(imagePath!).existsSync())
          Image.file(File(imagePath!), fit: BoxFit.cover)
        else
          Container(
            decoration: BoxDecoration(gradient: gradientCard),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.photo_camera_rounded, size: 28, color: primaryLight),
                  const SizedBox(height: 6),
                  Text(
                    'Long-press to set cover photo',
                    style: TextStyle(
                      fontFamily: AppTextStyles.fontFamily,
                      fontSize: 10,
                      color: textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, background.withValues(alpha: 0.75)],
                stops: const [0.45, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Timeline Search Bar ───────────────────────────────────────────────────────

class _TimelineSearchBar extends StatelessWidget {
  const _TimelineSearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClose,
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            autofocus: true,
            style: TextStyle(
              fontFamily: AppTextStyles.fontFamily,
              fontSize: 13,
              color: t.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Search memories…',
              hintStyle: AppTextStyles.inputHint,
              prefixIcon: Icon(Icons.search_rounded, size: 16, color: t.textMuted),
              prefixIconConstraints: const BoxConstraints(minWidth: 36),
              filled: true,
              fillColor: t.surfaceMain,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
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
                borderSide: BorderSide(color: t.primaryMid, width: 1.5),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onClose,
          child: Icon(Icons.close_rounded, size: 18, color: t.textMuted),
        ),
      ],
    );
  }
}

// ── Year Carousel ─────────────────────────────────────────────────────────────

class _YearCarousel extends StatelessWidget {
  const _YearCarousel({
    required this.years,
    required this.selected,
    required this.onSelect,
  });
  final List<int> years;
  final int? selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);
    return SizedBox(
      height: 28,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: years.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final year = years[i];
          final active = year == selected;
          return GestureDetector(
            onTap: () => onSelect(year),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: active ? t.primary : t.surfaceCream,
                borderRadius: AppRadius.chip,
                border: Border.all(color: active ? t.primary : t.borderCream),
              ),
              child: Text(
                year.toString(),
                style: AppTextStyles.widgetSince.copyWith(
                  color: active ? Colors.white : t.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Tag Filter Bar ────────────────────────────────────────────────────────────

class _TagFilterBar extends StatelessWidget {
  const _TagFilterBar({
    required this.tags,
    required this.selected,
    required this.onSelect,
  });
  final List<String> tags;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);
    return SizedBox(
      height: 28,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tags.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final tag = tags[i];
          final active = tag == selected;
          return GestureDetector(
            onTap: () => onSelect(tag),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: active ? t.primaryPale : t.surface,
                borderRadius: AppRadius.chip,
                border: Border.all(color: active ? t.primaryMid : t.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '# ',
                    style: TextStyle(
                      fontFamily: AppTextStyles.fontFamily,
                      fontSize: 9,
                      color: active ? t.primary : t.textFaint,
                    ),
                  ),
                  Text(
                    tag,
                    style: TextStyle(
                      fontFamily: AppTextStyles.fontFamily,
                      fontSize: 10,
                      color: active ? t.primary : t.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Tag Input Row (used in New Event form) ────────────────────────────────────

class _TagInputRow extends StatelessWidget {
  const _TagInputRow({
    required this.tags,
    required this.controller,
    required this.onAdd,
    required this.onRemove,
  });
  final List<String> tags;
  final TextEditingController controller;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ...tags.map((tag) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: t.primaryPale,
            borderRadius: AppRadius.chip,
            border: Border.all(color: t.primaryMid),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '# $tag',
                style: TextStyle(
                  fontFamily: AppTextStyles.fontFamily,
                  fontSize: 10,
                  color: t.primary,
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => onRemove(tag),
                child: Icon(Icons.close_rounded, size: 12, color: t.primary),
              ),
            ],
          ),
        )),
        SizedBox(
          width: 100,
          height: 28,
          child: TextField(
            controller: controller,
            onSubmitted: onAdd,
            style: TextStyle(
              fontFamily: AppTextStyles.fontFamily,
              fontSize: 11,
              color: t.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'add tag…',
              hintStyle: AppTextStyles.inputHint.copyWith(fontSize: 10),
              filled: true,
              fillColor: t.surfaceBlush,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              border: OutlineInputBorder(
                borderRadius: AppRadius.chip,
                borderSide: BorderSide(color: t.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.chip,
                borderSide: BorderSide(color: t.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.chip,
                borderSide: BorderSide(color: t.primaryMid, width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Event Context Menu Sheet ──────────────────────────────────────────────────

class _EventContextSheet extends StatelessWidget {
  const _EventContextSheet({
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
    required this.onColor,
  });
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final VoidCallback onColor;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);
    final items = [
      (Icons.edit_rounded, 'Edit', t.textPrimary, onEdit),
      (Icons.copy_rounded, 'Duplicate', t.textPrimary, onDuplicate),
      (Icons.palette_rounded, 'Change color', t.textPrimary, onColor),
      (Icons.delete_outline_rounded, 'Delete', Colors.redAccent, onDelete),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: t.border,
              borderRadius: AppRadius.chip,
            ),
          ),
          ...items.map((item) => ListTile(
            dense: true,
            leading: Icon(item.$1, size: 20, color: item.$3),
            title: Text(
              item.$2,
              style: TextStyle(
                fontFamily: AppTextStyles.fontFamily,
                fontSize: 13,
                color: item.$3,
              ),
            ),
            onTap: item.$4,
          )),
        ],
      ),
    );
  }
}

// ── Timeline cache ────────────────────────────────────────────────────────────

class _TimelineCache {
  static const _key = 'timeline_events_v1';

  static Future<List<_Event>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => _Event.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<_Event> events) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(events.map((e) => e.toJson()).toList());
    await prefs.setString(_key, encoded);
  }

  // ignore: unused_element
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
