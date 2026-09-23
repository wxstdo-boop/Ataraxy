import 'package:flutter/material.dart';
import 'package:ataraxy/l10n/strings.dart';

class DreamSign {
  final String id;
  final IconData icon;

  const DreamSign(this.id, this.icon);
}

class DreamSigns {
  const DreamSigns._();

  static const List<DreamSign> presets = [
    DreamSign('flying', Icons.flight),
    DreamSign('falling', Icons.arrow_downward_rounded),
    DreamSign('chased', Icons.directions_run_rounded),
    DreamSign('teeth', Icons.health_and_safety_rounded),
    DreamSign('water', Icons.water_drop_rounded),
    DreamSign('school', Icons.school_rounded),
    DreamSign('paralysis', Icons.bedtime_rounded),
    DreamSign('lost', Icons.explore_off_rounded),
    DreamSign('animal', Icons.pets_rounded),
    DreamSign('vehicle', Icons.directions_car_rounded),
    DreamSign('celebrity', Icons.star_rounded),
    DreamSign('naked', Icons.accessibility_rounded),
  ];

  static IconData iconOf(String id) {
    for (final s in presets) {
      if (s.id == id) return s.icon;
    }
    return Icons.auto_awesome_rounded;
  }

  static String label(BuildContext context, String id) {
    return L.dreamSign(context, id);
  }
}
