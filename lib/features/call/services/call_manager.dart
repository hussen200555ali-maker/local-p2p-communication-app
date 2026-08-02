import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../core/services/local_network_service.dart';
import '../models/call_model.dart';
import 'call_audio_service.dart';
import 'call_vibration_service.dart';
import 'call_notification_service.dart';

/// مدير المكالمات المتكامل
/// يربط بين جميع خدمات المكالمات
class CallManager {
  static final CallManager _instance = CallManager._internal();
  factory CallManager() => _instance;
  CallManager._internal();

  final LocalNetworkService _networkService = LocalNetworkService();
  final CallAudioService _audioService = CallAudioService();
  final CallVibrationService _vibrationService = CallVibrationService();
  final CallNotificationService _notificationService = CallNotificationService();

  bool _isInitialized = false;
  StreamSubscription? _callStatusSubscription;
  StreamSubscription? _callEndedSubscription;
  StreamSubscription? _signalingSubscription;

  // --- WebRTC State ---
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  
  // --- Signaling State ---
  final List<Map<String, dynamic>> _pendingSignals = [];
  final List<RTCIceCandidate> _pendingCandidates = [];
  bool _isHandshakeComplete = false;

  // --- ICE Restart State ---
  int _iceRestartAttempts = 0;
  static const int _maxIceRestartAttempts = 3;

  // --- Call State ---
  CallModel? _currentCall;
  bool _hasShownActiveNotification = false;
  final StreamController<CallModel?> _callStateController = StreamController.broadcast();
  Stream<CallModel?> get onCallStateChanged => _callStateController.stream;
  
