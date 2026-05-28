import 'dart:io';
import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import 'package:shelf/shelf.dart' hide Pipeline, show Router, logRequests;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:dotenv/dotenv.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

import 'src/services/auth_service.dart';
import 'src/services/sync_service.dart';
import 'src/services/device_service.dart';
import 'src/services/encryption_service.dart';
import 'src/middleware/auth_middleware.dart';

// Global services
late AuthService _authService;
late SyncService _syncService;
late DeviceService _deviceService;

void _validateSecret(String name, String? value, int minLength) {
  if (value == null || value.isEmpty) {
    throw StateError('CRITICAL: $name environment variable is not set. Server cannot start.');
  }
  if (value.contains('default') || value.contains('change')) {
    throw StateError('CRITICAL: $name contains placeholder value. Set a secure secret.');
  }
  if (value.length < minLength) {
    throw StateError('CRITICAL: $name must be at least $minLength characters. Got ${value.length}.');
  }
}

Future<HttpServer> run(InternetAddress ip, int port) async {
  final env = DotEnv(includePlatformEnvironment: true)..load();
  
  // Initialize services with fail-fast validation
  final jwtSecret = env['JWT_SECRET'];
  _validateSecret('JWT_SECRET', jwtSecret, 32);

  final encryptionKey = env['ENCRYPTION_KEY'];
  _validateSecret('ENCRYPTION_KEY', encryptionKey, 32);
  
  final encryption = EncryptionService(encryptionKey);
  _authService = AuthService(encryption, jwtSecret);
  _syncService = SyncService(encryption, null);
  _deviceService = DeviceService();

  final handler = const dart_frog.Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsHeaders())
      .addHandler(_router);

  return serve(handler, ip, port);
}

final _router = Router()
    .get('/health', _healthHandler)
    // Auth routes (no auth required)
    .post('/api/v1/auth/register', _authRegisterHandler)
    .post('/api/v1/auth/login', _authLoginHandler)
    // Sync routes (auth required)
    .post('/api/v1/sync/upload', _syncUploadHandler)
    .get('/api/v1/sync/download', _syncDownloadHandler)
    .get('/api/v1/sync/conflicts', _syncConflictsHandler)
    .post('/api/v1/sync/conflicts/<conflictId>/resolve', _syncConflictResolveHandler)
    // Device routes (auth required)
    .get('/api/v1/devices', _devicesHandler)
    .post('/api/v1/devices/register', _deviceRegisterHandler)
    .delete('/api/v1/devices/<deviceId>', _deviceDeleteHandler);

// Health check
Response _healthHandler(Request request) {
  return Response.json(body: {
    'status': 'healthy',
    'version': '0.1.0',
    'timestamp': DateTime.now().toIso8601String(),
  });
}

// Auth: Register
Future<Response> _authRegisterHandler(Request request) async {
  try {
    final body = await request.body();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final email = data['email'] as String?;
    final password = data['password'] as String?;

    if (email == null || password == null) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'Email and password are required'},
      );
    }

    final result = await _authService.register(email: email, password: password);
    return Response.json(body: result);
  } catch (e) {
    return Response.json(
      statusCode: 500,
      body: {'error': 'Registration failed: ${e.toString()}'},
    );
  }
}

// Auth: Login
Future<Response> _authLoginHandler(Request request) async {
  try {
    final body = await request.body();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final email = data['email'] as String?;
    final password = data['password'] as String?;

    if (email == null || password == null) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'Email and password are required'},
      );
    }

    final result = await _authService.login(email: email, password: password);
    
    if (result == null) {
      return Response.json(
        statusCode: 401,
        body: {'error': 'Invalid email or password'},
      );
    }

    return Response.json(body: result);
  } catch (e) {
    return Response.json(
      statusCode: 500,
      body: {'error': 'Login failed: ${e.toString()}'},
    );
  }
}

// Sync: Upload
Future<Response> _syncUploadHandler(Request request) async {
  try {
    // Get userId from auth header
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
    final records = data['records'] as List<dynamic>?;

    if (deviceId == null || records == null) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'device_id and records are required'},
      );
    }

    // Verify device belongs to user
    final isOwner = await _deviceService.isDeviceOwnedByUser(
      deviceId: deviceId,
      userId: userId,
    );
    
    if (!isOwner) {
      return Response.json(
        statusCode: 403,
        body: {'error': 'Device does not belong to user'},
      );
    }

    final syncRecords = records.map((r) {
      return SyncRecordRequest.fromJson(r as Map<String, dynamic>);
    }).toList();

    final result = await _syncService.upload(
      userId: userId,
      deviceId: deviceId,
      records: syncRecords,
    );

    return Response.json(body: result.toJson());
  } catch (e) {
    return Response.json(
      statusCode: 500,
      body: {'error': 'Sync upload failed: ${e.toString()}'},
    );
  }
}

