import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/accounts/account_controller.dart';
import '../../../core/accounts/profile_media.dart';
import '../../../core/accounts/password_policy.dart';
import '../../../core/models/app_failure.dart';
import '../../scanner/presentation/ui_components.dart';
import '../data/device_profile_preferences.dart';
import 'auth_page.dart';
import 'profile_avatar.dart';

// Choice symbols match the same meaning in editors and selected summaries.
// Food pictograms are project-authored companions to the Solar line controls.
const _preferenceSymbols = <String, String>{
  'Low sugar': 'food-low-sugar',
  'High fibre': 'food-fibre',
  'Vegetarian': 'food-carrot',
  'Higher protein': 'dumbbell',
  'Lower sodium': 'food-salt',
  'Less saturated fat': 'food-fat',
  'No added sugar': 'food-no-added-sugar',
  'Vegan': 'food-seedling',
  'Milk': 'food-milk',
  'Gluten': 'food-bread',
  'Eggs': 'food-egg',
  'Peanuts': 'food-peanut',
  'Tree nuts': 'food-walnut',
  'Soy': 'food-soy',
  'Fish': 'food-fish',
  'Shellfish': 'food-shrimp',
  'Sesame': 'food-sesame',
  'Mustard': 'food-mustard',
  'Celery': 'food-celery',
  'Sulphites': 'food-sulphites',
};

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
    bool fromProfile = true,
  }) => Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => AuthPage(
        controller: controller,
        create: create,
        fromProfile: fromProfile,
      ),
    ),
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
      builder: (_) => _NameDialog(
        initialName:
            controller.localData?.displayName ??
            controller.identity?.displayName ??
            '',
      ),
    );
    if (value != null && mounted) {
      await _run(context, () => controller.updateDisplayName(value));
    }
  }

  Future<void> _gender(ProfileMediaController media) async {
    final selected = await showDialog<ProfileGender>(
      context: context,
      builder: (context) => _ProfileWindow(
        title: 'Gender',
        icon: Icons.person_outline_rounded,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Optional. This selects your default avatar.'),
            const SizedBox(height: 16),
            for (final gender in ProfileGender.values)
              ListTile(
                selected: media.value.gender == gender,
                contentPadding: EdgeInsets.zero,
                title: Text(gender.label),
                leading: Icon(
                  media.value.gender == gender
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                onTap: () => Navigator.pop(context, gender),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (selected != null && mounted) {
      await _run(context, () => media.updateGender(selected));
    }
  }

  Future<void> _signInMethods() => showDialog<void>(
    context: context,
    builder: (context) => _SignInMethodsDialog(controller: controller),
  );

  Future<void> _choosePreferences({bool allergensOnly = false}) async {
    final preferences = await showDialog<DeviceProfilePreferences>(
      context: context,
      barrierDismissible: false,
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
    animationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (context) => _ProfileWindow(
      title: title,
      icon: title == 'Notifications'
          ? Icons.notifications_none_outlined
          : Icons.help_outline_rounded,
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
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );

  Future<void> _privacy() => showDialog<void>(
    context: context,
    animationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (dialogContext) => AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final signedIn = controller.identity != null;
        final pending =
            controller.state == AccountSyncState.checking ||
            controller.state == AccountSyncState.syncing;
        return _ProfileWindow(
          title: 'Privacy & account data',
          icon: Icons.shield_outlined,
          scrollContent: false,
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Guest history stays on this device. Signed-in history, saved reports and your display name sync privately. Your selected profile thumbnail and gender are private account settings. Label photos, raw label text and personal reminders stay outside account sync.',
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
                                    'Clear account library?',
                                    'Remove this account’s library display name, saved products and history from this device and sync the empty library. Guest reports, public facts, sign-in profile, profile picture and gender stay unchanged. If sync fails, deletion remains pending.',
                                    'Clear account library',
                                  ) &&
                                  context.mounted) {
                                await _run(
                                  context,
                                  controller.clearAccountLibrary,
                                );
                              }
                            },
                      child: const Text('Clear account library'),
                    ),
                  ] else ...[
                    Text(controller.message),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            FilledButton(
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
                        'assets/artwork/profile-botanical.webp',
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
    final libraryName = controller.localData?.displayName?.trim();
    final displayName = libraryName?.isNotEmpty == true
        ? libraryName
        : controller.identity?.displayName?.trim();
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
                      'assets/artwork/profile-botanical.webp',
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
                  final media = ProfileMediaScope.maybeOf(context);
                  final avatar = IconButton(
                    tooltip: 'Change profile picture',
                    onPressed: media == null || media.loading || media.busy
                        ? null
                        : () => ProfilePhotoEditor.show(
                            context,
                            media: media,
                            identity: controller.identity,
                          ),
                    padding: EdgeInsets.zero,
                    icon: AccountAvatar(
                      identity: controller.identity,
                      displayName: displayName,
                      size: largeText ? 72 : 88,
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
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: onTap == null ? 0 : 48),
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
      ),
    );
  }

  Widget _preferenceCard() => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading(
          'Preferences',
          Icons.tune_rounded,
          onTap: _preferencesBusy ? null : () => _choosePreferences(),
        ),
        Text(
          _preferences.selectedPreferenceLabels.isEmpty
              ? 'No preferences selected'
              : '${_preferences.selectedPreferenceLabels.length} selected',
          key: const ValueKey('profile-preferences-summary-count'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (_preferences.selectedPreferenceLabels.isNotEmpty) ...[
          const SizedBox(height: 8),
          _selectionSummary(_preferences.selectedPreferenceLabels),
        ],
        const SizedBox(height: 20),
        _sectionHeading(
          'Allergens to remember',
          Icons.warning_amber_rounded,
          onTap: _preferencesBusy
              ? null
              : () => _choosePreferences(allergensOnly: true),
        ),
        Text(
          _preferences.allergens.isEmpty
              ? 'No allergens selected'
              : '${_preferences.allergens.length} selected',
          key: const ValueKey('profile-allergens-summary-count'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (_preferences.allergens.isNotEmpty) ...[
          const SizedBox(height: 8),
          _selectionSummary([
            for (final allergen
                in DeviceProfilePreferences.allergenLabels.entries)
              if (_preferences.allergens.contains(allergen.key))
                '${allergen.value} reminder',
          ], allergensOnly: true),
        ],
        if (_preferenceError != null) ...[
          const SizedBox(height: 8),
          Text(_preferenceError!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    ),
  );

  Widget _selectionSummary(List<String> labels, {bool allergensOnly = false}) {
    final group = allergensOnly ? 'allergens' : 'preferences';
    final edit = _preferencesBusy
        ? null
        : () => _choosePreferences(allergensOnly: allergensOnly);
    return Wrap(
      key: ValueKey('profile-$group-summary-chips'),
      spacing: 7,
      runSpacing: 7,
      children: [
        for (final label in labels.take(2))
          ActionChip(
            avatar: FeatureIcon(
              _preferenceSymbols[allergensOnly
                  ? label.substring(0, label.length - ' reminder'.length)
                  : label]!,
              size: 17,
            ),
            label: Text(label),
            onPressed: edit,
          ),
        if (labels.length > 2)
          ActionChip(
            key: ValueKey('profile-$group-overflow'),
            label: Text('+${labels.length - 2}'),
            tooltip: 'View ${labels.length - 2} more selected $group',
            onPressed: edit,
          ),
      ],
    );
  }

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
    final media = ProfileMediaScope.maybeOf(context);
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
          if (media != null) ...[
            _setting(
              'Profile picture',
              Icons.account_circle_outlined,
              subtitle: 'Google, upload or default avatar',
              onTap: media.loading || media.busy
                  ? null
                  : () => ProfilePhotoEditor.show(
                      context,
                      media: media,
                      identity: controller.identity,
                    ),
            ),
            _setting(
              'Gender',
              Icons.person_outline_rounded,
              subtitle: media.value.gender.label,
              onTap: media.loading || media.busy ? null : () => _gender(media),
            ),
            if (media.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      media.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    TextButton(
                      onPressed: media.refresh,
                      child: const Text('Retry profile settings'),
                    ),
                  ],
                ),
              ),
          ],
          _setting(
            'Sign-in methods',
            Icons.manage_accounts_outlined,
            subtitle: signedIn
                ? 'Manage Google and email sign-in'
                : 'Sign in to connect your account',
            onTap: controller.authBusy
                ? null
                : signedIn
                ? _signInMethods
                : () => ProfilePage.showSignIn(context, controller),
          ),
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

  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _toggleAllergen(String key) {
    setState(() {
      final allergens = {..._value.allergens};
      if (!allergens.add(key)) allergens.remove(key);
      _value = _value.copyWith(allergens: allergens);
    });
  }

  void _toggleExtraPreference(String key) {
    setState(() {
      final preferences = {..._value.extraPreferences};
      if (!preferences.add(key)) preferences.remove(key);
      _value = _value.copyWith(extraPreferences: preferences);
    });
  }

  Widget _foodPreferences() {
    final choices = [
      _PreferenceChoice(
        key: const ValueKey('food-choice-low-sugar'),
        label: 'Low sugar',
        icon: _preferenceSymbols['Low sugar']!,
        selected: _value.lowSugar,
        onTap: () => setState(
          () => _value = _value.copyWith(lowSugar: !_value.lowSugar),
        ),
      ),
      _PreferenceChoice(
        key: const ValueKey('food-choice-high-fibre'),
        label: 'High fibre',
        icon: _preferenceSymbols['High fibre']!,
        selected: _value.highFibre,
        onTap: () => setState(
          () => _value = _value.copyWith(highFibre: !_value.highFibre),
        ),
      ),
      _PreferenceChoice(
        key: const ValueKey('food-choice-vegetarian'),
        label: 'Vegetarian',
        icon: _preferenceSymbols['Vegetarian']!,
        selected: _value.vegetarian,
        onTap: () => setState(
          () => _value = _value.copyWith(vegetarian: !_value.vegetarian),
        ),
      ),
      for (final preference
          in DeviceProfilePreferences.extraPreferenceLabels.entries)
        _PreferenceChoice(
          key: ValueKey('food-choice-${preference.key}'),
          label: preference.value,
          icon: _preferenceSymbols[preference.value]!,
          selected: _value.extraPreferences.contains(preference.key),
          onTap: () => _toggleExtraPreference(preference.key),
        ),
    ];
    return LayoutBuilder(
      key: const ValueKey('food-preferences-section'),
      builder: (context, box) {
        final largeText = MediaQuery.textScalerOf(context).scale(14) > 21;
        final columns = box.maxWidth >= 420 && !largeText ? 2 : 1;
        final width = (box.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final choice in choices) SizedBox(width: width, child: choice),
          ],
        );
      },
    );
  }

  Widget _allergenPreferences() => Column(
    key: const ValueKey('allergen-preferences-section'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      LayoutBuilder(
        builder: (context, box) {
          final largeText = MediaQuery.textScalerOf(context).scale(14) > 21;
          final columns = box.maxWidth >= 300 && !largeText ? 2 : 1;
          final width = (box.maxWidth - (columns - 1) * 10) / columns;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final allergen
                  in DeviceProfilePreferences.allergenLabels.entries)
                SizedBox(
                  width: width,
                  child: _PreferenceChoice(
                    key: ValueKey('allergen-choice-${allergen.key}'),
                    label: allergen.value,
                    icon: _preferenceSymbols[allergen.value]!,
                    selected: _value.allergens.contains(allergen.key),
                    onTap: () => _toggleAllergen(allergen.key),
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final size = MediaQuery.sizeOf(context);
    final inset = size.width < 600 ? 16.0 : 32.0;
    return Dialog(
      key: const ValueKey('profile-preferences-dialog'),
      backgroundColor: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      insetPadding: EdgeInsets.all(inset),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      constraints: BoxConstraints(
        maxWidth: widget.allergensOnly ? 620 : 560,
        maxHeight: 680,
      ),
      child: SizedBox(
        key: const ValueKey('profile-preferences-panel'),
        width: widget.allergensOnly ? 620 : 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: Scrollbar(
                controller: _scroll,
                child: SingleChildScrollView(
                  key: const ValueKey('profile-preferences-scroll'),
                  controller: _scroll,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        namesRoute: true,
                        header: true,
                        child: Text(
                          widget.allergensOnly
                              ? 'Allergen reminders'
                              : 'Your preferences',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          '${widget.allergensOnly ? _value.allergens.length : _value.selectedPreferenceLabels.length} selected',
                          key: const ValueKey('profile-selection-count'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const FeatureIcon('shield', size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Saved only on this device. Reminders cannot confirm food safety or suitability.',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      widget.allergensOnly
                          ? _allergenPreferences()
                          : _foodPreferences(),
                    ],
                  ),
                ),
              ),
            ),
            Divider(height: 1, color: scheme.outlineVariant),
            Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, box) {
                  final save = FilledButton(
                    key: const ValueKey('save-profile-preferences'),
                    onPressed: () => Navigator.pop(context, _value),
                    child: Text(
                      widget.allergensOnly
                          ? 'Save allergens'
                          : 'Save preferences',
                      textAlign: TextAlign.center,
                    ),
                  );
                  final cancel = TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  );
                  if (box.maxWidth < 300 ||
                      MediaQuery.textScalerOf(context).scale(16) > 24) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [save, const SizedBox(height: 4), cancel],
                    );
                  }
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      cancel,
                      const SizedBox(width: 12),
                      Flexible(child: save),
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
}

class _PreferenceChoice extends StatelessWidget {
  const _PreferenceChoice({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.icon,
    super.key,
  });

  final String label;
  final String icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      checked: selected,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: selected
              ? scheme.primaryContainer
              : scheme.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: selected ? scheme.primary : scheme.outlineVariant,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                child: Row(
                  children: [
                    FeatureIcon(icon, size: 25),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          height: 1.25,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      size: 22,
                      color: selected ? scheme.primary : scheme.outline,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileWindow extends StatelessWidget {
  const _ProfileWindow({
    required this.title,
    required this.icon,
    required this.content,
    required this.actions,
    this.scrollContent = true,
    this.canDismiss = true,
  });
  final String title;
  final IconData icon;
  final Widget content;
  final List<Widget> actions;
  final bool scrollContent;
  final bool canDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Dialog(
      key: const ValueKey('profile-detail-window'),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: MediaQuery.sizeOf(context).height * .85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: scheme.primaryContainer.withValues(alpha: .24),
              padding: const EdgeInsets.fromLTRB(24, 20, 12, 20),
              child: Row(
                children: [
                  Icon(icon, color: scheme.primary, size: 28),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(title, style: theme.textTheme.titleLarge),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Close $title',
                    onPressed: canDismiss ? () => Navigator.pop(context) : null,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(
              child: DefaultTextStyle.merge(
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                child: scrollContent
                    ? SingleChildScrollView(
                        primary: false,
                        padding: const EdgeInsets.all(24),
                        child: content,
                      )
                    : Padding(
                        padding: const EdgeInsets.all(24),
                        child: content,
                      ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 12,
                runSpacing: 8,
                children: actions,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignInMethodsDialog extends StatefulWidget {
  const _SignInMethodsDialog({required this.controller});
  final AccountController controller;
  @override
  State<_SignInMethodsDialog> createState() => _SignInMethodsDialogState();
}

class _SignInMethodsDialogState extends State<_SignInMethodsDialog> {
  String? _error;
  Future<void> _google() async {
    setState(() => _error = null);
    try {
      await widget.controller.linkGoogle();
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.userMessage);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final identity = widget.controller.identity;
      final busy = widget.controller.authBusy;
      return PopScope(
        canPop: !busy,
        child: _ProfileWindow(
          title: 'Sign-in methods',
          canDismiss: !busy,
          icon: Icons.manage_accounts_outlined,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Use either method to open the same Unlabel account.'),
              const SizedBox(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.account_circle_outlined),
                title: const Text('Google'),
                subtitle: Text(
                  identity?.hasGoogle == true
                      ? 'Connected'
                      : 'Connect your Google account',
                ),
              ),
              if (identity?.hasGoogle != true)
                OutlinedButton(
                  onPressed: busy || identity == null ? null : _google,
                  child: const Text('Connect Google'),
                ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.mail_outline_rounded),
                title: const Text('Email and password'),
                subtitle: Text(
                  identity?.hasPassword == true
                      ? 'Connected'
                      : 'Add a password for ${identity?.email ?? 'your email'}',
                ),
              ),
              if (identity?.hasPassword != true)
                OutlinedButton(
                  onPressed: busy || identity == null
                      ? null
                      : () => showDialog<void>(
                          context: context,
                          builder: (_) => _LinkPasswordDialog(
                            controller: widget.controller,
                          ),
                        ),
                  child: const Text('Add email and password'),
                ),
              if (busy) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
              ],
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
            ],
          ),
          actions: [
            FilledButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    },
  );
}

class _LinkPasswordDialog extends StatefulWidget {
  const _LinkPasswordDialog({required this.controller});
  final AccountController controller;
  @override
  State<_LinkPasswordDialog> createState() => _LinkPasswordDialogState();
}

class _LinkPasswordDialogState extends State<_LinkPasswordDialog> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(
    text: widget.controller.identity?.email,
  );
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false, _obscure = true;
  String? _error;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.controller.linkPassword(_email.text.trim(), _password.text);
      if (mounted) Navigator.pop(context);
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.userMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: _ProfileWindow(
      title: 'Add a password',
      canDismiss: !_busy,
      icon: Icons.lock_outline_rounded,
      content: Form(
        key: _form,
        child: AutofillGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Your Google sign-in and private library stay connected.',
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _email,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Account email',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
                autofillHints: const [AutofillHints.email],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _password,
                enabled: !_busy,
                obscureText: _obscure,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: 'New password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'Show password' : 'Hide password',
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (value) => validateNewPassword(value ?? ''),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirm,
                enabled: !_busy,
                obscureText: _obscure,
                decoration: const InputDecoration(
                  labelText: 'Confirm password',
                  prefixIcon: Icon(Icons.lock_outline_rounded),
                ),
                validator: (value) =>
                    value != _password.text ? 'Passwords must match.' : null,
                onFieldSubmitted: (_) => _save(),
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
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Adding password…' : 'Add password'),
        ),
      ],
    ),
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
  Widget build(BuildContext context) => _ProfileWindow(
    title: 'Your display name',
    icon: Icons.person_outline_rounded,
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
