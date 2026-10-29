import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'figma/live/auth.dart';
import 'figma/live/backend.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Backend.init();
  final remembered = await loadRemembered();
  runApp(ProviderScope(
    overrides: [if (remembered != null) initialAccountProvider.overrideWithValue(remembered)],
    child: const BoutikEcoleApp(),
  ));
}
