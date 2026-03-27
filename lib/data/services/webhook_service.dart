import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../core/constants/app_constants.dart';

enum WebhookErrorType {
  none,
  connectionTimeout,
  sendTimeout,
  receiveTimeout,
  connectionError,
  payloadTooLarge,
  rateLimited,
  serverError,
  badRequest,
  unauthorized,
  unknown,
}

class WebhookResult {
  final bool success;
  final bool isConnectionError;
  final WebhookErrorType errorType;
  final String? message;
  final int? statusCode;

  const WebhookResult({
    required this.success,
    this.isConnectionError = false,
    this.errorType = WebhookErrorType.none,
    this.message,
    this.statusCode,
  });

  String get userFriendlyMessage {
    switch (errorType) {
      case WebhookErrorType.none:
        return message ?? '';
      case WebhookErrorType.connectionTimeout:
        return 'No se pudo establecer conexión con el servidor. '
            'Verifique su conexión a internet e intente nuevamente.';
      case WebhookErrorType.sendTimeout:
        return 'Se agotó el tiempo enviando los datos (las fotos pueden ser muy pesadas). '
            'Intente con menos fotos o una conexión más rápida.';
      case WebhookErrorType.receiveTimeout:
        return 'El servidor no respondió a tiempo. '
            'Los datos podrían haberse recibido parcialmente. '
            'Verifique antes de reintentar.';
      case WebhookErrorType.connectionError:
        return 'Se perdió la conexión durante el envío. '
            'Verifique su conexión a internet e intente nuevamente.';
      case WebhookErrorType.payloadTooLarge:
        return 'El contenido es demasiado pesado para el servidor. '
            'Intente reducir el número de fotos o su calidad.';
      case WebhookErrorType.rateLimited:
        return 'Se han realizado demasiadas solicitudes. '
            'Espere unos minutos antes de intentar nuevamente.';
      case WebhookErrorType.serverError:
        return 'El servidor encontró un error interno '
            '(código ${statusCode ?? "desconocido"}). '
            'Intente nuevamente en unos minutos.';
      case WebhookErrorType.badRequest:
        return 'Los datos enviados no son válidos. '
            '${message ?? "Revise la información e intente nuevamente."}';
      case WebhookErrorType.unauthorized:
        return 'No tiene autorización para realizar esta operación. '
            'Cierre sesión y vuelva a iniciar.';
      case WebhookErrorType.unknown:
        return message ?? 'Ocurrió un error inesperado al enviar la información.';
    }
  }
}

class WebhookService {
  static String get _webhookUrl =>
      '${AppConstants.webhookBaseUrl}/webhook/wasi';

  static String get _deleteWebhookUrl =>
      '${AppConstants.webhookBaseUrl}/webhook/ap-delete';

  static int estimatePayloadSizeBytes(Map<String, dynamic> data) {
    try {
      final jsonString = jsonEncode(data);
      return jsonString.length;
    } catch (_) {
      return 0;
    }
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Envía una solicitud de eliminación de propiedad al webhook.
  static Future<WebhookResult> sendDelete(Map<String, dynamic> data) async {
    return _post(_deleteWebhookUrl, data);
  }

  static Future<WebhookResult> send(Map<String, dynamic> data) async {
    return _post(_webhookUrl, data);
  }

  static Future<WebhookResult> _post(String url, Map<String, dynamic> data) async {
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: AppConstants.webhookConnectTimeout,
          sendTimeout: AppConstants.webhookSendTimeout,
          receiveTimeout: AppConstants.webhookReceiveTimeout,
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      final response = await dio.post(url, data: data);
      final status = response.statusCode ?? 0;

      if (status >= 200 && status < 300) {
        return const WebhookResult(success: true);
      }

      debugPrint('Webhook responded with status $status: ${response.data}');
      return _classifyHttpStatus(status, response.data);
    } on DioException catch (dioError, stackTrace) {
      debugPrint('Error enviando al webhook: $dioError');
      debugPrint(stackTrace.toString());
      return _classifyDioError(dioError);
    } catch (e, stackTrace) {
      debugPrint('Error inesperado enviando al webhook: $e');
      debugPrint(stackTrace.toString());
      return WebhookResult(
        success: false,
        errorType: WebhookErrorType.unknown,
        message: e.toString(),
      );
    }
  }

