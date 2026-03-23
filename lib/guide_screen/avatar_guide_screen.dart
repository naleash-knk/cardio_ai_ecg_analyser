import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_proj/ai_chat/ai_chat_service.dart';
import 'package:go_proj/dashboard/dashboard.dart';
import 'package:go_proj/models/account_creation_data.dart';

class AvatarGuideScreen extends StatefulWidget {
  const AvatarGuideScreen({
    super.key,
    this.fullName,
    this.accountData,
    this.ecgStatus,
    this.vitalSamples = const <Map<String, num>>[],
  });

  final String? fullName;
  final AccountCreationData? accountData;
  final String? ecgStatus;
  final List<Map<String, num>> vitalSamples;

  @override
  State<AvatarGuideScreen> createState() => _AvatarGuideScreenState();
}

class _AvatarGuideScreenState extends State<AvatarGuideScreen> with SingleTickerProviderStateMixin {
  static const int _lipMotionStartFrame = 1;
  static const int _lipMotionEndFrame = 200;
  static const int _lipMotionFps = 18;
  static const int _avatarDecodeSizePx = 420;
  static const List<String> _frames = <String>[
    'assets/images/initialmotion/avatar 1.png',
    'assets/images/initialmotion/avatar 2.png',
    'assets/images/initialmotion/avatar 3.png',
    'assets/images/initialmotion/avatar 4.png',
    'assets/images/initialmotion/avatar 5.png',
  ];

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _initialFrameIndex = 0;
  int _lipFrameIndex = 0;
  late final Ticker _avatarTicker;
  bool _isInitialAnimationRunning = false;
  bool _isLipAnimationRunning = false;
  bool _didPrecache = false;
  List<String> _lipFrames = <String>[];
  bool _isLipFramePrecacheStarted = false;
  late final ValueNotifier<String> _avatarFrameNotifier;
  AccountCreationData? _accountData;

