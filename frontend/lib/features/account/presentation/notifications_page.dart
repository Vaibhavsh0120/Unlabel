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

  Future<void> _clear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear notifications?'),
        content: const Text(
          'Remove messages from this device. Your reports and reminder settings stay saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear notifications'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await _run(context, controller.clear);
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
              key: const ValueKey('daily-reminder-card'),
              padding: MediaQuery.sizeOf(context).width < 600 ? 16 : 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Daily label reminder',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      if (c.gateway.supported)
                        Semantics(
                          label: 'Daily label reminder',
                          child: Switch.adaptive(
                            key: const ValueKey('daily-reminder-toggle'),
                            value: c.reminderEnabled,
                            onChanged: c.busy || c.loading
                                ? null
                                : (value) => c.setReminder(value),
                          ),
                        ),
                    ],
                  ),
                  Text(
                    !c.gateway.supported
                        ? 'For iPhone or iPad, open Unlabel from your Home Screen to enable reminders.'
                        : c.gateway.webPush
                        ? '${c.reminderEnabled ? "On" : "Off"} · Around $window daily'
                        : '${c.reminderEnabled ? "On" : "Off"} · $time daily, on this device',
                    style: theme.textTheme.bodyMedium,
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
                          label: const Text('Test reminder'),
                          onPressed: c.busy ? null : c.test,
                        ),
                      ],
                    ),
                  ],
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
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text('Inbox', style: theme.textTheme.headlineSmall),
                ),
                IconButton(
                  tooltip: 'Refresh app updates',
                  onPressed: c.loading ? null : c.refresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            if (c.entries.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (c.unread > 0)
                    TextButton.icon(
                      onPressed: () => _run(context, () => c.markRead()),
                      icon: const Icon(Icons.done_all, size: 18),
                      label: const Text('Mark all read'),
                    ),
                  TextButton.icon(
                    onPressed: () => _clear(context),
                    icon: const Icon(Icons.clear_all, size: 18),
                    label: const Text('Clear all'),
                  ),
                ],
              ),
            if (c.feedError != null) ...[
              const SizedBox(height: 12),
              Text(c.feedError!),
              TextButton(
                onPressed: c.refresh,
                child: const Text('Retry app updates'),
              ),
            ],
            const SizedBox(height: 12),
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
                padding: 16,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Icon(
                        entry.read
                            ? Icons.notifications_none
                            : Icons.notifications_active_outlined,
                        color: entry.read
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry.title, style: theme.textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text(entry.body),
                          const SizedBox(height: 8),
                          Text(
                            MaterialLocalizations.of(context)
                                .formatMediumDate(entry.at.toLocal()),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (!entry.read)
                      IconButton(
                        tooltip: 'Mark read',
                        onPressed: () =>
                            _run(context, () => c.markRead(entry.id)),
                        icon: const Icon(Icons.done),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      );
    },
  );
}
