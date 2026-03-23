import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_proj/guide_screen/avatar_guide_screen.dart';
import 'package:go_proj/models/account_creation_data.dart';
import 'package:go_proj/theme_controller.dart';
import 'package:mqtt_client/mqtt_client.dart';

import 'mqtt_connector.dart';

enum _CheckupOutcome { none, normal, abnormal, noData }

class DashBoard extends StatefulWidget {
  const DashBoard({super.key, this.accountData});

  final AccountCreationData? accountData;

  @override
  State<DashBoard> createState() => _DashBoardState();
}

class _DashBoardState extends State<DashBoard> {
  // ================== GRAPH SETTINGS (UPDATED) ==================
  // Real-time scrolling window shown on screen (last N seconds).
  static const int _windowMs = 15000;

  // Keep some extra buffer to avoid frequent trims.
  static const int _bufferMs = 3000;

  // (Old) max queue size kept as-is but not used for X spacing anymore.
  // Keeping it so you don't have to change other places/meaning.
  static const int _maxGraphQueueSize = 80;
  // Force each newly plotted point to advance by at least 1 second on X.
  static const int _plotStepMs = 1000;
  // =============================================================

  // ================== MQTT SETTINGS ==================
  static const String _mqttTopic = 'ecg/data';
  static const String _mqttHost = 'ab3f619ef35341738381fe9ef8defdbd.s1.eu.hivemq.cloud';
  static const int _mqttPort = 8883;
  static const String _mqttUsername = 'admin';
  static const String _mqttPassword = 'Admin123';
  static const bool _mqttUseTls = true;
  static const String _mqttWebsocketPath = '/mqtt';
  static const int _checkupDurationSeconds = 30;
  static const int _checkupRequiredSamples = 30;
  static const int _normalHeartRateMin = 60;
  static const int _normalHeartRateMax = 100;
  static const double _normalRrMin = 0.6;
  static const double _normalRrMax = 1.2;
  // ===================================================

  final List<_VitalSample> _vitalSamples = <_VitalSample>[];
  final List<Map<String, num>> _checkedVitalSamples = <Map<String, num>>[];

  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _mqttSubscription;
  MqttClient? _mqttClient;

  int _heartRate = 0;
  double _rrInterval = 0.0;
  int _timestamp = 0;
  int? _lastPlotTimestampMs;
  int? _lastSourceTimestamp;

  // Keep defaults as you had; you can set fixed ECG range if you know your sensor scale.
  double _displayMinY = -0.5;
  double _displayMaxY = 1.5;

  bool _isConnected = false;
  bool _isConnecting = false;
  bool _isPaused = false;

  String _connectionStatus = 'Disconnected';
  String _checkupStatus = 'Connect for check up';
  bool _isCheckupRunning = false;
  int _checkupSecondsRemaining = 0;
  int _checkupSamples = 0;
  int _checkupAbnormalSamples = 0;
  _CheckupOutcome _checkupOutcome = _CheckupOutcome.none;
  _SelectedGraphPoint? _selectedGraphPoint;

  // ================== SMOOTH MOVEMENT TICKER (UPDATED) ==================
  late final ValueNotifier<int> _repaintTick;
  Timer? _repaintTimer;
  Timer? _checkupTimer;
  AccountCreationData? _accountData;
  // =====================================================================

