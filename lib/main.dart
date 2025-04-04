import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'screens/register_screen.dart';
import 'screens/login_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/home_screen.dart';
import 'screens/transfer_usage_screen.dart';
import 'screens/admin_panel_screen.dart';
import 'screens/admin_add_product_screen.dart';
import 'screens/admin_update_stock_screen.dart';
import 'screens/admin_user_stocks_screen.dart';
import 'screens/my_stock_screen.dart';
import 'screens/admin_settings_screen.dart';
import 'screens/admin_min_limit_screen.dart';
import 'screens/push_notification_screen.dart';
import 'screens/notification_history_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Firebase initialize işlemi
  runApp(TokenRegister(child: MyApp()));
}

Future<bool> checkLoginStatus() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
  return token != null && token.isNotEmpty;
}

/// Bu widget, uygulama başlatıldığında cihazın tokenını alır, backend'e gönderir
/// ve gelen foreground mesajları yerel bildirim olarak gösterir.
class TokenRegister extends StatefulWidget {
  final Widget child;
  const TokenRegister({required this.child});

  @override
  _TokenRegisterState createState() => _TokenRegisterState();
}

class _TokenRegisterState extends State<TokenRegister> {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  @override
  void initState() {
    super.initState();

    // Local notifications plugin'ini initialize ediyoruz.
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        navigatorKey.currentState?.pushNamed('/notification_history');
      },
    );

    _registerAndSendToken();

    // Gelen FCM mesajlarını dinliyoruz.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      print(
        "Mesaj alındı: ${message.notification?.title} - ${message.notification?.body}",
      );
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;
      if (notification != null && android != null) {
        const AndroidNotificationDetails
        androidPlatformChannelSpecifics = AndroidNotificationDetails(
          'high_importance_channel', // AndroidManifest'de tanımlı kanal id'si
          'High Importance Notifications',
          channelDescription:
              'This channel is used for important notifications.',
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'ticker',
        );
        const NotificationDetails platformChannelSpecifics =
            NotificationDetails(android: androidPlatformChannelSpecifics);
        await flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          platformChannelSpecifics,
          payload: 'Default_Sound',
        );
      }
    });
  }

  Future<void> _registerAndSendToken() async {
    String? token = await _messaging.getToken();
    print("Device Token: $token");
    if (token != null) {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString("username") ?? "";
      if (username.isEmpty) {
        print("Username bulunamadı, token gönderilemedi.");
        return;
      }
      final url = Uri.parse(
        "http://nukstoktakip.eu-north-1.elasticbeanstalk.com/api/save_device_token/",
      );
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"device_token": token, "username": username}),
      );
      print("Token gönderildi, status: ${response.statusCode}");
      print("Sunucu cevabı: ${response.body}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // Global navigator key ekleniyor
      title: 'Inventory Mobile',
      home: FutureBuilder<bool>(
        future: checkLoginStatus(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData && snapshot.data == true) {
            return HomeScreen();
          } else {
            return LoginScreen();
          }
        },
      ),
      routes: {
        '/login': (context) => LoginScreen(),
        '/register': (context) => RegisterScreen(),
        '/forgot_password': (context) => ForgotPasswordScreen(),
        '/home': (context) => HomeScreen(),
        '/transfer_usage': (context) => TransferUsageScreen(),
        '/admin_panel': (context) => AdminPanelScreen(),
        '/admin_add_product': (context) => AdminAddProductScreen(),
        '/admin_update_stock': (context) => AdminUpdateStockScreen(),
        '/admin_user_stocks': (context) => AdminUserStocksScreen(),
        '/my_stock_screen': (context) => MyStockScreen(),
        '/admin_settings': (context) => AdminSettingsScreen(),
        '/admin_min_limit': (context) => AdminMinLimitScreen(),
        '/push_notification': (context) => PushNotificationScreen(),
        '/notification_history': (context) => NotificationHistoryScreen(),
      },
    );
  }
}
