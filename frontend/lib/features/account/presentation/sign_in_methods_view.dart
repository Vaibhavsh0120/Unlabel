import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/accounts/account_auth.dart';

/// Presentation only: provider ownership and reauthentication remain in the SDK.
class SignInMethodsView extends StatelessWidget {
  const SignInMethodsView({
    required this.identity,
    required this.busy,
    required this.onClose,
    required this.onGoogle,
    required this.onPassword,
    required this.onDelete,
    required this.onChangeEmail,
    required this.onChangePassword,
    required this.onSwitchGoogle,
    this.error,
    super.key,
  });

  final AccountIdentity? identity;
  final bool busy;
  final String? error;
  final VoidCallback onClose, onGoogle, onPassword, onDelete;
  final VoidCallback onChangeEmail, onChangePassword, onSwitchGoogle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final mobile = MediaQuery.sizeOf(context).width < 600;
    final hasPassword = identity?.hasPassword == true;
    final hasGoogle = identity?.hasGoogle == true;
    final locked = busy || identity == null;
    final green = dark ? const Color(0xff50d6b0) : const Color(0xff00725d);
    final mint = dark ? const Color(0xff17342d) : const Color(0xffeafbf5);
    final muted = colors.onSurfaceVariant;
    final email = identity?.googleEmail ?? identity?.email;
    final masked = email == null || !email.contains('@')
        ? 'Google account connected'
        : '${email.substring(0, 1)}••••@${email.split('@').last}';

