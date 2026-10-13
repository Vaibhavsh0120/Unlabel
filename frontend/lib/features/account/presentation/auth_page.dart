import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/accounts/account_controller.dart';
import '../../../core/accounts/password_policy.dart';
import '../../../core/models/app_failure.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../scanner/presentation/ui_components.dart';

enum _AuthMode { signIn, signUp, forgot, sent, newPassword, success }

/// One responsive authentication flow. The SDK owns credentials; this page
/// keeps passwords and reset codes only for the lifetime of the open form.
class AuthPage extends StatefulWidget {
  const AuthPage({
    required this.controller,
    this.create = false,
    this.fromProfile = true,
    this.resetCode,
    this.onComplete,
    super.key,
  });

  final AccountController controller;
  final bool create, fromProfile;
  final String? resetCode;

  /// Root email-action routes replace their content when this flow completes.
  /// Pushed profile routes can omit this and return to their existing caller.
  final VoidCallback? onComplete;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _form = GlobalKey<FormState>();
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  late _AuthMode _mode;
  String? _resetCode, _error, _sentEmail;
  bool _busy = false, _verifying = false, _verified = false;
  bool _showPassword = false, _showConfirm = false;
  int _fieldStep = 0;
  late _AuthLayout _layout;

  List<FocusNode> get _fieldFocus => switch (_mode) {
    _AuthMode.signIn => [_emailFocus, _passwordFocus],
    _AuthMode.signUp => [_nameFocus, _emailFocus, _passwordFocus],
    _AuthMode.forgot => [_emailFocus],
    _AuthMode.newPassword => [_passwordFocus, _confirmFocus],
    _ => [],
  };

  bool get _locked => _busy || _verifying || widget.controller.authBusy;
  bool get _accountForm =>
      _mode == _AuthMode.signIn || _mode == _AuthMode.signUp;

  @override
  void initState() {
    super.initState();
    _resetCode = widget.resetCode;
    _mode = _resetCode != null
        ? _AuthMode.newPassword
        : widget.create
        ? _AuthMode.signUp
        : _AuthMode.signIn;
    widget.controller.addListener(_accountChanged);
    if (_resetCode != null) unawaited(_verifyCode());
  }

