import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:priceshield/core/services/auth_session.dart';
import 'package:priceshield/core/services/priceshield_api_client.dart';

/// Service managing real-time event streaming (SSE) between the backend/dashboard
/// and the mobile application. When an admin updates complaint status, moderation
/// notes, or settlement offers from the dashboard, this service delivers the update
/// live to active screens without requiring an app restart or pull-to-refresh.
class RealtimeComplaintService {
  RealtimeComplaintService._();
  static final RealtimeComplaintService instance = RealtimeComplaintService._();

  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get stream => _controller.stream;

  http.Client? _streamingClient;
  bool _isConnected = false;
  bool _isDisposed = false;
  int _activeListeners = 0;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;

  bool get isConnected => _isConnected;

  /// Start listening to backend real-time event stream
  void start() {
    if (_isDisposed) return;
    _activeListeners++;
    if (!_isConnected && _activeListeners == 1) {
      _connect();
    }
  }

  /// Stop listening when screen is disposed or app goes to background
  void stop() {
    _activeListeners = (_activeListeners - 1).clamp(0, 9999);
    if (_activeListeners <= 0) {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      try {
        _streamingClient?.close();
      } catch (_) {}
      _streamingClient = null;
      _isConnected = false;
    }
  }

  /// Manually dispatch an updated complaint to all listening screens
  void notifyComplaintUpdated(Map<String, dynamic> payload) {
    if (!_controller.isClosed) {
      _controller.add(payload);
    }
  }

  /// Immediately fetch the latest complaint data from the API and broadcast it
  Future<Map<String, dynamic>?> syncComplaintNow(String complaintId, {PriceShieldApiClient? client}) async {
    try {
      final api = client ?? priceShieldApi;
      final fresh = await api.getComplaint(complaintId);
      notifyComplaintUpdated({
        'type': 'COMPLAINT_UPDATED',
        'complaintId': complaintId,
        'status': fresh['status'],
        'confidenceLevel': fresh['confidenceLevel'],
        'moderationNotes': fresh['moderationNotes'],
        'merchantResponse': fresh['merchantResponse'],
        'complaint': fresh,
      });
      return fresh;
    } catch (e) {
      debugPrint('[RealtimeComplaintService] syncComplaintNow error: $e');
      return null;
    }
  }

  Future<void> _connect() async {
    if (_isDisposed || _activeListeners <= 0) return;
    _reconnectTimer?.cancel();

    try {
      final streamUrl = priceShieldApi.streamUrl;
      String? token;
      String? currentUserId;
      if (AuthSession.isSignedIn) {
        try {
          token = await AuthSession.refreshToken();
        } catch (_) {
          token = null;
        }
        token ??= AuthSession.token;
        currentUserId = AuthSession.currentUser.value?.id;
      }

      final queryParams = <String, String>{};
      if (token != null && token.isNotEmpty) queryParams['token'] = token;
      if (currentUserId != null && currentUserId.isNotEmpty) queryParams['userId'] = currentUserId;

      final baseUri = Uri.parse(streamUrl);
      final uri = queryParams.isNotEmpty
          ? baseUri.replace(
              queryParameters: {
                ...baseUri.queryParameters,
                ...queryParams,
              },
            )
          : baseUri;

      _streamingClient = http.Client();
      final request = http.Request('GET', uri);
      request.headers['Accept'] = 'text/event-stream';
      request.headers['Cache-Control'] = 'no-cache';
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      final response = await _streamingClient!.send(request).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        _scheduleReconnect();
        return;
      }

      _isConnected = true;
      _reconnectAttempts = 0;
      debugPrint('[RealtimeComplaintService] Connected to SSE event stream at $streamUrl');

      response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) {
              _processSseLine(line);
            },
            onDone: () {
              _isConnected = false;
              _scheduleReconnect();
            },
            onError: (err) {
              debugPrint('[RealtimeComplaintService] Stream error: $err');
              _isConnected = false;
              _scheduleReconnect();
            },
            cancelOnError: true,
          );
    } catch (e) {
      debugPrint('[RealtimeComplaintService] Connection failed: $e');
      _isConnected = false;
      _scheduleReconnect();
    }
  }

  void _processSseLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith(':')) {
      // Ping or keepalive comment
      return;
    }

    if (trimmed.startsWith('data:')) {
      final jsonStr = trimmed.substring(5).trim();
      if (jsonStr.isEmpty) return;

      try {
        final dynamic decoded = jsonDecode(jsonStr);
        if (decoded is Map<String, dynamic>) {
          debugPrint('[RealtimeComplaintService] Received event: ${decoded['type'] ?? decoded['status']}');
          _controller.add(decoded);
        }
      } catch (err) {
        debugPrint('[RealtimeComplaintService] Failed to parse SSE payload: $err');
      }
    }
  }

  void _scheduleReconnect() {
    if (_isDisposed || _activeListeners <= 0) return;
    _reconnectAttempts++;
    final delaySeconds = (_reconnectAttempts * 3).clamp(3, 30);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (!_isConnected && !_isDisposed && _activeListeners > 0) {
        _connect();
      }
    });
  }

  void dispose() {
    _isDisposed = true;
    _activeListeners = 0;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    stop();
    _controller.close();
  }
}
