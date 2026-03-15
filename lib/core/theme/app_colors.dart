import 'package:flutter/material.dart';

class AppColors {
  // ── Paleta de identidad Inmobarco ──────────────────────────────────────────
  static const Color primaryColor   = Color(0xFF1B99D3); // azul principal
  static const Color secondaryColor = Color(0xFF48BFF7); // azul claro

  // ── Neutros del manual de identidad ───────────────────────────────────────
  static const Color white     = Color(0xFFF1FAFE); // blanco Inmobarco
  static const Color pureWhite = Color(0xFFFFFFFF); // blanco absoluto (iconos, textos sobre primario)
  static const Color gray      = Color(0xFFD2D9E0); // gris Inmobarco
  static const Color dark      = Color(0xFF141F21); // ~negro Inmobarco

  // ── Texto ──────────────────────────────────────────────────────────────────
  static const Color textDark   = dark;
  static const Color textColor  = Color(0xFF3F3F3F);
  static const Color textColor2 = Color(0xFF8B8B8B);

  // ── Backgrounds (usa la paleta de identidad) ──────────────────────────────
  static const Color backgroundLevel1 = pureWhite;          // tarjetas / modales
  static const Color backgroundLevel2 = Color(0xFFF8FAFB); // superficies intermedias
  static const Color backgroundLevel3 = white;              // scaffold (blanco Inmobarco)

  // ── Bordes / divisores ────────────────────────────────────────────────────
  static const Color border       = gray;
  static const Color borderLight  = Color(0xFFEAEEF2);

  // ── Colores semánticos ────────────────────────────────────────────────────
  static const Color success = Color(0xFF28A745);
  static const Color error   = Color(0xFFDC3545);
  static const Color warning = Color(0xFFE07B00);
  static const Color info    = Color(0xFF0D7BB5);

  // ── Overlays ──────────────────────────────────────────────────────────────
  static const Color overlayDark  = Color(0xB3141F21); // dark 70 %
  static const Color overlayLight = Color(0x4D141F21); // dark 30 %
}
