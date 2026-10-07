import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/accounts/account_controller.dart';
import '../../../core/models/app_failure.dart';
import '../../scanner/presentation/ui_components.dart';
import '../data/device_profile_preferences.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    required this.controller,
    required this.onContinue,
    this.onAppearance,
    this.onAbout,
    this.onSaved,
    this.onScans,
    this.onCompare,
    this.themeMode,
    this.onThemeModeChanged,
    this.showHeader = true,
    this.embedded = false,
    super.key,
  });
  final AccountController controller;
  final VoidCallback onContinue;
  final VoidCallback? onAppearance, onAbout, onSaved, onScans, onCompare;
  final ThemeMode? themeMode;
  final ValueChanged<ThemeMode>? onThemeModeChanged;
  final bool embedded, showHeader;

  static Future<void> showSignIn(
    BuildContext context,
    AccountController controller, {
    bool create = false,
  }) => showDialog<void>(
    context: context,
    builder: (_) =>
        _LoginDialog(controller: controller, initiallyCreate: create),
  );

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  AccountController get controller => widget.controller;
  DeviceProfilePreferencesStore get _preferencesStore =>
      DeviceProfilePreferencesStore(controller.guestStore.preferences);
  DeviceProfilePreferences _preferences = const DeviceProfilePreferences();
  int? _scans, _saved;
  String? _preferenceError;
  bool _preferencesBusy = false;
  int _statsGeneration = 0;
  String? _statsUid;

  @override
  void initState() {
    super.initState();
    _statsUid = controller.identity?.uid;
    controller.addListener(_accountChanged);
    unawaited(_loadPreferences());
    unawaited(_refreshStats());
  }

  @override
  void didUpdateWidget(ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != controller) {
      oldWidget.controller.removeListener(_accountChanged);
      controller.addListener(_accountChanged);
      _statsUid = controller.identity?.uid;
      _scans = null;
      _saved = null;
      unawaited(_loadPreferences());
      unawaited(_refreshStats());
    }
  }

  @override
  void dispose() {
    controller.removeListener(_accountChanged);
    super.dispose();
  }

  void _accountChanged() {
    if (!mounted) return;
    setState(() {
      if (_statsUid != controller.identity?.uid) {
        _statsUid = controller.identity?.uid;
        _scans = null;
        _saved = null;
      }
    });
    unawaited(_refreshStats());
  }

  Future<void> _refreshStats() async {
    final generation = ++_statsGeneration;
    final store = controller.activeStore;
    try {
      final counts = await Future.wait([store.history(), store.saved()]);
      if (mounted &&
          generation == _statsGeneration &&
          identical(store, controller.activeStore)) {
        setState(() {
          _scans = counts[0].length;
          _saved = counts[1].length;
        });
      }
    } catch (_) {
      if (mounted && generation == _statsGeneration) {
        setState(() {
          _scans = null;
          _saved = null;
        });
      }
    }
  }

  Future<void> _loadPreferences() async {
    try {
      final preferences = await _preferencesStore.read();
      if (mounted) {
        setState(() {
          _preferences = preferences;
          _preferenceError = null;
        });
      }
    } on AppFailure catch (error) {
      if (mounted) setState(() => _preferenceError = error.userMessage);
    }
  }

  Future<void> _savePreferences(DeviceProfilePreferences preferences) async {
    if (_preferencesBusy) return;
    setState(() => _preferencesBusy = true);
    await _run(context, () async {
      await _preferencesStore.write(preferences);
      if (mounted) {
        setState(() {
          _preferences = preferences;
          _preferenceError = null;
        });
      }
    });
    if (mounted) setState(() => _preferencesBusy = false);
  }

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } on AppFailure catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.userMessage)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('That change could not finish. Please try again.'),
          ),
        );
      }
    }
  }

  Future<bool> _confirm(
    BuildContext context,
    String title,
    String text,
    String action,
  ) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _name() async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) =>
          _NameDialog(initialName: controller.localData?.displayName ?? ''),
    );
    if (value != null && mounted) {
      await _run(context, () => controller.updateDisplayName(value));
    }
  }

  Future<void> _choosePreferences({bool allergensOnly = false}) async {
    final preferences = await showDialog<DeviceProfilePreferences>(
      context: context,
      builder: (_) => _PreferencesDialog(
        preferences: _preferences,
        allergensOnly: allergensOnly,
      ),
    );
    if (preferences != null && mounted) await _savePreferences(preferences);
  }

  Future<void> _information(
    String title,
    String message, {
    bool showAbout = false,
  }) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        if (showAbout && widget.onAbout != null)
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onAbout!();
            },
            child: const Text('About Unlabel'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );

  Future<void> _privacy() => showDialog<void>(
    context: context,
    builder: (dialogContext) => AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final signedIn = controller.identity != null;
        final pending =
            controller.state == AccountSyncState.checking ||
            controller.state == AccountSyncState.syncing;
        return AlertDialog(
          title: const Text('Privacy & account data'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Guest history stays on this device. Signed-in history, saved reports and your display name sync privately. Photos, raw label text and personal reminders stay outside account sync.',
                  ),
                  const SizedBox(height: 20),
                  if (signedIn) ...[
                    Text(
                      'Private sync',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Semantics(
                      liveRegion: true,
                      child: Text(controller.message),
                    ),
                    if (pending) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                    ],
                    const SizedBox(height: 16),
                    if (controller.state == AccountSyncState.needsChoice) ...[
                      FilledButton(
                        onPressed: () async {
                          if (await _confirm(
                                context,
                                'Use the cloud library?',
                                'This replaces this account’s device library with its cloud version. Guest reports stay separate.',
                                'Use cloud',
                              ) &&
                              context.mounted) {
                            await _run(context, controller.useCloud);
                          }
                        },
                        child: const Text('Use cloud library'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () async {
                          if (await _confirm(
                                context,
                                'Use this device library?',
                                'This replaces your account’s cloud library with this device’s account data. Other devices will need to check sync again.',
                                'Use device',
                              ) &&
                              context.mounted) {
                            await _run(context, controller.useDevice);
                          }
                        },
                        child: const Text('Use this device library'),
                      ),
                    ] else ...[
                      FilledButton.icon(
                        onPressed: pending
                            ? null
                            : () => _run(context, controller.refreshSync),
                        icon: const Icon(Icons.sync_rounded),
                        label: const Text('Check sync'),
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: pending
                          ? null
                          : () async {
                              if (await _confirm(
                                    context,
                                    'Copy guest reports?',
                                    'Copy guest saved products and history into an empty account library and sync them privately. Guest copies remain on this device.',
                                    'Copy reports',
                                  ) &&
                                  context.mounted) {
                                await _run(
                                  context,
                                  controller.copyGuestLibrary,
                                );
                              }
                            },
                      child: const Text('Copy this device’s guest reports'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: pending
                          ? null
                          : () async {
                              if (await _confirm(
                                    context,
                                    'Clear account data?',
                                    'Remove this account’s display name, saved products and history from this device and sync the empty library. Guest reports and public package facts stay separate. If sync fails, deletion remains pending.',
                                    'Clear account data',
                                  ) &&
                                  context.mounted) {
                                await _run(
                                  context,
                                  controller.clearAccountLibrary,
                                );
                              }
                            },
                      child: const Text('Clear account data'),
                    ),
                  ] else ...[
                    Text(controller.message),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        );
      },
    ),
  );

  Future<void> _logout() async {
    if (await _confirm(
          context,
          'Sign out?',
          'Account reports remain in this account’s private device library. You’ll return to the separate guest library. Pending changes may still need syncing next time.',
          'Sign out',
        ) &&
        mounted) {
      await _run(context, controller.signOut);
    }
  }

  Color get _mint => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xff1d332b)
      : const Color(0xffe8faf2);

  Widget _card(Widget child, {bool botanical = false, double padding = 16}) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? theme.colorScheme.surfaceContainerLow
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: .5),
        ),
        boxShadow: theme.brightness == Brightness.dark
            ? const []
            : const [
                BoxShadow(
                  color: Color(0x080e6950),
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            if (botanical)
              Positioned(
                right: -20,
                bottom: -20,
                width: 140,
                height: 150,
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: Opacity(
                      opacity: .38,
                      child: Image.asset(
                        'assets/artwork/profile-botanical.png',
                        cacheWidth: 512,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            Padding(padding: EdgeInsets.all(padding), child: child),
          ],
        ),
      ),
    );
  }

  Widget _identity() {
    final theme = Theme.of(context);
    final signedIn = controller.identity != null;
    final displayName = controller.localData?.displayName?.trim();
    final name = signedIn
        ? ((displayName?.isNotEmpty ?? false)
              ? displayName!
              : 'Your Unlabel account')
        : 'Your guest profile';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _mint,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: .45),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned(
              right: -38,
              bottom: -32,
              width: 165,
              height: 200,
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: Opacity(
                    opacity: .5,
                    child: Image.asset(
                      'assets/artwork/profile-botanical.png',
                      cacheWidth: 512,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, box) {
                  final largeText =
                      MediaQuery.textScalerOf(context).scale(14) > 21;
                  final avatar = ExcludeSemantics(
                    child: Image.asset(
                      'assets/artwork/profile-avatar.png',
                      cacheWidth: 256,
                      width: largeText ? 72 : 88,
                      height: largeText ? 72 : 88,
                    ),
                  );
                  final details = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        signedIn
                            ? controller.identity!.email ?? 'Signed in'
                            : 'Saved on this device',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        softWrap: true,
                      ),
                      const SizedBox(height: 10),
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(48, 42),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          backgroundColor: theme.colorScheme.primaryContainer,
                          shape: const StadiumBorder(),
                        ),
                        onPressed: controller.authBusy
                            ? null
                            : signedIn
                            ? _name
                            : () => ProfilePage.showSignIn(context, controller),
                        icon: Icon(
                          signedIn ? Icons.edit_outlined : Icons.login_rounded,
                          size: 19,
                        ),
                        label: Text(signedIn ? 'Edit profile' : 'Sign in'),
                      ),
                    ],
                  );
                  if (largeText && box.maxWidth < 460) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [avatar, const SizedBox(height: 12), details],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      avatar,
                      const SizedBox(width: 14),
                      Expanded(child: details),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, Widget icon, VoidCallback? onTap) {
    final theme = Theme.of(context);
    return _card(
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: LayoutBuilder(
              builder: (context, box) {
                final vertical =
                    box.maxWidth < 75 ||
                    MediaQuery.textScalerOf(context).scale(12) > 17;
                final compact = box.maxWidth < 130;
                final image = Container(
                  width: compact ? 28 : 38,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _mint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(child: icon),
                );
                final caption = Text(
                  label,
                  maxLines: vertical ? null : 1,
                  semanticsLabel: label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: compact ? 10 : 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                );
                final text = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (vertical)
                      caption
                    else
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: caption,
                      ),
                    Text(
                      value,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                );
                return vertical
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [image, const SizedBox(height: 8), text],
                      )
                    : Row(
                        children: [
                          image,
                          SizedBox(width: compact ? 6 : 10),
                          Expanded(child: text),
                        ],
                      );
              },
            ),
          ),
        ),
      ),
      padding: 0,
    );
  }

  Widget _statistics() => LayoutBuilder(
    builder: (context, box) {
      final theme = Theme.of(context);
      // These are current library sizes, not lifetime totals. Comparisons were
      // never recorded by earlier releases, so do not invent a historical count.
      final tiles = [
        _stat(
          'Scans',
          _scans?.toString() ?? '—',
          FeatureIcon('barcode', size: 24, color: theme.colorScheme.onSurface),
          widget.onScans,
        ),
        _stat(
          'Saved',
          _saved?.toString() ?? '—',
          FeatureIcon('bookmark', size: 24, color: theme.colorScheme.onSurface),
          widget.onSaved,
        ),
        Tooltip(
          message: 'Comparison totals are not recorded on this device.',
          child: _stat(
            'Comparisons',
            '—',
            Icon(
              Icons.balance_outlined,
              size: 25,
              color: theme.colorScheme.onSurface,
            ),
            widget.onCompare,
          ),
        ),
      ];
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < tiles.length; index++) ...[
            if (index > 0) const SizedBox(width: 10),
            Expanded(child: tiles[index]),
          ],
        ],
      );
    },
  );

  Widget _sectionHeading(String text, IconData icon, {VoidCallback? onTap}) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 25),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }

  Widget _preferenceCard() => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading(
          'Preferences',
          Icons.eco_outlined,
          onTap: _preferencesBusy ? null : () => _choosePreferences(),
        ),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            _preferenceChip(
              'Low sugar',
              Icons.eco_outlined,
              _preferences.lowSugar,
              () => _savePreferences(
                _preferences.copyWith(lowSugar: !_preferences.lowSugar),
              ),
            ),
            _preferenceChip(
              'High fibre',
              Icons.grass_outlined,
              _preferences.highFibre,
              () => _savePreferences(
                _preferences.copyWith(highFibre: !_preferences.highFibre),
              ),
            ),
            _preferenceChip(
              'Veg',
              Icons.restaurant_outlined,
              _preferences.vegetarian,
              () => _savePreferences(
                _preferences.copyWith(vegetarian: !_preferences.vegetarian),
              ),
            ),
            for (final allergen in _preferences.allergens)
              ActionChip(
                avatar: const Icon(Icons.warning_amber_rounded, size: 17),
                label: Text(
                  '${DeviceProfilePreferences.allergenLabels[allergen]} alert',
                ),
                onPressed: _preferencesBusy
                    ? null
                    : () => _choosePreferences(allergensOnly: true),
              ),
          ],
        ),
        if (_preferenceError != null) ...[
          const SizedBox(height: 8),
          Text(_preferenceError!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    ),
  );

  Widget _preferenceChip(
    String label,
    IconData icon,
    bool selected,
    VoidCallback change,
  ) => FilterChip(
    label: Text(label),
    avatar: Icon(icon, size: 18),
    selected: selected,
    showCheckmark: true,
    onSelected: _preferencesBusy ? null : (_) => change(),
    backgroundColor: _mint,
    selectedColor: Theme.of(context).colorScheme.primaryContainer,
    side: selected
        ? BorderSide(color: Theme.of(context).colorScheme.primary)
        : BorderSide.none,
    shape: const StadiumBorder(),
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
  );

  Widget _setting(
    String label,
    IconData icon, {
    VoidCallback? onTap,
    Widget? trailing,
    bool danger = false,
    bool divider = true,
    String? subtitle,
  }) {
    final theme = Theme.of(context);
    final color = danger
        ? theme.colorScheme.error
        : theme.colorScheme.onSurface;
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: danger
                            ? theme.colorScheme.errorContainer.withValues(
                                alpha: .3,
                              )
                            : _mint,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 23, color: color),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontSize: 15,
                              color: color,
                              height: 1.2,
                            ),
                          ),
                          if (subtitle != null)
                            Text(subtitle, style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    trailing ??
                        Icon(
                          Icons.chevron_right,
                          color: theme.colorScheme.onSurfaceVariant,
                          size: 22,
                        ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (divider)
          Padding(
            padding: const EdgeInsets.only(left: 50),
            child: Divider(
              height: 1,
              thickness: 1,
              color: theme.colorScheme.outlineVariant.withValues(alpha: .5),
            ),
          ),
      ],
    );
  }

  Widget _settingsCard() {
    final dark =
        widget.themeMode == ThemeMode.dark ||
        (widget.themeMode != ThemeMode.light &&
            Theme.of(context).brightness == Brightness.dark);
    final signedIn = controller.identity != null;
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeading('Settings', Icons.settings_outlined),
          _setting(
            'Notifications',
            Icons.notifications_none_outlined,
            subtitle: 'Not available yet',
            onTap: () => _information(
              'Notifications',
              'Push notifications and reminders are not supported in this version.',
            ),
            trailing: Semantics(
              label: 'Notifications unavailable in this version',
              child: const Switch(value: false, onChanged: null),
            ),
          ),
          _setting(
            'Dark mode',
            Icons.dark_mode_outlined,
            onTap: widget.onThemeModeChanged != null
                ? () => widget.onThemeModeChanged!(
                    dark ? ThemeMode.light : ThemeMode.dark,
                  )
                : widget.onAppearance,
            trailing: Switch(
              value: dark,
              onChanged: widget.onThemeModeChanged == null
                  ? null
                  : (value) => widget.onThemeModeChanged!(
                      value ? ThemeMode.dark : ThemeMode.light,
                    ),
            ),
          ),
          _setting(
            'Allergens',
            Icons.warning_amber_rounded,
            onTap: _preferencesBusy
                ? null
                : () => _choosePreferences(allergensOnly: true),
          ),
          _setting('Privacy', Icons.shield_outlined, onTap: _privacy),
          _setting(
            'Help',
            Icons.help_outline_rounded,
            onTap: () => _information(
              'Help',
              'Scan a package label, confirm the text, and read its report. Saved keeps your selected reports. Compare uses each package’s stated nutrition basis. Unknown facts are left unknown.',
              showAbout: true,
            ),
          ),
          if (signedIn)
            _setting(
              'Log out',
              Icons.logout_rounded,
              danger: true,
              divider: false,
              onTap: controller.authBusy ? null : _logout,
              trailing: const SizedBox(width: 22),
            ),
        ],
      ),
      botanical: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 900;
        return PageBody(
          maxWidth: 1120,
          children: [
            if (widget.showHeader) ...[
              Semantics(
                header: true,
                child: Text(
                  'Profile',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
              ),
              const SizedBox(height: 18),
            ],
            _identity(),
            if (controller.identity != null &&
                (controller.state == AccountSyncState.needsChoice ||
                    controller.state == AccountSyncState.failed)) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _privacy,
                icon: const Icon(Icons.cloud_outlined),
                label: Text(
                  controller.state == AccountSyncState.needsChoice
                      ? 'Choose your sync library'
                      : 'Check private sync',
                ),
              ),
            ],
            if (controller.identity == null &&
                controller.state == AccountSyncState.failed) ...[
              const SizedBox(height: 8),
              Text(controller.message),
            ],
            const SizedBox(height: 14),
            _statistics(),
            const SizedBox(height: 14),
            if (desktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 4, child: _preferenceCard()),
                  const SizedBox(width: 20),
                  Expanded(flex: 5, child: _settingsCard()),
                ],
              )
            else ...[
              _preferenceCard(),
              const SizedBox(height: 14),
              _settingsCard(),
            ],
          ],
        );
      },
    );
    return widget.embedded ? body : Scaffold(body: body);
  }
}