// Sync: Download
Future<Response> _syncDownloadHandler(Request request) async {
  try {
    final userId = _getUserIdFromRequest(request);
    if (userId == null) {
      return Response.json(
        statusCode: 401,
        body: {'error': 'Unauthorized'},
      );
    }
    
    final deviceId = request.url.queryParameters['device_id'];
    final sinceStr = request.url.queryParameters['since'];
    final tablesStr = request.url.queryParameters['tables'];

    if (deviceId == null) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'device_id is required'},
      );
    }

    // Verify device belongs to user
    final isOwner = await _deviceService.isDeviceOwnedByUser(
      deviceId: deviceId,
      userId: userId,
    );
    
    if (!isOwner) {
      return Response.json(
        statusCode: 403,
        body: {'error': 'Device does not belong to user'},
      );
    }

    DateTime? since;
    if (sinceStr != null) {
      since = DateTime.tryParse(sinceStr);
    }

    List<String>? tables;
    if (tablesStr != null) {
      tables = tablesStr.split(',').map((t) => t.trim()).toList();
    }

    final result = await _syncService.download(
      userId: userId,
      deviceId: deviceId,
      since: since,
      tableNames: tables,
    );

    return Response.json(body: result.toJson());
  } catch (e) {
    return Response.json(
      statusCode: 500,
      body: {'error': 'Sync download failed: ${e.toString()}'},
    );
  }
}

// Sync: Get conflicts
Future<Response> _syncConflictsHandler(Request request) async {
  try {
    final userId = _getUserIdFromRequest(request);
    if (userId == null) {
      return Response.json(
        statusCode: 401,
        body: {'error': 'Unauthorized'},
      );
    }
    
    final conflicts = await _syncService.getConflicts(userId);
    return Response.json(body: {
      'conflicts': conflicts.map((c) => c.toJson()).toList(),
    });
  } catch (e) {
    return Response.json(
      statusCode: 500,
      body: {'error': 'Failed to get conflicts: ${e.toString()}'},
    );
  }
}

// Sync: Resolve conflict
Future<Response> _syncConflictResolveHandler(Request request, String conflictId) async {
  try {
    final body = await request.body();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final resolution = data['resolution'] as String?;
    final resolvedData = data['data'] as String?;

    if (resolution == null || resolvedData == null) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'resolution and data are required'},
      );
    }

    final success = await _syncService.resolveConflict(
      conflictId: conflictId,
      resolution: resolution,
      resolvedData: resolvedData,
    );

    return Response.json(body: {'success': success});
  } catch (e) {
    return Response.json(
      statusCode: 500,
      body: {'error': 'Failed to resolve conflict: ${e.toString()}'},
    );
  }
}

// Devices: List
Future<Response> _devicesHandler(Request request) async {
  try {
    final userId = _getUserIdFromRequest(request);
    if (userId == null) {
      return Response.json(
        statusCode: 401,
        body: {'error': 'Unauthorized'},
      );
    }
    
    final devices = await _deviceService.getDevices(userId);
    return Response.json(body: {
      'devices': devices.map((d) => {
        'id': d.id,
        'name': d.name,
        'public_key': d.publicKey,
        'created_at': d.createdAt.toIso8601String(),
        'last_sync_at': d.lastSyncAt.toIso8601String(),
      }).toList(),
    });
  } catch (e) {
    return Response.json(
      statusCode: 500,
      body: {'error': 'Failed to get devices: ${e.toString()}'},
    );
  }
}

// Devices: Register
Future<Response> _deviceRegisterHandler(Request request) async {
  try {
    final userId = _getUserIdFromRequest(request);
    if (userId == null) {
      return Response.json(
        statusCode: 401,
        body: {'error': 'Unauthorized'},
      );
    }
    
    final body = await request.body();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final name = data['name'] as String?;
    final publicKey = data['public_key'] as String?;

    if (name == null) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'name is required'},
      );
    }

    final device = await _deviceService.register(
      userId: userId,
      name: name,
      publicKey: publicKey,
    );

    return Response.json(body: {
      'id': device.id,
      'name': device.name,
      'public_key': device.publicKey,
      'created_at': device.createdAt.toIso8601String(),
      'last_sync_at': device.lastSyncAt.toIso8601String(),
    });
  } catch (e) {
    return Response.json(
      statusCode: 500,
      body: {'error': 'Failed to register device: ${e.toString()}'},
    );
  }
}

// Devices: Delete
Future<Response> _deviceDeleteHandler(Request request, String deviceId) async {
  try {
    final userId = _getUserIdFromRequest(request);
    if (userId == null) {
      return Response.json(
        statusCode: 401,
        body: {'error': 'Unauthorized'},
      );
    }
    
    // Verify device belongs to user
    final isOwner = await _deviceService.isDeviceOwnedByUser(
      deviceId: deviceId,
      userId: userId,
    );
    
    if (!isOwner) {
      return Response.json(
        statusCode: 403,
        body: {'error': 'Device does not belong to user'},
      );
    }

    final success = await _deviceService.deleteDevice(deviceId);
    return Response.json(body: {'success': success});
  } catch (e) {
    return Response.json(
      statusCode: 500,
      body: {'error': 'Failed to delete device: ${e.toString()}'},
    );
  }
}

/// Helper to extract userId from JWT token in Authorization header
String? _getUserIdFromRequest(Request request) {
  final authHeader = request.headers['authorization'];
  if (authHeader == null || !authHeader.startsWith('Bearer ')) {
    return null;
  }
  
  final token = authHeader.substring(7);
  final env = DotEnv(includePlatformEnvironment: true)..load();
  final jwtSecret = env['JWT_SECRET'];
  _validateSecret('JWT_SECRET', jwtSecret, 32);
  
  try {
    final jwt = JWT.verify(token, SecretKey(jwtSecret!));
    return jwt.payload['sub'] as String?;
  } catch (e) {
    return null;
  }
}