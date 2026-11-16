import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../notifications/notification_controller.dart';

/// Matches the bundled Solar line icons used by the adjacent search control.
class NotificationBell extends StatelessWidget {
  const NotificationBell({required this.onPressed, super.key});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final count = NotificationScope.maybeOf(context)?.unread ?? 0;
    return IconButton(
      onPressed: onPressed,
      tooltip: count > 0 ? 'Notifications, $count unread' : 'Notifications',
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(count > 9 ? '9+' : '$count'),
        child: SvgPicture.asset(
          'assets/icons/bell-linear.svg',
          width: 26,
          height: 26,
          colorFilter: ColorFilter.mode(
            Theme.of(context).colorScheme.primary,
            BlendMode.srcIn,
          ),
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}
