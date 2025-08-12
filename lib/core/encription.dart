import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Property ID Encryption/Decryption Class - Dart version
/// Replicates the functionality of the JavaScript PropertyEncryption class
class PropertyEncryption {
  String? _key;
  String? _salt;
  bool _initialized = false;
  String? _keyWithSalt;
  
  // Cached property ID for performance
  String? _cachedPropertyId;
  
  // Regex pattern for encrypted IDs validation
  static final RegExp _encryptionPattern = RegExp(r'^[A-Za-z0-9_-]+$');

  /// Initialize the encryption with configuration
  /// Returns true if initialization is successful
  bool init({String? encryptionKey, String? encryptionSalt}) {
    try {
      _key = encryptionKey ?? dotenv.env['VITE_ENCRYPTION_KEY'] ?? '';
      _salt = encryptionSalt ?? dotenv.env['VITE_ENCRYPTION_SALT'] ?? '';
      
      if (!_validateKeys()) {
        return _initializationFailed();
      }
      
      // Cache key with salt for performance
      _keyWithSalt = _key! + _salt!;
      _initialized = true;
      return true;
      
    } catch (error) {
      debugPrint('❌ Failed to initialize encryption: $error');
      return _initializationFailed();
    }
  }

  /// Validate that the encryption keys are properly set
  bool _validateKeys() {
    const List<String> invalidKeys = [
      'TU_CLAVE_DE_ENCRIPTACION_AQUI',
      'TU_SALT_AQUI'
    ];
    
    return _key != null && 
           _key!.isNotEmpty &&
           _salt != null && 
           _salt!.isNotEmpty &&
           !invalidKeys.contains(_key) && 
           !invalidKeys.contains(_salt);
  }

  /// Handle initialization failure
  bool _initializationFailed() {
    debugPrint('❌ Invalid encryption configuration. Please set proper encryption keys.');
    _initialized = false;
    _keyWithSalt = null;
    return false;
  }

  /// Encrypt a property ID using XOR-based encryption
  /// Returns the encrypted string or null if encryption fails
  String? encrypt(dynamic propertyId) {
    if (!_isInitialized('encrypt')) return null;

    try {
      final String id = propertyId.toString();
      final String encrypted = _xorTransform(id, _keyWithSalt!);
      return _encodeToUrlSafe(encrypted);
    } catch (error) {
      debugPrint('❌ Encryption failed: $error');
      return null;
    }
  }

  /// Decrypt an encrypted property ID
  /// Returns the decrypted string or null if decryption fails
  String? decrypt(String? encryptedId) {
    if (!_isInitialized('decrypt') || encryptedId == null || encryptedId.isEmpty) {
      return null;
    }

    try {
      final String encrypted = _decodeFromUrlSafe(encryptedId);
      return _xorTransform(encrypted, _keyWithSalt!);
    } catch (error) {
      debugPrint('❌ Decryption failed: $error');
      return null;
    }
  }

  /// XOR transformation used for both encryption and decryption
  String _xorTransform(String input, String key) {
    final StringBuffer result = StringBuffer();
    final int keyLength = key.length;
    
    for (int i = 0; i < input.length; i++) {
      final int keyChar = key.codeUnitAt(i % keyLength);
      final int inputChar = input.codeUnitAt(i);
      result.writeCharCode(inputChar ^ keyChar);
    }
    
    return result.toString();
  }

  /// Encode to URL-safe Base64
  String _encodeToUrlSafe(String input) {
    return base64Encode(utf8.encode(input))
        .replaceAll('+', '-')
        .replaceAll('/', '_')
        .replaceAll('=', '');
  }

  /// Decode from URL-safe Base64
  String _decodeFromUrlSafe(String input) {
    String base64 = input
        .replaceAll('-', '+')
        .replaceAll('_', '/');
    
    // Add padding if needed
    final int padding = base64.length % 4;
    if (padding != 0) {
      base64 += '=' * (4 - padding);
    }
    
    return utf8.decode(base64Decode(base64));
  }

  /// Check if the encryption is properly initialized
  bool _isInitialized(String operation) {
    if (!_initialized) {
      debugPrint('❌ Encryption not initialized. Cannot $operation property ID.');
      return false;
    }
    return true;
  }

  /// Check if a value is an encrypted ID
  bool isEncrypted(String? value) {
    if (value == null || value.isEmpty) return false;
    
    // Quick numeric check
    if (RegExp(r'^\d+$').hasMatch(value)) return false;
    
    // Use regex pattern and check length
    return _encryptionPattern.hasMatch(value) && 
           value.length >= 4 && 
           _hasMixedCharacters(value);
  }

  /// Helper to check for mixed characters
  bool _hasMixedCharacters(String value) {
    final bool hasLetters = RegExp(r'[A-Za-z]').hasMatch(value);
    final bool hasNumbersOrSpecial = RegExp(r'[0-9_-]').hasMatch(value);
    return hasLetters && (hasNumbersOrSpecial || hasLetters);
  }

  /// Generate encrypted URL with better error handling
  String? generatePropertyUrl(dynamic propertyId, {String? baseUrl}) {
    final String? encryptedId = encrypt(propertyId);
    
    if (encryptedId == null) {
      debugPrint('❌ Cannot generate URL: encryption failed for property ID: $propertyId');
      return null;
    }
    
    return _buildUrl(baseUrl ?? 'https://ficha.inmobarco.com', encryptedId);
  }

  /// Helper to build URL safely
  String? _buildUrl(String baseUrl, String encryptedId) {
    try {
      final Uri uri = Uri.parse(baseUrl);
      final Map<String, String> queryParams = Map.from(uri.queryParameters);
      queryParams['id'] = encryptedId;
      
      final Uri newUri = uri.replace(queryParameters: queryParams);
      return newUri.toString();
    } catch (error) {
      debugPrint('❌ Failed to generate property URL: $error');
      return null;
    }
  }

  /// Extract and decrypt property ID from URL parameters
  String? getPropertyIdFromUrl(String url) {
    if (_cachedPropertyId != null) {
      return _cachedPropertyId;
    }

    try {
      final Uri uri = Uri.parse(url);
      final String? idParam = uri.queryParameters['id'];
      
      if (idParam == null || idParam.isEmpty) {
        _cachedPropertyId = null;
        return null;
      }

      // Only accept encrypted IDs
      if (isEncrypted(idParam)) {
        final String? decryptedId = decrypt(idParam);
        if (decryptedId != null) {
          _cachedPropertyId = decryptedId;
          return decryptedId;
        } else {
          debugPrint('❌ Failed to decrypt property ID: $idParam');
          _cachedPropertyId = null;
          return null;
        }
      } else {
        // Reject non-encrypted IDs
        debugPrint('❌ Property ID must be encrypted. Non-encrypted IDs are not allowed: $idParam');
        _cachedPropertyId = null;
        return null;
      }
    } catch (error) {
      debugPrint('❌ Failed to extract property ID from URL: $error');
      _cachedPropertyId = null;
      return null;
    }
  }

  /// Clear cached property ID
  void clearCache() {
    _cachedPropertyId = null;
  }

  /// Cleanup method for memory management
  void cleanup() {
    _key = null;
    _salt = null;
    _keyWithSalt = null;
    _initialized = false;
    _cachedPropertyId = null;
  }

  /// Check if the encryption is initialized
  bool get isInitialized => _initialized;

  /// Get the current encryption key (for debugging purposes only)
  String? get debugKey => _key;

  /// Get the current salt (for debugging purposes only)
  String? get debugSalt => _salt;
}

/// Global instance of PropertyEncryption
final PropertyEncryption propertyEncryption = PropertyEncryption();
