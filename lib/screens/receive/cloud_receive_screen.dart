import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../services/cloud_relay_service.dart';
import '../../widgets/common/app_button.dart';

class CloudReceiveScreen extends StatefulWidget {
  const CloudReceiveScreen({super.key});

  @override
  State<CloudReceiveScreen> createState() => _CloudReceiveScreenState();
}

class _CloudReceiveScreenState extends State<CloudReceiveScreen> {
  final CloudRelayService _relay = CloudRelayService.instance;
  final TextEditingController _codeController = TextEditingController();

  bool _isChecking = false;
  bool _isDownloading = false;
  bool _showFileInfo = false;
  String? _error;
  Map<String, dynamic>? _fileInfo;
  Map<String, dynamic>? _downloadResult;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _checkServerUrlHelp() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finding Your IP'),
        content: const Text(
          'Windows: Open cmd and type "ipconfig" - look for IPv4 Address\n\n'
          'Mac/Linux: Open terminal and type "ifconfig" or "ip a" - look for inet address\n\n'
          'Both devices must be on the same network, or the server must be publicly accessible.\n\n'
          'Example URL: http://192.168.1.100:3000',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkCode() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() {
      _isChecking = true;
      _error = null;
      _showFileInfo = false;
      _fileInfo = null;
      _downloadResult = null;
    });

    final result = await _relay.getFileInfo(code);

    setState(() {
      _isChecking = false;
      if (result['status'] == 'ok') {
        _fileInfo = result;
        _showFileInfo = true;
      } else {
        _error = result['error'] as String? ?? 'Invalid share code';
      }
    });
  }

  Future<void> _downloadFile() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() {
      _isDownloading = true;
      _error = null;
    });

    final result = await _relay.downloadFile(shareCode: code);

    setState(() {
      _isDownloading = false;
      if (result['status'] == 'ok') {
        _downloadResult = result;
        _showFileInfo = false;
      } else {
        _error = result['error'] as String? ?? 'Download failed';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Colors.orange, Colors.deepOrange],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.cloud_download_rounded,
                size: 48,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Receive via Cloud',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter the share code from the sender\nto download files remotely',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),

            // Setup info card (shown when server is localhost)
            if (_relay.serverUrl.contains('localhost') || _relay.serverUrl.contains('127.0.0.1'))
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline,
                            color: Colors.orange, size: 20),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Relay Server Required',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Cloud transfers need a relay server running on a computer.\n\n'
                      'Quick setup:',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '1. cd server && npm install\n'
                        '2. node server.js\n'
                        '3. Find your computer IP\n'
                        '4. Settings > Cloud Relay > set URL',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                          height: 1.5,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => _checkServerUrlHelp(),
                      icon: const Icon(Icons.help_outline, size: 16),
                      label: const Text('How to find my IP?'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.orange,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),

            // Share Code Input
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.vpn_key_rounded,
                      color: Colors.orange.shade400, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _codeController,
                      textCapitalization: TextCapitalization.characters,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 4,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter share code',
                        hintStyle: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade400,
                          letterSpacing: 1,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onSubmitted: (_) => _checkCode(),
                    ),
                  ),
                  if (_codeController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        _codeController.clear();
                        setState(() {
                          _showFileInfo = false;
                          _fileInfo = null;
                          _downloadResult = null;
                          _error = null;
                        });
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Check button
            SizedBox(
              width: double.infinity,
              child: AppButton(
                text: _isChecking ? 'Checking...' : 'Check Code',
                icon: _isChecking ? null : Icons.search,
                onPressed: _isChecking || _isDownloading ? null : _checkCode,
              ),
            ),

            // Error
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppColors.error, size: 20),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Connection Error',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.error,
                        height: 1.5,
                      ),
                    ),
                    if (_error!.contains('localhost') || _error!.contains('127.0.0.1')) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quick Setup:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.error,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              '1. Open a terminal on your computer\n'
                              '2. cd server && node server.js\n'
                              '3. Find your computer IP (ipconfig/ifconfig)\n'
                              '4. Go to Settings > Cloud Relay\n'
                              '5. Enter: http://YOUR_IP:3000',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.error,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // File Info
            if (_showFileInfo && _fileInfo != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDark : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primaryGreen.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreenSurface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.description_rounded,
                            color: AppColors.primaryGreen,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _fileInfo!['fileName'] as String? ?? 'Unknown',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatSize(
                                    _fileInfo!['fileSize'] as int? ?? 0),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _infoChip(Icons.person, 'From: ${_fileInfo!['senderName'] ?? 'Unknown'}'),
                        _infoChip(Icons.timer_outlined,
                            'Expires: ${_formatExpiry(_fileInfo!['expiresAt'] as int? ?? 0)}'),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: AppButton(
                        text: _isDownloading ? 'Downloading...' : 'Download File',
                        icon: _isDownloading ? null : Icons.download_rounded,
                        onPressed:
                            _isDownloading ? null : _downloadFile,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Download Success
            if (_downloadResult != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: AppColors.success, size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      'Download Complete!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _downloadResult!['fileName'] as String? ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      _formatSize(
                          _downloadResult!['fileSize'] as int? ?? 0),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _downloadResult = null;
                          _codeController.clear();
                          _showFileInfo = false;
                          _fileInfo = null;
                        });
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Download Another'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatExpiry(int timestamp) {
    final remaining = timestamp - DateTime.now().millisecondsSinceEpoch;
    if (remaining <= 0) return 'Expired';
    final hours = remaining ~/ 3600000;
    final minutes = (remaining % 3600000) ~/ 60000;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }
}
