import 'package:flutter/material.dart';
import 'package:dream_journal/l10n/strings.dart';
import 'package:dream_journal/widgets/limited_context_menu.dart';

class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const LockScreen({super.key, required this.onUnlocked});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _controller = TextEditingController();
  String? _error;

  void _submit(String expected) {
    if (_controller.text == expected) {
      _controller.clear();
      FocusScope.of(context).unfocus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onUnlocked();
      });
    } else {
      if (!mounted) return;
      setState(() {
        _error = L.tr(context, 'pinWrong');
        _controller.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final expected = SettingsProviderPin.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_rounded,
                size: 72,
                color: scheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Ataraxy',
                // Explicit style: the brand wordmark stays in the system
                // sans (as originally) — the italic display font is only
                // for generic headings, not the brand name.
                style: TextStyle(
                  fontSize: Theme.of(context).textTheme.headlineMedium?.fontSize ?? 24,
                  fontWeight: FontWeight.bold,
                  color: scheme.primary,
                  fontStyle: FontStyle.normal,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                L.tr(context, 'enterPin'),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: 220,
                child: TextField(
        magnifierConfiguration: TextMagnifierConfiguration.disabled,
                contextMenuBuilder: (ctx, state) =>
                    buildLimitedContextMenu(ctx, state),
                  controller: _controller,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  textAlign: TextAlign.center,
                  maxLength: 8,
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '••••',
                    errorText: _error,
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest,
                  ),
                  onSubmitted: (_) => _submit(expected),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => _submit(expected),
                child: Text(L.tr(context, 'unlock')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Отдельный наследуемый виджет только для передачи ожидаемого PIN,
// чтобы не тянуть весь SettingsProvider в LockScreen.
class SettingsProviderPin extends InheritedWidget {
  final String pin;

  const SettingsProviderPin({
    super.key,
    required this.pin,
    required super.child,
  });

  static String of(BuildContext context) {
    final result =
        context.dependOnInheritedWidgetOfExactType<SettingsProviderPin>();
    assert(result != null, 'No SettingsProviderPin found');
    return result!.pin;
  }

  @override
  bool updateShouldNotify(SettingsProviderPin oldWidget) =>
      oldWidget.pin != pin;
}