  @override
  void didUpdateWidget(AuthPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_accountChanged);
      widget.controller.addListener(_accountChanged);
    }
  }

  void _accountChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_accountChanged);
    _resetCode = null;
    _password.clear();
    _confirm.clear();
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  void _changeMode(_AuthMode mode) {
    if (_locked) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _mode = mode;
      _error = null;
      _password.clear();
      _confirm.clear();
      _showPassword = false;
      _showConfirm = false;
      _fieldStep = 0;
    });
  }

  Future<void> _verifyCode() async {
    _verifying = true;
    try {
      final email = await widget.controller.verifyPasswordResetCode(
        _resetCode!,
      );
      if (!mounted) return;
      setState(() {
        _email.text = email;
        _verified = true;
      });
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.userMessage);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'This reset link could not be checked. Request a new link.',
        );
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _submit() async {
    if (_locked) return;
    if (_layout.paged && _fieldStep < _fieldFocus.length - 1) {
      if (!(_form.currentState?.validate() ?? false)) return;
      FocusScope.of(context).unfocus();
      setState(() => _fieldStep++);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fieldFocus[_fieldStep].requestFocus();
      });
      return;
    }
    final errors = switch (_mode) {
      _AuthMode.signIn => [
        _emailError(_email.text),
        _passwordError(_password.text),
      ],
      _AuthMode.signUp => [
        _nameError(_name.text),
        _emailError(_email.text),
        _passwordError(_password.text),
      ],
      _AuthMode.forgot => [_emailError(_email.text)],
      _AuthMode.newPassword => [
        _passwordError(_password.text),
        _passwordError(_confirm.text, confirm: true),
      ],
      _ => <String?>[],
    };
    final invalid = errors.indexWhere((error) => error != null);
    if (invalid >= 0) {
      FocusScope.of(context).unfocus();
      setState(() => _fieldStep = invalid);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _form.currentState?.validate();
        _fieldFocus[invalid].requestFocus();
      });
      return;
    }
    if (!(_form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      switch (_mode) {
        case _AuthMode.signIn:
          await widget.controller.signIn(_email.text.trim(), _password.text);
          if (!mounted) return;
          TextInput.finishAutofillContext();
          _password.clear();
          _closeAfterSignIn();
        case _AuthMode.signUp:
          await widget.controller.create(
            _email.text.trim(),
            _password.text,
            displayName: _name.text.trim(),
          );
          if (!mounted) return;
          TextInput.finishAutofillContext();
          _password.clear();
          _closeAfterSignIn();
        case _AuthMode.forgot:
          final email = _email.text.trim();
          await widget.controller.resetPassword(email);
          if (mounted) {
            setState(() {
              _sentEmail = email;
              _mode = _AuthMode.sent;
            });
          }
        case _AuthMode.newPassword:
          if (!_verified || _resetCode == null) return;
          await widget.controller.confirmPasswordReset(
            _resetCode!,
            _password.text,
          );
          if (!mounted) return;
          TextInput.finishAutofillContext();
          _password.clear();
          _confirm.clear();
          _resetCode = null;
          if (mounted) {
            setState(() => _mode = _AuthMode.success);
          }
        case _AuthMode.sent:
        case _AuthMode.success:
          break;
      }
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.userMessage);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'This action could not finish. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() async {
    if (_locked) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.controller.signInGoogle();
      if (!mounted) return;
      _closeAfterSignIn();
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.userMessage);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Google sign-in could not finish. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _closeAfterSignIn() {
    if (!mounted) return;
    if (widget.onComplete != null) {
      widget.onComplete!();
      return;
    }
    final navigator = Navigator.of(context);
    // A completed action may close its own route even while PopScope prevents
    // the user from dismissing a still-pending authentication operation.
    if (navigator.canPop()) navigator.pop();
  }

  void _leaveAuth() {
    if (_locked) return;
    FocusScope.of(context).unfocus();
    _resetCode = null;
    _password.clear();
    _confirm.clear();
    if (widget.onComplete != null) {
      widget.onComplete!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  String get _title => switch (_mode) {
    _AuthMode.signIn => 'Welcome back',
    _AuthMode.signUp => 'Create your account',
    _AuthMode.forgot => 'Forgot your password?',
    _AuthMode.sent => 'Reset link sent!',
    _AuthMode.newPassword => 'Create a new password',
    _AuthMode.success => 'Password updated!',
  };

  String get _subtitle => switch (_mode) {
    _AuthMode.signIn => 'Sign in to continue to Unlabel',
    _AuthMode.signUp => 'It’s quick and easy.',
    _AuthMode.forgot => 'Enter your email and we’ll send you a reset link.',
    _AuthMode.sent =>
      'If this email has an account, a reset link is on its way to',
    _AuthMode.newPassword =>
      'Choose a strong password you haven’t used before.',
    _AuthMode.success => 'Your password has been changed successfully.',
  };

  String get _asset => switch (_mode) {
    _AuthMode.signIn => 'auth-signin',
    _AuthMode.signUp => 'auth-signup',
    _AuthMode.forgot => 'auth-forgot',
    _AuthMode.sent => 'auth-sent',
    _AuthMode.newPassword => 'auth-new-password',
    _AuthMode.success => 'auth-success',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_locked,
      child: Scaffold(
        backgroundColor: MediaQuery.sizeOf(context).width >= 900
            ? scheme.surfaceContainerLow
            : scheme.surface,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _layout = _AuthLayout(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                scale: MediaQuery.textScalerOf(context).scale(14) / 14,
                keyboard: MediaQuery.viewInsetsOf(context).bottom > 0,
              );
              if (_layout.paged) {
                final active = _fieldFocus.indexWhere((node) => node.hasFocus);
                if (active >= 0) _fieldStep = active;
                if (_fieldFocus.isNotEmpty) {
                  _fieldStep = _fieldStep.clamp(0, _fieldFocus.length - 1);
                }
              }
              final desktop = _layout.desktop;
              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: desktop
                        ? 1160
                        : _layout.wideFields
                        ? 600
                        : 430,
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: desktop
                          ? 32
                          : constraints.maxWidth < 360
                          ? 16
                          : 24,
                      vertical: _layout.minimal
                          ? 4
                          : desktop
                          ? 20
                          : 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _header(desktop),
                        if (desktop) ...[
                          const SizedBox(height: 20),
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(child: _desktopIntroduction()),
                                const SizedBox(width: 64),
                                SizedBox(
                                  width: 430,
                                  child: _formCard(desktop: true),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          if (!_layout.focused)
                            Flexible(
                              fit: FlexFit.loose,
                              child: _artwork(height: _accountForm ? 144 : 210),
                            )
                          else if (!_layout.minimal)
                            const Spacer(),
                          _formCard(desktop: false),
                          if (_layout.focused && !_layout.minimal)
                            const Spacer(),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _header(bool desktop) {
    final theme = Theme.of(context);
    final brand = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandLeaf(size: desktop ? 30 : 25),
        if (desktop) ...[
          const SizedBox(width: 10),
          Text('Unlabel', style: theme.textTheme.titleMedium),
        ],
      ],
    );
    final canBack = _mode != _AuthMode.signIn;
    final close = IconButton(
      key: const ValueKey('auth-close'),
      tooltip: widget.fromProfile ? 'Close sign-in' : 'Back to sign in',
      onPressed: _locked
          ? null
          : widget.fromProfile
          ? _leaveAuth
          : () => _changeMode(_AuthMode.signIn),
      icon: Icon(widget.fromProfile ? Icons.close : Icons.arrow_back),
      style: IconButton.styleFrom(minimumSize: const Size(40, 40)),
    );
    if (_layout.minimal) {
      return SizedBox(
        height: 40,
        child: Row(
          children: [
            if (widget.fromProfile || canBack)
              close
            else
              const SizedBox(width: 40),
            const Spacer(),
            brand,
            const Spacer(),
            _optionsMenu(),
          ],
        ),
      );
    }
    if (desktop) {
      return Row(
        children: [
          brand,
          const Spacer(),
          Flexible(child: _modeSwitch()),
          if (widget.fromProfile) ...[const SizedBox(width: 16), close],
        ],
      );
    }
    return SizedBox(
      height: _layout.scale > 1.4 ? 56 : 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          brand,
          if (widget.fromProfile || canBack)
            Align(alignment: Alignment.centerLeft, child: close),
          if (_accountForm)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const ValueKey('auth-mode-switch'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(40, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  textStyle: const TextStyle(fontSize: 12),
                ),
                onPressed: _locked
                    ? null
                    : () => _changeMode(
                        _mode == _AuthMode.signUp
                            ? _AuthMode.signIn
                            : _AuthMode.signUp,
                      ),
                child: Text(_mode == _AuthMode.signUp ? 'Sign in' : 'Sign up'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _modeSwitch() {
    if (!_accountForm) return _backToSignIn();
    final create = _mode == _AuthMode.signUp;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.center,
      children: [
        Text(
          create ? 'Already have an account?' : 'Don’t have an account?',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        TextButton(
          key: const ValueKey('auth-mode-switch'),
          onPressed: _locked
              ? null
              : () => _changeMode(create ? _AuthMode.signIn : _AuthMode.signUp),
          child: Text(create ? 'Sign in' : 'Sign up'),
        ),
      ],
    );
  }

  Widget _desktopIntroduction() {
    final theme = Theme.of(context);
    final (headline, body) = switch (_mode) {
      _AuthMode.signIn => (
        'Make\nhealthier choices\neasier',
        'Scan food labels, understand ingredients and get clear, sourced insights.',
      ),
      _AuthMode.signUp => (
        'Join Unlabel',
        'Start making informed food choices today.',
      ),
      _AuthMode.forgot || _AuthMode.sent => (
        'Reset your\npassword',
        'Get a secure reset link in your email and choose a new password.',
      ),
      _AuthMode.newPassword => (
        'A fresh start',
        'Set your new password to return to your account.',
      ),
      _AuthMode.success => (
        'You’re ready to sign in',
        'Your saved products and account history will be waiting.',
      ),
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_mode == _AuthMode.signIn)
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Make\nhealthier choices\n'),
                TextSpan(
                  text: 'easier',
                  style: TextStyle(color: theme.colorScheme.primary),
                ),
              ],
            ),
            style: theme.textTheme.headlineLarge?.copyWith(fontSize: 40),
          )
        else
          Text(
            headline,
            style: theme.textTheme.headlineLarge?.copyWith(fontSize: 40),
          ),
        const SizedBox(height: 16),
        Text(
          body,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        _artwork(height: 340),
      ],
    );
  }

  Widget _artwork({required double height}) => ExcludeSemantics(
    child: RepaintBoundary(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Image.asset(
          'assets/artwork/$_asset.webp',
          key: ValueKey(_asset),
          fit: BoxFit.contain,
          cacheWidth: 768,
          excludeFromSemantics: true,
        ),
      ),
    ),
  );

  Widget _formCard({required bool desktop}) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final focused = _layout.focused;
    final compactSent = focused && _layout.scale > 1.4 && _layout.height < 720;
    final gap = focused ? 8.0 : 10.0;
    final fields = switch (_mode) {
      _AuthMode.signIn => [_emailField(), _passwordField()],
      _AuthMode.signUp => [_nameField(), _emailField(), _passwordField()],
      _AuthMode.forgot => [_emailField()],
      _AuthMode.newPassword when _verified => [
        _passwordField(newPassword: true),
        _passwordField(confirm: true),
      ],
      _ => <Widget>[],
    };
    final heading = focused && _layout.scale > 1.4
        ? switch (_mode) {
            _AuthMode.signIn => 'Sign in',
            _AuthMode.signUp => 'Create account',
            _AuthMode.forgot => 'Reset password',
            _AuthMode.newPassword => 'New password',
            _AuthMode.sent when compactSent => 'Link sent!',
            _ => _title,
          }
        : _title;
    final content = AutofillGroup(
      onDisposeAction: AutofillContextAction.cancel,
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_layout.minimal) ...[
              Semantics(
                header: true,
                child: Text(
                  heading,
                  key: const ValueKey('auth-title'),
                  textAlign: desktop ? TextAlign.left : TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontSize: focused && _layout.scale > 1.4
                        ? 18
                        : focused
                        ? 22
                        : 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.5,
                    height: 1.15,
                  ),
                ),
              ),
              if (!focused) ...[
                const SizedBox(height: 4),
                Text(
                  _subtitle,
                  textAlign: desktop ? TextAlign.left : TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
              SizedBox(height: gap),
            ],
            if (_mode == _AuthMode.sent && _sentEmail != null) ...[
              if (focused)
                Text(
                  compactSent && _layout.minimal
                      ? 'Reset link requested.'
                      : compactSent
                      ? 'If this email has an account, check your inbox.'
                      : 'If this email has an account, a reset link is on its way.',
                  style: const TextStyle(fontSize: 13, height: 1.25),
                ),
              if (!compactSent)
                Text(
                  _sentEmail!,
                  textAlign: desktop ? TextAlign.left : TextAlign.center,
                  style: TextStyle(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    height: 1.25,
                  ),
                ),
              SizedBox(height: gap),
            ],
            if (_accountForm && !focused) ...[
              _googleButton(),
              const _OrDivider(),
            ],
            if (fields.isNotEmpty) ...[
              if (_layout.paged)
                fields[_fieldStep]
              else if (_layout.wideFields && fields.length > 1) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: fields[0]),
                    const SizedBox(width: 12),
                    Expanded(child: fields[1]),
                  ],
                ),
                if (fields.length > 2) ...[SizedBox(height: gap), fields[2]],
              ] else
                for (final entry in fields.indexed) ...[
                  if (entry.$1 > 0) SizedBox(height: gap),
                  entry.$2,
                ],
              if ((_mode == _AuthMode.signUp ||
                      _mode == _AuthMode.newPassword) &&
                  _layout.showHints) ...[
                const SizedBox(height: 6),
                _passwordHints(),
              ],
            ],
            if (_mode == _AuthMode.newPassword && _verifying) ...[
              Semantics(
                liveRegion: true,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Flexible(child: Text('Checking reset link…')),
                  ],
                ),
              ),
              SizedBox(height: gap),
            ],
            if (_error != null) ...[
              SizedBox(height: gap),
              if (focused)
                Semantics(
                  liveRegion: true,
                  label: '$_error View error',
                  child: TextButton.icon(
                    key: const ValueKey('auth-error-details'),
                    onPressed: () => _showErrorDetails(_error!),
                    icon: Icon(Icons.error_outline, color: scheme.error),
                    label: const Text('View error'),
                  ),
                )
              else
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: TextStyle(color: scheme.error, fontSize: 12),
                  ),
                ),
            ],
            if (_mode == _AuthMode.signIn && !focused)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const ValueKey('auth-forgot'),
                  onPressed: _locked
                      ? null
                      : () => _changeMode(_AuthMode.forgot),
                  child: const Text('Forgot password?'),
                ),
              ),
            if (_accountForm ||
                _mode == _AuthMode.forgot ||
                (_mode == _AuthMode.newPassword && _verified)) ...[
              SizedBox(height: gap),
              _submitButton(),
            ],
            if (_mode == _AuthMode.newPassword &&
                !_verifying &&
                !_verified) ...[
              SizedBox(height: gap),
              FilledButton(
                onPressed: _locked ? null : () => _changeMode(_AuthMode.forgot),
                child: const Text('Request a new reset link'),
              ),
            ],
            if (_accountForm && !focused) ...[
              const _OrDivider(),
              _guestButton(),
              if (_layout.showHints) ...[
                const SizedBox(height: 4),
                Text(
                  'Explore the app without an account',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
              _informationLinks(),
            ],
            if (_accountForm && focused && !_layout.minimal) ...[
              const SizedBox(height: 6),
              _optionsMenu(),
            ],
            if (_mode == _AuthMode.forgot) ...[
              if (!focused) ...[
                const SizedBox(height: 16),
                _noticePanel([
                  (
                    Icons.info_outline,
                    'Check your inbox and spam folder for the reset link.',
                  ),
                ]),
              ],
              if (!_layout.minimal) _backToSignIn(),
            ],
            if (_mode == _AuthMode.sent) ...[
              if (!focused)
                _noticePanel([
                  (Icons.mail_outline, 'Check your inbox and spam folder'),
                  (Icons.link, 'Click the link in the email'),
                  (Icons.lock_outline, 'Create a new password'),
                ]),
              SizedBox(height: gap),
              FilledButton(
                onPressed: _locked ? null : () => _changeMode(_AuthMode.signIn),
                child: Text(compactSent ? 'Sign in' : 'Back to sign in'),
              ),
              TextButton(
                onPressed: _locked ? null : () => _changeMode(_AuthMode.forgot),
                child: Text(
                  compactSent ? 'Change email' : 'Use a different email',
                ),
              ),
            ],
            if (_mode == _AuthMode.success) ...[
              if (focused)
                Text(
                  _layout.minimal
                      ? 'Password updated!'
                      : 'Your password has been changed successfully.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, height: 1.25),
                ),
              SizedBox(height: gap),
              FilledButton(
                key: const ValueKey('auth-success-signin'),
                onPressed: () => _changeMode(_AuthMode.signIn),
                child: Text(
                  _layout.minimal ? 'Sign in' : 'Continue to sign in',
                ),
              ),
            ],
          ],
        ),
      ),
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    );
    final controlHeight = _layout.scale > 1.4 ? 56.0 : 44.0;
    final controlStyle = FilledButton.styleFrom(
      minimumSize: Size(44, controlHeight),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      shape: shape,
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    );
    final styledContent = Theme(
      data: theme.copyWith(
        filledButtonTheme: FilledButtonThemeData(style: controlStyle),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: Size(44, controlHeight),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: shape,
            side: BorderSide(color: scheme.outlineVariant),
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            minimumSize: Size(32, _layout.scale > 1.4 ? 48 : 32),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            textStyle: const TextStyle(fontSize: 12),
          ),
        ),
      ),
      child: content,
    );
    if (!desktop) return styledContent;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(padding: const EdgeInsets.all(28), child: styledContent),
    );
  }

  Widget _googleButton() => OutlinedButton.icon(
    key: const ValueKey('auth-google'),
    onPressed: _locked ? null : _google,
    style: OutlinedButton.styleFrom(
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
    ),
    icon: SvgPicture.asset(
      'assets/brand/google-g.svg',
      width: 19,
      height: 19,
      excludeFromSemantics: true,
    ),
    label: const Text('Continue with Google'),
  );

  Widget _guestButton() => FilledButton.tonal(
    key: const ValueKey('auth-guest'),
    onPressed: _locked ? null : _leaveAuth,
    style: FilledButton.styleFrom(
      backgroundColor: Theme.of(context).colorScheme.primary
          .withValues(alpha: .08),
      foregroundColor: Theme.of(context).colorScheme.primary,
    ),
    child: const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FeatureIcon('user', size: 20),
        SizedBox(width: 8),
        Flexible(child: Text('Continue as guest')),
      ],
    ),
  );

  Widget _optionsMenu() => PopupMenuButton<String>(
    key: const ValueKey('auth-options'),
    enabled: !_locked,
    tooltip: 'Account options',
    onSelected: (choice) {
      switch (choice) {
        case 'google':
          _google();
        case 'guest':
          _leaveAuth();
        case 'forgot':
          _changeMode(_AuthMode.forgot);
        case 'mode':
          _changeMode(
            _mode == _AuthMode.signUp ? _AuthMode.signIn : _AuthMode.signUp,
          );
        case 'privacy':
          _information(privacy: true);
        case 'terms':
          _information(privacy: false);
      }
    },
    itemBuilder: (_) => [
      const PopupMenuItem(value: 'google', child: Text('Continue with Google')),
      const PopupMenuItem(value: 'guest', child: Text('Continue as guest')),
      const PopupMenuItem(value: 'forgot', child: Text('Forgot password?')),
      PopupMenuItem(
        value: 'mode',
        child: Text(_mode == _AuthMode.signUp ? 'Sign in' : 'Sign up'),
      ),
      const PopupMenuItem(value: 'terms', child: Text('Terms')),
      const PopupMenuItem(value: 'privacy', child: Text('Privacy Policy')),
    ],
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_layout.minimal) const Flexible(child: Text('Account options')),
          const Icon(Icons.more_horiz, size: 24),
        ],
      ),
    ),
  );

  Future<void> _showErrorDetails(String error) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Could not finish'),
      scrollable: true,
      content: Text(error),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );

  InputDecoration _decoration(String hint, IconData icon, {Widget? suffix}) {
    final scheme = Theme.of(context).colorScheme;
    return InputDecoration(
      isDense: true,
      hintText: hint,
      prefixIcon: Icon(icon, size: 20),
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      errorStyle: const TextStyle(fontSize: 12, height: 1.15),
      errorMaxLines: 2,
      fillColor: scheme.surfaceContainerLowest,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _labelled(String label, Widget field) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          if (_layout.paged && _fieldStep > 0)
            IconButton(
              key: const ValueKey('auth-previous-field'),
              tooltip: 'Previous field',
              style: IconButton.styleFrom(
                minimumSize: const Size(36, 36),
                padding: const EdgeInsets.all(4),
              ),
              onPressed: _locked
                  ? null
                  : () {
                      FocusScope.of(context).unfocus();
                      setState(() => _fieldStep--);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _fieldFocus[_fieldStep].requestFocus();
                      });
                    },
              icon: const Icon(Icons.arrow_back, size: 18),
            ),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Semantics(label: label, child: field),
    ],
  );

  Widget _nameField() => _labelled(
    'Name',
    TextFormField(
      key: const ValueKey('auth-name'),
      controller: _name,
      focusNode: _nameFocus,
      style: const TextStyle(fontSize: 14),
      enabled: !_locked,
      decoration: _decoration('Your name', Icons.person_outline),
      autofillHints: const [AutofillHints.name],
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.next,
      onFieldSubmitted: (_) =>
          _layout.paged ? _submit() : _emailFocus.requestFocus(),
      maxLength: 80,
      buildCounter: (
        _, {
        required currentLength,
        required isFocused,
        maxLength,
      }) => null,
      validator: _nameError,
    ),
  );

  Widget _emailField() => _labelled(
    'Email',
    TextFormField(
      key: const ValueKey('auth-email'),
      controller: _email,
      focusNode: _emailFocus,
      style: const TextStyle(fontSize: 14),
      enabled: !_locked,
      decoration: _decoration('you@example.com', Icons.mail_outline),
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email, AutofillHints.username],
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: _mode == _AuthMode.forgot
          ? TextInputAction.done
          : TextInputAction.next,
      onFieldSubmitted: (_) => _mode == _AuthMode.forgot || _layout.paged
          ? _submit()
          : _passwordFocus.requestFocus(),
      validator: _emailError,
    ),
  );

  Widget _passwordField({bool newPassword = false, bool confirm = false}) {
    final visible = confirm ? _showConfirm : _showPassword;
    final creating =
        _mode == _AuthMode.signUp || _mode == _AuthMode.newPassword;
    return _labelled(
      confirm
          ? 'Confirm new password'
          : newPassword
          ? 'New password'
          : 'Password',
      TextFormField(
        key: ValueKey(confirm ? 'auth-confirm-password' : 'auth-password'),
        controller: confirm ? _confirm : _password,
        focusNode: confirm ? _confirmFocus : _passwordFocus,
        style: const TextStyle(fontSize: 14),
        enabled: !_locked,
        decoration: _decoration(
          confirm
              ? 'Re-enter password'
              : creating
              ? 'Create a password'
              : 'Enter your password',
          Icons.lock_outline,
          suffix: IconButton(
            tooltip: visible
                ? 'Hide ${confirm ? 'confirmed ' : ''}password'
                : 'Show ${confirm ? 'confirmed ' : ''}password',
            onPressed: _locked
                ? null
                : () => setState(() {
                    if (confirm) {
                      _showConfirm = !_showConfirm;
                    } else {
                      _showPassword = !_showPassword;
                    }
                  }),
            icon: Icon(
              visible
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 20,
            ),
          ),
        ),
        obscureText: !visible,
        autocorrect: false,
        enableSuggestions: false,
        autofillHints: [
          creating ? AutofillHints.newPassword : AutofillHints.password,
        ],
        textInputAction: newPassword
            ? TextInputAction.next
            : TextInputAction.done,
        onChanged: creating && !confirm ? (_) => setState(() {}) : null,
        onFieldSubmitted: (_) => newPassword && !_layout.paged
            ? _confirmFocus.requestFocus()
            : _submit(),
        validator: (value) => _passwordError(value, confirm: confirm),
      ),
    );
  }

  String? _nameError(String? value) =>
      value == null || value.trim().isEmpty ? 'Enter your name.' : null;

  String? _emailError(String? value) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value?.trim() ?? '')
      ? null
      : 'Enter a valid email address.';

  String? _passwordError(String? value, {bool confirm = false}) {
    if (value == null || value.isEmpty) return 'Enter your password.';
    if (confirm) {
      return value == _password.text ? null : 'Your passwords don’t match.';
    }
    return _mode == _AuthMode.signUp || _mode == _AuthMode.newPassword
        ? validateNewPassword(value)
        : null;
  }

  Widget _passwordHints() {
    final value = _password.text;
    final checks = [
      ('At least 8 characters', value.length >= 8),
      (
        'Includes a letter and a number',
        RegExp(r'[A-Za-z]').hasMatch(value) && RegExp(r'[0-9]').hasMatch(value),
      ),
      ('Avoid common passwords', value.isNotEmpty && !isCommonPassword(value)),
    ];
    final theme = Theme.of(context);
    return Column(
      children: checks
          .map(
            (check) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(
                    check.$2
                        ? Icons.check_circle_outline
                        : Icons.radio_button_unchecked,
                    size: 16,
                    color: check.$2
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(check.$1, style: theme.textTheme.bodySmall),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _submitButton() => FilledButton(
    key: const ValueKey('account-submit'),
    onPressed: _locked ? null : _submit,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
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
            _layout.paged && _fieldStep < _fieldFocus.length - 1
                ? 'Next'
                : switch (_mode) {
                    _AuthMode.signUp => 'Create account',
                    _AuthMode.forgot => 'Send reset link',
                    _AuthMode.newPassword => 'Update password',
                    _ => 'Sign in',
                  },
          ),
        ),
      ],
    ),
  );

  Widget _backToSignIn() => TextButton.icon(
    onPressed: _locked ? null : () => _changeMode(_AuthMode.signIn),
    icon: const Icon(Icons.arrow_back, size: 18),
    label: const Text('Back to sign in'),
  );

  Widget _noticePanel(List<(IconData, String)> rows) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer
          .withValues(alpha: .4),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: rows.indexed
          .map(
            (entry) => Padding(
              padding: EdgeInsets.only(top: entry.$1 == 0 ? 0 : 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    entry.$2.$1,
                    size: 22,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(entry.$2.$2)),
                ],
              ),
            ),
          )
          .toList(),
    ),
  );

  Widget _informationLinks() => Wrap(
    alignment: WrapAlignment.center,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      TextButton(
        onPressed: () => _information(privacy: false),
        child: const Text('Terms'),
      ),
      TextButton(
        onPressed: () => _information(privacy: true),
        child: const Text('Privacy Policy'),
      ),
    ],
  );

  Future<void> _information({required bool privacy}) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(privacy ? 'Privacy Policy' : 'Using Unlabel'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Text(
            privacy
                ? 'Guest history and saved products stay on this device. Signing in opens a separate private account library. You choose which library to keep if cloud and device copies differ. Google sign-in supplies your name and profile photo. Photos you scan and raw text are not part of private library sync.'
                : 'Unlabel explains sourced food-label facts and shows missing information as unknown. It does not certify product compliance or replace professional health advice. You can use scanning, saved products and history as a guest; an account is optional.',
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        const Expanded(child: Divider(height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('or', style: Theme.of(context).textTheme.bodySmall),
        ),
        const Expanded(child: Divider(height: 1)),
      ],
    ),
  );
}

class _AuthLayout {
  const _AuthLayout({
    required this.width,
    required this.height,
    required this.scale,
    required this.keyboard,
  });
  final double width, height, scale;
  final bool keyboard;
  bool get focused =>
      keyboard || height < (width >= 900 ? 800 : 700) || scale > 1.3;
  bool get desktop => width >= 900 && !focused;
  bool get minimal => height < 340;
  bool get paged => focused && (height < 400 || (height < 700 && scale > 1.4));
  bool get wideFields => focused && width >= 560;
  bool get showHints => !focused && height >= 790;
}
