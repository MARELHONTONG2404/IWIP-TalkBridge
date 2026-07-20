import 'package:flutter/material.dart';

/// Calm, professional palette for IWIP TalkBridge.
abstract final class AppColors {
  static const coral = Color(0xFF2563EB);
  static const orange = Color(0xFFF59E0B);
  static const sunny = Color(0xFFEAB308);
  static const mint = Color(0xFF16A34A);
  static const sky = Color(0xFF0EA5E9);
  static const violet = Color(0xFF7C3AED);
  static const pink = Color(0xFFDB2777);
  static const cyan = Color(0xFF06B6D4);

  static const backgroundTop = Color(0xFFF8FAFC);
  static const backgroundMid = Color(0xFFF1F5F9);
  static const backgroundBottom = Color(0xFFEFF6FF);

  static const heroGradient = [
    Color(0xFF1D4ED8),
    Color(0xFF2563EB),
    Color(0xFF0EA5E9),
  ];

  static const splashGradient = [
    Color(0xFF0F172A),
    Color(0xFF1E40AF),
    Color(0xFF2563EB),
    Color(0xFF0EA5E9),
  ];

  static const featuredGradient = [
    Color(0xFF1D4ED8),
    Color(0xFF2563EB),
    Color(0xFF0EA5E9),
  ];

  static const statColors = [sky, mint, violet];

  // Conversation mode uses a dedicated dark surface palette.
  static const translateBg = Color(0xFF0F172A);
  static const cardBg = Color(0xFF172033);
  static const textPrimary = Color(0xFFF8FAFC);
  static const textMuted = Color(0xFF94A3B8);
  static const accentBlue = Color(0xFF60A5FA);
  static const accentRed = Color(0xFFFB7185);
  static const divider = Color(0xFF334155);
  static const pillBg = Color(0xFF2563EB);
  static const card = Color(0xFF172033);
  static const cardElevated = Color(0xFF1E293B);
}

