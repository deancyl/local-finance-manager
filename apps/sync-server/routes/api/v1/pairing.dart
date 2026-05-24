import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import 'package:shelf/shelf.dart' show Router;
import '../../../src/services/pairing_service.dart';
import '../../../src/middleware/auth_middleware.dart';

/// Pairing API routes.
/// 
/// POST /api/v1/pairing/initiate - Generate pairing token
/// POST /api/v1/pairing/complete - Complete pairing
/// GET /api/v1/pairing/status/:id - Check pairing status
Handler get onRequest => Router()
    .post('/initiate', _initiatePairing)
    .post('/complete', _completePairing)
    .get('/status/<id>', _checkStatus);

Future<Response> _initiatePairing(Request request) async {
  final userId = _getUserIdFromRequest(request);
  if (userId == null) {
    return Response.json(
      statusCode: 401,
      body: {'error': 'Unauthorized'},
    );
  }
  
  final body = await request.body();
  final data = jsonDecode(body) as Map<String, dynamic>;
  final deviceId = data['device_id'] as String?;
  
  if (deviceId == null) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'device_id is required'},
    );
  }
  
  final pairingService = PairingService();
  final token = await pairingService.initiatePairing(
    userId: userId,
    deviceId: deviceId,
  );
  
  return Response.json(body: token.toJson());
}

Future<Response> _completePairing(Request request) async {
  final userId = _getUserIdFromRequest(request);
  if (userId == null) {
    return Response.json(
      statusCode: 401,
      body: {'error': 'Unauthorized'},
    );
  }
  
  final body = await request.body();
  final data = jsonDecode(body) as Map<String, dynamic>;
  final token = data['token'] as String?;
  final newDeviceId = data['device_id'] as String?;
  
  if (token == null || newDeviceId == null) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'token and device_id are required'},
    );
  }
  
  final pairingService = PairingService();
  final pairedDeviceId = await pairingService.completePairing(
    token: token,
    newDeviceId: newDeviceId,
    userId: userId,
  );
  
  if (pairedDeviceId == null) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'Invalid or expired token'},
    );
  }
  
  return Response.json(body: {
    'success': true,
    'paired_device_id': pairedDeviceId,
  });
}

Future<Response> _checkStatus(Request request, String id) async {
  final pairingService = PairingService();
  final status = await pairingService.checkStatus(id);
  
  return Response.json(body: {
    'id': id,
    'status': status.name,
  });
}

/// Helper to extract userId from request headers
String? _getUserIdFromRequest(Request request) {
  // In a real implementation, this would extract from JWT token
  // For now, return null to indicate auth is needed
  final authHeader = request.headers['authorization'];
  if (authHeader == null || !authHeader.startsWith('Bearer ')) {
    return null;
  }
  // Token validation would happen here
  return 'user-id-from-token';
}