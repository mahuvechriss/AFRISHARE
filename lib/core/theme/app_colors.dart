import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary - Green (Growth, Agriculture, Nature)
  static const Color primaryGreen = Color(0xFF2E7D32);
  static const Color primaryGreenLight = Color(0xFF4CAF50);
  static const Color primaryGreenDark = Color(0xFF1B5E20);
  static const Color primaryGreenSurface = Color(0xFFE8F5E9);

  // Secondary - Blue (Connectivity, Technology, Trust)
  static const Color primaryBlue = Color(0xFF1565C0);
  static const Color primaryBlueLight = Color(0xFF42A5F5);
  static const Color primaryBlueDark = Color(0xFF0D47A1);
  static const Color primaryBlueSurface = Color(0xFFE3F2FD);

  // Neutral
  static const Color white = Color(0xFFFFFFFF);
  static const Color backgroundLight = Color(0xFFF5F7FA);
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color cardDark = Color(0xFF2C2C2C);

  // Text
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textLight = Color(0xFF9CA3AF);
  static const Color textOnDark = Color(0xFFF5F5F5);

  // Status
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFC107);
  static const Color error = Color(0xFFE53935);
  static const Color info = Color(0xFF2196F3);

  // Transfer Status
  static const Color transferProgress = Color(0xFF42A5F5);
  static const Color transferPaused = Color(0xFFFFA726);
  static const Color transferFailed = Color(0xFFEF5350);
  static const Color transferCompleted = Color(0xFF66BB6A);

  // Device Status
  static const Color deviceOnline = Color(0xFF4CAF50);
  static const Color deviceOffline = Color(0xFFBDBDBD);
  static const Color deviceConnecting = Color(0xFFFFA726);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryGreen, primaryBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient greenGradient = LinearGradient(
    colors: [primaryGreenLight, primaryGreenDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient blueGradient = LinearGradient(
    colors: [primaryBlueLight, primaryBlueDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
