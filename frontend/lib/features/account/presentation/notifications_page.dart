import 'package:flutter/material.dart';

import '../../../core/interaction/ui_feedback.dart';
import '../../../core/models/app_failure.dart';
import '../../../core/notifications/notification_controller.dart';
import '../../scanner/presentation/ui_components.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({required this.controller, super.key});
  final NotificationController controller;
  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
      await UiFeedback.confirmed();
    } on AppFailure catch (failure) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(failure.userMessage)));
      }
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final theme = Theme.of(context), c = controller;
      final time = TimeOfDay(hour: c.hour, minute: c.minute).format(context);
      final today = DateTime.now().toUtc();
      final webTime = DateTime.utc(
        today.year,
        today.month,
        today.day,
        13,
        30,
      ).toLocal();
      final webEnd = webTime.add(const Duration(hours: 1));
      final window =
          '${TimeOfDay.fromDateTime(webTime).format(context)}–${TimeOfDay.fromDateTime(webEnd).format(context)}';
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: PageBody(
          maxWidth: 800,
          children: [
            if (c.loading) const LinearProgressIndicator(),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Daily label-reading reminder',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    c.gateway.webPush
                        ? 'A gentle reminder around $window each day. Delivered by your browser, even when this page is closed.'
                        : 'A gentle reminder at $time each day. Scheduled on this device, with no internet needed.',
                  ),
                  const SizedBox(height: 16),
                  if (c.gateway.supported)
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Daily reminder'),
                      subtitle: Text(
                        c.reminderEnabled
                            ? 'On for this device'
                            : 'Off for this device',
                      ),
                      value: c.reminderEnabled,
                      onChanged: c.busy || c.loading
                          ? null
                          : (value) => c.setReminder(value),
                    )
                  else
                    const Text(
                      'To enable reminders on iPhone or iPad, add Unlabel to the Home Screen and open it there. Other devices need a browser that supports notifications.',
                    ),
                  if (c.reminderEnabled && c.gateway.supported) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        if (!c.gateway.webPush)
                          OutlinedButton.icon(
                            icon: const Icon(Icons.schedule),
                            label: Text('Change time · $time'),
                            onPressed: c.busy
                                ? null
                                : () async {
                                    final selected = await showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay(
                                        hour: c.hour,
                                        minute: c.minute,
                                      ),
                                    );
                                    if (selected != null) {
                                      await c.setReminder(
                                        true,
                                        atHour: selected.hour,
                                        atMinute: selected.minute,
                                      );
                                    }
                                  },
                          ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.notifications_active_outlined),
                          label: const Text('Send test notification'),
                          onPressed: c.busy ? null : c.test,
                        ),
                      ],
                    ),
                  ],
                  if (c.reminderEnabled)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        icon: const Icon(Icons.notifications_off_outlined),
                        label: const Text('Unsubscribe from reminders'),
                        onPressed: c.busy ? null : () => c.setReminder(false),
                      ),
                    ),
                  if (c.busy) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                  ],
                  if (c.error != null) ...[
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        c.error!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 28),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 8,
              children: [
                Text('Your inbox', style: theme.textTheme.headlineSmall),
                Wrap(
                  spacing: 4,
                  children: [
                    IconButton(
                      tooltip: 'Refresh app updates',
                      onPressed: c.loading ? null : c.refresh,
                      icon: const Icon(Icons.refresh),
                    ),
                    if (c.unread > 0)
                      TextButton(
                        onPressed: () => _run(context, () => c.markRead()),
                        child: const Text('Mark all read'),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'App updates and scan activity stay in this browser or app. No label photos or product details are included.',
              style: theme.textTheme.bodySmall,
            ),
            if (c.feedError != null) ...[
              const SizedBox(height: 12),
              Text(c.feedError!),
              TextButton(
                onPressed: c.refresh,
                child: const Text('Retry app updates'),
              ),
            ],
            const SizedBox(height: 20),
            if (c.entries.isEmpty)
              const SectionCard(
                child: Column(
                  children: [
                    Icon(Icons.notifications_none_outlined, size: 36),
                    SizedBox(height: 12),
                    Text('You’re all caught up'),
                    SizedBox(height: 8),
                    Text(
                      'App updates and completed scan activity will appear here.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            for (final entry in c.entries) ...[
              SectionCard(
                padding: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          entry.read
                              ? Icons.notifications_none
                              : Icons.notifications_active_outlined,
                          color: entry.read
                              ? theme.colorScheme.onSurfaceVariant
                              : theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            entry.title,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(entry.body),
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      children: [
                        Text(
                          MaterialLocalizations.of(context)
                              .formatMediumDate(entry.at.toLocal()),
                          style: theme.textTheme.bodySmall,
                        ),
                        if (!entry.read)
                          TextButton(
                            onPressed: () =>
                                _run(context, () => c.markRead(entry.id)),
                            child: const Text('Mark read'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (c.entries.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Clear this inbox?'),
                        content: const Text(
                          'Remove these messages from this device. Your reports and reminder settings stay as they are.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Clear inbox'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true && context.mounted) {
                      await _run(context, c.clear);
                    }
                  },
                  child: const Text('Clear inbox'),
                ),
              ),
          ],
        ),
      );
    },
  );
}
