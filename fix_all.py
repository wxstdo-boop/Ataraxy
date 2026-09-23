import re, sys

# ============ WELCOME SCREEN ============
f = r'D:\Удалять запрещено\ataraxy\lib\welcome_screen.dart'
c = open(f, 'r', encoding='utf-8')
text = c.read()
c.close()

# Fix: when permissions already granted, close immediately
text = text.replace(
    'if (mounted) setState(() => _notificationsGranted = true);\n          return;\n        }\n      }\n\n      final granted = await NotificationService().requestPermissions();\n      if (mounted) {\n        if (granted) {\n          // Battery optimization is requested at the same moment — only\n          // from this button, never at startup.\n          if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {\n            final battery = await Permission.ignoreBatteryOptimizations.status;\n            if (!battery.isGranted && !battery.isRestricted) {\n              await Permission.ignoreBatteryOptimizations.request();\n            }\n          }\n          setState(() => _notificationsGranted = true);\n          // Stay on the welcome screen',
    'if (mounted) {\n            setState(() => _notificationsGranted = true);\n            _finish();\n          }\n          return;\n        }\n      }\n\n      final granted = await NotificationService().requestPermissions();\n      if (mounted) {\n        if (granted) {\n          // Battery optimization is requested at the same moment\n          if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {\n            final battery = await Permission.ignoreBatteryOptimizations.status;\n            if (!battery.isGranted && !battery.isRestricted) {\n              await Permission.ignoreBatteryOptimizations.request();\n            }\n          }\n          setState(() => _notificationsGranted = true);\n          // Permissions granted — close the welcome screen immediately.\n          _finish();'
)

open(f, 'w', encoding='utf-8').write(text)
print('welcome_screen.dart fixed')

# ============ SEARCH TOOLTIP ============
f2 = r'D:\Удалять запрещено\ataraxy\lib\screens\home_screen.dart'
c2 = open(f2, 'r', encoding='utf-8')
text2 = c2.read()
c2.close()

# Move tooltip before icon for proper rebuild
old = """      tooltip: isSearching
          ? L.tr(context, 'closeSearch')
          : L.tr(context, 'search'),
      onPressed: onTap,
      // Clean cross-fade between the search glass and the X."""
new = """      onPressed: onTap,
      tooltip: isSearching
          ? L.tr(context, 'closeSearch')
          : L.tr(context, 'search'),
      // Clean cross-fade between the search glass and the X."""
text2 = text2.replace(old, new)
open(f2, 'w', encoding='utf-8').write(text2)
print('home_screen.dart tooltip fixed')

# ============ STREAK BADGE ============
f3 = r'D:\Удалять запрещено\ataraxy\lib\widgets\streak_badge.dart'
c3 = open(f3, 'r', encoding='utf-8')
text3 = c3.read()
c3.close()

text3 = text3.replace(
    'final size = 30.0 + (digits - 1).clamp(0, 3) * 7.0;',
    'final size = 38.0 + (digits - 1).clamp(0, 3) * 8.0;'
)
text3 = text3.replace(
    'fontSize = 16,',
    'fontSize = 18,'
)
text3 = text3.replace(
    'top: -13,',
    'top: -16,'
)
text3 = text3.replace(
    'const WinterHat(width: 22, height: 16),',
    'const WinterHat(width: 26, height: 19),'
)
text3 = text3.replace(
    'const SizedBox(width: 4),\n                    StreakBadge(streak: _streak),',
    'const SizedBox(width: 2),\n                    StreakBadge(streak: _streak),'
)

open(f3, 'w', encoding='utf-8').write(text3)
print('streak_badge.dart fixed')

# ============ TAB SEGMENT PRESS ============
f4 = r'D:\Удалять запрещено\ataraxy\lib\screens\home_screen.dart'
c4 = open(f4, 'r', encoding='utf-8')
text4 = c4.read()
c4.close()

# Replace the _TabSegment build body
old_tab = """        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            color: scheme.onPrimary.withValues(alpha: _pressed ? 0.18 : 0.0),
          ),
          child: Center(
            child: AnimatedDefaultTextStyle("""
new_tab = """        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              color: scheme.onPrimary.withValues(alpha: _pressed ? 0.18 : 0.0),
            ),
            child: Center(
              child: AnimatedDefaultTextStyle("""
text4 = text4.replace(old_tab, new_tab)

# Fix closing parens - add one for AnimatedScale
old_close = """              child: Text(widget.label),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryChips"""
new_close = """              child: Text(widget.label),
            ),
          ),
        ), // AnimatedContainer
      ), // AnimatedScale
    );
  }
}

class _CategoryChips"""
text4 = text4.replace(old_close, new_close)

open(f4, 'w', encoding='utf-8').write(text4)
print('home_screen.dart tab segment fixed')

print('\\nALL FIXES APPLIED')
