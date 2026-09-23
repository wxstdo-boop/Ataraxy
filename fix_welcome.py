import re

f = r'D:\Удалять запрещено\ataraxy\lib\welcome_screen.dart'
with open(f, 'r', encoding='utf-8') as file:
    content = file.read()

# Fix 1: Remove Navigator.pop() from _finish()
content = content.replace(
    'Navigator.of(context).pop();',
    '// Navigator.pop() removed - WelcomeScreen is not a Navigator route'
)

# Fix 2: Ensure _finish() calls onComplete with correct settings
old_finish = '''void _finish() {
    // Navigator.pop() removed - WelcomeScreen is not a Navigator route
    widget.onComplete(updated);
  }'''

new_finish = '''void _finish() {
    // WelcomeScreen is a child widget of HomeContent, not a Navigator route.
    // Just notify the shell to switch to the home screen.
    widget.onComplete(
      widget.settings.copyWith(showWelcome: !_dontShowAgain),
    );
  }'''

content = content.replace(old_finish, new_finish)

# If the replacement didn't match (maybe different formatting), try a more general approach
if 'widget.onComplete(updated)' in content:
    content = content.replace(
        'widget.onComplete(updated);',
        '''widget.onComplete(
      widget.settings.copyWith(showWelcome: !_dontShowAgain),
    );'''
    )

with open(f, 'w', encoding='utf-8') as file:
    file.write(content)

print('welcome_screen.dart fixed')
