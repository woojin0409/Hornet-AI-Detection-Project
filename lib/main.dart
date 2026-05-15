import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'services/api_service.dart';
import 'settings_screen.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:math';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'services/config.dart';
import 'services/fcm_service.dart';
import 'splash_screen.dart';
import 'widgets/pressable_button.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

const kCream = Color(0xFFF8F6F0);
const kGold = Color(0xFFE8A820);
const kDarkBrown = Color(0xFF1C1207);
const kLightBorder = Color(0xFFE0D8C8);
const kMutedGold = Color(0xFFA08040);
const kRed = Color(0xFFC62828);
const kLightRed = Color(0xFFFFF5F5);

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }

  final FlutterLocalNotificationsPlugin localNotifications =
      FlutterLocalNotificationsPlugin();

  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/launcher_icon');
  await localNotifications.initialize(
    InitializationSettings(android: androidSettings),
  );

  final deviceId = message.data['device_id'] ?? '';
  final confidence = double.tryParse(message.data['confidence'] ?? '0') ?? 0.0;

  await localNotifications.show(
    0,
    '말벌 침입 감지!',
    '벌통 $deviceId | 신뢰도 ${(confidence * 100).toStringAsFixed(1)}%',
    NotificationDetails(
      android: AndroidNotificationDetails(
        'hornet_alert',
        '말벌 감지 알림',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      ),
    ),
  );
}

final fcmService = FcmService();
RemoteMessage? _initialMessage;

final FlutterLocalNotificationsPlugin _globalLocalNotifications =
    FlutterLocalNotificationsPlugin();
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _globalLocalNotifications.initialize(
    InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/launcher_icon'),
    ),
    onDidReceiveNotificationResponse: (details) {
      // 알림 탭 시 payload로 FCM 데이터 전달
      if (details.payload != null) {
        _pendingPayload = details.payload;
      }
    },
  );

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {}

  _initialMessage = await FirebaseMessaging.instance.getInitialMessage();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(HivemindApp());
}

String? _pendingPayload;

class HivemindApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.light(),
      home: SplashScreen(nextScreen: HomeScreen()),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaleFactor: 1.15),
          child: child!,
        );
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _showLogDetail = false;
  Set<int> _expandedGroups = {};
  int _selectedGroupIndex = 0;
  int _selectedHiveIndex = 0;
  bool _showDetailScreen = false;
  late AnimationController _bannerController;
  late Animation<Color?> _bannerColor;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  List<Map<String, dynamic>> _groups = [];

  Map<String, dynamic>? get _currentHive {
    if (_groups.isEmpty) return null;
    final hives = _groups[_selectedGroupIndex]['hives'] as List;
    if (hives.isEmpty) return null;
    if (_selectedHiveIndex >= hives.length) return null;
    return hives[_selectedHiveIndex];
  }

  List get _currentHives {
    if (_groups.isEmpty) return [];
    return _groups[_selectedGroupIndex]['hives'] as List;
  }

  @override
  void initState() {
    super.initState();
    _bannerController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _bannerColor = ColorTween(
      begin: kRed,
      end: Color(0xFF8B0000),
    ).animate(_bannerController);

    _pulseController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initialize();
  }

  Future<void> _initialize() async {
    await _initNotifications(); // 먼저
    await _loadDevices(); // 그 다음
  }

  @override
  void dispose() {
    _bannerController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadDevices() async {
    final groups = await ApiService().getDevices();
    if (groups.isNotEmpty) {
      for (final group in groups) {
        final hives = group['hives'] as List;
        for (final hive in hives) {
          // 기존 로컬 상태 찾기
          Map<String, dynamic>? existingHive;
          for (final g in _groups) {
            final hivesList = (g['hives'] as List).cast<Map<String, dynamic>>();
            if (hivesList.isEmpty) continue;

            final found = hivesList.firstWhere(
              (h) => h['id'].toString() == hive['id'].toString(),
              orElse: () => <String, dynamic>{},
            );
            if (found.isNotEmpty) {
              existingHive = found;
              break;
            }
          }

          if (existingHive != null) {
            // 기존 상태 유지
            hive['isAlert'] = existingHive['isAlert'];
            hive['confidence'] = existingHive['confidence'];
            hive['lastDetected'] = existingHive['lastDetected'];
            hive['logs'] = existingHive['logs'];
            hive['isDoorOpen'] = existingHive['isDoorOpen'];
            hive['isAutoMode'] = existingHive['isAutoMode'];
            hive['predictionImageUrl'] = existingHive['predictionImageUrl'];
          } else {
            // 새 벌통이면 서버에서 로그 불러오기
            final logs = await ApiService().getPredictions(
              hive['id'].toString(),
            );
            hive['logs'] = logs;
            if (logs.isNotEmpty) {
              hive['lastDetected'] = logs.last['time'];
              hive['confidence'] = logs.last['confidence'];
            }
          }
        }
      }
      // 기존 구역의 cctvUrl 유지
      for (final group in groups) {
        for (final g in _groups) {
          if (g['name'] == group['name']) {
            group['cctvUrl'] = g['cctvUrl'] ?? '';
            break;
          }
        }
      }

      setState(() {
        _groups = groups;
      });
      setState(() {
        _groups = groups;
      });
      await _loadCctvUrls();
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        for (int gi = 0; gi < _groups.length; gi++) {
          final hives = _groups[gi]['hives'] as List;
          for (final hive in hives) {
            await ApiService().registerDevice(
              deviceId: hive['id'].toString(),
              userId: 'khivemind',
              appToken: token,
              deviceName: hive['name'] as String,
              group: _groups[gi]['name'] as String,
            );
            print('loadDevices 후 토큰 등록: ${hive['id']}');
          }
        }
      }
    }

    if (_pendingPayload != null) {
      final data = jsonDecode(_pendingPayload!);
      _handleFcmMessageFromData(data);
      _pendingPayload = null;
    } else if (_initialMessage != null) {
      _handleFcmMessage(_initialMessage!);
      _initialMessage = null;
    }
  }

  void _handleFcmMessage(RemoteMessage message) async {
    print('FCM 수신 데이터: ${message.data}');
    print('FCM 알림: ${message.notification?.title}');
    final deviceId = message.data['device_id'] ?? '';
    final confidence =
        double.tryParse(message.data['confidence'] ?? '0') ?? 0.0;
    final imageUrl = message.data['image_url'] ?? '';

    for (int gi = 0; gi < _groups.length; gi++) {
      final hives = _groups[gi]['hives'] as List;
      for (int hi = 0; hi < hives.length; hi++) {
        if (hives[hi]['id'].toString() == message.data['device_id']) {
          hives[hi]['predictionImageUrl'] = imageUrl;
          setState(() {
            hives[hi]['isAlert'] = true;
            hives[hi]['confidence'] = confidence;
            hives[hi]['lastDetected'] = DateTime.now();
            hives[hi]['logs'].add({
              'time': DateTime.now(),
              'confidence': confidence,
            });
            _selectedGroupIndex = gi;
            _selectedHiveIndex = hi;
            _expandedGroups.add(gi);
            _showDetailScreen = false;
            if (hives[hi]['isAutoMode'] == true)
              hives[hi]['isDoorOpen'] = false;
          });
          break;
        }
      }
    }

    await _localNotifications.show(
      0,
      '말벌 침입 감지!',
      '벌통 $deviceId | 신뢰도 ${(confidence * 100).toStringAsFixed(1)}%',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'hornet_alert',
          '말벌 감지 알림',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        ),
      ),
      payload: jsonEncode(message.data), // ← 추가
    );
  }

  void _handleFcmMessageFromData(Map<String, dynamic> data) async {
    final deviceId = data['device_id'] ?? '';
    final confidence = double.tryParse(data['confidence'] ?? '0') ?? 0.0;
    final imageUrl = data['image_url'] ?? '';

    for (int gi = 0; gi < _groups.length; gi++) {
      final hives = _groups[gi]['hives'] as List;
      for (int hi = 0; hi < hives.length; hi++) {
        if (hives[hi]['id'].toString() == deviceId) {
          hives[hi]['predictionImageUrl'] = imageUrl;
          setState(() {
            hives[hi]['isAlert'] = true;
            hives[hi]['confidence'] = confidence;
            hives[hi]['lastDetected'] = DateTime.now();
            hives[hi]['logs'].add({
              'time': DateTime.now(),
              'confidence': confidence,
            });
            _selectedGroupIndex = gi;
            _selectedHiveIndex = hi;
            _expandedGroups.add(gi);
            _showDetailScreen = false;
            if (hives[hi]['isAutoMode'] == true)
              hives[hi]['isDoorOpen'] = false;
          });
          break;
        }
      }
    }
  }

  Future<void> _initNotifications() async {
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      print('FCM 토큰 갱신: $newToken');
      for (int gi = 0; gi < _groups.length; gi++) {
        final hives = _groups[gi]['hives'] as List;
        for (final hive in hives) {
          await ApiService().registerDevice(
            deviceId: hive['id'].toString(),
            userId: 'khivemind',
            appToken: newToken,
            deviceName: hive['name'] as String,
            group: _groups[gi]['name'] as String,
          );
          print('토큰 재등록 완료: ${hive['id']}');
        }
      }
    });

    await fcmService.init('khivemind');
    FirebaseMessaging.onMessage.listen(_handleFcmMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleFcmMessage);

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
    final token = await FirebaseMessaging.instance.getToken();
    print('FCM 토큰: $token');
  }

  String _timeAgo(DateTime? dt) {
    if (dt == null) return '없음';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  String _formatLogTime(DateTime? dt) {
    if (dt == null) return '-';
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _tempStatus(double t) {
    if (t >= 34 && t <= 36) return '정상 (34~36°C)';
    if (t < 34) return '낮음';
    return '높음';
  }

  Color _tempColor(double t) => (t >= 34 && t <= 36) ? Color(0xFF4CAF50) : kRed;

  String _humidityStatus(double h) {
    if (h >= 50 && h <= 70) return '정상 (50~70%)';
    if (h < 50) return '건조';
    return '과습';
  }

  Color _humidityColor(double h) =>
      (h >= 50 && h <= 70) ? Color(0xFF4CAF50) : kRed;

  @override
  Widget build(BuildContext context) {
    final hive = _currentHive;
    return Scaffold(
      backgroundColor: kCream,
      body: SafeArea(
        child: _showLogDetail
            ? _buildLogDetailScreen()
            : _showDetailScreen && hive != null
            ? _buildDetailScreen(hive)
            : _buildMainScreen(),
      ),
    );
  }

  Widget _buildMainScreen() {
    final hive = _currentHive;
    return Stack(
      children: [
        Column(
          children: [
            _buildAppBar(),
            if (_groups.isEmpty)
              Expanded(child: _buildEmptyState())
            else ...[
              _buildGroupTabs(),
              _buildHiveTabs(),
              Expanded(
                child: _currentHives.isEmpty
                    ? _buildEmptyHiveState()
                    : RefreshIndicator(
                        color: kGold,
                        onRefresh: () async {
                          await _loadDevices();
                        },
                        child: SingleChildScrollView(
                          physics: AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.all(14),
                          child: Column(
                            children: [
                              _buildMonitor(hive!),
                              SizedBox(height: 8),
                              _buildMonitorActions(hive),
                              _buildStatusCards(hive),
                              SizedBox(height: 12),
                              _buildTodayLogs(hive),
                              SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ],
        ),
        if (hive != null && hive['isAlert']) _buildAlertBanner(hive),
      ],
    );
  }

  Widget _buildMonitorActions(Map<String, dynamic> hive) {
    final isAlert = hive['isAlert'] as bool;

    return Row(
      children: [
        // 감지 활성화 토글 (왼쪽)
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kLightBorder, width: 0.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.radar, size: 18, color: Colors.amber),
                    SizedBox(width: 6),
                    Text(
                      '감지 가동',
                      style: TextStyle(fontSize: 13, color: kDarkBrown),
                    ),
                  ],
                ),
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: hive['is_enabled'] ?? true,
                    activeColor: kGold,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (bool value) async {
                      bool success = await ApiService().updateDeviceStatus(
                        hive['id'].toString(),
                        value,
                      );
                      if (success) {
                        setState(() {
                          hive['is_enabled'] = value;
                        });
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('상태 변경에 실패했습니다.')),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        // AI 분석결과 버튼 (알림 왔을 때만, 오른쪽)
        if (isAlert) ...[
          SizedBox(width: 8),
          Expanded(
            child: PressableButton(
              onTap: () {
                setState(() {
                  _showDetailScreen = true;
                });
              },
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: kRed,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'AI 분석결과',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyState() {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SettingsScreen(groups: _groups)),
        );
        if (result != null) {
          setState(() {
            _groups = result['groups'];
          });
          await _saveCctvUrls(); // ← 추가
        }
      },
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, size: 48, color: kMutedGold),
            SizedBox(height: 16),
            Text(
              '구역을 추가해주세요',
              style: TextStyle(fontSize: 16, color: kMutedGold),
            ),
            SizedBox(height: 8),
            Text(
              '탭하여 설정으로 이동',
              style: TextStyle(fontSize: 14, color: kLightBorder),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyHiveState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hive_outlined, size: 48, color: kMutedGold),
          SizedBox(height: 16),
          Text('벌통을 추가해주세요', style: TextStyle(fontSize: 16, color: kMutedGold)),
          SizedBox(height: 8),
          Text(
            '설정에서 이 구역에 벌통을 추가할 수 있어요',
            style: TextStyle(fontSize: 14, color: kLightBorder),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: kCream,
        border: Border(bottom: BorderSide(color: kLightBorder, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              CustomPaint(painter: HexLogoPainter(), size: Size(24, 24)),
              SizedBox(width: 8),
              Text(
                'HIVEMIND',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 18,
                  letterSpacing: 3,
                  color: kDarkBrown,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
          PressableButton(
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(groups: _groups),
                ),
              );
              if (result != null) {
                setState(() {
                  _groups = result['groups'];
                  if (_selectedGroupIndex >= _groups.length) {
                    _selectedGroupIndex = 0;
                  }
                  if (_selectedHiveIndex >= _currentHives.length) {
                    _selectedHiveIndex = 0;
                  }
                });
                await _saveCctvUrls();
              }
            },
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Color(0xFFF0EBE0),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kLightBorder, width: 0.5),
              ),
              child: Icon(Icons.settings_outlined, size: 18, color: kMutedGold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupTabs() {
    const double minButtonWidth = 40.0; // 버튼 최소 너비 (글자 기준)
    const double gap = 6.0;

    return Container(
      padding: EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final count = _groups.length;
          final totalGap = gap * (count - 1);
          final buttonWidth = count == 0
              ? totalWidth
              : (totalWidth - totalGap) / count;
          final useScroll = buttonWidth < minButtonWidth;

          Widget buildButton(int gi) {
            final group = _groups[gi];
            final isExpanded = _expandedGroups.contains(gi);
            final hasAlert = (group['hives'] as List).any(
              (h) => h['isAlert'] == true,
            );

            return PressableButton(
              onTap: () {
                setState(() {
                  if (_expandedGroups.contains(gi)) {
                    _expandedGroups.remove(gi); // 같은 구역 누르면 접기
                  } else {
                    _expandedGroups.clear(); // ← 추가: 다른 구역 다 접기
                    _expandedGroups.add(gi);
                    _selectedGroupIndex = gi;
                    _selectedHiveIndex = 0;
                  }
                  _showDetailScreen = false;
                });
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: hasAlert
                      ? kLightRed
                      : (isExpanded ? Color(0xFFFFF8E0) : Color(0xFFF0EBE0)),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: hasAlert
                        ? kRed
                        : (isExpanded ? kGold : kLightBorder),
                    width: hasAlert || isExpanded ? 1.5 : 0.5,
                  ),
                ),
                child: Text(
                  group['name'],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: hasAlert ? kRed : kDarkBrown,
                  ),
                ),
              ),
            );
          }

          if (useScroll) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _groups.asMap().entries.map((e) {
                  return Padding(
                    padding: EdgeInsets.only(
                      right: e.key < _groups.length - 1 ? gap : 0,
                    ),
                    child: SizedBox(
                      width: minButtonWidth,
                      child: buildButton(e.key),
                    ),
                  );
                }).toList(),
              ),
            );
          }

          return Row(
            children: _groups.asMap().entries.map((e) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: e.key < _groups.length - 1 ? gap : 0,
                  ),
                  child: buildButton(e.key),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildHiveTabs() {
    if (_expandedGroups.isEmpty) return SizedBox.shrink();

    final gi = _expandedGroups.first;
    if (gi >= _groups.length) return SizedBox.shrink();

    final hives = _groups[gi]['hives'] as List;

    if (hives.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(14),
        child: Text(
          '벌통을 추가해주세요',
          style: TextStyle(fontSize: 14, color: kMutedGold),
        ),
      );
    }

    const double minButtonWidth = 40.0;
    const double gap = 6.0;

    return AnimatedSize(
      duration: Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: Container(
        padding: EdgeInsets.fromLTRB(14, 8, 14, 4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final totalWidth = constraints.maxWidth;
            final count = hives.length;
            final totalGap = gap * (count - 1);
            final buttonWidth = count == 0
                ? totalWidth
                : (totalWidth - totalGap) / count;
            final useScroll = buttonWidth < minButtonWidth;

            Widget buildButton(int hi) {
              final hive = hives[hi];
              final isAlert = hive['isAlert'] as bool;
              final isSelected =
                  _selectedGroupIndex == gi && _selectedHiveIndex == hi;

              return PressableButton(
                onTap: () {
                  setState(() {
                    _selectedGroupIndex = gi;
                    _selectedHiveIndex = hi;
                  });
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: isAlert
                        ? kLightRed
                        : (isSelected ? Color(0xFFFFF8E0) : Color(0xFFF0EBE0)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isAlert
                          ? kRed
                          : (isSelected ? kGold : kLightBorder),
                      width: isAlert || isSelected ? 1.5 : 0.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        hive['name'],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isAlert ? kRed : kDarkBrown,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        isAlert ? '말벌 감지 ⚠️' : '정상',
                        style: TextStyle(
                          fontSize: 11,
                          color: isAlert ? Color(0xFFE57373) : kMutedGold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (useScroll) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: hives.asMap().entries.map((e) {
                    return Padding(
                      padding: EdgeInsets.only(
                        right: e.key < hives.length - 1 ? gap : 0,
                      ),
                      child: SizedBox(
                        width: minButtonWidth,
                        child: buildButton(e.key),
                      ),
                    );
                  }).toList(),
                ),
              );
            }

            return Row(
              children: hives.asMap().entries.map((e) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: e.key < hives.length - 1 ? gap : 0,
                    ),
                    child: buildButton(e.key),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMonitor(Map<String, dynamic> hive) {
    final cctvUrl = (_groups[_selectedGroupIndex]['cctvUrl'] as String?) ?? '';

    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: kDarkBrown,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hive['isAlert'] ? kRed : Color(0xFF3D2E00),
          width: hive['isAlert'] ? 1.5 : 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            cctvUrl.isNotEmpty
                ? _VideoPlayerWidget(url: cctvUrl)
                : Container(
                    color: kDarkBrown,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.videocam_off_outlined,
                            color: kMutedGold,
                            size: 28,
                          ),
                          SizedBox(height: 6),
                          Text(
                            'CCTV 미연결',
                            style: TextStyle(
                              color: kMutedGold,
                              fontSize: 13,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            Positioned(
              top: 8,
              left: 10,
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: cctvUrl.isNotEmpty
                          ? (hive['isAlert'] ? kRed : Color(0xFF4CAF50))
                          : kMutedGold,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 4),
                  Text(
                    cctvUrl.isNotEmpty ? 'LIVE' : 'NO SIGNAL',
                    style: TextStyle(
                      fontSize: 10,
                      color: kGold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 8,
              right: 10,
              child: Text(
                '${hive['name']} CAM',
                style: TextStyle(
                  fontSize: 10,
                  color: kMutedGold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCards(Map<String, dynamic> hive) {
    final isAlert = hive['isAlert'] as bool;
    final isDoorOpen = hive['isDoorOpen'] as bool;
    final temp = hive['temp'] as double;
    final humidity = hive['humidity'] as double;
    final hiveIsAutoMode = hive['isAutoMode'] as bool? ?? true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${hive['name']} 상태',
          style: TextStyle(fontSize: 12, color: kMutedGold, letterSpacing: 1),
        ),
        SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _infoCard(
                label: '온도',
                value: '${temp.toStringAsFixed(1)}°',
                status: _tempStatus(temp),
                statusColor: _tempColor(temp),
                isAlert: false,
              ),
            ),
            SizedBox(width: 6),
            Expanded(
              child: _infoCard(
                label: '습도',
                value: '${humidity.toStringAsFixed(0)}%',
                status: _humidityStatus(humidity),
                statusColor: _humidityColor(humidity),
                isAlert: false,
              ),
            ),
          ],
        ),

        SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isAlert ? kLightRed : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isAlert ? Color(0xFFFFCDD2) : kLightBorder,
                    width: 0.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '소문 상태',
                          style: TextStyle(fontSize: 11, color: kMutedGold),
                        ),
                        Row(
                          children: [
                            Text(
                              hiveIsAutoMode ? '자동' : '수동',
                              style: TextStyle(fontSize: 10, color: kMutedGold),
                            ),
                            SizedBox(width: 4),
                            Transform.scale(
                              scale: 0.6,
                              child: Switch(
                                value: hiveIsAutoMode,
                                onChanged: (v) {
                                  setState(() {
                                    _currentHive!['isAutoMode'] = v;
                                  });
                                },
                                activeColor: kGold,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    PressableButton(
                      onTap: () async {
                        if (!hiveIsAutoMode) {
                          final ip =
                              _currentHive!['raspberryPiIp'] as String? ?? '';
                          if (ip.isNotEmpty) {
                            try {
                              final endpoint = isDoorOpen ? 'close' : 'open';
                              await http.post(
                                Uri.parse('http://$ip:8000/door/$endpoint'),
                                headers: {'x-api-key': Config.apiKey},
                              );
                            } catch (e) {
                              print('소문 제어 실패: $e');
                            }
                          }
                          setState(() {
                            _currentHive!['isDoorOpen'] = !isDoorOpen;
                          });
                        }
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isDoorOpen ? '열림' : '닫힘',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: isDoorOpen ? Color(0xFF4CAF50) : kRed,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            hiveIsAutoMode ? '자동 모드' : '탭하여 변경',
                            style: TextStyle(
                              fontSize: 10,
                              color: hiveIsAutoMode ? kMutedGold : kGold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 6),
            Expanded(
              child: _infoCard(
                label: '마지막 감지',
                value: _timeAgo(hive['lastDetected']),
                status: hive['confidence'] > 0
                    ? '탐지율 ${(hive['confidence'] * 100).toStringAsFixed(0)}%'
                    : '이상 없음',
                statusColor: isAlert ? Color(0xFFE57373) : kMutedGold,
                isAlert: isAlert,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _infoCard({
    required String label,
    required String value,
    required String status,
    required Color statusColor,
    required bool isAlert,
  }) {
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isAlert ? kLightRed : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isAlert ? Color(0xFFFFCDD2) : kLightBorder,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: kMutedGold)),
          SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: kDarkBrown,
            ),
          ),
          SizedBox(height: 3),
          Row(
            children: [
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 3),
              Expanded(
                child: Text(
                  status,
                  style: TextStyle(fontSize: 10, color: statusColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTodayLogs(Map<String, dynamic> hive) {
    final logs = hive['logs'] as List;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '오늘 탐지 현황',
              style: TextStyle(
                fontSize: 12,
                color: kMutedGold,
                letterSpacing: 1,
              ),
            ),
            Row(
              children: [
                Text(
                  '${logs.length}회',
                  style: TextStyle(
                    fontSize: 12,
                    color: kRed,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(width: 6),
                PressableButton(
                  onTap: () => _showAllLogs(hive),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Color(0xFFFFF8E0),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: kGold, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '전체',
                          style: TextStyle(fontSize: 10, color: kGold),
                        ),
                        SizedBox(width: 2),
                        Icon(Icons.chevron_right, size: 12, color: kGold),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: 6),
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kLightBorder, width: 0.5),
          ),
          child: logs.isEmpty
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '탐지 기록 없음',
                      style: TextStyle(fontSize: 13, color: kMutedGold),
                    ),
                  ),
                )
              : Column(
                  children: logs.reversed.take(5).map((log) {
                    return PressableButton(
                      onTap: () async {
                        final hiveId = hive['id'].toString();
                        final seq = log['prediction_seq']?.toString();
                        if (seq == null) return;

                        // 로딩 표시
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => Center(
                            child: CircularProgressIndicator(color: kGold),
                          ),
                        );

                        final imageUrl = await ApiService()
                            .getPredictionImageUrl(
                              deviceId: hiveId,
                              predictionSeq: seq,
                            );

                        if (!mounted) return;
                        Navigator.pop(context); // 로딩 닫기

                        setState(() {
                          hive['predictionImageUrl'] = imageUrl ?? '';
                          hive['lastDetected'] = log['time'];
                          hive['confidence'] = log['confidence'];
                          _showLogDetail = true;
                        });
                      },
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: kRed,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  _formatLogTime(log['time']),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: kDarkBrown,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Text(
                                  '탐지율 : ${(log['confidence'] * 100).toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFFE57373),
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(
                                  Icons.chevron_right,
                                  size: 14,
                                  color: kMutedGold,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  void _showAllLogs(Map<String, dynamic> hive) async {
    final rootContext = context;
    // 서버에서 전체 기록 불러오기
    final allLogs = await ApiService().getPredictions(hive['id'].toString());

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: kCream,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: kLightBorder, width: 0.5),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${hive['name']} 전체 탐지 기록',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: kDarkBrown,
                  ),
                ),
                Text(
                  '${allLogs.length}회',
                  style: TextStyle(fontSize: 13, color: kRed),
                ),
              ],
            ),
          ),
          Expanded(
            child: allLogs.isEmpty
                ? Center(
                    child: Text(
                      '탐지 기록 없음',
                      style: TextStyle(color: kMutedGold),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.all(16),
                    itemCount: allLogs.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: kLightBorder),
                    itemBuilder: (_, i) {
                      final log = allLogs[allLogs.length - 1 - i];
                      return PressableButton(
                        onTap: () async {
                          final hiveId = hive['id'].toString();
                          final seq = log['prediction_seq']?.toString();
                          if (seq == null) return;

                          Navigator.pop(rootContext); // bottomSheet 닫기

                          // 로딩 표시
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => Center(
                              child: CircularProgressIndicator(color: kGold),
                            ),
                          );

                          final imageUrl = await ApiService()
                              .getPredictionImageUrl(
                                deviceId: hiveId,
                                predictionSeq: seq,
                              );

                          if (!mounted) return;
                          Navigator.pop(rootContext); // 로딩 닫기

                          setState(() {
                            hive['predictionImageUrl'] = imageUrl ?? '';
                            hive['lastDetected'] = log['time'];
                            hive['confidence'] = log['confidence'];
                            _showLogDetail = true;
                          });
                        },
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: kRed,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    _formatLogTime(log['time']),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: kDarkBrown,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Text(
                                    '탐지율 ${(log['confidence'] * 100).toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFFE57373),
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(
                                    Icons.chevron_right,
                                    size: 14,
                                    color: kMutedGold,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveCctvUrls() async {
    final prefs = await SharedPreferences.getInstance();
    for (final group in _groups) {
      print('저장: ${group['name']} → ${group['cctvUrl']}'); // ← 추가

      prefs.setString('cctvUrl_${group['name']}', group['cctvUrl'] ?? '');
    }
  }

  Future<void> _loadCctvUrls() async {
    final prefs = await SharedPreferences.getInstance();
    for (final group in _groups) {
      final saved = prefs.getString('cctvUrl_${group['name']}') ?? '';
      print('불러오기: ${group['name']} → $saved'); // ← 추가

      group['cctvUrl'] = saved;
    }
  }

  Widget _buildAlertBanner(Map<String, dynamic> hive) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: PressableButton(
        onTap: () {
          setState(() {
            _showDetailScreen = true;
          });
        },
        child: AnimatedBuilder(
          animation: _bannerColor,
          builder: (context, child) {
            return Container(
              color: _bannerColor.value,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: child,
            );
          },
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 8),
              Text(
                '${hive['name']} — 말벌 침입 감지',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
              Spacer(),
              Text(
                '${(hive['confidence'] * 100).toStringAsFixed(0)}%',
                style: TextStyle(color: Color(0xFFFFCDD2), fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailScreen(Map<String, dynamic> hive) {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, child) {
        final borderColor = Color.lerp(
          kRed,
          Color(0xFFFF5252),
          _pulseAnim.value,
        )!;
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: 2),
          ),
          child: child,
        );
      },
      child: Column(
        children: [
          // 헤더
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: kCream,
              border: Border(
                bottom: BorderSide(color: kLightBorder, width: 0.5),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                PressableButton(
                  onTap: () => setState(() => _showDetailScreen = false),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Color(0xFFF0EBE0),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kLightBorder, width: 0.5),
                    ),
                    child: Icon(
                      Icons.arrow_back_ios,
                      size: 14,
                      color: kMutedGold,
                    ),
                  ),
                ),
                Text(
                  'AI 예측 결과',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 16,
                    letterSpacing: 1,
                    color: kDarkBrown,
                    fontWeight: FontWeight.normal,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: kRed,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '말벌 감지',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 스크롤 영역
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _graphLabel('AI 탐지 결과'),
                  SizedBox(height: 6),
                  (hive['predictionImageUrl'] as String? ?? '').isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            hive['predictionImageUrl'],
                            width: double.infinity,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                height: 200,
                                color: kDarkBrown,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: kGold,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stack) => Container(
                              height: 200,
                              decoration: BoxDecoration(
                                color: kDarkBrown,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  '이미지를 불러올 수 없어요',
                                  style: TextStyle(
                                    color: kMutedGold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                      : Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: kDarkBrown,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              '분석 이미지 없음',
                              style: TextStyle(color: kMutedGold, fontSize: 14),
                            ),
                          ),
                        ),
                  SizedBox(height: 12),
                ],
              ),
            ),
          ),
          // 조치완료 버튼 하단 고정
          Container(
            padding: EdgeInsets.fromLTRB(14, 10, 14, 14),
            decoration: BoxDecoration(
              color: kCream,
              border: Border(top: BorderSide(color: kLightBorder, width: 0.5)),
            ),
            child: PressableButton(
              onTap: () {
                setState(() {
                  final hives = _groups[_selectedGroupIndex]['hives'] as List;
                  hives[_selectedHiveIndex]['isAlert'] = false;
                  hives[_selectedHiveIndex]['confidence'] = 0.0;
                  if (hives[_selectedHiveIndex]['isAutoMode'] == true) {
                    hives[_selectedHiveIndex]['isDoorOpen'] = true;
                  }
                  _showDetailScreen = false;
                });
              },
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: kGold,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kGold, width: 0.8),
                ),
                child: Text(
                  '조치 완료',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 16,
                    letterSpacing: 2,
                    color: kDarkBrown,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 14),
          _graphLabel('세부 결과 (RMS / FFT / Spectrogram)'),
          SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildLogDetailScreen() {
    final hive = _currentHive;
    if (hive == null) return _buildMainScreen();

    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: kCream,
            border: Border(bottom: BorderSide(color: kLightBorder, width: 0.5)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, // ← 변경
            children: [
              PressableButton(
                onTap: () => setState(() => _showLogDetail = false),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Color(0xFFF0EBE0),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kLightBorder, width: 0.5),
                  ),
                  child: Icon(
                    Icons.arrow_back_ios,
                    size: 14,
                    color: kMutedGold,
                  ),
                ),
              ),
              Text(
                // ← 추가
                'AI 분석 결과',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 16,
                  letterSpacing: 1,
                  color: kDarkBrown,
                  fontWeight: FontWeight.normal,
                ),
              ),
              SizedBox(width: 32), // ← 균형 맞추기
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(14),
            child: (hive['predictionImageUrl'] as String? ?? '').isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      hive['predictionImageUrl'],
                      width: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          height: 300,
                          color: kDarkBrown,
                          child: Center(
                            child: CircularProgressIndicator(color: kGold),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stack) => Container(
                        height: 300,
                        decoration: BoxDecoration(
                          color: kDarkBrown,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            '이미지를 불러올 수 없어요',
                            style: TextStyle(color: kMutedGold),
                          ),
                        ),
                      ),
                    ),
                  )
                : Container(
                    height: 300,
                    decoration: BoxDecoration(
                      color: kDarkBrown,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '분석 이미지 없음',
                        style: TextStyle(color: kMutedGold),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _graphLabel(String label) {
    return Text(
      label,
      style: TextStyle(fontSize: 12, color: kMutedGold, letterSpacing: 1.5),
    );
  }
}

class _VideoPlayerWidget extends StatefulWidget {
  final String url;
  const _VideoPlayerWidget({required this.url});

  @override
  State<_VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<_VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  @override
  void initState() {
    super.initState();
    print('재생 시도 URL: ${widget.url}'); // ← 추가
    _controller =
        VideoPlayerController.networkUrl(
            Uri.parse(widget.url),
            httpHeaders: {'Connection': 'keep-alive'},
          )
          ..initialize()
              .then((_) {
                print('비디오 초기화 성공!');
                setState(() => _initialized = true);
                _controller.setLooping(true);
                _controller.play();
              })
              .catchError((e) {
                print('비디오 초기화 실패: $e'); // ← 추가
                print('실패 URL: ${widget.url}');  // ← 추가
              });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return Container(
        color: const Color(0xFF1C1207),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFFE8A820)),
        ),
      );
    }
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _controller.value.size.width,
          height: _controller.value.size.height,
          child: VideoPlayer(_controller),
        ),
      ),
    );
  }
}

class HexLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = Color(0xFF1C1207)
      ..style = PaintingStyle.fill;
    final border = Paint()
      ..color = Color(0xFFE8A820)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path();
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60 - 90) * pi / 180;
      final x = cx + r * cos(angle);
      final y = cy + r * sin(angle);
      if (i == 0)
        path.moveTo(x, y);
      else
        path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, border);
  }

  @override
  bool shouldRepaint(_) => false;
}
