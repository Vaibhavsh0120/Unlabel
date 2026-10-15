import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/accounts/account_controller.dart';
import '../../../core/accounts/profile_media.dart';
import '../../../core/accounts/password_policy.dart';
import '../../../core/models/app_failure.dart';
import '../../scanner/presentation/ui_components.dart';
import '../data/device_profile_preferences.dart';
import 'auth_page.dart';
import 'profile_avatar.dart';
import 'sign_in_methods_view.dart';

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
    this.pickProfilePhoto,
    super.key,
  });
  final AccountController controller;
  final VoidCallback onContinue;
  final VoidCallback? onAppearance, onAbout, onSaved, onScans, onCompare;
  final ThemeMode? themeMode;
  final ValueChanged<ThemeMode>? onThemeModeChanged;
  final bool embedded, showHeader;
  final Future<Uint8List?> Function()? pickProfilePhoto;

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

  Future<void> _editProfile() => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _EditProfileDialog(
      controller: controller,
      media: ProfileMediaScope.maybeOf(context),
      pickPhoto: widget.pickProfilePhoto,
    ),
  );

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
                    'Guest history stays on this device. Signed-in history, saved reports and your display name sync privately. Your selected profile thumbnail and gender are private account settings. Label photos, raw label text and personal reminders stay outside account sync. When you enable AI photo reading, compatible package facts may be shared automatically as unverified machine observations with their provider and date. Original catalogue sources are preserved, and disagreements stay unresolved. Package photos are not stored by our backend; AI provider retention terms apply.',
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

  Widget _card(Widget child, {double padding = 16}) {
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
      ),
      child: Padding(padding: EdgeInsets.all(padding), child: child),
    );
  }

  Widget _identity() {
    final theme = Theme.of(context);
    final signedIn = controller.identity != null;
    final displayName = controller.displayName?.trim();
    final name = displayName?.isNotEmpty == true
        ? displayName!
        : signedIn
        ? 'Your Unlabel account'
        : 'Your guest profile';
    return DecoratedBox(
      key: const ValueKey('profile-identity-card'),
      decoration: BoxDecoration(
        color: _mint,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: .45),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, box) {
            final largeText = MediaQuery.textScalerOf(context).scale(14) > 21;
            final avatar = AccountAvatar(
              identity: controller.identity,
              displayName: displayName,
              size: largeText ? 72 : 88,
            );
            final edit = IconButton(
              key: const ValueKey('profile-edit'),
              tooltip: 'Edit profile',
              onPressed: controller.authBusy ? null : _editProfile,
              icon: const Icon(Icons.edit_outlined),
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
                ),
                if (!signedIn) ...[
                  const SizedBox(height: 10),
                  FilledButton.tonalIcon(
                    onPressed: controller.authBusy
                        ? null
                        : () => ProfilePage.showSignIn(context, controller),
                    icon: const Icon(Icons.login_rounded, size: 19),
                    label: const Text('Sign in'),
                  ),
                ],
              ],
            );
            if (largeText && box.maxWidth < 460) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [avatar, const Spacer(), edit],
                  ),
                  const SizedBox(height: 12),
                  details,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                avatar,
                const SizedBox(width: 14),
                Expanded(child: details),
                const SizedBox(width: 8),
                edit,
              ],
            );
          },
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

  Widget _preferenceCard() {
    final media = ProfileMediaScope.maybeOf(context);
    return KeyedSubtree(
      key: const ValueKey('profile-preferences-card'),
      child: _card(
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
            if (media != null) ...[
              const SizedBox(height: 20),
              _sectionHeading(
                'Gender',
                Icons.person_outline_rounded,
                onTap: media.loading || media.busy || media.error != null
                    ? null
                    : () => _gender(media),
              ),
              Text(
                media.value.gender.label,
                key: const ValueKey('profile-gender-summary'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (media.error != null) ...[
                const SizedBox(height: 8),
                Text(
                  media.error!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                TextButton(
                  onPressed: media.refresh,
                  child: const Text('Retry profile settings'),
                ),
              ],
            ],
            if (_preferenceError != null) ...[
              const SizedBox(height: 8),
              Text(
                _preferenceError!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

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
    final dark =
        widget.themeMode == ThemeMode.dark ||
        (widget.themeMode != ThemeMode.light &&
            Theme.of(context).brightness == Brightness.dark);
    final signedIn = controller.identity != null;
    return KeyedSubtree(
      key: const ValueKey('profile-settings-card'),
      child: _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeading('Settings', Icons.settings_outlined),
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
      ),
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

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _error = null);
    try {
      await action();
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.userMessage);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'This sign-in change could not finish. Try again.',
        );
      }
    }
  }

  Future<void> _confirm({
    required String title,
    required String body,
    required String label,
    required Future<void> Function(String? password) action,
    bool password = false,
    bool danger = false,
  }) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _AccountActionDialog(
      controller: widget.controller,
      title: title,
      body: body,
      actionLabel: label,
      action: action,
      requiresPassword: password,
      danger: danger,
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final identity = widget.controller.identity;
      return SignInMethodsView(
        identity: identity,
        busy: widget.controller.authBusy,
        error: _error,
        onClose: () => Navigator.pop(context),
        onGoogle: () {
          if (identity?.hasGoogle != true) {
            _run(widget.controller.linkGoogle);
          } else if (identity?.hasPassword == true) {
            _confirm(
              title: 'Disconnect Google?',
              body: 'Your email and password will still open this account. Your private library stays with the same account.',
              label: 'Disconnect',
              password: true,
              danger: true,
              action: (value) =>
                  widget.controller.unlinkGoogle(password: value!),
            );
          }
        },
        onPassword: () {
          if (identity?.hasPassword != true) {
            showDialog<void>(
              context: context,
              builder: (_) =>
                  _LinkPasswordDialog(controller: widget.controller),
            );
          } else if (identity?.hasGoogle == true) {
            _confirm(
              title: 'Remove email and password?',
              body: 'You can still sign in with the Google account connected here.',
              label: 'Remove',
              danger: true,
              action: (_) => widget.controller.unlinkPassword(),
            );
          }
        },
        onChangeEmail: _changeEmail,
        onChangePassword: _changePassword,
        onSwitchGoogle: () => _confirm(
          title: 'Switch Google account?',
          body: 'Confirm your password, then choose a different Google account. Your current password remains available if linking does not finish.',
          label: 'Switch account',
          password: true,
          action: (value) =>
              widget.controller.changeGoogleAccount(password: value!),
        ),
        onDelete: () => showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _DeleteAccountDialog(controller: widget.controller),
        ),
      );
    },
  );

  Future<void> _changeEmail() => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        _ChangeCredentialDialog(controller: widget.controller, email: true),
  );

  Future<void> _changePassword() => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        _ChangeCredentialDialog(controller: widget.controller, email: false),
  );
}

