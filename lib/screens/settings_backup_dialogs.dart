part of 'settings_screen.dart';

/// Prompts for a backup password (with confirmation) before an encrypted
/// export. Pops the password string, or null when cancelled.
class _ExportPasswordDialog extends StatefulWidget {
  const _ExportPasswordDialog();

  @override
  State<_ExportPasswordDialog> createState() => _ExportPasswordDialogState();
}

class _ExportPasswordDialogState extends State<_ExportPasswordDialog> {
  final _first = TextEditingController();
  final _second = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_first.text.length < 4) {
      setState(() => _error = L.tr(context, 'backupPasswordTooShort'));
      return;
    }
    if (_first.text != _second.text) {
      setState(() => _error = L.tr(context, 'backupPasswordMismatch'));
      return;
    }
    Navigator.of(context).pop(_first.text);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: scheme.surfaceContainerHigh,
      title: Text(L.tr(context, 'exportEncryptTitle')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            L.tr(context, 'exportEncryptHint'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          TextField(
            cursorOpacityAnimates: true,
            magnifierConfiguration: TextMagnifierConfiguration.disabled,
            contextMenuBuilder: (ctx, state) =>
                buildLimitedContextMenu(ctx, state),
            controller: _first,
            obscureText: true,
            autofocus: true,
            decoration: InputDecoration(
              hintText: L.tr(context, 'backupPassword'),
              filled: true,
              fillColor: scheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            cursorOpacityAnimates: true,
            magnifierConfiguration: TextMagnifierConfiguration.disabled,
            contextMenuBuilder: (ctx, state) =>
                buildLimitedContextMenu(ctx, state),
            controller: _second,
            obscureText: true,
            decoration: InputDecoration(
              hintText: L.tr(context, 'backupPasswordConfirm'),
              errorText: _error,
              filled: true,
              fillColor: scheme.surfaceContainerHighest,
            ),
            onSubmitted: (_) => _confirm(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(L.tr(context, 'cancel')),
        ),
        FilledButton(
          onPressed: _confirm,
          child: Text(L.tr(context, 'export')),
        ),
      ],
    );
  }
}

/// Prompts for the password of an encrypted backup during import. Pops the
/// entered password, or null when cancelled.
class _ImportPasswordDialog extends StatefulWidget {
  const _ImportPasswordDialog();

  @override
  State<_ImportPasswordDialog> createState() => _ImportPasswordDialogState();
}

class _ImportPasswordDialogState extends State<_ImportPasswordDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: scheme.surfaceContainerHigh,
      title: Text(L.tr(context, 'importPasswordTitle')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            L.tr(context, 'importPasswordHint'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          TextField(
            cursorOpacityAnimates: true,
            magnifierConfiguration: TextMagnifierConfiguration.disabled,
            contextMenuBuilder: (ctx, state) =>
                buildLimitedContextMenu(ctx, state),
            controller: _controller,
            obscureText: true,
            autofocus: true,
            decoration: InputDecoration(
              hintText: L.tr(context, 'backupPassword'),
              filled: true,
              fillColor: scheme.surfaceContainerHighest,
            ),
            onSubmitted: (_) =>
                Navigator.of(context).pop(_controller.text),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(L.tr(context, 'cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(L.tr(context, 'import')),
        ),
      ],
    );
  }
}
