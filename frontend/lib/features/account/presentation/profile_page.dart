import 'package:flutter/material.dart';

import '../../../core/accounts/account_controller.dart';
import '../../../core/models/app_failure.dart';
import '../../scanner/presentation/ui_components.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({
    required this.controller,
    required this.onContinue,
    this.onAppearance,
    this.onAbout,
    this.embedded = false,
    super.key,
  });
  final AccountController controller;
  final VoidCallback onContinue;
  final VoidCallback? onAppearance;
  final VoidCallback? onAbout;
  final bool embedded;

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
  Future<void> _login(BuildContext context, {bool create = false}) async {
    await showDialog<void>(
      context: context,
      builder: (_) =>
          _LoginDialog(controller: controller, initiallyCreate: create),
    );
  }

  Future<void> _name(BuildContext context) async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) =>
          _NameDialog(initialName: controller.localData?.displayName ?? ''),
    );
    if (value != null && context.mounted) {
      await _run(context, () => controller.updateDisplayName(value));
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final signedIn = controller.identity != null;
      final theme = Theme.of(context);
      final pending =
          controller.state == AccountSyncState.checking ||
          controller.state == AccountSyncState.syncing;
      final body = PageBody(
        maxWidth: 720,
        children: [
          Semantics(
            header: true,
            child: Text('Profile', style: theme.textTheme.headlineMedium),
          ),
          const SizedBox(height: 24),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(
                    Icons.person_outline_rounded,
                    size: 38,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  signedIn
                      ? controller.localData?.displayName ??
                            'Your Unlabel account'
                      : 'Make yourself at home',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  signedIn
                      ? controller.identity!.email ?? 'Signed in'
                      : 'Save your history across devices.',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                if (!signedIn) ...[
                  FilledButton.icon(
                    onPressed: controller.authBusy
                        ? null
                        : () => _login(context),
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('Sign in'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: onContinue,
                    child: const Text('Continue as guest'),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Guest data stays here. Public food facts save separately.',
                  ),
                ] else ...[
                  OutlinedButton.icon(
                    onPressed: controller.authBusy
                        ? null
                        : () => _name(context),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit display name'),
                  ),
                ],
              ],
            ),
          ),
          if (signedIn) ...[
            const SizedBox(height: 20),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        pending
                            ? Icons.cloud_upload_outlined
                            : Icons.cloud_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Private sync',
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Semantics(liveRegion: true, child: Text(controller.message)),
                  if (pending) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(),
                  ],
                  if (controller.localData != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      '${controller.localData!.saved.length} saved · ${controller.localData!.history.length} in history',
                      style: theme.textTheme.bodyMedium,
                    ),
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
                              await _run(context, controller.copyGuestLibrary);
                            }
                          },
                    child: const Text('Copy this device’s guest reports'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    onPressed: controller.authBusy
                        ? null
                        : () async {
                            if (await _confirm(
                                  context,
                                  'Sign out?',
                                  'Account reports remain in this account’s private device library. You’ll return to the separate guest library. Pending changes may still need syncing next time.',
                                  'Sign out',
                                ) &&
                                context.mounted) {
                              await _run(context, controller.signOut);
                            }
                          },
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Sign out'),
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
                ],
              ),
            ),
          ],
          if (!signedIn && controller.state == AccountSyncState.failed) ...[
            const SizedBox(height: 16),
            Text(controller.message),
          ],
          if (onAppearance != null || onAbout != null) ...[
            const SizedBox(height: 20),
            SectionCard(
              padding: 8,
              child: Column(
                children: [
                  PopupMenuButton<String>(
                    tooltip: 'Appearance & app info',
                    onSelected: (value) => value == 'appearance'
                        ? onAppearance?.call()
                        : onAbout?.call(),
                    itemBuilder: (_) => [
                      if (onAppearance != null)
                        const PopupMenuItem(
                          value: 'appearance',
                          child: Text('Appearance'),
                        ),
                      if (onAbout != null)
                        const PopupMenuItem(
                          value: 'about',
                          child: Text('About Unlabel'),
                        ),
                    ],
                    child: const ListTile(
                      minVerticalPadding: 16,
                      leading: Icon(Icons.brightness_6_outlined),
                      title: Text('Appearance & app info'),
                      trailing: Icon(Icons.expand_more),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
      return embedded ? body : Scaffold(body: body);
    },
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