class _PreferencesDialog extends StatefulWidget {
  const _PreferencesDialog({
    required this.preferences,
    this.allergensOnly = false,
  });
  final DeviceProfilePreferences preferences;
  final bool allergensOnly;
  @override
  State<_PreferencesDialog> createState() => _PreferencesDialogState();
}

class _PreferencesDialogState extends State<_PreferencesDialog> {
  late DeviceProfilePreferences _value = widget.preferences;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.allergensOnly ? 'Allergen reminders' : 'Your preferences',
    ),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'These choices stay on this device. They are personal reminders and do not mark any food as safe or suitable.',
            ),
            const SizedBox(height: 14),
            if (!widget.allergensOnly) ...[
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Low sugar'),
                value: _value.lowSugar,
                onChanged: (value) =>
                    setState(() => _value = _value.copyWith(lowSugar: value)),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('High fibre'),
                value: _value.highFibre,
                onChanged: (value) =>
                    setState(() => _value = _value.copyWith(highFibre: value)),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Vegetarian'),
                value: _value.vegetarian,
                onChanged: (value) =>
                    setState(() => _value = _value.copyWith(vegetarian: value)),
              ),
              const SizedBox(height: 10),
              Text(
                'Allergens to remember',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
            for (final allergen
                in DeviceProfilePreferences.allergenLabels.entries)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(allergen.value),
                value: _value.allergens.contains(allergen.key),
                onChanged: (value) => setState(() {
                  final allergens = {..._value.allergens};
                  if (value == true) {
                    allergens.add(allergen.key);
                  } else {
                    allergens.remove(allergen.key);
                  }
                  _value = _value.copyWith(allergens: allergens);
                }),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _value),
        child: const Text('Save preferences'),
      ),
    ],
  );
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.initialName});
  final String initialName;
  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _field = TextEditingController(text: widget.initialName);
  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Your display name'),
    content: TextField(
      controller: _field,
      maxLength: 80,
      textCapitalization: TextCapitalization.words,
      decoration: const InputDecoration(
        labelText: 'Display name',
        hintText: 'What should we call you?',
      ),
      textInputAction: TextInputAction.done,
      onSubmitted: (value) => Navigator.pop(context, value),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _field.text),
        child: const Text('Save name'),
      ),
    ],
  );
}

