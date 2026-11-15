import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_theme_notifier.dart';
import '../design_tokens.dart';
import '../services/message_cache.dart';

// ── Shared prefs keys ─────────────────────────────────────────────────────────
const kCustomQuotesKey = 'custom_quotes';
const kYourNameKey     = 'your_name';
const kPartnerNameKey  = 'partner_name';
const kCouplePicKey    = 'couple_photo';
const kServerUrlKey    = 'server_url';

// ── Page ──────────────────────────────────────────────────────────────────────

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Us
  DateTime _startDate = DateUtils.dateOnly(DateTime.now());
  String   _yourName     = '';
  String   _partnerName  = '';
  String?  _couplePicPath;

  // Data
  String _serverUrl = '';

  // Quotes
  final _quoteCtrl = TextEditingController();
  List<String> _customQuotes = [];

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final startRaw = prefs.getString('relationship_start');
    final quotesRaw = prefs.getString(kCustomQuotesKey);
    setState(() {
      if (startRaw != null) _startDate = DateTime.parse(startRaw);
      _yourName    = prefs.getString(kYourNameKey)    ?? '';
      _partnerName = prefs.getString(kPartnerNameKey) ?? '';
      _couplePicPath = prefs.getString(kCouplePicKey);
      _serverUrl   = prefs.getString(kServerUrlKey)   ?? '';
      _customQuotes = quotesRaw != null
          ? List<String>.from(jsonDecode(quotesRaw) as List)
          : [];
      _loading = false;
    });
  }

  // ── Quotes ──────────────────────────────────────────────────────────────────

  Future<void> _persistQuotes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kCustomQuotesKey, jsonEncode(_customQuotes));
  }

  void _addQuote() {
    final text = _quoteCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _customQuotes.insert(0, text));
    _quoteCtrl.clear();
    _persistQuotes();
  }

  void _deleteQuote(int i) {
    setState(() => _customQuotes.removeAt(i));
    _persistQuotes();
  }

  // ── Us ───────────────────────────────────────────────────────────────────────

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('relationship_start', picked.toIso8601String());
      setState(() => _startDate = picked);
    }
  }

  Future<void> _pickCouplePic() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null && mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kCouplePicKey, picked.path);
      setState(() => _couplePicPath = picked.path);
    }
  }

  // ── Generic text editor ───────────────────────────────────────────────────

  Future<void> _editText(
    String title,
    String current,
    String prefsKey,
    void Function(String) onSave,
  ) async {
    final ctrl = TextEditingController(text: current);
    final t = AppThemeScope.of(context);
    final result = await showDialog<String>(
      context: context,
      barrierColor: AppColors.pinkDeep.withValues(alpha: 0.15),
      builder: (ctx) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
        title: Text(title,
            style: AppTextStyles.cardTitle.copyWith(color: t.textPrimary)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(
              fontFamily: AppTextStyles.fontFamily,
              fontSize: 13,
              color: t.textPrimary),
          decoration: InputDecoration(
            hintText: 'Enter $title…',
            hintStyle: AppTextStyles.inputHint,
            filled: true,
            fillColor: t.surfaceBlush,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            border: OutlineInputBorder(
                borderRadius: AppRadius.inputField,
                borderSide: BorderSide(color: t.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.inputField,
                borderSide: BorderSide(color: t.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.inputField,
                borderSide: BorderSide(color: t.primaryMid, width: 1.5)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(
                    color: t.textMuted,
                    fontFamily: AppTextStyles.fontFamily,
                    fontSize: 12)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text('Save',
                style: TextStyle(
                    color: t.primary,
                    fontFamily: AppTextStyles.fontFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsKey, result);
      onSave(result);
    }
  }

  // ── Data actions ──────────────────────────────────────────────────────────

  Future<void> _confirmClearChat() async {
    if (!await _confirm('Clear chat history',
        'This will delete all messages. This cannot be undone.')) {
      return;
    }
    await MessageCache.clear();
    if (mounted) { _snack('Chat history cleared'); }
  }

  Future<void> _confirmClearTimeline() async {
    if (!await _confirm('Clear timeline',
        'This will delete all timeline events. This cannot be undone.')) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('timeline_events_v1');
    if (mounted) { _snack('Timeline cleared'); }
  }

  Future<bool> _confirm(String title, String body) async {
    final t = AppThemeScope.of(context);
    return await showDialog<bool>(
          context: context,
          barrierColor: AppColors.pinkDeep.withValues(alpha: 0.15),
          builder: (ctx) => AlertDialog(
            backgroundColor: t.surface,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
            title: Text(title,
                style: AppTextStyles.cardTitle.copyWith(color: t.textPrimary)),
            content: Text(body, style: AppTextStyles.cardDesc),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel',
                    style: TextStyle(
                        color: t.textMuted,
                        fontFamily: AppTextStyles.fontFamily,
                        fontSize: 12)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Delete',
                    style: TextStyle(
                        color: Colors.red.shade400,
                        fontFamily: AppTextStyles.fontFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _snack(String msg) {
    final t = AppThemeScope.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: TextStyle(
              fontFamily: AppTextStyles.fontFamily,
              fontSize: 12,
              color: t.textPrimary)),
      backgroundColor: t.surface,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: AppRadius.card, side: BorderSide(color: t.border)),
    ));
  }

  @override
  void dispose() {
    _quoteCtrl.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);
    return Scaffold(
      backgroundColor: t.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              decoration: BoxDecoration(
                color: t.surface,
                border:
                    Border(bottom: BorderSide(color: t.border, width: 1)),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: t.primaryPale,
                        shape: BoxShape.circle,
                        border: Border.fromBorderSide(
                            BorderSide(color: t.border)),
                      ),
                      child: Icon(Icons.arrow_back_rounded,
                          size: 16, color: t.textMuted),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('Settings', style: AppTextStyles.pageTitle),
                ],
              ),
            ),
            // Body
            Expanded(
              child: _loading
                  ? Center(
                      child: CircularProgressIndicator(
                          color: t.primaryMid, strokeWidth: 2))
                  : ListView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 20),
                      children: [
                        _buildUsSection(t),
                        const SizedBox(height: 20),
                        _buildAppearanceSection(t),
                        const SizedBox(height: 20),
                        _buildQuotesSection(t),
                        const SizedBox(height: 20),
                        _buildDataSection(t),
                        const SizedBox(height: 40),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section builders ──────────────────────────────────────────────────────

  Widget _buildUsSection(AppThemeData t) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec',
    ];
    final dateLabel =
        '${_startDate.day} ${months[_startDate.month - 1]} ${_startDate.year}';

    return _SettingsSection(
      label: 'US',
      children: [
        _SettingsTile(
          title: 'Relationship start',
          value: dateLabel,
          icon: Icons.calendar_today_rounded,
          onTap: _pickStartDate,
          showChevron: true,
        ),
        const _SettingsDivider(),
        _SettingsTile(
          title: 'Your name',
          value: _yourName.isEmpty ? 'Not set' : _yourName,
          icon: Icons.person_rounded,
          onTap: () => _editText('Your name', _yourName, kYourNameKey,
              (v) => setState(() => _yourName = v)),
          showChevron: true,
        ),
        const _SettingsDivider(),
        _SettingsTile(
          title: "Partner's name",
          value: _partnerName.isEmpty ? 'Not set' : _partnerName,
          icon: Icons.favorite_rounded,
          onTap: () => _editText(
              "Partner's name", _partnerName, kPartnerNameKey,
              (v) => setState(() => _partnerName = v)),
          showChevron: true,
        ),
        const _SettingsDivider(),
        _CouplePicTile(picPath: _couplePicPath, onTap: _pickCouplePic),
      ],
    );
  }

  Widget _buildAppearanceSection(AppThemeData t) {
    return _SettingsSection(
      label: 'APPEARANCE',
      children: [
        _SettingsSwitchTile(
          title: 'Dark mode',
          icon: Icons.dark_mode_rounded,
          value: t.isDark,
          onChanged: (v) => themeDarkMode.value = v,
        ),
        const _SettingsDivider(),
        _SettingsSwitchTile(
          title: 'Theme',
          subtitle: t.isHers ? 'Her side — pink' : 'His side — blue',
          icon: Icons.palette_rounded,
          value: t.isHers,
          onChanged: (v) => themeIsHers.value = v,
        ),
      ],
    );
  }

  Widget _buildQuotesSection(AppThemeData t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('DAILY QUOTES', style: AppTextStyles.sectionLabel),
        const SizedBox(height: 6),
        Text(
          'Add personal quotes that appear alongside the built-in ones in your daily card.',
          style: AppTextStyles.cardDesc,
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _quoteCtrl,
                maxLines: 3,
                minLines: 1,
                style: TextStyle(
                    fontFamily: AppTextStyles.fontFamily,
                    fontSize: 13,
                    color: t.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Write a quote…',
                  hintStyle: AppTextStyles.inputHint,
                  filled: true,
                  fillColor: t.surfaceBlush,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: AppRadius.inputField,
                      borderSide: BorderSide(color: t.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: AppRadius.inputField,
                      borderSide: BorderSide(color: t.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: AppRadius.inputField,
                      borderSide:
                          BorderSide(color: t.primaryMid, width: 1.5)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _addQuote,
              child: Container(
                width: 36,
                height: 36,
                decoration:
                    BoxDecoration(color: t.primary, shape: BoxShape.circle),
                child: const Icon(Icons.add_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_customQuotes.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('No custom quotes yet',
                  style:
                      AppTextStyles.cardDesc.copyWith(color: t.textFaint)),
            ),
          )
        else
          ...List.generate(
            _customQuotes.length,
            (i) => _QuoteItem(
                text: _customQuotes[i], onDelete: () => _deleteQuote(i)),
          ),
      ],
    );
  }

  Widget _buildDataSection(AppThemeData t) {
    return _SettingsSection(
      label: 'DATA',
      children: [
        _SettingsTile(
          title: 'Server URL',
          value: _serverUrl.isEmpty ? 'Not configured' : _serverUrl,
          icon: Icons.dns_rounded,
          onTap: () => _editText(
              'Server URL', _serverUrl, kServerUrlKey,
              (v) => setState(() => _serverUrl = v)),
          showChevron: true,
        ),
        const _SettingsDivider(),
        _SettingsTile(
          title: 'Clear chat history',
          icon: Icons.chat_bubble_outline_rounded,
          danger: true,
          onTap: _confirmClearChat,
        ),
        const _SettingsDivider(),
        _SettingsTile(
          title: 'Clear timeline events',
          icon: Icons.auto_stories_outlined,
          danger: true,
          onTap: _confirmClearTimeline,
        ),
      ],
    );
  }
}

// ── Section wrapper ───────────────────────────────────────────────────────────

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.label, required this.children});
  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.sectionLabel),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            gradient: t.gradientCard,
            borderRadius: AppRadius.card,
            border: Border.all(color: t.border),
            boxShadow: AppShadows.card,
          ),
          child: ClipRRect(
            borderRadius: AppRadius.card,
            child: Column(children: children),
          ),
        ),
      ],
    );
  }
}