  Timer? _callDurationTimer;

  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
    ]
  };

  // تهيئة مدير المكالمات
  Future<void> initialize() async {
    if (_isInitialized) return;

    await Future.wait([
      _audioService.initialize(),
      _vibrationService.initialize(),
      _notificationService.initialize(),
      localRenderer.initialize(),
      remoteRenderer.initialize(),
    ]).catchError((e) {
      debugPrint("Error during CallManager initialization: $e");
      return [];
    });

    _registerServiceCallbacks();
    _isInitialized = true;
    debugPrint('CallManager initialized successfully');
  }

  // تسجيل استدعاءات الخدمات
  void _registerServiceCallbacks() {
    _networkService.registerCallbacks(
      onCallStatusChanged: _handleCallStatusChange,
      onCallEnded: (callId) => _handleCallEnded(callId),
      onCallSignalReceived: (callId, signal) => _handleSignaling(signal),
      onIncomingCall: (call) {
        if (_currentCall == null || _currentCall!.status != CallStatus.active) {
          _currentCall = call;
          _callStateController.add(call);
        }
      },
    );
  }

  // التعامل مع تغيير حالة المكالمة
  void _handleCallStatusChange(CallModel call) {
    _currentCall = call;
    _callStateController.add(_currentCall);

    switch (call.status) {
      case CallStatus.ringing:
        _handleCallRinging(call);
        break;
      case CallStatus.active:
        _handleCallActive(call);
        break;
      case CallStatus.ended:
      case CallStatus.missed:
      case CallStatus.rejected:
        _cleanupCall();
        break;
      default:
        break;
    }
  }

  // التعامل مع المكالمة التي ترن
  void _handleCallRinging(CallModel call) {
    final currentUserId = _networkService.getCurrentUser()?.id;
    if (currentUserId == null) return;
    if (call.receiverId == currentUserId) {
      _audioService.playRingtone();
      _vibrationService.startIncomingCallVibration();
    } else if (call.callerId == currentUserId) {
      _audioService.playRingbackTone();
    }
  }

  // التعامل مع المكالمة النشطة
  void _handleCallActive(CallModel call) {
    _audioService.stopRingtone();
    _audioService.stopRingbackTone();
    _vibrationService.stopIncomingCallVibration();

    if (!_hasShownActiveNotification) {
      _hasShownActiveNotification = true;

      // تشغيل صوت بدء المكالمة
      _audioService.playCallStartSound();
      _vibrationService.vibrateCallStart();

      // عرض إشعار المكالمة النشطة
      final otherUserId = call.callerId == _networkService.getCurrentUser()?.id
          ? call.receiverId
          : call.callerId;
      final otherUser = _networkService.getUserById(otherUserId);

      if (otherUser != null) {
        _notificationService.showActiveCallNotification(
          call: call,
          otherUser: otherUser,
          duration: call.duration ?? 0,
        );
      }
    }
  }

  // التعامل مع انتهاء المكالمة
  void _handleCallEnded(String callId) {
    if (_currentCall?.id == callId) {
      _cleanupCall();
    }
  }

  // بدء مكالمة جديدة
  Future<void> startCall(String receiverId, CallType callType) async {
    try {
      if (!_isInitialized) await initialize();
      await _createPeerConnection(callType);

      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      await _networkService.startCall(receiverId, callType);
      _networkService.sendWebRTCSignal(
        _networkService.getActiveCalls().first.id,
        receiverId,
        {'type': 'offer', 'sdp': offer.sdp},
      );
    } catch (e) {
      debugPrint('Error starting call: $e');
      _cleanupCall();
    }
  }

  bool _isAcceptingCall = false;

  Future<void> acceptCall(String callId) async {
    if (_isAcceptingCall) return;
    _isAcceptingCall = true;
    try {
      final call = _networkService.getActiveCall(callId);
      if (call == null) return;

      if (_isHandshakeComplete) return;

      _isHandshakeComplete = false;
      _currentCall = call;
      await _createPeerConnection(call.callType);

      await _drainPendingSignals();

      await _networkService.acceptCall(callId);
    } catch (e) {
      debugPrint('Error accepting call: $e');
      _cleanupCall();
    } finally {
      _isAcceptingCall = false;
    }
  }

  // رفض مكالمة واردة
  Future<void> rejectCall(String callId) async {
    await _networkService.rejectCall(callId);

    // إيقاف نغمة الرنين والاهتزاز
    _audioService.stopRingtone();
    _vibrationService.stopIncomingCallVibration();

    // إلغاء إشعار المكالمة الواردة
    _notificationService.cancelActiveCallNotification();
  }

  // إنهاء مكالمة نشطة
  Future<void> endCall(String callId) async {
    await _networkService.endCall(callId);

    // سيتم التعامل مع باقي الخطوات في _handleCallEnded
  }

  // تعيين مستوى صوت المكالمة
  Future<void> setCallVolume(double volume) async {
    await _audioService.setVolume(volume);
  }

  // الحصول على المكالمات النشطة
  List<CallModel> getActiveCalls() {
    return _networkService.getActiveCalls();
  }

  // الحصول على سجل المكالمات
  CallHistory getCallHistory() {
    return _networkService.getCallHistory();
  }

  // التحقق مما إذا كان المدير مهيأً
  bool get isInitialized => _isInitialized;

  Future<void> _handleSignaling(Map<String, dynamic> signal) async {
    try {
      if (signal['type'] == 'candidate') {
        if (_peerConnection != null && _isHandshakeComplete) {
          await _peerConnection!.addCandidate(RTCIceCandidate(signal['candidate'], signal['sdpMid'], signal['sdpMLineIndex']));
        } else if (_peerConnection != null) {
          _pendingCandidates.add(RTCIceCandidate(signal['candidate'], signal['sdpMid'], signal['sdpMLineIndex']));
        } else {
          _pendingSignals.add(signal);
        }
        return;
      }
      if (_peerConnection == null) {
        _pendingSignals.add(signal);
        return;
      }
      await _processSignal(signal);
    } catch (e) {
      debugPrint('Error handling signaling: $e');
    }
  }

  Future<void> _processSignal(Map<String, dynamic> signal) async {
    if (_peerConnection == null) return;
    switch (signal['type']) {
      case 'offer':
        try {
          await _peerConnection!.setRemoteDescription(RTCSessionDescription(signal['sdp'], 'offer'));
        } catch (e) {
          debugPrint('Error setting remote description (offer): $e');
          return;
        }
        final answer = await _peerConnection!.createAnswer();
        try {
          await _peerConnection!.setLocalDescription(answer);
        } catch (e) {
          debugPrint('Error setting local description (answer): $e');
          return;
        }
        _isHandshakeComplete = true;
        if (_currentCall != null) {
          _networkService.sendWebRTCSignal(_currentCall!.id, _currentCall!.callerId, {'type': 'answer', 'sdp': answer.sdp});
        }
        _flushPendingCandidates();
        break;
      case 'answer':
        try {
          await _peerConnection!.setRemoteDescription(RTCSessionDescription(signal['sdp'], 'answer'));
        } catch (e) {
          debugPrint('Error setting remote description (answer): $e');
          return;
        }
        _isHandshakeComplete = true;
        _flushPendingCandidates();
        break;
      case 'candidate':
        if (_isHandshakeComplete) {
          try {
            await _peerConnection!.addCandidate(RTCIceCandidate(signal['candidate'], signal['sdpMid'], signal['sdpMLineIndex']));
          } catch (e) {
            debugPrint('Error adding ICE candidate: $e');
          }
        }
        break;
    }
  }

  Future<void> _drainPendingSignals() async {
    final remaining = List<Map<String, dynamic>>.from(_pendingSignals);
    _pendingSignals.clear();
    for (final signal in remaining) {
      await _processSignal(signal);
    }
  }

  void _flushPendingCandidates() {
    final candidates = List<RTCIceCandidate>.from(_pendingCandidates);
    _pendingCandidates.clear();
    if (_currentCall != null && candidates.isNotEmpty) {
      final receiverId = _currentCall!.callerId == _networkService.getCurrentUser()?.id
          ? _currentCall!.receiverId
          : _currentCall!.callerId;
      for (final candidate in candidates) {
        _networkService.sendWebRTCSignal(
          _currentCall!.id,
          receiverId,
          {'type': 'candidate', 'candidate': candidate.candidate, 'sdpMid': candidate.sdpMid, 'sdpMLineIndex': candidate.sdpMLineIndex},
        );
      }
    }
  }

  Future<void> _initiateIceRestart() async {
    if (_currentCall == null || _peerConnection == null) return;
    _iceRestartAttempts++;
    if (_iceRestartAttempts > _maxIceRestartAttempts) {
      debugPrint('ICE restart failed after $_maxIceRestartAttempts attempts, ending call');
      if (_currentCall != null) {
        await _networkService.endCall(_currentCall!.id);
      }
      _cleanupCall();
      return;
    }
    try {
      debugPrint('ICE restart attempt $_iceRestartAttempts');
      final offer = await _peerConnection!.createOffer(
        {'iceRestart': true},
      );
      await _peerConnection!.setLocalDescription(offer);
      final receiverId = _currentCall!.callerId == _networkService.getCurrentUser()?.id
          ? _currentCall!.receiverId
          : _currentCall!.callerId;
      _networkService.sendWebRTCSignal(
        _currentCall!.id,
        receiverId,
        {'type': 'offer', 'sdp': offer.sdp, 'iceRestart': true},
      );
    } catch (e) {
      debugPrint('ICE restart failed: $e');
    }
  }

  // **الإصلاح**: إضافة دوال التحكم في المكالمات
  void toggleMute(bool isMuted) {
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = !isMuted;
    });
  }

  void toggleCamera(bool isCameraOff) {
    _localStream?.getVideoTracks().forEach((track) {
      track.enabled = !isCameraOff;
    });
  }

  void toggleSpeaker(bool isSpeakerOn) {
    if (Platform.isWindows) return;
    try {
      Helper.setSpeakerphoneOn(isSpeakerOn);
    } catch (e) {
      debugPrint('Failed to toggle speaker: $e');
    }
  }

  Future<void> switchCamera() async {
    try {
      final videoTrack = _localStream?.getVideoTracks().firstOrNull;
      if (videoTrack != null) {
        await Helper.switchCamera(videoTrack);
      }
    } catch (e) {
      debugPrint('Failed to switch camera: $e');
    }
  }

  Future<void> _createPeerConnection(CallType callType) async {
    if (_peerConnection != null) return;
    try {
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': callType == CallType.video,
      });
      localRenderer.srcObject = _localStream;

      _peerConnection = await createPeerConnection(_configuration);
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      _peerConnection!.onIceCandidate = (candidate) {
        if (_currentCall == null) {
          _pendingCandidates.add(candidate);
          return;
        }
        if (_isHandshakeComplete) {
          final receiverId = _currentCall!.callerId == _networkService.getCurrentUser()?.id
              ? _currentCall!.receiverId
              : _currentCall!.callerId;
          _networkService.sendWebRTCSignal(_currentCall!.id, receiverId, {'type': 'candidate', 'candidate': candidate.candidate, 'sdpMid': candidate.sdpMid, 'sdpMLineIndex': candidate.sdpMLineIndex});
        } else {
          _pendingCandidates.add(candidate);
        }
      };

      _peerConnection!.onTrack = (event) {
        remoteRenderer.srcObject = event.streams[0];
      };

      _peerConnection!.onIceConnectionState = (state) {
        debugPrint('ICE connection state: $state');
        if (state == RTCIceConnectionState.RTCIceConnectionStateConnected) {
          _iceRestartAttempts = 0;
        }
        if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
            state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
          if (_currentCall != null && _currentCall!.status == CallStatus.active) {
            _initiateIceRestart();
          }
        }
      };

      if (callType == CallType.video && !Platform.isWindows) {
        Helper.setSpeakerphoneOn(true);
      }
    } catch (e) {
      debugPrint('Error creating peer connection: $e');
    }
  }

  void _cleanupCall() {
    _audioService.stopRingtone();
    _audioService.stopRingbackTone();
    _vibrationService.stopIncomingCallVibration();
    _notificationService.cancelActiveCallNotification();
    if (_peerConnection == null && _localStream == null) return;
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream?.dispose();
    _localStream = null;
    _peerConnection?.close();
    _peerConnection = null;
    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;
    _callDurationTimer?.cancel();
    _pendingSignals.clear();
    _pendingCandidates.clear();
    _isHandshakeComplete = false;
    _isAcceptingCall = false;
    _iceRestartAttempts = 0;
    _hasShownActiveNotification = false;
    _currentCall = null;
    _callStateController.add(null);
  }

  // **الإضافة الجديدة**: دالة لإرسال إشارات WebRTC
  void sendWebRTCSignal(String callId, String receiverId, Map<String, dynamic> signal) {
    _networkService.sendWebRTCSignal(callId, receiverId, signal);
  }

  // التخلص من الموارد
  void dispose() {
    _cleanupCall();
    _callStatusSubscription?.cancel();
    _callEndedSubscription?.cancel();
    _signalingSubscription?.cancel();
    localRenderer.dispose();
    remoteRenderer.dispose();
    _callStateController.close();
    _vibrationService.dispose();
    _isInitialized = false;
  }

  /// تنبيه عند الحاجة إلى تنظيف قنوات المكالمات يدوياً
  void cleanupCallSockets() {
    if (_currentCall != null) {
      _networkService.endCall(_currentCall!.id);
    }
  }
}
