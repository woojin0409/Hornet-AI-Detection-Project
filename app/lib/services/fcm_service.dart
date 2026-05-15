import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

class FcmService {
  static const String _serverUrl = 'http://34.81.221.132:8000';
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> init(String deviceId) async {
    // 1. 알림 권한 요청
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      print('[FCM] 알림 권한 거부됨');
      return;
    }

    // 2. FCM 토큰 가져오기
    String? token = await _fcm.getToken();

    if (token == null) {
      print('[FCM] 토큰 없음');
      return;
    }
    print('[FCM] 토큰: $token');


  }

  Future<void> _registerDevice({
    required String deviceId,
    required String appToken,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_serverUrl/v1/register-device'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'device_id': deviceId,
          'user_id': 'khivemind',
          'app_token': appToken,
          'device_name': '벌통 $deviceId',
          'group': 'khivemind',
        }),
      );

      if (response.statusCode == 200) {
        print('[FCM] 디바이스 등록 성공');
      } else {
        print('[FCM] 디바이스 등록 실패: ${response.body}');
      }
    } catch (e) {
      print('[FCM] 디바이스 등록 에러: $e');
    }
  }
}
