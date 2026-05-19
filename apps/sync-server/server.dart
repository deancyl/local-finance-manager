import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:dotenv/dotenv.dart' as dotenv;

Future<HttpServer> run(InternetAddress ip, int port) async {
  dotenv.load();
  
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsHeaders())
      .addHandler(_router);

  return serve(handler, ip, port);
}

Handler _router = Router()
    .get('/health', _healthHandler)
    .post('/api/v1/sync/upload', _syncUploadHandler)
    .get('/api/v1/sync/download', _syncDownloadHandler)
    .post('/api/v1/auth/register', _authRegisterHandler)
    .post('/api/v1/auth/login', _authLoginHandler)
    .get('/api/v1/devices', _devicesHandler)
    .post('/api/v1/devices/register', _deviceRegisterHandler);

Response _healthHandler(RequestContext context) {
  return Response.json(body: {'status': 'healthy', 'version': '0.1.0'});
}

Response _syncUploadHandler(RequestContext context) {
  return Response.json(body: {'message': 'Sync upload endpoint'});
}

Response _syncDownloadHandler(RequestContext context) {
  return Response.json(body: {'message': 'Sync download endpoint'});
}

Response _authRegisterHandler(RequestContext context) {
  return Response.json(body: {'message': 'Auth register endpoint'});
}

Response _authLoginHandler(RequestContext context) {
  return Response.json(body: {'message': 'Auth login endpoint'});
}

Response _devicesHandler(RequestContext context) {
  return Response.json(body: {'message': 'Devices endpoint'});
}

Response _deviceRegisterHandler(RequestContext context) {
  return Response.json(body: {'message': 'Device register endpoint'});
}