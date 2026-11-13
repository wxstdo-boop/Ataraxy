part of 'settings_screen.dart';

class _CurrentPinDialog extends StatefulWidget {
  final String expected;

  const _CurrentPinDialog({required this.expected});

  @override
  State<_CurrentPinDialog> createState() => _CurrentPinDialogState();
}

class _CurrentPinDialogState extends State<_CurrentPinDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _check() {
    if (_controller.text == widget.expected) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _error = L.tr(context, 'pinWrong'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: scheme.surfaceContainerHigh,
      title: Text(L.tr(context, 'enterCurrentPin')),
      content: TextField(
        cursorOpacityAnimates: true,
        magnifierConfiguration: TextMagnifierConfiguration.disabled,
                contextMenuBuilder: (ctx, state) =>
                    buildLimitedContextMenu(ctx, state),
        controller: _controller,
        keyboardType: TextInputType.number,
        obscureText: true,
        maxLength: 8,
        autofocus: true,
        decoration: InputDecoration(
          counterText: '',
          hintText: '••••',
          errorText: _error,
          filled: true,
          fillColor: scheme.surfaceContainerHighest,
        ),
        onSubmitted: (_) => _check(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(L.tr(context, 'cancel')),
        ),
        FilledButton(
          onPressed: _check,
          child: Text(L.tr(context, 'unlock')),
        ),
      ],
    );
  }
}

class _PinSetupDialog extends StatefulWidget {
  const _PinSetupDialog();

  @override
  State<_PinSetupDialog> createState() => _PinSetupDialogState();
}

class _PinSetupDialogState extends State<_PinSetupDialog> {
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
      setState(() => _error = L.tr(context, 'pinMismatch'));
      return;
    }
    if (_first.text != _second.text) {
      setState(() => _error = L.tr(context, 'pinMismatch'));
      return;
    }
    Navigator.of(context).pop(_first.text);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: scheme.surfaceContainerHigh,
      title: Text(L.tr(context, 'setPin')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
        cursorOpacityAnimates: true,
        magnifierConfiguration: TextMagnifierConfiguration.disabled,
                contextMenuBuilder: (ctx, state) =>
                    buildLimitedContextMenu(ctx, state),
            controller: _first,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 8,
            decoration: InputDecoration(
              counterText: '',
              hintText: L.tr(context, 'enterPin'),
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
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 8,
            decoration: InputDecoration(
              counterText: '',
              hintText: L.tr(context, 'confirmPin'),
              errorText: _error,
              filled: true,
              fillColor: scheme.surfaceContainerHighest,
            ),
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
          child: Text(L.tr(context, 'save')),
        ),
      ],
    );
  }
}

/// A small tappable pill that opens a provider's key page in the browser.