class _LoginDialog extends StatefulWidget {
  const _LoginDialog({required this.controller, required this.initiallyCreate});
  final AccountController controller;
  final bool initiallyCreate;
  @override
  State<_LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<_LoginDialog> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  late bool _create = widget.initiallyCreate;
  bool _busy = false;
  bool _visible = false;
  String? _error;
  String? _notice;
  @override
  void dispose() {
    _email.dispose();
    _password.clear();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate() || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      if (_create) {
        await widget.controller.create(_email.text.trim(), _password.text);
      } else {
        await widget.controller.signIn(_email.text.trim(), _password.text);
      }
      _password.clear();
      if (mounted) Navigator.of(context).pop();
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.userMessage);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Sign-in could not finish. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    final email = _email.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _error = 'Enter your email address first.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await widget.controller.resetPassword(email);
      if (mounted) {
        setState(
          () => _notice = 'If this email has an account, password reset instructions are on their way.',
        );
      }
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.userMessage);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'The reset request could not finish. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text(_create ? 'Create your account' : 'Welcome back'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: AutofillGroup(
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Save your history across devices.'),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _email,
                    enabled: !_busy,
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                    ),
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    validator: (value) =>
                        RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                            .hasMatch(value?.trim() ?? '')
                        ? null
                        : 'Enter a valid email address.',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    enabled: !_busy,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        tooltip: _visible ? 'Hide password' : 'Show password',
                        onPressed: _busy
                            ? null
                            : () => setState(() => _visible = !_visible),
                        icon: Icon(
                          _visible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                    obscureText: !_visible,
                    autocorrect: false,
                    enableSuggestions: false,
                    autofillHints: [
                      _create
                          ? AutofillHints.newPassword
                          : AutofillHints.password,
                    ],
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Enter your password.'
                        : _create && value.length < 6
                        ? 'Use at least 6 characters.'
                        : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                  if (_notice != null) ...[
                    const SizedBox(height: 16),
                    Semantics(liveRegion: true, child: Text(_notice!)),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    key: const ValueKey('account-submit'),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_busy) ...[
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Flexible(
                          child: Text(
                            _create ? 'Create account' : 'Sign in',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  PopupMenuButton<String>(
                    enabled: !_busy,
                    tooltip: 'Account help',
                    onSelected: (value) {
                      if (value == 'reset') {
                        _reset();
                      } else {
                        setState(() {
                          _create = !_create;
                          _error = null;
                          _notice = null;
                        });
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'mode',
                        child: Text(
                          _create ? 'Sign in instead' : 'Create an account',
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'reset',
                        child: Text('Reset password'),
                      ),
                    ],
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Text('Account help'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Keep using as guest'),
        ),
      ],
    ),
  );
}
