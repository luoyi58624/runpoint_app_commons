import 'package:flutter/material.dart';

Future<T?> showAppUpdateDialog<T>({
  required BuildContext context,
  String title = 'New Version',
  String? versionLabel,
  String? description,
  Widget? content,
  bool forceUpdate = false,
  String primaryLabel = 'Update',
  String secondaryLabel = 'Cancel',
  VoidCallback? onUpdate,
  VoidCallback? onLater,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: !forceUpdate,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: _AppUpdateDialogBody(
        title: title,
        versionLabel: versionLabel,
        description: description,
        content: content,
        forceUpdate: forceUpdate,
        primaryLabel: primaryLabel,
        secondaryLabel: secondaryLabel,
        onUpdate: onUpdate,
        onLater: onLater,
      ),
    ),
  );
}

class _AppUpdateDialogBody extends StatelessWidget {
  const _AppUpdateDialogBody({
    required this.title,
    required this.versionLabel,
    required this.description,
    required this.content,
    required this.forceUpdate,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.onUpdate,
    required this.onLater,
  });

  final String title;
  final String? versionLabel;
  final String? description;
  final Widget? content;
  final bool forceUpdate;
  final String primaryLabel;
  final String secondaryLabel;
  final VoidCallback? onUpdate;
  final VoidCallback? onLater;

  static const double _radius = 16;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bodyStyle = theme.textTheme.bodyMedium?.copyWith(
      color: cs.onSurfaceVariant,
      height: 1.45,
    );

    Widget body;
    if (content != null) {
      body = ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 220),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: content!,
        ),
      );
    } else if (description != null && description!.isNotEmpty) {
      body = ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 220),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Text(description!, style: bodyStyle),
        ),
      );
    } else {
      body = const SizedBox(height: 4);
    }

    final actions = forceUpdate
        ? SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: onUpdate,
              style: FilledButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(primaryLabel),
            ),
          )
        : Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: onLater,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cs.onSurface,
                      side: BorderSide(color: cs.outline.withValues(alpha: 0.6)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(secondaryLabel),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: onUpdate,
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(primaryLabel),
                  ),
                ),
              ),
            ],
          );

    return Material(
      color: cs.surface,
      elevation: 8,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(_radius),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.system_update_rounded, size: 30, color: cs.primary),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (versionLabel != null && versionLabel!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        versionLabel!,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              body,
              const SizedBox(height: 20),
              actions,
            ],
          ),
        ),
      ),
    );
  }
}