  late final List<_ChatMessage> _messages;
  late String _userSummaryMessage;
  late String _ecgStatusMessage;
  final TextEditingController _chatController = TextEditingController();
  final AiChatService _aiChatService = AiChatService();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSending = false;
  bool _isSpeaking = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didPrecache) {
      return;
    }
    for (final String frame in _frames) {
      precacheImage(_avatarProvider(frame), context);
    }
    _didPrecache = true;
  }

  @override
  void initState() {
    super.initState();
    _avatarTicker = createTicker(_onAvatarTick);
    _avatarFrameNotifier = ValueNotifier<String>(_frames.first);
    _accountData = widget.accountData;
    _configureTts();
    _userSummaryMessage = _buildUserSummaryMessage();
    _ecgStatusMessage = _buildEcgStatusMessage();
    _messages = <_ChatMessage>[
      _ChatMessage(
        text: _userSummaryMessage,
        isUser: false,
      ),
      _ChatMessage(
        text: _ecgStatusMessage,
        isUser: false,
      ),
      const _ChatMessage(
        text: 'Ok Now How can I help you...??',
        isUser: false,
      ),
    ];
    _startInitialAnimation();
    _loadLipMotionFrames();
  }

  @override
  void dispose() {
    _avatarTicker.dispose();
    _avatarFrameNotifier.dispose();
    _flutterTts.stop();
    _chatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('Take Guide'),
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[Color(0xFF03120F), Color(0xFF072721), Color(0xFF04110E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double width = constraints.maxWidth;
              final double height = constraints.maxHeight;
              final double screenShort = constraints.biggest.shortestSide;
              final double backdropSizeA =
                  (screenShort * 0.62).clamp(140.0, 240.0).toDouble();
              final double backdropSizeB =
                  (screenShort * 0.56).clamp(130.0, 220.0).toDouble();
              final double contentPadding = width < 380 ? 12 : 20;
              final bool compactHeight = height < 560;
              final double maxContentWidth = width.clamp(0.0, 980.0).toDouble();
              final double avatarSize = compactHeight
                  ? (screenShort * 0.42).clamp(120.0, 200.0).toDouble()
                  : (screenShort * (height < 720 ? 0.52 : 0.6)).clamp(180.0, 272.0).toDouble();
              final double bubbleMaxWidth = (maxContentWidth * 0.62).clamp(200.0, 430.0).toDouble();

              return Center(
                child: SizedBox(
                  width: maxContentWidth,
                  child: Stack(
                    children: [
                Positioned(
                  top: -80,
                  right: -40,
                  child: Container(
                    width: backdropSizeA,
                    height: backdropSizeA,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.tealAccent.withOpacity(0.08),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -70,
                  left: -30,
                  child: Container(
                    width: backdropSizeB,
                    height: backdropSizeB,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.greenAccent.withOpacity(0.05),
                    ),
                  ),
                ),
                      Padding(
                        padding: EdgeInsets.all(contentPadding),
                        child: Column(
                          children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const SweepGradient(
                            colors: <Color>[
                              Color(0xFF1BBE9A),
                              Color(0xFF0D4B3E),
                              Color(0xFF1BBE9A),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2AE2B5).withOpacity(0.25),
                              blurRadius: 28,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Container(
                          margin: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF020909),
                          ),
                          width: avatarSize,
                          height: avatarSize,
                          child: ClipOval(
                            child: Center(
                              child: RepaintBoundary(
                                child: ValueListenableBuilder<String>(
                                  valueListenable: _avatarFrameNotifier,
                                  builder: (context, framePath, _) {
                                    return Image(
                                      image: _avatarProvider(framePath),
                                      fit: BoxFit.cover,
                                      gaplessPlayback: true,
                                      filterQuality: FilterQuality.low,
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: compactHeight ? 8 : 16),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xE60A211C),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF1E5D4E)),
                          ),
                          child: Column(
                            children: [
                              Expanded(
                                child: ListView.builder(
                                  reverse: true,
                                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                                  itemCount: _messages.length,
                                  itemBuilder: (context, index) {
                                    final int reversedIndex = _messages.length - 1 - index;
                                    final _ChatMessage message = _messages[reversedIndex];
                                    final bool isUser = message.isUser;
                                    return Align(
                                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(vertical: 6),
                                        constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: isUser
                                                ? const <Color>[
                                                    Color(0xFF2DA283),
                                                    Color(0xFF1F7F67),
                                                  ]
                                                : const <Color>[
                                                    Color(0xFF153A34),
                                                    Color(0xFF0F2924),
                                                  ],
                                          ),
                                          borderRadius: BorderRadius.only(
                                            topLeft: const Radius.circular(16),
                                            topRight: const Radius.circular(16),
                                            bottomLeft: Radius.circular(isUser ? 16 : 5),
                                            bottomRight: Radius.circular(isUser ? 5 : 16),
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withOpacity(isUser ? 0.22 : 0.12),
                                            width: 1,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.28),
                                              blurRadius: 12,
                                              offset: const Offset(0, 6),
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          message.text,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14.5,
                                            height: 1.38,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const Divider(height: 1, color: Color(0xFF1E5D4E)),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _chatController,
                                        style: const TextStyle(color: Colors.white),
                                        decoration: InputDecoration(
                                          hintText: 'Ask medical query...',
                                          hintStyle: TextStyle(
                                            color: Colors.white.withOpacity(0.58),
                                          ),
                                          isDense: true,
                                          filled: true,
                                          fillColor: const Color(0xFF0E2E28),
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 12,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(16),
                                            borderSide: BorderSide(
                                              color: Colors.white.withOpacity(0.12),
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(16),
                                            borderSide: BorderSide(
                                              color: Colors.white.withOpacity(0.12),
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(16),
                                            borderSide: const BorderSide(
                                              color: Color(0xFF31B892),
                                              width: 1.4,
                                            ),
                                          ),
                                        ),
                                        onSubmitted: (_) => _sendMedicalQuery(),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (_isSpeaking)
                                      IconButton(
                                        onPressed: _stopSpeaking,
                                        icon: const Icon(Icons.stop_circle_outlined),
                                        color: Colors.redAccent.shade100,
                                        tooltip: 'Stop audio',
                                      ),
                                    _isSending
                                        ? const Padding(
                                            padding: EdgeInsets.all(8),
                                            child: SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                          )
                                        : Container(
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient: LinearGradient(
                                                colors: <Color>[
                                                  Color(0xFF31B892),
                                                  Color(0xFF1C8168),
                                                ],
                                              ),
                                            ),
                                            child: IconButton(
                                              onPressed: _sendMedicalQuery,
                                              icon: const Icon(Icons.send_rounded),
                                              color: Colors.white,
                                            ),
                                          ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _configureTts() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.47);
    await _flutterTts.setPitch(1.0);
    _flutterTts.setStartHandler(() {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSpeaking = true;
      });
      _startLipAnimation();
    });
    _flutterTts.setCompletionHandler(() {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSpeaking = false;
      });
      _startInitialAnimation(resetToFirst: true);
    });
    _flutterTts.setErrorHandler((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSpeaking = false;
      });
      _startInitialAnimation(resetToFirst: true);
    });
  }

  String _sanitizeForSpeech(String text) {
    final String noSymbols = text.replaceAll(RegExp(r'[\*\-\(\)\[\]\{\}]'), ' ');
    final String singleSpaces = noSymbols.replaceAll(RegExp(r'\s+'), ' ').trim();
    return singleSpaces;
  }

  Future<void> _speakReply(String text) async {
    final String toSpeak = _sanitizeForSpeech(text);
    if (toSpeak.isEmpty) {
      return;
    }
    await _flutterTts.stop();
    await _flutterTts.speak(toSpeak);
  }

  Future<void> _stopSpeaking() async {
    await _flutterTts.stop();
    if (!mounted) {
      return;
    }
    setState(() {
      _isSpeaking = false;
    });
    _startInitialAnimation(resetToFirst: true);
  }

  Future<void> _loadLipMotionFrames() async {
    final List<String> orderedFrames = List<String>.generate(
      _lipMotionEndFrame - _lipMotionStartFrame + 1,
      (index) => 'assets/images/lipmotion/${index + _lipMotionStartFrame}.jpg',
    );

    if (!mounted) {
      return;
    }
    setState(() {
      _lipFrames = orderedFrames;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precacheLipMotionFrames();
    });
  }

  Future<void> _precacheLipMotionFrames() async {
    if (!mounted || _isLipFramePrecacheStarted || _lipFrames.isEmpty) {
      return;
    }
    _isLipFramePrecacheStarted = true;
    for (final String frame in _lipFrames) {
      if (!mounted) {
        return;
      }
      await precacheImage(_avatarProvider(frame), context);
    }
  }

  void _startInitialAnimation({bool resetToFirst = false}) {
    _isLipAnimationRunning = false;
    _isInitialAnimationRunning = true;
    if (resetToFirst) {
      _initialFrameIndex = 0;
      _lipFrameIndex = 0;
    }
    _publishCurrentFrame();
    _restartAvatarTicker();
  }

  void _startLipAnimation() {
    if (_lipFrames.isEmpty) {
      return;
    }
    _isInitialAnimationRunning = false;
    _isLipAnimationRunning = true;
    _lipFrameIndex = 0;
    _publishCurrentFrame();
    _restartAvatarTicker();
  }

  void _restartAvatarTicker() {
    if (_avatarTicker.isActive) {
      _avatarTicker.stop();
    }
    _avatarTicker.start();
  }

  void _onAvatarTick(Duration elapsed) {
    if (!mounted) {
      return;
    }

    if (_isLipAnimationRunning && _isSpeaking && _lipFrames.isNotEmpty) {
      final int nextLipFrame =
          ((elapsed.inMicroseconds * _lipMotionFps) ~/ Duration.microsecondsPerSecond) %
              _lipFrames.length;
      if (nextLipFrame != _lipFrameIndex) {
        _lipFrameIndex = nextLipFrame;
        _publishCurrentFrame();
      }
      return;
    }

    if (_isInitialAnimationRunning && !_isSpeaking) {
      final int nextIdleFrame = elapsed.inSeconds % _frames.length;
      if (nextIdleFrame != _initialFrameIndex) {
        _initialFrameIndex = nextIdleFrame;
        _publishCurrentFrame();
      }
      return;
    }

    if (_avatarTicker.isActive) {
      _avatarTicker.stop();
    }
  }

  String get _currentAvatarFrame {
    if (_isSpeaking && _lipFrames.isNotEmpty) {
      return _lipFrames[_lipFrameIndex % _lipFrames.length];
    }
    return _frames[_initialFrameIndex % _frames.length];
  }

  ImageProvider _avatarProvider(String assetPath) {
    return ResizeImage.resizeIfNeeded(
      _avatarDecodeSizePx,
      _avatarDecodeSizePx,
      AssetImage(assetPath),
    );
  }

  void _publishCurrentFrame() {
    final String frame = _currentAvatarFrame;
    if (_avatarFrameNotifier.value != frame) {
      _avatarFrameNotifier.value = frame;
    }
  }

  Drawer _buildDrawer() {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AccountCreationData? accountData = _accountData;
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
                            _resolveGreetingName(),
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: scheme.onPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            accountData?.email.isNotEmpty == true
                                ? accountData!.email
                                : (FirebaseAuth.instance.currentUser?.email ?? 'Account details'),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      tileColor: Colors.white.withOpacity(0.06),
                      onTap: _openTakeGuideScreen,
                    ),
                    const SizedBox(height: 10),
                    ListTile(
                      leading: const Icon(Icons.dashboard_outlined),
                      title: const Text('Dashboard'),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      tileColor: Colors.white.withOpacity(0.06),
                      onTap: _openDashboardScreen,
                    ),
                    const SizedBox(height: 10),
                    if (accountData != null)
                      ListTile(
                        leading: const Icon(Icons.edit_outlined),
                        title: const Text('Edit Profile Data'),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        tileColor: Colors.white.withOpacity(0.06),
                        onTap: () {
                          Navigator.of(context).pop();
                          Future<void>.delayed(
                            const Duration(milliseconds: 220),
                            _openDrawerEditSheet,
                          );
                        },
                      ),
                    if (accountData != null) const SizedBox(height: 10),
                    if (accountData == null)
                      const ListTile(
                        title: Text('Create an account to view entered details here.'),
                      )
                    else ...[
                      _drawerSectionTitle(theme, 'Basic Details'),
                      _drawerInfoTile('Name', _valueOrDash(accountData.name)),
                      _drawerInfoTile('Age', _valueOrDash(accountData.age)),
                      _drawerInfoTile('Gender', _valueOrDash(accountData.gender)),
                      _drawerInfoTile('Email', _valueOrDash(accountData.email)),
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

  void _openTakeGuideScreen() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => AvatarGuideScreen(
          fullName: widget.fullName,
          accountData: _accountData,
          ecgStatus: widget.ecgStatus,
          vitalSamples: widget.vitalSamples,
        ),
      ),
    );
  }

  void _openDashboardScreen() {
    Navigator.of(context).pop();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => DashBoard(
          accountData: _accountData,
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
        _userSummaryMessage = _buildUserSummaryMessage();
        if (_messages.isNotEmpty && !_messages.first.isUser) {
          _messages[0] = _ChatMessage(text: _userSummaryMessage, isUser: false);
        }
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

  String _buildUserSummaryMessage() {
    final AccountCreationData? data = _accountData;
    final String name = _resolveGreetingName();
    if (data == null) {
      return 'Hello $name. Profile data is not available yet.';
    }

    String formatMap(Map<String, bool> values) {
      final List<String> selected = values.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();
      if (selected.isEmpty) {
        return 'None';
      }
      return selected.join(', ');
    }

    return '''
Hello $name.
Here is your profile:
Full Name: ${_valueOrDash(data.name)}
Age: ${_valueOrDash(data.age)}
Gender: ${_valueOrDash(data.gender)}
Email: ${_valueOrDash(data.email)}
Complaints: ${formatMap(data.complaints)}
Other Symptoms: ${_valueOrDash(data.otherSymptoms)}
History: ${formatMap(data.history)}
Other History: ${_valueOrDash(data.otherHistory)}
Medications: ${data.hasMedications ? _valueOrDash(data.medications) : 'No'}
Anticoagulant: ${data.hasAnticoagulant ? _valueOrDash(data.anticoagulant) : 'No'}
'''.trim();
  }

  String _buildEcgStatusMessage() {
    final String status = (widget.ecgStatus ?? '').trim().toLowerCase();
    if (status == 'normal') {
      return 'ECG Test Status: NORMAL.';
    }
    if (status == 'abnormal') {
      return 'ECG Test Status: ABNORMAL.';
    }
    return 'ECG Test Status: No ECG test found. Please take ECG test first.';
  }

  String _buildVitalsSnapshotMessage() {
    if (widget.vitalSamples.isEmpty) {
      return 'ECG Samples (timestamp, heartRate, rrInterval): Not available.';
    }
    final StringBuffer buffer = StringBuffer(
      'ECG Samples (timestamp, heartRate, rrInterval):\n',
    );
    for (final Map<String, num> sample in widget.vitalSamples) {
      final int timestamp = (sample['timestamp'] ?? 0).toInt();
      final int heartRate = (sample['heartRate'] ?? 0).toInt();
      final double rrInterval = (sample['rrInterval'] ?? 0).toDouble();
      buffer.writeln('$timestamp, $heartRate, ${rrInterval.toStringAsFixed(2)}');
    }
    return buffer.toString().trim();
  }

  String _buildCarePromptWithPatientQuery(String patientQuery) {
    return '''
$_userSummaryMessage

$_ecgStatusMessage

${_buildVitalsSnapshotMessage()}

Task:
- Use the profile + ECG context + patient query.
- Provide remedies and caring guidance for the patient.
- Keep response practical, safe, and concise.
- If emergency signs are suspected, advise immediate professional/ER care.

Patient query:
$patientQuery
'''.trim();
  }

  String _normalizedEcgStatus() {
    final String status = (widget.ecgStatus ?? '').trim().toLowerCase();
    if (status == 'normal' || status == 'abnormal') {
      return status;
    }
    return 'none';
  }

  List<Map<String, num>> _latestCheckedSamplesForApi() {
    final List<Map<String, num>> sanitized = widget.vitalSamples
        .map(
          (sample) {
            final int timestamp = (sample['timestamp'] ?? 0).toInt();
            final int heartRate = (sample['heartRate'] ?? 0).toInt();
            final double rrRaw = (sample['rrInterval'] ?? 0).toDouble();
            final double rrInterval = rrRaw.isFinite ? rrRaw : 0.0;
            return <String, num>{
              'timestamp': timestamp > 0 ? timestamp : 0,
              'heartRate': heartRate >= 0 ? heartRate : 0,
              'rrInterval': rrInterval >= 0 ? rrInterval : 0.0,
            };
          },
        )
        .toList();
    if (sanitized.length <= 30) {
      return sanitized;
    }
    return sanitized.sublist(sanitized.length - 30);
  }

  Map<String, dynamic> _buildPatientProfileForApi() {
    final AccountCreationData? data = _accountData;
    if (data == null) {
      return <String, dynamic>{};
    }
    return data.toMap();
  }

  Map<String, dynamic> _buildEcgReportForApi() {
    final List<Map<String, num>> checkedSamples = _latestCheckedSamplesForApi();
    return <String, dynamic>{
      'status': _normalizedEcgStatus(),
      'sampleCount': checkedSamples.length,
      'checkedSamples': checkedSamples,
    };
  }

  String _resolveGreetingName() {
    final String fromAccount = (_accountData?.name ?? '').trim();
    if (fromAccount.isNotEmpty) {
      return fromAccount;
    }
    final String fromArg = (widget.fullName ?? '').trim();
    if (fromArg.isNotEmpty) {
      return fromArg;
    }
    final String fromAuth = (FirebaseAuth.instance.currentUser?.displayName ?? '').trim();
    if (fromAuth.isNotEmpty) {
      return fromAuth;
    }
    return 'User';
  }

  Widget _drawerSectionTitle(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  List<Widget> _buildBoolMapTiles(Map<String, bool> map) {
    if (map.isEmpty) {
      return <Widget>[
        const ListTile(
          dense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 8),
          title: Text('-'),
        ),
      ];
    }
    return map.entries
        .map(
          (entry) => _drawerInfoTile(
            entry.key,
            entry.value ? 'Yes' : 'No',
          ),
        )
        .toList();
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

  String _valueOrDash(String value) {
    if (value.trim().isEmpty) {
      return '-';
    }
    return value.trim();
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

  Future<void> _sendMedicalQuery() async {
    final String query = _chatController.text.trim();
    if (query.isEmpty || _isSending) {
      return;
    }

    setState(() {
      _messages.add(_ChatMessage(text: query, isUser: true));
      _isSending = true;
      _chatController.clear();
    });

    try {
      final List<Map<String, String>> history = _buildConversationHistoryForApi();
      final String reply = await _aiChatService.sendMessage(
        message: query,
        history: history,
        patientProfile: _buildPatientProfileForApi(),
        ecgReport: _buildEcgReportForApi(),
        patientQuery: query,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _messages.add(
          _ChatMessage(text: reply, isUser: false),
        );
      });
      await _speakReply(reply);
    } catch (error) {
      if (!mounted) {
        return;
      }
      final String failureMessage = error is AiChatException
          ? error.toString()
          : 'Unable to get AI reply right now. Please try again.';
      if (kDebugMode) {
        debugPrint('Guide bot error: $error');
      }
      setState(() {
        _messages.add(
          _ChatMessage(
            text: failureMessage,
            isUser: false,
          ),
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failureMessage)),
      );
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSending = false;
      });
    }
  }

  List<Map<String, String>> _buildConversationHistoryForApi() {
    final List<_ChatMessage> conversationalMessages = _messages.length > 3
        ? _messages.sublist(3)
        : const <_ChatMessage>[];
    final List<_ChatMessage> recent = conversationalMessages.length > 6
        ? conversationalMessages.sublist(conversationalMessages.length - 6)
        : conversationalMessages;

    return recent
        .map(
          (msg) => <String, String>{
            'role': msg.isUser ? 'user' : 'assistant',
            'content': msg.text.length > 600 ? msg.text.substring(0, 600) : msg.text,
          },
        )
        .toList();
  }
}

class _ChatMessage {
  const _ChatMessage({required this.text, required this.isUser});

  final String text;
  final bool isUser;
}