class _ChangeCredentialDialog extends StatefulWidget {
  const _ChangeCredentialDialog({
    required this.controller,
    required this.email,
  });
  final AccountController controller;
  final bool email;

  @override
  State<_ChangeCredentialDialog> createState() =>
      _ChangeCredentialDialogState();
}

class _ChangeCredentialDialogState extends State<_ChangeCredentialDialog> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _newValue = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false, _done = false, _show = false;
  String? _error;

  @override
  void dispose() {
    _current.clear();
    _newValue.clear();
    _confirm.clear();
    _current.dispose();
    _newValue.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.email) {
        await widget.controller.changeEmail(
          _newValue.text.trim(),
          _current.text,
        );
      } else {
        await widget.controller.changePassword(_current.text, _newValue.text);
      }
      if (mounted) setState(() => _done = true);
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.userMessage);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'This change could not finish. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: _ProfileWindow(
      title: widget.email ? 'Change email' : 'Change password',
      icon: widget.email ? Icons.mail_outline : Icons.lock_outline,
      canDismiss: !_busy,
      content: _done
          ? Text(
              widget.email
                  ? 'Check your new email for a verification link. Your current email remains active until you verify it.'
                  : 'Your password has been changed. Both connected sign-in methods remain available.',
            )
          : Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Current email',
                      hintText: widget.controller.identity?.email,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    key: const ValueKey('credential-current-password'),
                    controller: _current,
                    enabled: !_busy,
                    obscureText: !_show,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: 'Current password',
                      suffixIcon: IconButton(
                        tooltip: _show ? 'Hide password' : 'Show password',
                        onPressed: () => setState(() => _show = !_show),
                        icon: Icon(
                          _show
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Enter your current password.'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    key: const ValueKey('credential-new-value'),
                    controller: _newValue,
                    enabled: !_busy,
                    obscureText: !widget.email && !_show,
                    keyboardType: widget.email
                        ? TextInputType.emailAddress
                        : TextInputType.text,
                    autofillHints: widget.email
                        ? const [AutofillHints.email]
                        : const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: widget.email ? 'New email' : 'New password',
                    ),
                    validator: (value) => widget.email
                        ? (RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                  .hasMatch(value?.trim() ?? '')
                              ? null
                              : 'Enter a valid email address.')
                        : validateNewPassword(value ?? ''),
                  ),
                  if (!widget.email) ...[
                    const SizedBox(height: 14),
                    TextFormField(
                      key: const ValueKey('credential-confirm-password'),
                      controller: _confirm,
                      enabled: !_busy,
                      obscureText: !_show,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: const InputDecoration(
                        labelText: 'Confirm new password',
                      ),
                      validator: (value) => value == _newValue.text
                          ? null
                          : 'Passwords do not match.',
                    ),
                  ],
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: LinearProgressIndicator(),
                    ),
                ],
              ),
            ),
      actions: [
        if (!_done)
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        FilledButton(
          onPressed: _busy
              ? null
              : _done
              ? () => Navigator.pop(context)
              : _save,
          child: Text(
            _done
                ? 'Done'
                : widget.email
                ? 'Send verification'
                : 'Change password',
          ),
        ),
      ],
    ),
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

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog({
    required this.controller,
    this.media,
    this.pickPhoto,
  });
  final AccountController controller;
  final ProfileMediaController? media;
  final Future<Uint8List?> Function()? pickPhoto;
  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final _owner = widget.controller.identity?.uid;
  late final _name = TextEditingController(
    text: widget.controller.displayName ?? '',
  );
  late ProfileMedia _draft = widget.media?.value ?? ProfileMedia();
  bool _working = false, _photoChanged = false;
  String? _error;
  bool get _signedIn => _owner != null;
  bool get _busy => _working || widget.controller.authBusy;
  bool get _photoReady =>
      widget.media != null &&
      !widget.media!.loading &&
      !widget.media!.busy &&
      widget.media!.error == null;
  bool get _hasGoogle => widget.controller.identity?.hasGoogle == true;
  bool get _hasGooglePhoto =>
      _hasGoogle &&
      safeGooglePhotoUrl(widget.controller.identity?.photoUrl) != null;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    widget.media?.addListener(_changed);
  }

  void _changed() {
    if (!mounted) return;
    if (widget.controller.identity?.uid != _owner) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final route = ModalRoute.of(context);
        if (route?.isActive == true) Navigator.of(context).removeRoute(route!);
      });
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    widget.media?.removeListener(_changed);
    _name.dispose();
    _draft = ProfileMedia();
    super.dispose();
  }

  void _select(ProfileAvatarSource source) {
    setState(() {
      _draft = ProfileMedia(gender: _draft.gender, source: source);
      _photoChanged = true;
      _error = null;
    });
  }

  Future<void> _custom() async {
    final media = widget.media;
    if (media == null || !_signedIn || !_photoReady) return;
    final bytes = await ProfilePhotoEditor.crop(
      context,
      media: media,
      identity: widget.controller.identity,
      pickPhoto: widget.pickPhoto,
    );
    if (!mounted ||
        widget.controller.identity?.uid != _owner ||
        bytes == null) {
      return;
    }
    setState(() {
      _draft = ProfileMedia(
        gender: _draft.gender,
        source: ProfileAvatarSource.custom,
        avatarPng: bytes,
      );
      _photoChanged = true;
      _error = null;
    });
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      if (widget.controller.identity?.uid != _owner) return;
      if (_photoChanged &&
          _draft.source == ProfileAvatarSource.google &&
          !_hasGooglePhoto) {
        throw const AppFailure(
          'google_photo_unavailable',
          'Google no longer has an available profile photo. Choose default or custom.',
        );
      }
      final name = _name.text.trim();
      if (name != widget.controller.displayName) {
        await widget.controller.updateDisplayName(name);
      }
      if (!mounted || widget.controller.identity?.uid != _owner) return;
      final media = widget.media;
      if (_photoChanged && media != null) {
        switch (_draft.source) {
          case ProfileAvatarSource.defaultAvatar:
            await media.useDefaultAvatar();
          case ProfileAvatarSource.google:
            await media.useGooglePhoto();
          case ProfileAvatarSource.custom:
            await media.saveCustomPhoto(_draft.avatarPng!);
          case ProfileAvatarSource.automatic:
            await media.removeCustomPhoto();
        }
      }
      if (mounted) Navigator.pop(context);
    } on AppFailure catch (failure) {
      if (mounted) setState(() => _error = failure.userMessage);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Your profile could not finish saving. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Widget _photoChoice(
    String label,
    ProfileAvatarSource source,
    IconData icon,
    VoidCallback? action,
  ) {
    final effective = _draft.source == ProfileAvatarSource.automatic
        ? (_hasGooglePhoto
              ? ProfileAvatarSource.google
              : ProfileAvatarSource.defaultAvatar)
        : _draft.source;
    return ChoiceChip(
      label: Text(label),
      avatar: Icon(icon, size: 18),
      selected: effective == source,
      onSelected: action == null || _busy ? null : (_) => action(),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: _ProfileWindow(
      title: 'Edit profile',
      icon: Icons.edit_outlined,
      canDismiss: !_busy,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.media != null) ...[
            Center(
              child: AccountAvatar(
                media: widget.media,
                identity: widget.controller.identity,
                displayName: _name.text,
                preview: _draft,
                size: 128,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                _photoChoice(
                  'Default',
                  ProfileAvatarSource.defaultAvatar,
                  Icons.person_outline,
                  _photoReady
                      ? () => _select(ProfileAvatarSource.defaultAvatar)
                      : null,
                ),
                if (_hasGoogle)
                  _photoChoice(
                    'Google',
                    ProfileAvatarSource.google,
                    Icons.account_circle_outlined,
                    _photoReady && _hasGooglePhoto
                        ? () => _select(ProfileAvatarSource.google)
                        : null,
                  ),
                _photoChoice(
                  'Custom',
                  ProfileAvatarSource.custom,
                  Icons.photo_library_outlined,
                  _signedIn && _photoReady ? _custom : null,
                ),
              ],
            ),
            if (widget.media!.loading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: LinearProgressIndicator(),
              ),
            if (widget.media!.error != null) ...[
              Text(widget.media!.error!),
              TextButton(
                onPressed: _busy ? null : widget.media!.refresh,
                child: const Text('Retry photo settings'),
              ),
            ],
            const SizedBox(height: 20),
          ],
          TextField(
            key: const ValueKey('edit-profile-name'),
            controller: _name,
            enabled: !_busy,
            maxLength: 80,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Display name',
              hintText: 'What should we call you?',
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
          ),
          if (!_signedIn)
            const Text(
              'Your name stays on this device. Sign in to save a custom photo.',
            ),
          if (_photoChanged)
            const Text(
              'Your photo selection is saved when you choose Save profile.',
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('edit-profile-save'),
          onPressed: _busy || (_photoChanged && !_photoReady) ? null : _save,
          child: Text(_working ? 'Saving profile…' : 'Save profile'),
        ),
      ],
    ),
  );
}