    Widget iconCircle(Widget icon, {Color? color}) => Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color ?? mint, shape: BoxShape.circle),
      child: icon,
    );
    Widget card(Widget child) => Container(
      padding: EdgeInsets.all(mobile ? 16 : 22),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .35)),
        boxShadow: [
          BoxShadow(
            color: green.withValues(alpha: .035),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
    Widget title(String value) => Text(
      value,
      style: theme.textTheme.titleMedium?.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
    );
    Widget subtitle(String value) => Text(
      value,
      style: theme.textTheme.bodyMedium?.copyWith(
        fontSize: 14,
        color: muted,
        height: 1.4,
      ),
    );
    Widget options(String label, Map<String, VoidCallback> actions) =>
        PopupMenuButton<String>(
          tooltip: label,
          enabled: !locked,
          onSelected: (value) => actions[value]?.call(),
          itemBuilder: (_) => [
            for (final label in actions.keys)
              PopupMenuItem(value: label, child: Text(label)),
          ],
          icon: const Icon(Icons.more_horiz, size: 21),
        );
    Widget providerRow(Widget icon, Widget text, Widget action) =>
        LayoutBuilder(
          builder: (context, bounds) {
            final large = MediaQuery.textScalerOf(context).scale(14) > 21;
            final content = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                iconCircle(icon),
                const SizedBox(width: 16),
                Expanded(child: text),
                if (!large) ...[const SizedBox(width: 10), action],
              ],
            );
            return large
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      content,
                      const SizedBox(height: 12),
                      Align(alignment: Alignment.centerRight, child: action),
                    ],
                  )
                : content;
          },
        );
    Widget info({
      required String heading,
      required String body,
      required IconData icon,
      required Color background,
      required Color foreground,
    }) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          iconCircle(
            Icon(icon, color: foreground, size: 26),
            color: foreground.withValues(alpha: .07),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  heading,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                subtitle(body),
              ],
            ),
          ),
        ],
      ),
    );

    return PopScope(
      canPop: !busy,
      child: Dialog(
        key: const ValueKey('profile-sign-in-methods'),
        backgroundColor: colors.surface,
        insetPadding: EdgeInsets.all(mobile ? 0 : 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(mobile ? 0 : 24),
        ),
        child: SizedBox(
          width: mobile ? double.infinity : 860,
          height: mobile
              ? double.infinity
              : math.min(820, MediaQuery.sizeOf(context).height - 48),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(mobile ? 8 : 20, 8, 12, 4),
                  child: Row(
                    children: [
                      TextButton.icon(
                        onPressed: busy ? null : onClose,
                        icon: const Icon(Icons.arrow_back_ios_new, size: 19),
                        label: Text(mobile ? 'Back' : 'Profile'),
                      ),
                      if (mobile)
                        Expanded(
                          child: Center(
                            child: Text(
                              'Sign-in methods',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      if (mobile)
                        const SizedBox(width: 64)
                      else ...[
                        const Spacer(),
                        IconButton(
                          tooltip: 'Close sign-in methods',
                          onPressed: busy ? null : onClose,
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      mobile ? 16 : 30,
                      mobile ? 24 : 8,
                      mobile ? 16 : 30,
                      24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sign-in methods',
                                    style: theme.textTheme.headlineMedium
                                        ?.copyWith(
                                          fontSize: mobile ? 25 : 30,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  subtitle(
                                    'Choose how you want to sign in. You can keep one or both methods enabled.',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ExcludeSemantics(
                              child: SizedBox(
                                width: mobile ? 72 : 106,
                                height: mobile ? 85 : 100,
                                child: CustomPaint(
                                  painter: _MethodsCloud(
                                    mint,
                                    colors.onSurface,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        card(
                          providerRow(
                            Icon(
                              Icons.mark_email_read_outlined,
                              color: colors.onSurface,
                              size: 27,
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                title('Email & password'),
                                const SizedBox(height: 5),
                                subtitle(
                                  'Sign in with your email address and password.',
                                ),
                                if (!hasPassword)
                                  TextButton(
                                    onPressed: locked ? null : onPassword,
                                    child: const Text('Add email and password'),
                                  ),
                              ],
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Semantics(
                                  label: 'Email & password sign-in',
                                  child: Switch.adaptive(
                                    key: const ValueKey(
                                      'sign-in-password-toggle',
                                    ),
                                    value: hasPassword,
                                    activeTrackColor: green,
                                    onChanged:
                                        locked || (hasPassword && !hasGoogle)
                                        ? null
                                        : (_) => onPassword(),
                                  ),
                                ),
                                if (hasPassword)
                                  options('Email and password options', {
                                    'Change email': onChangeEmail,
                                    'Change password': onChangePassword,
                                  }),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        card(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              providerRow(
                                SvgPicture.asset(
                                  'assets/brand/google-g.svg',
                                  width: 28,
                                  height: 28,
                                  excludeFromSemantics: true,
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    title('Google account'),
                                    const SizedBox(height: 5),
                                    subtitle(
                                      'Sign in with your Google account for a faster and easier experience.',
                                    ),
                                  ],
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        foregroundColor: hasGoogle
                                            ? colors.error
                                            : green,
                                        backgroundColor: hasGoogle
                                            ? colors.errorContainer.withValues(
                                                alpha: .4,
                                              )
                                            : mint,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                        ),
                                        minimumSize: const Size(0, 44),
                                      ),
                                      onPressed:
                                          locked || (hasGoogle && !hasPassword)
                                          ? null
                                          : onGoogle,
                                      child: Text(
                                        hasGoogle
                                            ? 'Disconnect'
                                            : 'Connect Google',
                                      ),
                                    ),
                                    if (hasGoogle && hasPassword)
                                      options('Google account options', {
                                        'Switch account': onSwitchGoogle,
                                      }),
                                  ],
                                ),
                              ),
                              if (hasGoogle) ...[
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 14),
                                  child: Divider(height: 1),
                                ),
                                Row(
                                  children: [
                                    iconCircle(Icon(Icons.check, color: green)),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Connected',
                                            style: TextStyle(
                                              color: green,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          subtitle(masked),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        info(
                          heading: 'Both methods can be active at once',
                          body: 'You can sign in with either method whenever you like.',
                          icon: Icons.auto_awesome_outlined,
                          background: mint,
                          foreground: green,
                        ),
                        const SizedBox(height: 12),
                        info(
                          heading: 'Keep your account secure',
                          body: 'At least one sign-in method must remain active at all times.',
                          icon: Icons.shield_outlined,
                          background: colors.surfaceContainerLow,
                          foreground: colors.onSurface,
                        ),
                        const SizedBox(height: 14),
                        Material(
                          color: colors.errorContainer.withValues(alpha: .16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: BorderSide(
                              color: colors.error.withValues(alpha: .22),
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: locked ? null : onDelete,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  iconCircle(
                                    Icon(
                                      Icons.delete_outline,
                                      color: colors.error,
                                      size: 29,
                                    ),
                                    color: colors.errorContainer.withValues(
                                      alpha: .4,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Delete account',
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(color: colors.error),
                                        ),
                                        const SizedBox(height: 5),
                                        subtitle(
                                          'Permanently delete your account and private library. This cannot be undone.',
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(Icons.chevron_right, color: muted),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (busy)
                          const Padding(
                            padding: EdgeInsets.only(top: 14),
                            child: LinearProgressIndicator(),
                          ),
                        if (error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: Semantics(
                              liveRegion: true,
                              child: Text(
                                error!,
                                style: TextStyle(color: colors.error),
                              ),
                            ),
                          ),
                      ],
                    ),
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

// A small vector illustration, decorative and unrelated to provider status.
class _MethodsCloud extends CustomPainter {
  const _MethodsCloud(this.mint, this.ink);
  final Color mint, ink;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100, size.height / 100);
    final blob = Path()
      ..moveTo(12, 40)
      ..cubicTo(25, 30, 40, 0, 64, 8)
      ..cubicTo(83, 12, 73, 31, 90, 38)
      ..cubicTo(115, 51, 89, 81, 72, 89)
      ..cubicTo(48, 100, 15, 90, 22, 73)
      ..cubicTo(30, 58, -5, 67, 12, 40);
    canvas.drawPath(blob, Paint()..color = mint);
    final cloud = Path()
      ..moveTo(38, 89)
      ..cubicTo(15, 78, 27, 59, 40, 63)
      ..cubicTo(41, 45, 58, 43, 66, 55)
      ..cubicTo(77, 46, 89, 56, 87, 68)
      ..cubicTo(103, 70, 100, 86, 91, 92);
    canvas.drawPath(cloud, Paint()..color = Colors.white);
    canvas.drawPath(
      cloud,
      Paint()
        ..color = ink
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
    canvas.drawCircle(const Offset(57, 74), 2, Paint()..color = ink);
    canvas.drawCircle(const Offset(74, 74), 2, Paint()..color = ink);
    canvas.drawArc(
      const Rect.fromLTWH(61, 76, 9, 7),
      0,
      math.pi,
      false,
      Paint()
        ..color = ink
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
    canvas.drawLine(
      const Offset(60, 36),
      const Offset(57, 27),
      Paint()
        ..color = ink
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      const Offset(73, 35),
      const Offset(76, 25),
      Paint()
        ..color = ink
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_MethodsCloud oldDelegate) =>
      mint != oldDelegate.mint || ink != oldDelegate.ink;
}
