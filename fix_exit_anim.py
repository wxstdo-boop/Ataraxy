import re

f = r'D:\Удалять запрещено\ataraxy\lib\welcome_screen.dart'
with open(f, 'r', encoding='utf-8') as file:
    content = file.read()

# Add _isClosing field
content = content.replace(
    '  bool _requesting = false;\n',
    '  bool _requesting = false;\n  bool _isClosing = false;\n'
)

# Replace _finish with animated version
old_finish = '''  void _finish() {
    final updated = widget.settings.copyWith(
      // The onboarding closes only via "Начать пользоваться" (respects the
      // checkbox) or the X — never auto-closes from the permission button.
      showWelcome: !_dontShowAgain,
      reminderEnabled: _notificationsGranted,
    );
    widget.onComplete(updated);
  }'''

new_finish = '''  void _finish() {
    if (_isClosing) return; // prevent double-fire
    setState(() => _isClosing = true);
    // Animate out (reverse the entrance: fade out + slide down), then complete.
    _animCtrl.reverse().then((_) {
      if (mounted) {
        final updated = widget.settings.copyWith(
          showWelcome: !_dontShowAgain,
          reminderEnabled: _notificationsGranted,
        );
        widget.onComplete(updated);
      }
    });
  }'''

content = content.replace(old_finish, new_finish)

with open(f, 'w', encoding='utf-8') as file:
    file.write(content)

print('exit animation added')
