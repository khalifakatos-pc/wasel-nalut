import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/admin_theme.dart';
import 'screens/pin_lock_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AdminColors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const WaselAdminApp());
}

class WaselAdminApp extends StatelessWidget {
  const WaselAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مدير واصل',
      debugShowCheckedModeBanner: false,
      theme: AdminTheme.darkTheme,
      home: const PinLockScreen(),
    );
  }
}