// ── Value tile ────────────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.title,
    this.value,
    required this.icon,
    this.onTap,
    this.showChevron = false,
    this.danger = false,
  });
  final String title;
  final String? value;
  final IconData icon;
  final VoidCallback? onTap;
  final bool showChevron;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);
    final titleColor = danger ? Colors.red.shade400 : t.textPrimary;
    final iconColor  = danger ? Colors.red.shade300 : t.primaryMid;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 17, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTextStyles.cardTitle
                          .copyWith(color: titleColor, fontSize: 13)),
                  if (value != null) ...[
                    const SizedBox(height: 2),
                    Text(value!,
                        style: AppTextStyles.cardDesc,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1),
                  ],
                ],
              ),
            ),
            if (showChevron)
              Icon(Icons.chevron_right_rounded, size: 18, color: t.textFaint),
          ],
        ),
      ),
    );
  }
}

// ── Switch tile ───────────────────────────────────────────────────────────────

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });
  final String title;
  final String? subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 17, color: t.primaryMid),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTextStyles.cardTitle
                        .copyWith(color: t.textPrimary, fontSize: 13)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: AppTextStyles.cardDesc),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: t.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

// ── Couple photo tile ─────────────────────────────────────────────────────────

class _CouplePicTile extends StatelessWidget {
  const _CouplePicTile({this.picPath, required this.onTap});
  final String? picPath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);
    final hasPhoto =
        picPath != null && picPath!.isNotEmpty && File(picPath!).existsSync();
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.photo_camera_rounded, size: 17, color: t.primaryMid),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Couple photo',
                  style: AppTextStyles.cardTitle
                      .copyWith(color: t.textPrimary, fontSize: 13)),
            ),
            if (hasPhoto)
              ClipRRect(
                borderRadius: AppRadius.card,
                child: Image.file(File(picPath!),
                    width: 44, height: 44, fit: BoxFit.cover),
              )
            else
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: t.surfaceBlush,
                  borderRadius: AppRadius.card,
                  border: Border.all(color: t.border),
                ),
                child: Icon(Icons.add_photo_alternate_rounded,
                    size: 20, color: t.textFaint),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Divider ───────────────────────────────────────────────────────────────────

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
        height: 1,
        thickness: 1,
        color: AppThemeScope.of(context).border,
        indent: 16,
        endIndent: 16);
  }
}

// ── Quote item ────────────────────────────────────────────────────────────────

class _QuoteItem extends StatelessWidget {
  const _QuoteItem({required this.text, required this.onDelete});
  final String text;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        gradient: t.gradientCard,
        borderRadius: AppRadius.card,
        border: Border.all(color: t.border),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('♡',
              style: TextStyle(fontSize: 13, color: t.primaryLight)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Aktura',
                fontSize: 13,
                fontStyle: FontStyle.italic,
                height: 1.45,
              ).copyWith(color: t.textPrimary),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onDelete,
            child: Icon(Icons.close_rounded, size: 16, color: t.textFaint),
          ),
        ],
      ),
    );
  }
}