class _AccountActionDialog extends StatefulWidget {
  const _AccountActionDialog({
    required this.controller,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.action,
    this.requiresPassword = false,
    this.deleteConfirmation = false,
    this.danger = false,
  });
  final AccountController controller;
  final String title, body, actionLabel;
  final Future<void> Function(String? password) action;
  final bool requiresPassword, deleteConfirmation, danger;
  @override
  State<_AccountActionDialog> createState() => _AccountActionDialogState();
}

class _AccountActionDialogState extends State<_AccountActionDialog> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _working = false, _obscure = true;
  String? _error;
  @override
  void dispose() {
    _password.clear();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_working ||
        widget.controller.authBusy ||
        !_form.currentState!.validate()) {
      return;
    }
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await widget.action(widget.requiresPassword ? _password.text : null);
      if (mounted) Navigator.pop(context);
    } on AppFailure catch (failure) {
      if (mounted) setState(() => _error = failure.userMessage);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'That account change could not finish. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final busy = _working || widget.controller.authBusy;
      return PopScope(
        canPop: !busy,
        child: _ProfileWindow(
          title: widget.title,
          icon: widget.danger
              ? Icons.warning_amber_rounded
              : Icons.manage_accounts_outlined,
          canDismiss: !busy,
          content: Form(
            key: _form,
            child: AutofillGroup(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(widget.body),
                  if (widget.deleteConfirmation) ...[
                    const SizedBox(height: 20),
                    TextFormField(
                      key: const ValueKey('account-delete-confirmation'),
                      controller: _confirmation,
                      enabled: !busy,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Type DELETE to confirm',
                      ),
                      validator: (value) =>
                          value == 'DELETE' ? null : 'Type DELETE to confirm.',
                    ),
                  ],
                  if (widget.requiresPassword) ...[
                    const SizedBox(height: 20),
                    TextFormField(
                      key: const ValueKey('account-current-password'),
                      controller: _password,
                      enabled: !busy,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.password],
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: 'Current password',
                        suffixIcon: IconButton(
                          tooltip: _obscure ? 'Show password' : 'Hide password',
                          onPressed: busy
                              ? null
                              : () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Enter your current password.'
                          : null,
                      onFieldSubmitted: (_) => _save(),
                    ),
                  ],
                  if (busy)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: LinearProgressIndicator(),
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
              onPressed: busy ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const ValueKey('account-action-confirm'),
              onPressed: busy ? null : _save,
              style: widget.danger
                  ? FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Theme.of(context).colorScheme.onError,
                    )
                  : null,
              child: Text(widget.actionLabel),
            ),
          ],
        ),
      );
    },
  );
}

class _DeleteAccountDialog extends StatelessWidget {
  const _DeleteAccountDialog({required this.controller});
  final AccountController controller;
  @override
  Widget build(BuildContext context) => _AccountActionDialog(
    controller: controller,
    title: 'Delete your account?',
    actionLabel: 'Delete account',
    body: 'Delete this Unlabel account, its private profile settings, saved products and history. Public label facts and your separate guest library remain. This cannot be undone. Confirm your current sign-in to continue.',
    requiresPassword: controller.identity?.hasPassword == true,
    deleteConfirmation: true,
    danger: true,
    action: (password) => controller.deleteAccount(password: password),
  );
}
