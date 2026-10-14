import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/accounts/account_controller.dart';
import '../../../core/accounts/password_policy.dart';
import '../../../core/models/app_failure.dart';
import 'auth_scene.dart';
import 'auth_widgets.dart';

enum _AuthMode { signIn, signUp, forgot, sent }

/// Real SDK-backed forms. Firebase owns reset-code validation and completion.
/// Passwords remain in these controllers only while the form is open.
class AuthPage extends StatefulWidget {
  const AuthPage({
    required this.controller,
    this.create = false,
    this.fromProfile = true,
    this.onComplete,
    super.key,
  });
  final AccountController controller;
  final bool create, fromProfile;
  final VoidCallback? onComplete;
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage>
    with SingleTickerProviderStateMixin {
  var _form = GlobalKey<FormState>();
  final _scroll = ScrollController();
  final _name = TextEditingController(), _email = TextEditingController();
  final _password = TextEditingController(), _confirm = TextEditingController();
  final _nameFocus = FocusNode(), _emailFocus = FocusNode();
  final _passwordFocus = FocusNode(), _confirmFocus = FocusNode();
  late final _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  late _AuthMode _mode;
  String? _error, _sentEmail;
  bool _busy = false, _showPassword = false, _showConfirm = false;
  bool _celebrating = false;
  int _reaction = 0;
  bool _keyboardShown = false;
  double _offsetBeforeKeyboard = 0;
  int _keyboardTransition = 0;
  bool get _locked => _busy || widget.controller.authBusy;
  bool get _creating => _mode == _AuthMode.signUp;
  bool get _accountForm => _mode == _AuthMode.signIn || _creating;
  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  @override
  void initState() {
    super.initState();
    _mode = widget.create ? _AuthMode.signUp : _AuthMode.signIn;
    widget.controller.addListener(_accountChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduceMotion) {
      _entrance.value = 1;
    } else if (_entrance.value == 0) {
      _entrance.forward();
    }
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
    _password.clear();
    _confirm.clear();
    for (final field in [_name, _email, _password, _confirm]) {
      field.dispose();
    }
    for (final node in [
      _nameFocus,
      _emailFocus,
      _passwordFocus,
      _confirmFocus,
    ]) {
      node.dispose();
    }
    _entrance.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _changeMode(_AuthMode mode) {
    if (_locked) return;
    FocusScope.of(context).unfocus();
    _form = GlobalKey<FormState>();
    _offsetBeforeKeyboard = 0;
    setState(() {
      _mode = mode;
      _error = null;
      _password.clear();
      _confirm.clear();
      _showPassword = false;
      _showConfirm = false;
      _celebrating = false;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    if (!_reduceMotion) _entrance.forward(from: 0);
  }

  String? _nameError(String? value) =>
      value == null || value.trim().isEmpty ? 'Enter your name.' : null;
  String? _emailError(String? value) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value?.trim() ?? '')
      ? null
      : 'Enter a valid email address.';
  String? _passwordError(String? value) {
    if (value == null || value.isEmpty) return 'Enter your password.';
    return _creating ? validateNewPassword(value) : null;
  }

  String? _confirmError(String? value) =>
      value == _password.text ? null : 'Passwords do not match.';

  Future<void> _submit() async {
    if (_locked) return;
    setState(() {
      _reaction++;
      _error = null;
    });
    if (!(_form.currentState?.validate() ?? false)) {
      final fields = [
        if (_creating) (_nameFocus, _nameError(_name.text)),
        (_emailFocus, _emailError(_email.text)),
        if (_accountForm) (_passwordFocus, _passwordError(_password.text)),
        if (_creating) (_confirmFocus, _confirmError(_confirm.text)),
      ];
      fields.firstWhere((field) => field.$2 != null).$1.requestFocus();
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      switch (_mode) {
        case _AuthMode.signIn:
          await widget.controller.signIn(_email.text.trim(), _password.text);
          if (!mounted) return;
          TextInput.finishAutofillContext();
          _password.clear();
          await _completeAuthentication();
        case _AuthMode.signUp:
          await widget.controller.create(
            _email.text.trim(),
            _password.text,
            displayName: _name.text.trim(),
          );
          if (!mounted) return;
          TextInput.finishAutofillContext();
          _password.clear();
          _confirm.clear();
          await _completeAuthentication();
        case _AuthMode.forgot:
          final email = _email.text.trim();
          await widget.controller.resetPassword(email);
          if (!mounted) return;
          setState(() {
            _sentEmail = email;
            _mode = _AuthMode.sent;
          });
          if (_scroll.hasClients) _scroll.jumpTo(0);
        case _AuthMode.sent:
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
      _reaction++;
    });
    try {
      await widget.controller.signInGoogle();
      if (mounted) await _completeAuthentication();
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

  Future<void> _completeAuthentication() async {
    // Reached only after the real controller operation has completed successfully.
    setState(() => _celebrating = true);
    if (!_reduceMotion) {
      await Future<void>.delayed(const Duration(milliseconds: 560));
    }
    if (mounted) _close();
  }

  void _close() {
    if (widget.onComplete != null) {
      widget.onComplete!();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _leaveAuth() {
    if (_locked) return;
    FocusScope.of(context).unfocus();
    _password.clear();
    _confirm.clear();
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette(context);
    final base = Theme.of(context);
    final authTheme = base.copyWith(
      textTheme: base.textTheme.apply(
        fontFamily: 'Quicksand',
        bodyColor: p.ink,
        displayColor: p.ink,
      ),
      colorScheme: base.colorScheme.copyWith(
        primary: p.green,
        onSurface: p.ink,
        surface: p.paper,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.green,
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          textStyle: p.body(15, bold: true),
        ),
      ),
    );
    return Theme(
      data: authTheme,
      child: PopScope(
        canPop: !_locked,
        child: Scaffold(
          backgroundColor: p.background,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, bounds) {
                final desktop =
                    bounds.maxWidth >= 900 &&
                    bounds.maxHeight >= 600 &&
                    MediaQuery.textScalerOf(context).scale(14) / 14 <= 1.15;
                if (desktop && _keyboardShown) {
                  _keyboardShown = false;
                  _keyboardTransition++;
                }
                return Stack(
                  children: [
                    Positioned.fill(
                      child: desktop ? _desktop(bounds) : _phone(bounds),
                    ),
                    if (widget.fromProfile || !_accountForm)
                      Positioned(
                        left: desktop ? 20 : 8,
                        top: 8,
                        child: IconButton(
                          key: const ValueKey('auth-close'),
                          tooltip: _accountForm
                              ? 'Back to Profile'
                              : 'Back to sign in',
                          style: IconButton.styleFrom(
                            backgroundColor: p.background.withValues(alpha: .9),
                            foregroundColor: p.green,
                          ),
                          onPressed: _locked
                              ? null
                              : _accountForm
                              ? _leaveAuth
                              : () => _changeMode(_AuthMode.signIn),
                          icon: const Icon(Icons.arrow_back_ios_new, size: 19),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _scene({required bool desktop, bool showCopy = true}) => AuthScene(
    key: const ValueKey('auth-layered-scene'),
    desktop: desktop,
    create: _creating,
    entrance: _entrance,
    reaction: _reaction,
    celebrating: _celebrating,
    showCopy: showCopy,
  );

  Widget _desktop(BoxConstraints bounds) {
    final p = AuthPalette(context);
    final width = bounds.maxWidth;
    final s = math.min(width / 1536, bounds.maxHeight / 1024).clamp(.55, 1.12);
    final modeTop = 22 * s;
    final cardTop = math.max(
      (_creating ? 110 : 123) * s,
      modeTop + 44 + 20 * s,
    );
    return SizedBox.expand(
      key: const ValueKey('auth-desktop-composition'),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: width * .555,
            child: _scene(desktop: true),
          ),
          Positioned(
            top: modeTop,
            right: width * .065,
            child: _accountForm
                ? _modeSwitch(desktop: true, scale: s)
                : _backToSignIn(),
          ),
          Positioned(
            // Shared edges keep login and signup exactly the same width.
            left: width * .6194,
            right: width * .0644,
            top: cardTop,
            bottom: 52 * s,
            child: AuthEntrance(
              animation: _entrance,
              order: 3,
              child: Container(
                key: const ValueKey('auth-form-card'),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: p.paper,
                  border: p.dark ? Border.all(color: p.border) : null,
                  borderRadius: BorderRadius.circular(30 * s),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: p.dark ? .18 : .025,
                      ),
                      blurRadius: 32,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: 52 * s,
                  vertical: (_creating ? 48 : 64) * s,
                ),
                child: LayoutBuilder(
                  builder: (context, card) {
                    // Content first takes its natural height. Scale down only if
                    // validation messages need extra room; the PC card never scrolls.
                    return FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: card.maxWidth,
                        child: _accountForm
                            ? _accountFields(desktop: true, scale: s)
                            : _resetFields(desktop: true, scale: s),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _followKeyboard(bool shown, double heroHeight) {
    if (shown == _keyboardShown) return;
    _keyboardShown = shown;
    final transition = ++_keyboardTransition;
    if (shown) _offsetBeforeKeyboard = _scroll.hasClients ? _scroll.offset : 0;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted ||
          !_scroll.hasClients ||
          transition != _keyboardTransition) {
        return;
      }
      final target =
          (shown ? math.max(heroHeight, _scroll.offset) : _offsetBeforeKeyboard)
              .clamp(0.0, _scroll.position.maxScrollExtent);
      if (_reduceMotion) {
        _scroll.jumpTo(target);
      } else {
        await _scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
      }
      if (!mounted || !shown || transition != _keyboardTransition) return;
      // A low field may need the entire sheet raised farther above the keyboard.
      for (final node in [
        _nameFocus,
        _emailFocus,
        _passwordFocus,
        _confirmFocus,
      ]) {
        if (node.hasFocus && node.context != null && node.context!.mounted) {
          await Scrollable.ensureVisible(
            node.context!,
            alignment: .45,
            duration: _reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 180),
          );
          break;
        }
      }
    });
  }

  Widget _phone(BoxConstraints bounds) {
    final p = AuthPalette(context);
    final w = bounds.maxWidth;
    final s = (w / 426).clamp(.8, 1.25);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final fullHeight = bounds.maxHeight + keyboard;
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final compact = textScale > 1.15 || fullHeight < 650;
    final heroHeight = compact || !_accountForm
        ? math.min(76.0, fullHeight * .18)
        : math.min((_creating ? 317 : 351) * s, fullHeight * .39);
    _followKeyboard(keyboard > 0, heroHeight);
    return Center(
      child: SizedBox(
        width: w,
        height: bounds.maxHeight,
        child: Stack(
          key: const ValueKey('auth-mobile-composition'),
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: heroHeight,
              child: SizedBox(
                key: const ValueKey('auth-fixed-header'),
                child: compact || !_accountForm
                    ? Stack(
                        children: [
                          Positioned(
                            left: widget.fromProfile || !_accountForm ? 58 : 28,
                            top: 16,
                            child: AuthWordmark(size: 32),
                          ),
                          if (_accountForm)
                            Positioned(
                              right: 12,
                              top: 0,
                              bottom: 0,
                              width: 90,
                              child: _scene(desktop: false, showCopy: false),
                            ),
                        ],
                      )
                    : _scene(desktop: false),
              ),
            ),
            Positioned.fill(
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context)
                    .copyWith(scrollbars: false, overscroll: false),
                // This is a track for the WHOLE card. There is deliberately no
                // scroll viewport inside the card; its border and fields move
                // together while the artwork stays stationary underneath.
                child: SingleChildScrollView(
                  key: const ValueKey('auth-sheet-travel'),
                  controller: _scroll,
                  physics: const ClampingScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.manual,
                  child: Column(
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => FocusScope.of(context).unfocus(),
                        child: SizedBox(height: heroHeight, width: w),
                      ),
                      AuthEntrance(
                        animation: _entrance,
                        order: 3,
                        child: Container(
                          key: const ValueKey('auth-form-card'),
                          width: w,
                          constraints: BoxConstraints(minHeight: fullHeight),
                          decoration: BoxDecoration(
                            color: p.paper,
                            border: p.dark
                                ? Border.all(
                                    color: p.border.withValues(alpha: .5),
                                  )
                                : null,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(40 * s),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: p.dark ? .15 : .035,
                                ),
                                blurRadius: 20,
                                offset: const Offset(0, -3),
                              ),
                            ],
                          ),
                          padding: EdgeInsets.fromLTRB(
                            36 * s,
                            14 * s,
                            36 * s,
                            18 * s,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ExcludeSemantics(
                                child: Center(
                                  child: Container(
                                    key: const ValueKey('auth-sheet-handle'),
                                    width: 48 * s,
                                    height: 5 * s,
                                    decoration: BoxDecoration(
                                      color: p.border.withValues(alpha: .7),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                height: (_creating || compact ? 16 : 27) * s,
                              ),
                              _accountForm
                                  ? _accountFields(
                                      desktop: false,
                                      scale: s,
                                      compact: compact,
                                    )
                                  : _resetFields(desktop: false, scale: s),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _accountFields({
    required bool desktop,
    required double scale,
    bool compact = false,
  }) {
    final p = AuthPalette(context), s = scale;
    final font = (desktop ? 20 : 15) * s;
    final control = math.max(44.0, (desktop ? (_creating ? 55 : 64) : 44) * s);
    final gap = (desktop ? (_creating ? 15 : 22) : (_creating ? 8 : 14)) * s;
    return AutofillGroup(
      onDisposeAction: AutofillContextAction.cancel,
      child: Form(
        key: _form,
        child: Column(
          key: const ValueKey('auth-reference-form'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (desktop || !_creating || compact) ...[
              _heading(
                _creating ? 'Create your account' : 'Welcome back',
                (desktop ? (_creating ? 38 : 44) : (compact ? 24 : 32)) * s,
                singleLine: desktop,
              ),
              SizedBox(height: 8 * s),
              Text(
                _creating
                    ? 'Join unlabel and start making healthier choices today.'
                    : 'Sign in to continue to unlabel',
                style: p.body((desktop ? (_creating ? 23 : 26) : 15.8) * s),
              ),
              SizedBox(height: (desktop ? (_creating ? 22 : 36) : 18) * s),
            ],
            AuthEntrance(
              animation: _entrance,
              order: 4,
              child: _googleButton(
                height: control,
                font: font,
                desktop: desktop,
              ),
            ),
            AuthDivider(
              height:
                  (desktop ? (_creating ? 52 : 78) : (_creating ? 36 : 48)) * s,
              fontSize: font,
            ),
            if (_creating) ...[
              _field(
                keyName: 'auth-name',
                hint: 'Full name',
                icon: Icons.person_outline_rounded,
                controller: _name,
                focus: _nameFocus,
                next: _emailFocus,
                height: control,
                font: font,
                validator: _nameError,
                autofill: const [AutofillHints.name],
                name: true,
              ),
              SizedBox(height: gap),
            ],
            _field(
              keyName: 'auth-email',
              hint: 'Email address',
              icon: Icons.mail_outline_rounded,
              controller: _email,
              focus: _emailFocus,
              next: _passwordFocus,
              height: control,
              font: font,
              validator: _emailError,
              autofill: const [AutofillHints.email, AutofillHints.username],
              email: true,
            ),
            SizedBox(height: gap),
            _field(
              keyName: 'auth-password',
              hint: 'Password',
              icon: Icons.lock_outline_rounded,
              controller: _password,
              focus: _passwordFocus,
              next: _creating ? _confirmFocus : null,
              height: control,
              font: font,
              validator: _passwordError,
              autofill: [
                _creating ? AutofillHints.newPassword : AutofillHints.password,
              ],
              password: true,
            ),
            if (_creating) ...[
              SizedBox(height: gap),
              _field(
                keyName: 'auth-confirm-password',
                hint: 'Confirm password',
                icon: Icons.lock_outline_rounded,
                controller: _confirm,
                focus: _confirmFocus,
                height: control,
                font: font,
                validator: _confirmError,
                autofill: const [AutofillHints.newPassword],
                password: true,
                confirmation: true,
              ),
              SizedBox(height: 12 * s),
              _passwordHints((desktop ? 14.5 : 12.5) * s),
              SizedBox(height: (desktop ? 24 : 17) * s),
            ] else
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  height: math.max(44, (desktop ? 53 : 36) * s),
                  child: TextButton(
                    key: const ValueKey('auth-forgot'),
                    onPressed: _locked
                        ? null
                        : () => _changeMode(_AuthMode.forgot),
                    child: Text(
                      'Forgot password?',
                      style: p
                          .body((desktop ? 18 : 14) * s, bold: true)
                          .copyWith(color: p.green),
                    ),
                  ),
                ),
              ),
            _errorMessage(font),
            _submitButton(
              height: math.max(
                48,
                (desktop ? (_creating ? 66 : 72) : (_creating ? 48 : 52)) * s,
              ),
              font: (desktop ? 23 : 17) * s,
            ),
            if (!_creating) ...[
              if (desktop)
                AuthDivider(height: 71 * s, fontSize: font)
              else
                SizedBox(height: 12 * s),
              _guestButton(
                height: (desktop ? 88 : 64) * s,
                font: font,
                desktop: desktop,
              ),
            ] else ...[
              SizedBox(height: (desktop ? 21 : 16) * s),
              _legal((desktop ? 14.5 : 12.3) * s),
            ],
            if (!desktop) ...[
              SizedBox(height: (_creating ? 8 : 6) * s),
              _modeSwitch(desktop: false, scale: s),
            ],
          ],
        ),
      ),
    );
  }

  Widget _heading(String text, double size, {bool singleLine = false}) =>
      Semantics(
        header: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: singleLine
                  ? FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        text,
                        key: const ValueKey('auth-title'),
                        style: AuthPalette(context).heading(size),
                        maxLines: 1,
                      ),
                    )
                  : Text(
                      text,
                      key: const ValueKey('auth-title'),
                      style: AuthPalette(context).heading(size),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 5),
              child: AuthAccent(size: size * .55),
            ),
          ],
        ),
      );

  ButtonStyle _buttonStyle(
    double height,
    double font, {
    bool secondary = false,
  }) {
    final p = AuthPalette(context);
    return FilledButton.styleFrom(
      minimumSize: Size(double.infinity, height),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      backgroundColor: secondary ? p.mint.withValues(alpha: .55) : p.button,
      foregroundColor: secondary ? p.ink : Colors.white,
      disabledBackgroundColor: secondary
          ? p.mint
          : p.button.withValues(alpha: .65),
      disabledForegroundColor: secondary ? p.muted : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(height * .28),
      ),
      textStyle: p.body(font, bold: true),
      elevation: 0,
    );
  }

  Widget _googleButton({
    required double height,
    required double font,
    required bool desktop,
  }) {
    final p = AuthPalette(context);
    return AuthPress(
      child: OutlinedButton(
        key: const ValueKey('auth-google'),
        onPressed: _locked ? null : _google,
        style: _buttonStyle(height, font).copyWith(
          backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
          foregroundColor: WidgetStatePropertyAll(p.ink),
          side: WidgetStatePropertyAll(BorderSide(color: p.border, width: 1.2)),
        ),
        child: Row(
          children: [
            Padding(
              padding: EdgeInsets.only(left: desktop ? 12 : 4),
              child: SvgPicture.asset(
                'assets/brand/google-g.svg',
                width: font * 1.6,
                height: font * 1.6,
              ),
            ),
            Expanded(
              child: Text(
                _creating && !desktop
                    ? 'Sign up with Google'
                    : 'Continue with Google',
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(width: font * .7),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required String keyName,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    required FocusNode focus,
    required double height,
    required double font,
    required String? Function(String?) validator,
    required List<String> autofill,
    FocusNode? next,
    bool email = false,
    bool name = false,
    bool password = false,
    bool confirmation = false,
  }) {
    final p = AuthPalette(context);
    final visible = confirmation ? _showConfirm : _showPassword;
    return Semantics(
      label: hint,
      child: TextFormField(
        key: ValueKey(keyName),
        controller: controller,
        focusNode: focus,
        enabled: !_locked,
        style: p.body(font).copyWith(color: p.ink),
        decoration: InputDecoration(
          hintText: hint,
          hintMaxLines: 2,
          hintStyle: p.body(font).copyWith(color: p.muted),
          filled: true,
          fillColor: Colors.transparent,
          isDense: true,
          constraints: BoxConstraints(minHeight: height),
          contentPadding: EdgeInsets.symmetric(
            vertical: math.max(10, (height - font * 1.3 - 2.4) / 2),
            horizontal: 14,
          ),
          prefixIcon: Icon(icon, size: font * 1.28),
          prefixIconColor: p.muted,
          prefixIconConstraints: BoxConstraints(
            minWidth: height,
            minHeight: height - 2.4,
          ),
          suffixIcon: password
              ? IconButton(
                  tooltip: visible
                      ? 'Hide ${confirmation ? 'confirmation password' : 'password'}'
                      : 'Show ${confirmation ? 'confirmation password' : 'password'}',
                  onPressed: _locked
                      ? null
                      : () => setState(() {
                          if (confirmation) {
                            _showConfirm = !_showConfirm;
                          } else {
                            _showPassword = !_showPassword;
                          }
                        }),
                  icon: AnimatedSwitcher(
                    duration: _reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 150),
                    child: Icon(
                      visible
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      key: ValueKey(visible),
                      size: font * 1.25,
                      color: p.muted,
                    ),
                  ),
                )
              : null,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(height * .28),
            borderSide: BorderSide(color: p.border, width: 1.2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(height * .28),
            borderSide: BorderSide(color: p.green, width: 1.8),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(height * .28),
          ),
          errorMaxLines: 3,
          errorStyle: const TextStyle(fontSize: 12, height: 1.2),
        ),
        keyboardType: email ? TextInputType.emailAddress : TextInputType.text,
        textCapitalization: name
            ? TextCapitalization.words
            : TextCapitalization.none,
        autofillHints: autofill,
        obscureText: password && !visible,
        autocorrect: name,
        enableSuggestions: !password && !email,
        textInputAction: next == null
            ? TextInputAction.done
            : TextInputAction.next,
        onFieldSubmitted: (_) => next == null ? _submit() : next.requestFocus(),
        onChanged: _creating && password ? (_) => setState(() {}) : null,
        maxLength: name ? 160 : null,
        buildCounter: (
          _, {
          required currentLength,
          required isFocused,
          maxLength,
        }) => null,
        validator: validator,
      ),
    );
  }

  Widget _passwordHints(double font) {
    final value = _password.text, p = AuthPalette(context);
    final checks = [
      ('At least 8 characters', value.length >= 8),
      (
        'One letter and one number',
        RegExp(r'[A-Za-z]').hasMatch(value) && RegExp(r'[0-9]').hasMatch(value),
      ),
      (
        'One special character (optional)',
        RegExp(r'[^A-Za-z0-9\s]').hasMatch(value),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Column(
        children: checks
            .map(
              (check) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    AnimatedSwitcher(
                      duration: _reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 150),
                      child: Icon(
                        check.$2
                            ? Icons.check_circle_rounded
                            : Icons.check_circle_outline_rounded,
                        key: ValueKey(check.$2),
                        size: font * 1.2,
                        color: check.$2
                            ? p.green
                            : p.muted.withValues(alpha: .6),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(child: Text(check.$1, style: p.body(font))),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _errorMessage(double font) {
    final message = _error == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                key: const ValueKey('auth-error'),
                style: TextStyle(
                  fontSize: math.min(font, 16),
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          );
    return _reduceMotion
        ? message
        : AnimatedSize(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.topCenter,
            child: message,
          );
  }

  Widget _submitButton({required double height, required double font}) =>
      AuthPress(
        child: FilledButton(
          key: const ValueKey('account-submit'),
          onPressed: _locked ? null : _submit,
          style: _buttonStyle(height, font),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_busy) ...[
                SizedBox(
                  width: font,
                  height: font,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Flexible(
                child: Text(
                  _creating
                      ? 'Create account'
                      : _mode == _AuthMode.forgot
                      ? 'Send reset link'
                      : 'Sign in',
                ),
              ),
              if (!_busy) ...[
                const SizedBox(width: 15),
                Icon(Icons.arrow_forward_rounded, size: font * 1.2),
              ],
            ],
          ),
        ),
      );

  Widget _guestButton({
    required double height,
    required double font,
    required bool desktop,
  }) => AuthPress(
    child: FilledButton.tonal(
      key: const ValueKey('auth-guest'),
      onPressed: _locked ? null : _leaveAuth,
      style: _buttonStyle(height, font, secondary: true),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_outline_rounded,
            size: font * 1.8,
            color: AuthPalette(context).green,
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: desktop
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                Text(
                  'Continue as Guest',
                  style: AuthPalette(context).body(font, bold: true),
                ),
                const SizedBox(height: 3),
                Text(
                  'Explore unlabel without an account',
                  style: AuthPalette(context).body(font * .77),
                ),
              ],
            ),
          ),
          if (!desktop) ...[
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: AuthPalette(context).green),
          ],
        ],
      ),
    ),
  );

  Widget _modeSwitch({required bool desktop, required double scale}) {
    final p = AuthPalette(context);
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          _creating
              ? 'Already have an account? '
              : desktop
              ? 'New here? '
              : 'Don’t have an account? ',
          style: p.body((desktop ? 18 : 12.5) * scale),
        ),
        TextButton(
          key: const ValueKey('auth-mode-switch'),
          onPressed: _locked
              ? null
              : () => _changeMode(
                  _creating ? _AuthMode.signIn : _AuthMode.signUp,
                ),
          child: Text(
            _creating
                ? 'Sign in'
                : desktop
                ? 'Create an account'
                : 'Create one',
            style: p
                .body((desktop ? 18 : 13) * scale, bold: true)
                .copyWith(color: p.green),
          ),
        ),
      ],
    );
  }

  Widget _legal(double font) => Column(
    children: [
      Text(
        'By creating an account, you agree to our',
        textAlign: TextAlign.center,
        style: AuthPalette(context).body(font),
      ),
      Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          TextButton(
            onPressed: () => _information(privacy: false),
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 44),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text('Terms of Service', style: TextStyle(fontSize: font)),
          ),
          Text(' and ', style: AuthPalette(context).body(font)),
          TextButton(
            onPressed: () => _information(privacy: true),
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 44),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text('Privacy Policy', style: TextStyle(fontSize: font)),
          ),
          Text('.', style: AuthPalette(context).body(font)),
        ],
      ),
    ],
  );

  Widget _resetFields({required bool desktop, required double scale}) {
    final p = AuthPalette(context), sent = _mode == _AuthMode.sent;
    return AutofillGroup(
      onDisposeAction: AutofillContextAction.cancel,
      child: Form(
        key: _form,
        child: Column(
          key: const ValueKey('auth-reference-reset-form'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/artwork/auth-${sent ? 'sent' : 'forgot'}.webp',
              key: ValueKey(sent ? 'auth-sent' : 'auth-forgot'),
              height: (desktop ? 180 : 135) * scale,
              excludeFromSemantics: true,
            ),
            const SizedBox(height: 18),
            _heading(
              sent ? 'Reset link sent!' : 'Forgot your password?',
              (desktop ? 38 : 28) * scale,
            ),
            const SizedBox(height: 14),
            Text(
              sent
                  ? 'If this email has an account, a reset link is on its way to'
                  : 'Enter your email and we’ll send you a reset link.',
              style: p.body(16 * scale),
            ),
            if (sent) ...[
              const SizedBox(height: 8),
              Text(_sentEmail ?? '', style: p.body(16 * scale, bold: true)),
              const SizedBox(height: 24),
              for (final step in [
                'Open the reset email',
                'Choose a password on Firebase’s secure page',
                'Choose Continue to return to Unlabel',
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text(step, style: p.body(15 * scale)),
                ),
              FilledButton(
                onPressed: () => _changeMode(_AuthMode.signIn),
                style: _buttonStyle(52, 17),
                child: const Text('Back to sign in'),
              ),
              TextButton(
                onPressed: () => _changeMode(_AuthMode.forgot),
                child: const Text('Change email'),
              ),
            ] else ...[
              const SizedBox(height: 24),
              _field(
                keyName: 'auth-email',
                hint: 'Email address',
                icon: Icons.mail_outline_rounded,
                controller: _email,
                focus: _emailFocus,
                height: 52,
                font: 16,
                validator: _emailError,
                autofill: const [AutofillHints.email],
                email: true,
              ),
              const SizedBox(height: 18),
              _errorMessage(15),
              _submitButton(height: 52, font: 17),
              const SizedBox(height: 18),
              Text(
                'Check your inbox and spam folder for the reset link.',
                style: p.body(14),
              ),
              _backToSignIn(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _backToSignIn() => TextButton.icon(
    onPressed: _locked ? null : () => _changeMode(_AuthMode.signIn),
    icon: const Icon(Icons.arrow_back, size: 18),
    label: const Text('Back to sign in'),
  );

  Future<void> _information({required bool privacy}) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(privacy ? 'Privacy Policy' : 'Using Unlabel'),
      scrollable: true,
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Text(
          privacy
              ? 'Guest history and saved products stay on this device. Signing in opens a separate private account library. You choose which library to keep if cloud and device copies differ. Google sign-in supplies your name and profile photo. Photos you scan and raw text are not part of private library sync.'
              : 'Unlabel explains sourced food-label facts and shows missing information as unknown. It does not certify product compliance or replace professional health advice. You can use scanning, saved products and history as a guest; an account is optional.',
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