  static WebhookResult _classifyHttpStatus(int status, dynamic responseData) {
    String? serverMessage;
    if (responseData is Map) {
      serverMessage = responseData['message']?.toString() ??
          responseData['error']?.toString();
    } else if (responseData is String && responseData.isNotEmpty) {
      serverMessage = responseData.length > 200
          ? '${responseData.substring(0, 200)}...'
          : responseData;
    }

    if (status == 413) {
      return WebhookResult(
        success: false,
        statusCode: status,
        errorType: WebhookErrorType.payloadTooLarge,
        message: serverMessage,
      );
    }
    if (status == 429) {
      return WebhookResult(
        success: false,
        statusCode: status,
        errorType: WebhookErrorType.rateLimited,
        message: serverMessage,
      );
    }
    if (status == 400) {
      return WebhookResult(
        success: false,
        statusCode: status,
        errorType: WebhookErrorType.badRequest,
        message: serverMessage,
      );
    }
    if (status == 401 || status == 403) {
      return WebhookResult(
        success: false,
        statusCode: status,
        errorType: WebhookErrorType.unauthorized,
        message: serverMessage,
      );
    }
    if (status >= 500) {
      return WebhookResult(
        success: false,
        statusCode: status,
        errorType: WebhookErrorType.serverError,
        message: serverMessage,
      );
    }

    return WebhookResult(
      success: false,
      statusCode: status,
      errorType: WebhookErrorType.unknown,
      message: serverMessage ?? 'El servidor respondió con estado $status.',
    );
  }

  static WebhookResult _classifyDioError(DioException dioError) {
    final response = dioError.response;
    if (response != null) {
      final status = response.statusCode ?? 0;
      if (status > 0) {
        return _classifyHttpStatus(status, response.data);
      }
    }

    switch (dioError.type) {
      case DioExceptionType.connectionTimeout:
        return const WebhookResult(
          success: false,
          isConnectionError: true,
          errorType: WebhookErrorType.connectionTimeout,
        );
      case DioExceptionType.sendTimeout:
        return const WebhookResult(
          success: false,
          isConnectionError: true,
          errorType: WebhookErrorType.sendTimeout,
        );
      case DioExceptionType.receiveTimeout:
        return const WebhookResult(
          success: false,
          isConnectionError: true,
          errorType: WebhookErrorType.receiveTimeout,
        );
      case DioExceptionType.connectionError:
        return const WebhookResult(
          success: false,
          isConnectionError: true,
          errorType: WebhookErrorType.connectionError,
        );
      case DioExceptionType.badCertificate:
        return const WebhookResult(
          success: false,
          isConnectionError: true,
          errorType: WebhookErrorType.connectionError,
          message: 'Error de certificado SSL. Contacte al administrador.',
        );
      case DioExceptionType.badResponse:
        return WebhookResult(
          success: false,
          errorType: WebhookErrorType.unknown,
          message: dioError.message ?? 'Respuesta inválida del servidor.',
        );
      case DioExceptionType.cancel:
        return const WebhookResult(
          success: false,
          errorType: WebhookErrorType.unknown,
          message: 'La solicitud fue cancelada.',
        );
      case DioExceptionType.unknown:
        final errorMsg = dioError.error?.toString() ?? '';
        final isConnection = errorMsg.contains('SocketException') ||
            errorMsg.contains('Connection refused') ||
            errorMsg.contains('Connection reset') ||
            errorMsg.contains('Network is unreachable') ||
            errorMsg.contains('HandshakeException');
        return WebhookResult(
          success: false,
          isConnectionError: isConnection,
          errorType: isConnection
              ? WebhookErrorType.connectionError
              : WebhookErrorType.unknown,
          message: isConnection
              ? null
              : (dioError.message ?? errorMsg),
        );
    }
  }
}