  @override
  void initState() {
    super.initState();
    _accountData = widget.accountData;

    // Smooth scrolling even between packets (keeps the trace moving).
    _repaintTick = ValueNotifier<int>(0);
    _repaintTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted) return;
      if (_isConnected && !_isPaused) {
        _repaintTick.value++;
      }
    });

  }

  @override
  void dispose() {
    _mqttSubscription?.cancel();
    _mqttClient?.disconnect();

    _repaintTimer?.cancel();
    _checkupTimer?.cancel();
    _repaintTick.dispose();

    super.dispose();
  }

  Future<void> _connectToMqtt() async {
    if (_isConnecting) {
      return;
    }

    if (_mqttHost.isEmpty) {
      setState(() {
        _connectionStatus = 'MQTT host is missing in dashboard.dart';
      });
      return;
    }

    setState(() {
      _isConnecting = true;
      _connectionStatus = 'Connecting to $_mqttHost...';
    });

    try {
      await _mqttSubscription?.cancel();
      _mqttSubscription = null;
      _mqttClient?.disconnect();

      final MqttClient client = await connectPlatformMqtt(
        host: _mqttHost,
        port: _mqttPort,
        username: _mqttUsername,
        password: _mqttPassword,
        useTls: _mqttUseTls,
        websocketPath: _mqttWebsocketPath,
        onConnected: _handleConnected,
        onDisconnected: _handleDisconnected,
      );

      _mqttClient = client;
      _startMqttSubscription(client);

      if (!mounted) {
        return;
      }
      setState(() {
        _isConnected = true;
        _isConnecting = false;
        _connectionStatus = 'Connected';
      });
      _startCheckup();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isConnected = false;
        _isConnecting = false;
        _connectionStatus = 'MQTT connection failed: $error';
      });
    }
  }

  Future<void> _disconnectFromMqtt() async {
    await _mqttSubscription?.cancel();
    _mqttSubscription = null;
    _mqttClient?.disconnect();
    _mqttClient = null;

    if (!mounted) {
      return;
    }

    setState(() {
      _isConnected = false;
      _isConnecting = false;
      _connectionStatus = 'Disconnected from MQTT broker';
    });
    _resetCheckupForDisconnectedState();
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
      _connectionStatus = _isPaused
          ? 'Paused live rendering (data still incoming)'
          : (_isConnected ? 'Connected' : _connectionStatus);
    });
  }

  void _startMqttSubscription(MqttClient client) {
    final subscription = client.subscribe(_mqttTopic, MqttQos.atMostOnce);
    if (subscription == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _connectionStatus = 'Subscribe failed for topic $_mqttTopic';
      });
      return;
    }

    if (client.updates == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _connectionStatus = 'Connected, but no MQTT update stream available';
      });
      return;
    }

    _mqttSubscription?.cancel();
    _mqttSubscription = client.updates?.listen((messages) {
      for (final MqttReceivedMessage<MqttMessage> message in messages) {
        final MqttPublishMessage payload = message.payload as MqttPublishMessage;
        final String payloadText = MqttPublishPayload.bytesToStringAsString(
          payload.payload.message,
        );
        if (kDebugMode) {
          print('MQTT payload on ${message.topic}: $payloadText');
        }
        ingestPayload(payloadText);
      }
    });
  }

  void _handleConnected() {
    if (!mounted) {
      return;
    }
    setState(() {
      _isConnected = true;
      _connectionStatus = 'Connected';
    });
    if (!_isCheckupRunning) {
      _startCheckup();
    }
  }

  void _handleDisconnected() {
    if (!mounted) {
      return;
    }
    setState(() {
      _isConnected = false;
      _isConnecting = false;
      _connectionStatus = 'Disconnected from MQTT broker';
    });
    _resetCheckupForDisconnectedState();
  }

  void _resetCheckupForDisconnectedState() {
    _checkupTimer?.cancel();
    if (!mounted) {
      return;
    }
    setState(() {
      _isCheckupRunning = false;
      _checkupSecondsRemaining = 0;
      _checkupSamples = 0;
      _checkupAbnormalSamples = 0;
      _checkedVitalSamples.clear();
      _checkupOutcome = _CheckupOutcome.none;
      _checkupStatus = 'Connect for check up';
    });
  }

  void _startCheckup() {
    if (!_isConnected || !mounted) {
      return;
    }

    _checkupTimer?.cancel();
    setState(() {
      _isCheckupRunning = true;
      _checkupSecondsRemaining = _checkupDurationSeconds;
      _checkupSamples = 0;
      _checkupAbnormalSamples = 0;
      _checkedVitalSamples.clear();
      _checkupOutcome = _CheckupOutcome.none;
      _checkupStatus = 'Checking data for $_checkupDurationSeconds seconds...';
    });

    _checkupTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted || !_isConnected) {
        timer.cancel();
        return;
      }

      if (_checkupSecondsRemaining <= 1) {
        timer.cancel();
        _finishCheckup();
        return;
      }

      setState(() {
        _checkupSecondsRemaining--;
      });
    });
  }

  void _finishCheckup() {
    if (!mounted) {
      return;
    }

    if (_checkupSamples == 0) {
      setState(() {
        _isCheckupRunning = false;
        _checkupSecondsRemaining = 0;
        _checkupOutcome = _CheckupOutcome.noData;
        _checkupStatus = 'No Data Transmission is happening.';
      });
      return;
    }

    final bool noAbnormalValues = _checkupAbnormalSamples == 0;
    final bool normal = noAbnormalValues;

    setState(() {
      _isCheckupRunning = false;
      _checkupSecondsRemaining = 0;
      _checkupOutcome = normal ? _CheckupOutcome.normal : _CheckupOutcome.abnormal;
      _checkupStatus = normal
          ? 'NORMAL: all $_checkupSamples samples were in range'
          : 'ABNORMAL: $_checkupAbnormalSamples abnormal in $_checkupSamples samples';
    });
  }

  bool _isSampleInNormalRange(int heartRate, double rrInterval) {
    return heartRate >= _normalHeartRateMin &&
        heartRate <= _normalHeartRateMax &&
        rrInterval >= _normalRrMin &&
        rrInterval <= _normalRrMax;
  }

  void _trackCheckupSample(int timestampMs, int heartRate, double rrInterval) {
    if (!_isCheckupRunning) {
      return;
    }

    _checkupSamples++;
    _checkedVitalSamples.add(<String, num>{
      'timestamp': timestampMs,
      'heartRate': heartRate,
      'rrInterval': rrInterval,
    });
    while (_checkedVitalSamples.length > _checkupRequiredSamples) {
      _checkedVitalSamples.removeAt(0);
    }
    if (!_isSampleInNormalRange(heartRate, rrInterval)) {
      _checkupAbnormalSamples++;
    }
  }

  // ================== PAYLOAD INGEST (UPDATED FOR VITAL COLLECTION) ==================
  void ingestPayload(String payload) {
    try {
      // Pause should stop rendering updates (your behavior).
      if (_isPaused) {
        return;
      }

      final String normalizedPayload = payload.trim().replaceAll('\u0000', '');
      Object? decoded;

      try {
        decoded = jsonDecode(normalizedPayload);
      } catch (_) {
        decoded = jsonDecode(normalizedPayload.replaceAll(';', ','));
      }

      if (decoded is! Map) {
        return;
      }

      final Map<String, dynamic> data = Map<String, dynamic>.from(decoded);

      final double? ecgValue = _asDouble(data['ecg_value']);
      final int? heartRate = _asInt(data['heart_rate']);
      final double? rrInterval = _asDouble(data['rr_interval']);
      final int? timestamp = _asInt(data['timestamp']);
      if (ecgValue == null && heartRate == null && rrInterval == null && timestamp == null) {
        return;
      }

      setState(() {
        final int receivedAtMs = DateTime.now().millisecondsSinceEpoch;
        int sampleTs = receivedAtMs;
        if (timestamp != null && timestamp > 0) {
          final int ts = timestamp;

          // Device may send epoch time or a relative running counter.
          if (ts >= 1000000000000) {
            sampleTs = ts;
          } else if (ts >= 1000000000) {
            sampleTs = ts * 1000;
          } else if (_lastSourceTimestamp != null &&
              _lastPlotTimestampMs != null &&
              ts > _lastSourceTimestamp!) {
            final int delta = ts - _lastSourceTimestamp!;
            sampleTs = _lastPlotTimestampMs! + delta.clamp(200, 5000);
          } else {
            sampleTs = receivedAtMs;
          }

          // Prevent stale/invalid past or future times from hiding the trace.
          if ((sampleTs - receivedAtMs).abs() > 30000) {
            sampleTs = receivedAtMs;
          }
          _lastSourceTimestamp = ts;
        }

        // Ensure one-step right movement for each incoming MQTT sample.
        if (_lastPlotTimestampMs != null) {
          final int minNextTs = _lastPlotTimestampMs! + _plotStepMs;
          if (sampleTs < minNextTs) {
            sampleTs = minNextTs;
          }
        }
        _lastPlotTimestampMs = sampleTs;

        final int sampleHeartRate = heartRate ?? _heartRate;
        final double sampleRrInterval = rrInterval ?? _rrInterval;
        final double sampleEcgValue = ecgValue ?? 0.0;
        _vitalSamples.add(
          _VitalSample(sampleTs, sampleHeartRate, sampleRrInterval, sampleEcgValue),
        );

        // Trim to rolling time window + buffer.
        final int cutoff = sampleTs - (_windowMs + _bufferMs);
        while (_vitalSamples.isNotEmpty && _vitalSamples.first.timestampMs < cutoff) {
          _vitalSamples.removeAt(0);
        }
        while (_vitalSamples.length > _maxGraphQueueSize) {
          _vitalSamples.removeAt(0);
        }
        if (_selectedGraphPoint != null &&
            !_vitalSamples.contains(_selectedGraphPoint!.sample)) {
          _selectedGraphPoint = null;
        }

        // Update value boxes.
        _heartRate = sampleHeartRate;
        _rrInterval = sampleRrInterval;
        _timestamp = sampleTs;

        // Dynamic range from the stored vitals collection.
        _updateDisplayRange();
        _trackCheckupSample(sampleTs, sampleHeartRate, sampleRrInterval);
      });
    } catch (error) {
      if (kDebugMode) {
        print('Failed to process MQTT payload: $error');
      }
    }
  }
  // =======================================================================

  double _vitalToPlotValue(_VitalSample sample) {
    final double rrFromHr = sample.heartRate > 0 ? (60.0 / sample.heartRate) : sample.rrInterval;
    if (sample.rrInterval > 0 && rrFromHr > 0) {
      return ((sample.rrInterval + rrFromHr) / 2.0).clamp(0.3, 2.0);
    }
    return (sample.rrInterval > 0 ? sample.rrInterval : rrFromHr).clamp(0.3, 2.0);
  }

  void _updateDisplayRange() {
    if (_vitalSamples.isEmpty) {
      _displayMinY = -0.5;
      _displayMaxY = 1.5;
      return;
    }

    double minSample = _vitalToPlotValue(_vitalSamples.first);
    double maxSample = minSample;

    for (final _VitalSample sample in _vitalSamples) {
      final double value = _vitalToPlotValue(sample);
      if (value < minSample) {
        minSample = value;
      }
      if (value > maxSample) {
        maxSample = value;
      }
    }

    final double paddedMin = minSample - 0.15;
    final double paddedMax = maxSample + 0.15;

    if ((paddedMax - paddedMin) < 0.4) {
      _displayMinY = paddedMin - 0.2;
      _displayMaxY = paddedMax + 0.2;
      return;
    }

    _displayMinY = (_displayMinY * 0.85) + (paddedMin * 0.15);
    _displayMaxY = (_displayMaxY * 0.85) + (paddedMax * 0.15);
  }

  double? _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  _SelectedGraphPoint? _nearestGraphPoint(Offset localPosition, Size chartSize) {
    if (_vitalSamples.isEmpty || chartSize.width <= 0 || chartSize.height <= 0) {
      return null;
    }

    final int now = DateTime.now().millisecondsSinceEpoch;
    final int effectiveNow =
        _vitalSamples.last.timestampMs > now ? _vitalSamples.last.timestampMs : now;
    final int start = effectiveNow - _windowMs;

    final double span = (_displayMaxY - _displayMinY).abs() < 0.000001
        ? 1
        : (_displayMaxY - _displayMinY);

    _SelectedGraphPoint? nearest;
    double nearestDistanceSq = double.infinity;

    for (final _VitalSample sample in _vitalSamples) {
      if (sample.timestampMs < start) {
        continue;
      }

      final double tNorm = ((sample.timestampMs - start) / _windowMs).clamp(0.0, 1.0);
      final double x = tNorm * chartSize.width;

      final double plotValue = _vitalToPlotValue(sample);
      final double vNorm = ((plotValue - _displayMinY) / span).clamp(0.0, 1.0);
      final double y = chartSize.height * (1 - vNorm);

      final double dx = localPosition.dx - x;
      final double dy = localPosition.dy - y;
      final double distanceSq = (dx * dx) + (dy * dy);

      if (distanceSq < nearestDistanceSq) {
        nearestDistanceSq = distanceSq;
        nearest = _SelectedGraphPoint(
          sample: sample,
          xSecondsFromWindowStart: (sample.timestampMs - start) / 1000.0,
          yValue: plotValue,
        );
      }
    }

    if (nearest == null || nearestDistanceSq > 24 * 24) {
      return null;
    }

    return nearest;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final bool showConnected = _isConnected && !_isConnecting;

    return Scaffold(
      appBar: _buildInnovativeAppBar(theme),
      drawer: _buildAccountDrawer(theme),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              theme.scaffoldBackgroundColor,
              scheme.primary.withOpacity(isDark ? 0.18 : 0.08),
              scheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double sidePadding = constraints.maxWidth < 380 ? 10 : 14;
              final double contentWidth =
                  (constraints.maxWidth - (sidePadding * 2)).clamp(0.0, 980.0).toDouble();
              final double panelHeight =
                  (constraints.maxHeight * 0.56).clamp(260.0, 560.0).toDouble();

              return Center(
                child: SizedBox(
                  width: contentWidth,
                  child: Padding(
                    padding: EdgeInsets.all(sidePadding),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildActionBar(theme, showConnected),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: panelHeight,
                            child: _buildMonitorPanel(theme),
                          ),
                          const SizedBox(height: 14),
                          _buildCheckupPanel(theme),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildInnovativeAppBar(ThemeData theme) {
    final bool isDark = theme.brightness == Brightness.dark;
    final ColorScheme scheme = theme.colorScheme;

    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: scheme.surface,
      iconTheme: IconThemeData(color: scheme.onSurface),
      titleSpacing: 6,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ECG Dashboard',
            style: theme.textTheme.titleLarge?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Container(
            decoration: BoxDecoration(
              color: scheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outline.withOpacity(0.3)),
            ),
            child: IconButton(
              tooltip: isDark ? 'Switch to light theme' : 'Switch to dark theme',
              onPressed: _toggleThemeMode,
              icon: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                color: scheme.onSurface,
              ),
            ),
          ),
        ),
      ],
      bottom: null,
    );
  }

  void _toggleThemeMode() {
    final ThemeController controller = ThemeScope.of(context);
    final Brightness brightness = Theme.of(context).brightness;
    controller.toggleFromBrightness(brightness);
  }

  Drawer _buildAccountDrawer(ThemeData theme) {
    final accountData = _accountData;
    final ColorScheme scheme = theme.colorScheme;
    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              scheme.primaryContainer.withOpacity(0.45),
              scheme.surface,
              scheme.tertiaryContainer.withOpacity(0.25),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      scheme.primary.withOpacity(0.95),
                      scheme.secondary.withOpacity(0.9),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.shadow.withOpacity(0.2),
                      blurRadius: 14,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: scheme.onPrimary.withOpacity(0.18),
                      child: Icon(
                        Icons.person_outline_rounded,
                        color: scheme.onPrimary,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            accountData?.name.isNotEmpty == true
                                ? accountData!.name
                                : 'Logged In User',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: scheme.onPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            accountData?.email.isNotEmpty == true
                                ? accountData!.email
                                : 'Account details',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onPrimary.withOpacity(0.92),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  children: [
                    ListTile(
                      leading: const Icon(Icons.menu_book_outlined),
                      title: const Text('Take Guide'),
                      onTap: () {
                        Navigator.of(context).pop();
                        _openTakeGuideScreen();
                      },
                    ),
                    if (accountData != null)
                      ListTile(
                        leading: const Icon(Icons.edit_outlined),
                        title: const Text('Edit Profile Data'),
                        onTap: () {
                          Navigator.of(context).pop();
                          Future<void>.delayed(
                            const Duration(milliseconds: 220),
                            _openDrawerEditSheet,
                          );
                        },
                      ),
                    if (accountData == null)
                      const ListTile(
                        title: Text('Create an account to view entered details here.'),
                      )
                    else ...[
                      _drawerSectionTitle(theme, 'Basic Details'),
                      ..._buildBasicInfoTiles(accountData),
                      _drawerSectionTitle(theme, 'Complaints'),
                      ..._buildBoolMapTiles(accountData.complaints),
                      _drawerInfoTile(
                        'Any other symptoms',
                        _valueOrDash(accountData.otherSymptoms),
                      ),
                      _drawerSectionTitle(theme, 'History'),
                      ..._buildBoolMapTiles(accountData.history),
                      _drawerInfoTile(
                        'If any other, mention',
                        _valueOrDash(accountData.otherHistory),
                      ),
                      _drawerSectionTitle(theme, 'Medications'),
                      _drawerInfoTile(
                        'Any medications',
                        accountData.hasMedications ? 'Yes' : 'No',
                      ),
                      _drawerInfoTile(
                        'If yes, mention',
                        _valueOrDash(accountData.medications),
                      ),
                      _drawerInfoTile(
                        'Any anticoagulant',
                        accountData.hasAnticoagulant ? 'Yes' : 'No',
                      ),
                      _drawerInfoTile(
                        'If yes, mention',
                        _valueOrDash(accountData.anticoagulant),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _confirmAndLogout,
                    icon: const Icon(Icons.logout_rounded),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    label: const Text('Logout'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBasicInfoTiles(AccountCreationData data) {
    return [
      _drawerInfoTile('Name', _valueOrDash(data.name)),
      _drawerInfoTile('Age', _valueOrDash(data.age)),
      _drawerInfoTile('Gender', _valueOrDash(data.gender)),
      _drawerInfoTile('Email', _valueOrDash(data.email)),
    ];
  }

  List<Widget> _buildBoolMapTiles(Map<String, bool> values) {
    return values.entries
        .map((entry) => _drawerInfoTile(entry.key, entry.value ? 'Yes' : 'No'))
        .toList();
  }

  Widget _drawerSectionTitle(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 12, 6, 6),
      child: Text(
        text,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _drawerInfoTile(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 3),
          Text(value),
        ],
      ),
    );
  }

  Future<void> _confirmAndLogout() async {
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Do you want to logout from this account?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) {
      return;
    }

    try {
      await _disconnectFromMqtt();
      await FirebaseAuth.instance.signOut();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logout failed. Please try again.')),
      );
    }
  }

  String _valueOrDash(String value) {
    if (value.trim().isEmpty) {
      return '-';
    }
    return value.trim();
  }

  Widget _buildActionBar(ThemeData theme, bool showConnected) {
    final ColorScheme scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surface.withOpacity(0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _statusBadge(
                showConnected
                    ? (_isPaused ? 'PAUSED' : 'LIVE')
                    : (_isConnecting ? 'CONNECTING' : 'OFFLINE'),
                showConnected
                    ? (_isPaused ? const Color(0xFFE8B84A) : const Color(0xFF30D68B))
                    : const Color(0xFFDA5A6A),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _timestamp > 0 ? 'Timestamp: $_timestamp ms' : 'Waiting for data...',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _connectionStatus,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurface.withOpacity(0.84),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _isConnected ? _disconnectFromMqtt : null,
                icon: const Icon(Icons.wifi_off),
                label: const Text('Disconnect'),
              ),
              OutlinedButton.icon(
                onPressed: _isConnected ? _togglePause : null,
                icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                label: Text(_isPaused ? 'Resume' : 'Pause'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonitorPanel(ThemeData theme) {
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final Color hrColor = isDark ? const Color(0xFF53F2A8) : const Color(0xFF0B8A63);
    final Color rrColor = isDark ? const Color(0xFF7CE2FF) : const Color(0xFF0E5FA8);
    final Color timestampColor = isDark ? const Color(0xFFF5D57A) : const Color(0xFF8A6700);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.primary.withOpacity(0.45), width: 1.3),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withOpacity(0.24),
            blurRadius: 22,
            spreadRadius: 1,
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            isDark ? const Color(0xFF02120F) : scheme.surface,
            isDark ? const Color(0xFF030A09) : scheme.surfaceContainerHighest.withOpacity(0.45),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: scheme.outline.withOpacity(0.3), width: 1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _monitorValueBox(
                    theme: theme,
                    label: 'HR',
                    value: _heartRate > 0 ? '$_heartRate' : '--',
                    unit: 'BPM',
                    color: hrColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _monitorValueBox(
                    theme: theme,
                    label: 'RR',
                    value: _rrInterval > 0 ? _rrInterval.toStringAsFixed(2) : '--',
                    unit: 'sec',
                    color: rrColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _monitorValueBox(
                    theme: theme,
                    label: 'TIMESTAMP',
                    value: _timestamp > 0 ? '$_timestamp' : '--',
                    unit: 'ms',
                    color: timestampColor,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
              child: RepaintBoundary(
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final Size chartSize = Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (TapDownDetails details) {
                        setState(() {
                          _selectedGraphPoint =
                              _nearestGraphPoint(details.localPosition, chartSize);
                        });
                      },
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _EcgPainter(
                                samples: _vitalSamples,
                                minY: _displayMinY,
                                maxY: _displayMaxY,
                                isPaused: _isPaused,
                                repaint: _repaintTick,
                                windowMs: _windowMs,
                                selectedTimestampMs:
                                    _selectedGraphPoint?.sample.timestampMs,
                              ),
                            ),
                          ),
                          if (_selectedGraphPoint != null)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.55),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFF6FE3BE).withOpacity(0.75),
                                  ),
                                ),
                                child: Text(
                                  'x=${_selectedGraphPoint!.xSecondsFromWindowStart.toStringAsFixed(2)}s  '
                                  'y=${_selectedGraphPoint!.yValue.toStringAsFixed(3)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          if (_selectedGraphPoint != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Text(
                'Selected point -> timestamp: ${_selectedGraphPoint!.sample.timestampMs} ms, '
                'HR: ${_selectedGraphPoint!.sample.heartRate}, '
                'RR: ${_selectedGraphPoint!.sample.rrInterval.toStringAsFixed(2)} s',
                style: TextStyle(
                  color: scheme.onSurface.withOpacity(0.75),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.17),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.8)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _monitorValueBox({
    required ThemeData theme,
    required String label,
    required String value,
    required String unit,
    required Color color,
  }) {
    final bool isDark = theme.brightness == Brightness.dark;
    final Color accent = isDark ? color : _darkenForLightTheme(color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF071916)
            : Color.alphaBlend(accent.withOpacity(0.08), theme.colorScheme.surface),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withOpacity(0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accent,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            unit,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accent.withOpacity(0.85),
              fontSize: 10,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckupPanel(ThemeData theme) {
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final Color noDataColor =
        isDark ? const Color(0xFFFFD38D) : const Color(0xFF8A5A00);
    final Color abnormalColor =
        isDark ? const Color(0xFFFF8D8D) : const Color(0xFFB3261E);
    final Color normalColor =
        isDark ? const Color(0xFF7FFFB1) : const Color(0xFF1F7A3D);
    final double progress =
        (_checkupDurationSeconds - _checkupSecondsRemaining) / _checkupDurationSeconds;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface.withOpacity(0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Check Up',
            style: theme.textTheme.titleMedium?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _checkupStatus,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurface.withOpacity(0.92),
            ),
          ),
          const SizedBox(height: 12),
          if (!_isConnected)
            FilledButton.icon(
              onPressed: _isConnecting ? null : _connectToMqtt,
              icon: const Icon(Icons.wifi),
              label: const Text('Connect for check up'),
            )
          else if (_isCheckupRunning) ...[
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
            ),
            const SizedBox(height: 10),
            Text(
              'Checking... $_checkupSecondsRemaining s left | Samples: $_checkupSamples/$_checkupRequiredSamples',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withOpacity(0.85),
              ),
            ),
          ] else if (_checkupOutcome == _CheckupOutcome.noData) ...[
            Text(
              'Result: Turn On Device and Recheck it',
              style: theme.textTheme.titleSmall?.copyWith(
                color: noDataColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            _buildRecheckAndGuideButtons(),
          ] else if (_checkupOutcome == _CheckupOutcome.abnormal) ...[
            Text(
              'Result: ABNORMAL',
              style: theme.textTheme.titleSmall?.copyWith(
                color: abnormalColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            _buildRecheckAndGuideButtons(),
          ] else if (_checkupOutcome == _CheckupOutcome.normal) ...[
            Text(
              'Result: NORMAL',
              style: theme.textTheme.titleSmall?.copyWith(
                color: normalColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            _buildRecheckAndGuideButtons(),
          ]
          else
            FilledButton.icon(
              onPressed: _startCheckup,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start check up'),
            ),
        ],
      ),
    );
  }

  Widget _buildRecheckAndGuideButtons() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        FilledButton.icon(
          onPressed: _startCheckup,
          icon: const Icon(Icons.refresh),
          label: const Text('Recheck'),
        ),
        OutlinedButton.icon(
          onPressed: _openTakeGuideScreen,
          icon: const Icon(Icons.menu_book_outlined),
          label: const Text('Take Guide'),
        ),
      ],
    );
  }

  void _openTakeGuideScreen() {
    String ecgStatus;
    switch (_checkupOutcome) {
      case _CheckupOutcome.normal:
        ecgStatus = 'normal';
        break;
      case _CheckupOutcome.abnormal:
        ecgStatus = 'abnormal';
        break;
      case _CheckupOutcome.noData:
      case _CheckupOutcome.none:
        ecgStatus = 'none';
        break;
    }

    final List<Map<String, num>> latestVitalSamples = List<Map<String, num>>.from(
      _checkedVitalSamples,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AvatarGuideScreen(
          fullName: _accountData?.name,
          accountData: _accountData,
          ecgStatus: ecgStatus,
          vitalSamples: latestVitalSamples,
        ),
      ),
    );
  }

  Future<void> _openDrawerEditSheet() async {
    final AccountCreationData? current = _accountData;
    if (current == null) {
      return;
    }

    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final TextEditingController nameController =
        TextEditingController(text: current.name);
    final TextEditingController ageController =
        TextEditingController(text: current.age);
    final TextEditingController otherSymptomsController =
        TextEditingController(text: current.otherSymptoms);
    final TextEditingController otherHistoryController =
        TextEditingController(text: current.otherHistory);
    final TextEditingController medicationsController =
        TextEditingController(text: current.medications);
    final TextEditingController anticoagulantController =
        TextEditingController(text: current.anticoagulant);
    final Map<String, bool> complaints = Map<String, bool>.from(current.complaints);
    final Map<String, bool> history = Map<String, bool>.from(current.history);

    String genderValue = current.gender;
    bool hasMedications = current.hasMedications;
    bool hasAnticoagulant = current.hasAnticoagulant;
    bool isSaving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext sheetContext) {
        final ThemeData theme = Theme.of(sheetContext);
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: FractionallySizedBox(
                heightFactor: 0.92,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth > 700 ? 620 : constraints.maxWidth,
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Edit Profile Data',
                                      style: theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: isSaving
                                        ? null
                                        : () => Navigator.of(sheetContext).pop(),
                                    icon: const Icon(Icons.close),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Form(
                                key: formKey,
                                child: ListView(
                                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                                  children: [
                                    TextFormField(
                                      controller: nameController,
                                      decoration: const InputDecoration(labelText: 'Name'),
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'Name is required';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: ageController,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(labelText: 'Age'),
                                    ),
                                    const SizedBox(height: 12),
                                    DropdownButtonFormField<String>(
                                      initialValue: genderValue.isEmpty ? null : genderValue,
                                      decoration: const InputDecoration(labelText: 'Gender'),
                                      items: const [
                                        DropdownMenuItem(value: 'Male', child: Text('Male')),
                                        DropdownMenuItem(value: 'Female', child: Text('Female')),
                                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                                      ],
                                      onChanged: (value) {
                                        setSheetState(() {
                                          genderValue = (value ?? '').trim();
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      initialValue: current.email,
                                      readOnly: true,
                                      decoration: const InputDecoration(
                                        labelText: 'Email',
                                        helperText: 'Email editing is disabled in drawer.',
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: otherSymptomsController,
                                      decoration:
                                          const InputDecoration(labelText: 'Any other symptoms'),
                                      minLines: 1,
                                      maxLines: 3,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Complaints',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ...complaints.entries.map(
                                      (entry) => SwitchListTile.adaptive(
                                        contentPadding: EdgeInsets.zero,
                                        value: entry.value,
                                        title: Text(entry.key),
                                        onChanged: (value) {
                                          setSheetState(() {
                                            complaints[entry.key] = value;
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: otherHistoryController,
                                      decoration:
                                          const InputDecoration(labelText: 'If any other, mention'),
                                      minLines: 1,
                                      maxLines: 3,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'History',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ...history.entries.map(
                                      (entry) => SwitchListTile.adaptive(
                                        contentPadding: EdgeInsets.zero,
                                        value: entry.value,
                                        title: Text(entry.key),
                                        onChanged: (value) {
                                          setSheetState(() {
                                            history[entry.key] = value;
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    SwitchListTile.adaptive(
                                      contentPadding: EdgeInsets.zero,
                                      value: hasMedications,
                                      title: const Text('Any medications'),
                                      onChanged: (value) {
                                        setSheetState(() {
                                          hasMedications = value;
                                        });
                                      },
                                    ),
                                    if (hasMedications)
                                      TextFormField(
                                        controller: medicationsController,
                                        decoration:
                                            const InputDecoration(labelText: 'If yes, mention'),
                                        minLines: 1,
                                        maxLines: 3,
                                      ),
                                    const SizedBox(height: 12),
                                    SwitchListTile.adaptive(
                                      contentPadding: EdgeInsets.zero,
                                      value: hasAnticoagulant,
                                      title: const Text('Any anticoagulant'),
                                      onChanged: (value) {
                                        setSheetState(() {
                                          hasAnticoagulant = value;
                                        });
                                      },
                                    ),
                                    if (hasAnticoagulant)
                                      TextFormField(
                                        controller: anticoagulantController,
                                        decoration:
                                            const InputDecoration(labelText: 'If yes, mention'),
                                        minLines: 1,
                                        maxLines: 3,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                              child: SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: isSaving
                                      ? null
                                      : () async {
                                    final FormState? form = formKey.currentState;
                                    if (form != null && !form.validate()) {
                                      return;
                                    }
                                    FocusScope.of(sheetContext).unfocus();
                                    setSheetState(() {
                                      isSaving = true;
                                    });

                                    final AccountCreationData updated = current.copyWith(
                                      name: nameController.text.trim(),
                                      age: ageController.text.trim(),
                                      gender: genderValue.trim(),
                                      complaints: complaints,
                                      otherSymptoms: otherSymptomsController.text.trim(),
                                      history: history,
                                      otherHistory: otherHistoryController.text.trim(),
                                      hasMedications: hasMedications,
                                      medications: hasMedications
                                          ? medicationsController.text.trim()
                                          : '',
                                      hasAnticoagulant: hasAnticoagulant,
                                      anticoagulant: hasAnticoagulant
                                          ? anticoagulantController.text.trim()
                                          : '',
                                    );

                                    try {
                                      await _saveAccountDataChanges(updated);
                                      if (!sheetContext.mounted) {
                                        return;
                                      }
                                      if (Navigator.of(sheetContext).canPop()) {
                                        Navigator.of(sheetContext).pop();
                                      }
                                    } finally {
                                      if (sheetContext.mounted) {
                                        setSheetState(() {
                                          isSaving = false;
                                        });
                                      }
                                    }
                                  },
                                  child: const Text('Save Changes'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );

    Future<void>.delayed(const Duration(milliseconds: 350), () {
      nameController.dispose();
      ageController.dispose();
      otherSymptomsController.dispose();
      otherHistoryController.dispose();
      medicationsController.dispose();
      anticoagulantController.dispose();
    });
  }

  Future<void> _saveAccountDataChanges(AccountCreationData updated) async {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        ...updated.toMap(),
        'uid': uid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) {
        return;
      }
      setState(() {
        _accountData = updated;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update profile. Please try again.')),
      );
    }
  }

  Color _darkenForLightTheme(Color color) {
    final HSLColor hsl = HSLColor.fromColor(color);
    final double adjustedLightness = (hsl.lightness * 0.45).clamp(0.22, 0.42);
    return hsl.withLightness(adjustedLightness).toColor();
  }
}

class _EcgPainter extends CustomPainter {
  _EcgPainter({
    required this.samples,
    required this.minY,
    required this.maxY,
    required this.isPaused,
    required Listenable repaint,
    required this.windowMs,
    this.selectedTimestampMs,
  }) : super(repaint: repaint);

  final List<_VitalSample> samples;
  final double minY;
  final double maxY;
  final bool isPaused;
  final int windowMs;
  final int? selectedTimestampMs;

  @override
  void paint(Canvas canvas, Size size) {
    _drawGrid(canvas, size);
    _drawAxesLabels(canvas, size);
    _drawTrace(canvas, size);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final Paint minorGrid = Paint()
      ..color = const Color(0x1F3A6E62)
      ..strokeWidth = 0.6;

    final Paint majorGrid = Paint()
      ..color = const Color(0x2E5A9687)
      ..strokeWidth = 0.9;

    const double minorStep = 14;
    const int majorEvery = 5;

    int index = 0;
    for (double x = 0; x <= size.width; x += minorStep) {
      final bool major = index % majorEvery == 0;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        major ? majorGrid : minorGrid,
      );
      index++;
    }

    index = 0;
    for (double y = 0; y <= size.height; y += minorStep) {
      final bool major = index % majorEvery == 0;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        major ? majorGrid : minorGrid,
      );
      index++;
    }
  }

  void _drawAxesLabels(Canvas canvas, Size size) {
    const TextStyle axisStyle = TextStyle(
      color: Color(0xFF9FC7BC),
      fontSize: 10,
      fontWeight: FontWeight.w600,
    );

    final double span = (maxY - minY).abs() < 0.000001 ? 1 : (maxY - minY);
    const int yTicks = 4;
    for (int i = 0; i <= yTicks; i++) {
      final double ratio = i / yTicks;
      final double y = size.height * ratio;
      final double value = maxY - (span * ratio);
      final TextPainter painter = TextPainter(
        text: TextSpan(text: value.toStringAsFixed(2), style: axisStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, Offset(4, (y - painter.height / 2).clamp(0.0, size.height - painter.height)));
    }

    const int xTicks = 5;
    for (int i = 0; i <= xTicks; i++) {
      final double ratio = i / xTicks;
      final double x = size.width * ratio;
      final int secondsAgo = ((windowMs / 1000.0) * (1 - ratio)).round();
      final String label = secondsAgo == 0 ? 'now' : '-${secondsAgo}s';
      final TextPainter painter = TextPainter(
        text: TextSpan(text: label, style: axisStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      final double labelX = (x - (painter.width / 2)).clamp(0.0, size.width - painter.width);
      painter.paint(canvas, Offset(labelX, size.height - painter.height - 2));
    }
  }

  void _drawTrace(Canvas canvas, Size size) {
    if (samples.isEmpty) {
      return;
    }

    final int now = DateTime.now().millisecondsSinceEpoch;
    final int effectiveNow = samples.last.timestampMs > now ? samples.last.timestampMs : now;
    final int start = effectiveNow - windowMs;

    final double span = (maxY - minY).abs() < 0.000001 ? 1 : (maxY - minY);

    final Path path = Path();
    bool started = false;
    double yForSample(_VitalSample sample) {
      final double rrFromHr = sample.heartRate > 0 ? (60.0 / sample.heartRate) : sample.rrInterval;
      final double plotValue = (sample.rrInterval > 0 && rrFromHr > 0)
          ? ((sample.rrInterval + rrFromHr) / 2.0)
          : (sample.rrInterval > 0 ? sample.rrInterval : rrFromHr);
      final double vNorm = ((plotValue - minY) / span).clamp(0.0, 1.0);
      return size.height * (1 - vNorm);
    }

    int firstVisibleIndex = -1;
    _VitalSample? previousSample;
    for (int i = 0; i < samples.length; i++) {
      final _VitalSample sample = samples[i];
      if (sample.timestampMs >= start) {
        firstVisibleIndex = i;
        break;
      }
      previousSample = sample;
    }

    // Anchor to the left boundary using interpolation so old points roll out smoothly.
    if (firstVisibleIndex > 0 && previousSample != null) {
      final _VitalSample nextSample = samples[firstVisibleIndex];
      final int t0 = previousSample.timestampMs;
      final int t1 = nextSample.timestampMs;
      if (t1 > t0) {
        final double y0 = yForSample(previousSample);
        final double y1 = yForSample(nextSample);
        final double ratio = ((start - t0) / (t1 - t0)).clamp(0.0, 1.0);
        final double yStart = y0 + ((y1 - y0) * ratio);
        path.moveTo(0, yStart);
        started = true;
      }
    }

    if (firstVisibleIndex == -1) {
      return;
    }

    for (int i = firstVisibleIndex; i < samples.length; i++) {
      final _VitalSample sample = samples[i];

      // Time -> X mapping (scrolling).
      final double tNorm = ((sample.timestampMs - start) / windowMs).clamp(0.0, 1.0);
      final double x = tNorm * size.width;

      // Value -> Y mapping.
      final double y = yForSample(sample);

      if (!started) {
        path.moveTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
      }
    }

    if (!started) return;

    final Paint glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 4.5
      ..color = const Color(0x3456DDB4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    final Paint trace = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 2
      ..color = isPaused ? const Color(0xFF8CB8AA) : const Color(0xFF6FE3BE);

    canvas.drawPath(path, glow);
    canvas.drawPath(path, trace);

    if (selectedTimestampMs != null && selectedTimestampMs! >= start) {
      final int targetTs = selectedTimestampMs!;
      _VitalSample? selectedSample;
      for (final _VitalSample sample in samples) {
        if (sample.timestampMs == targetTs) {
          selectedSample = sample;
          break;
        }
      }
      if (selectedSample != null) {
        final double tNorm = ((selectedSample.timestampMs - start) / windowMs).clamp(0.0, 1.0);
        final double x = tNorm * size.width;
        final double y = yForSample(selectedSample);
        final Paint selectionPaint = Paint()..color = const Color(0xFFFFD54F);
        final Paint ringPaint = Paint()
          ..color = const Color(0xFFFFD54F)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4;
        canvas.drawCircle(Offset(x, y), 4.0, selectionPaint);
        canvas.drawCircle(Offset(x, y), 7.0, ringPaint);
      }
    }

    // End dot (optional, keeps your look nice).
    final _VitalSample last = samples.last;
    if (last.timestampMs >= start) {
      final double tNorm = ((last.timestampMs - start) / windowMs).clamp(0.0, 1.0);
      final double endX = tNorm * size.width;

      final double rrFromHr = last.heartRate > 0 ? (60.0 / last.heartRate) : last.rrInterval;
      final double plotValue = (last.rrInterval > 0 && rrFromHr > 0)
          ? ((last.rrInterval + rrFromHr) / 2.0)
          : (last.rrInterval > 0 ? last.rrInterval : rrFromHr);
      final double vNorm = ((plotValue - minY) / span).clamp(0.0, 1.0);
      final double endY = size.height * (1 - vNorm);

      final Paint endDot = Paint()
        ..color = isPaused ? const Color(0xFF8CB8AA) : const Color(0xFF6FE3BE);

      canvas.drawCircle(Offset(endX, endY), 3.0, endDot);
    }
  }

  @override
  bool shouldRepaint(covariant _EcgPainter oldDelegate) {
    return true;
  }
}

class _VitalSample {
  const _VitalSample(this.timestampMs, this.heartRate, this.rrInterval, this.ecgValue);

  final int timestampMs;
  final int heartRate;
  final double rrInterval;
  final double ecgValue;
}

class _SelectedGraphPoint {
  const _SelectedGraphPoint({
    required this.sample,
    required this.xSecondsFromWindowStart,
    required this.yValue,
  });

  final _VitalSample sample;
  final double xSecondsFromWindowStart;
  final double yValue;
}
