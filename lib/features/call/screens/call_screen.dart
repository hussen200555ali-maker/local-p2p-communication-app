import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:iconsax/iconsax.dart';
import '../../auth/models/user_model.dart';
import '../models/call_model.dart';
import '../services/call_manager.dart';

class CallScreen extends StatefulWidget {
  final User friend;
  final bool isCaller;
  final String? callId;
  final CallType callType;
  final Map<String, dynamic>? offer;

  const CallScreen({
    super.key,
    required this.friend,
    this.isCaller = true,
    this.callId,
    required this.callType,
    this.offer,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with TickerProviderStateMixin {
  final CallManager _callManager = CallManager();
  StreamSubscription? _callStateSubscription;

  late AnimationController _scaleController;
  late AnimationController _slideController;

  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isSpeakerOn = true;
  bool _isEnding = false;
  CallModel? _currentCall;
  Timer? _callDurationTimer;
  int _callDuration = 0;

  @override
  void initState() {
    super.initState();

    _setupAnimations();
    _startAnimations();

    _isCameraOff = widget.callType == CallType.audio;

    _callStateSubscription = _callManager.onCallStateChanged.listen((call) {
      if (!mounted) return;
      setState(() {
        _currentCall = call;
      });
      if (call == null ||
          call.status == CallStatus.ended ||
          call.status == CallStatus.rejected ||
          call.status == CallStatus.missed) {
        _handleHangUp();
      } else if (call.status == CallStatus.active) {
        _startCallDurationTimer();
      }
    });

    if (widget.isCaller) {
      _callManager.startCall(widget.friend.id, widget.callType);
    } else if (widget.callId != null) {
      _callManager.acceptCall(widget.callId!);
    }
  }

  void _setupAnimations() {
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
  }

  void _startAnimations() {
    _scaleController.forward();
    Future.delayed(const Duration(milliseconds: 600), () {
      _slideController.forward();
    });
  }

  void _stopAnimations() {
    _scaleController.stop();
    _slideController.stop();
  }

  @override
  void dispose() {
    _stopAnimations();
    _scaleController.dispose();
    _slideController.dispose();
    _callStateSubscription?.cancel();
    _callDurationTimer?.cancel();
    super.dispose();
  }

  void _startCallDurationTimer() {
    _callDurationTimer?.cancel();
    _callDurationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callDuration = timer.tick;
        });
      }
    });
  }

  void _handleHangUp() {
    if (_isEnding) return;
    _isEnding = true;
    if (mounted) {
      try {
        Navigator.of(context).pop();
      } catch (e) {
        debugPrint('_handleHangUp error: $e');
      }
    }
  }

  void _toggleMute() => setState(() {
        _isMuted = !_isMuted;
        _callManager.toggleMute(_isMuted);
      });

  void _toggleCamera() {
    if (widget.callType == CallType.audio) return;
    setState(() {
      _isCameraOff = !_isCameraOff;
      _callManager.toggleCamera(_isCameraOff);
    });
  }

  void _toggleSpeaker() => setState(() {
        _isSpeakerOn = !_isSpeakerOn;
        _callManager.toggleSpeaker(_isSpeakerOn);
      });

  void _hangUp() {
    if (_currentCall != null) {
      _callManager.endCall(_currentCall!.id);
    }
    _handleHangUp();
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds / 60).floor().toString().padLeft(2, '0');
    final remainingSeconds = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainingSeconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (widget.callType == CallType.video)
            Positioned.fill(
              child: RTCVideoView(_callManager.remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
            ),
          if (widget.callType == CallType.audio || _isCameraOff)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(radius: 60, child: Text(widget.friend.username.substring(0, 1).toUpperCase(), style: TextStyle(fontSize: 50))),
                  SizedBox(height: 20),
                  Text("مكالمة صوتية...", style: TextStyle(color: Colors.white, fontSize: 18)),
                ],
              ),
            ),
          if (widget.callType == CallType.video && !_isCameraOff)
            Positioned(
              top: 40,
              right: 20,
              width: 100,
              height: 150,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: RTCVideoView(_callManager.localRenderer, mirror: true, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
              ),
            ),
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: _buildControls(),
          ),
          Positioned(
            top: 50,
            left: 20,
            right: 130,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.friend.username,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 4, color: Colors.black54)]),
                ),
                if (_currentCall?.status == CallStatus.active)
                  Text(
                    _formatDuration(_callDuration),
                    style: const TextStyle(color: Colors.white, fontSize: 16, shadows: [Shadow(blurRadius: 4, color: Colors.black54)]),
                  )
                else
                  Text(
                    _currentCall?.status.toString().split('.').last ?? 'Connecting...',
                    style: const TextStyle(color: Colors.white, fontSize: 16, shadows: [Shadow(blurRadius: 4, color: Colors.black54)]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildControlButton(
          icon: _isMuted ? Iconsax.microphone_slash_1 : Iconsax.microphone_2,
          onPressed: _toggleMute,
          color: _isMuted ? Colors.white : Colors.blue,
          backgroundColor: _isMuted ? Colors.red : Colors.white24,
        ),
        _buildControlButton(
          icon: Iconsax.call_remove,
          onPressed: _hangUp,
          color: Colors.white,
          backgroundColor: Colors.red,
          iconSize: 32,
        ),
        if (widget.callType == CallType.video) ...[
          _buildControlButton(
            icon: _isCameraOff ? Iconsax.video_slash : Iconsax.video,
            onPressed: _toggleCamera,
            color: _isCameraOff ? Colors.white : Colors.blue,
            backgroundColor: _isCameraOff ? Colors.red : Colors.white24,
          ),
          _buildControlButton(
            icon: Iconsax.repeat,
            onPressed: () => _callManager.switchCamera(),
            color: Colors.white,
            backgroundColor: Colors.white24,
          ),
        ],
        _buildControlButton(
          icon: _isSpeakerOn ? Iconsax.volume_high : Iconsax.volume_slash,
          onPressed: _toggleSpeaker,
          color: Colors.white,
          backgroundColor: Colors.white24,
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
    required Color backgroundColor,
    double iconSize = 24,
  }) {
    return CircleAvatar(
      radius: 30,
      backgroundColor: backgroundColor,
      child: IconButton(
        icon: Icon(icon, color: color, size: iconSize),
        onPressed: onPressed,
      ),
    );
  }
}
