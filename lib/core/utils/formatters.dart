import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

String formatWithThousandsSeparator(String digits) {
  if (digits.isEmpty) {
    return '';
  }
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    buffer.write(digits[i]);
    final remaining = digits.length - i - 1;
    if (remaining > 0 && remaining % 3 == 0) {
      buffer.write('.');
    }
  }
  return buffer.toString();
}

class ThousandsSeparatorFormatter extends TextInputFormatter {
  const ThousandsSeparatorFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final formatted = formatWithThousandsSeparator(digits);
    var selectionEnd = newValue.selection.end;
    if (selectionEnd < 0) {
      selectionEnd = 0;
    } else if (selectionEnd > newValue.text.length) {
      selectionEnd = newValue.text.length;
    }
    final digitsToRight = newValue.text
        .substring(selectionEnd)
        .replaceAll(RegExp(r'[^0-9]'), '')
        .length;
    var selectionIndex = formatted.length - digitsToRight;
    if (selectionIndex < 0) {
      selectionIndex = 0;
    } else if (selectionIndex > formatted.length) {
      selectionIndex = formatted.length;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: selectionIndex),
    );
  }
}

String digitsOnly(String value, {int? maxLength}) {
  var digits = value.replaceAll(RegExp(r'[^0-9]'), '');
  if (maxLength != null && digits.length > maxLength) {
    digits = digits.substring(0, maxLength);
  }
  return digits;
}

String numericString(String value) {
  final cleaned = value
      .replaceAll(RegExp(r'[^0-9.,]'), '')
      .replaceAll(',', '');
  return cleaned;
}

void applyThousandsFormat(TextEditingController controller) {
  final digits = digitsOnly(controller.text);
  if (digits.isEmpty) {
    controller.value = const TextEditingValue(
      text: '',
      selection: TextSelection.collapsed(offset: 0),
    );
    return;
  }
  final formatted = formatWithThousandsSeparator(digits);
  controller.value = TextEditingValue(
    text: formatted,
    selection: TextSelection.collapsed(offset: formatted.length),
  );
}

bool parseBool(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final text = value.trim().toLowerCase();
    if (text.isEmpty) return false;
    return text == 'true' || text == '1' || text == 'si' || text == 'yes';
  }
  return false;
}

List<String> extractFeatures(String raw) {
  return raw
      .split(RegExp(r'[\n,;]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

String normalizeSortText(String value) {
  final lower = value.toLowerCase();
  return lower
      .replaceAll('á', 'a')
      .replaceAll('à', 'a')
      .replaceAll('ä', 'a')
      .replaceAll('â', 'a')
      .replaceAll('ã', 'a')
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ë', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ì', 'i')
      .replaceAll('ï', 'i')
      .replaceAll('î', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ò', 'o')
      .replaceAll('ö', 'o')
      .replaceAll('ô', 'o')
      .replaceAll('õ', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ù', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('û', 'u')
      .replaceAll('ñ', 'n')
      .replaceAll('ç', 'c');
}

String? normalizeProfileValue(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

String? lookupNameById(List<Map<String, dynamic>> items, String? targetId) {
  if (targetId == null || targetId.isEmpty) {
    return null;
  }
  for (final item in items) {
    final id = item['id']?.toString();
    if (id == targetId) {
      final rawName = item['name'] ?? item['nombre'] ?? item['text'];
      if (rawName == null) {
        return null;
      }
      final name = rawName.toString().trim();
      return name.isEmpty ? null : name;
    }
  }
  return null;
}
