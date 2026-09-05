import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/captured_specimen.dart';
import '../../theme/strata_theme.dart';
import '../../widgets/glass_icon_button.dart';

enum IdentifyMode { library, photo, liveId }

class IdentifyScreen extends StatefulWidget {
  const IdentifyScreen({super.key});

  static const defaultSpecimenId = 'dact-1';

  @override
  State<IdentifyScreen> createState() => _IdentifyScreenState();
}

class _IdentifyScreenState extends State<IdentifyScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();

  IdentifyMode _mode = IdentifyMode.photo;
  bool _flashOn = false;
  bool _busy = false;
  Uint8List? _previewBytes;
  String? _previewPath;
  late final AnimationController _scanController;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  Future<void> _pickFromGallery() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        imageQuality: 88,
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _previewBytes = bytes;
        _previewPath = file.path;
        _mode = IdentifyMode.library;
      });
    } catch (error) {
      _showCaptureError('Could not open the photo library.', error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _capturePhoto() async {
    if (_busy) return;
    if (_previewBytes != null) {
      _openResult(_previewBytes!, _previewPath);
      return;
    }

    setState(() => _busy = true);
    try {
      XFile? file;
      if (kIsWeb) {
        // Web/Edge: gallery path (no reliable camera capture).
        file = await _picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 2048,
          imageQuality: 88,
        );
      } else {
        file = await _picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 2048,
          imageQuality: 88,
          preferredCameraDevice: CameraDevice.rear,
        );
      }
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _previewBytes = bytes;
        _previewPath = file!.path;
        _mode = IdentifyMode.photo;
      });
      _openResult(bytes, file.path);
    } catch (error) {
      _showCaptureError(
        kIsWeb
            ? 'Could not pick an image from the library.'
            : 'Could not open the camera.',
        error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showCaptureError(String message, Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$message\n$error',
          style: GoogleFonts.dmSans(),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openResult(Uint8List bytes, String? path) {
    context.push(
      '/id-result',
      extra: CapturedSpecimen(bytes: bytes, path: path),
    );
  }

  void _onModeChanged(IdentifyMode mode) {
    setState(() => _mode = mode);
    if (mode == IdentifyMode.library) {
      _pickFromGallery();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _PreviewImage(bytes: _previewBytes),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.45),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.72),
                ],
                stops: const [0, 0.22, 0.55, 1],
              ),
            ),
          ),
          if (_busy)
            const ColoredBox(
              color: Color(0x44000000),
              child: Center(child: CircularProgressIndicator()),
            ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      GlassIconButton(
                        icon: Icons.close,
                        onPressed: _busy ? null : () => context.pop(),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: StrataColors.glass,
                          borderRadius: BorderRadius.circular(StrataRadii.pill),
                        ),
                        child: Text(
                          'Identify fossil',
                          style: GoogleFonts.dmSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const Spacer(),
                      GlassIconButton(
                        icon: _flashOn
                            ? Icons.flash_on_rounded
                            : Icons.flash_off_rounded,
                        onPressed: _busy
                            ? null
                            : () => setState(() => _flashOn = !_flashOn),
                      ),
                    ],
                  ),
                ),
                const Spacer(flex: 2),
                SizedBox(
                  width: 260,
                  height: 260,
                  child: AnimatedBuilder(
                    animation: _scanController,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: _FocusBracketPainter(
                          scanProgress: _scanController.value,
                        ),
                        child: child,
                      );
                    },
                    child: const SizedBox.expand(),
                  ),
                ),
                const SizedBox(height: 20),
                _StatusPill(
                  icon: Icons.auto_awesome,
                  iconColor: StrataColors.gold,
                  text: _previewBytes == null
                      ? 'Specimen detected · centering...'
                      : 'Photo ready · tap shutter to identify',
                  textColor: StrataColors.gold,
                ),
                const SizedBox(height: 8),
                _StatusPill(
                  icon: Icons.edit_outlined,
                  iconColor: Colors.white,
                  text: 'Tip: include a coin or scale bar for size',
                  textColor: Colors.white,
                ),
                const Spacer(),
                _ModeSelector(
                  mode: _mode,
                  onChanged: _busy ? (_) {} : _onModeChanged,
                ),
                const SizedBox(height: 22),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _GalleryThumb(
                        previewBytes: _previewBytes,
                        onTap: _busy ? null : _pickFromGallery,
                      ),
                      _ShutterButton(
                        onPressed: _busy ? null : _capturePhoto,
                      ),
                      _FlipButton(
                        onTap: _busy
                            ? null
                            : () {
                                // Flip stays visual-only until live camera preview.
                              },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewImage extends StatelessWidget {
  const _PreviewImage({required this.bytes});

  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) {
    if (bytes != null) {
      return Image.memory(bytes!, fit: BoxFit.cover, gaplessPlayback: true);
    }
    return Image.asset(
      'assets/images/fossil_ammonite.png',
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(color: const Color(0xFF2A1A10)),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.iconColor,
    required this.text,
    required this.textColor,
  });

  final IconData icon;
  final Color iconColor;
  final String text;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 28),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: StrataColors.glass,
        borderRadius: BorderRadius.circular(StrataRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: GoogleFonts.dmSans(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({
    required this.mode,
    required this.onChanged,
  });

  final IdentifyMode mode;
  final ValueChanged<IdentifyMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ModeLabel(
          label: 'Library',
          selected: mode == IdentifyMode.library,
          onTap: () => onChanged(IdentifyMode.library),
        ),
        const SizedBox(width: 28),
        _ModeLabel(
          label: 'Photo',
          selected: mode == IdentifyMode.photo,
          onTap: () => onChanged(IdentifyMode.photo),
        ),
        const SizedBox(width: 28),
        _ModeLabel(
          label: 'Live ID',
          selected: mode == IdentifyMode.liveId,
          onTap: () => onChanged(IdentifyMode.liveId),
        ),
      ],
    );
  }
}

class _ModeLabel extends StatelessWidget {
  const _ModeLabel({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.dmSans(
              color: selected
                  ? StrataColors.orange
                  : Colors.white.withValues(alpha: 0.55),
              fontSize: 15,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 3,
            width: selected ? 28 : 0,
            decoration: BoxDecoration(
              color: StrataColors.orange,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryThumb extends StatelessWidget {
  const _GalleryThumb({
    required this.previewBytes,
    required this.onTap,
  });

  final Uint8List? previewBytes;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 48,
          height: 48,
          child: previewBytes != null
              ? Image.memory(previewBytes!, fit: BoxFit.cover)
              : Image.asset(
                  'assets/images/fossil_trilobite.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: const Color(0xFF3A2A20),
                    child: const Icon(Icons.image, color: Colors.white54, size: 20),
                  ),
                ),
        ),
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  const _ShutterButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Opacity(
        opacity: onPressed == null ? 0.5 : 1,
        child: Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
          ),
          padding: const EdgeInsets.all(5),
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [StrataColors.orange, Color(0xFFE07A2F)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FlipButton extends StatelessWidget {
  const _FlipButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: StrataColors.glass,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            Icons.cameraswitch_outlined,
            color: onTap == null ? Colors.white38 : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _FocusBracketPainter extends CustomPainter {
  _FocusBracketPainter({required this.scanProgress});

  final double scanProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = StrataColors.orange
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const arm = 28.0;
    final rect = Offset.zero & size;

    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(arm, 0), paint);
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(0, arm), paint);

    canvas.drawLine(rect.topRight, rect.topRight + const Offset(-arm, 0), paint);
    canvas.drawLine(rect.topRight, rect.topRight + const Offset(0, arm), paint);

    canvas.drawLine(
      rect.bottomLeft,
      rect.bottomLeft + const Offset(arm, 0),
      paint,
    );
    canvas.drawLine(
      rect.bottomLeft,
      rect.bottomLeft + const Offset(0, -arm),
      paint,
    );

    canvas.drawLine(
      rect.bottomRight,
      rect.bottomRight + const Offset(-arm, 0),
      paint,
    );
    canvas.drawLine(
      rect.bottomRight,
      rect.bottomRight + const Offset(0, -arm),
      paint,
    );

    final y = size.height * (0.12 + scanProgress * 0.76);
    final linePaint = Paint()
      ..color = StrataColors.orange.withValues(alpha: 0.9)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(12, y), Offset(size.width - 12, y), linePaint);
  }

  @override
  bool shouldRepaint(covariant _FocusBracketPainter oldDelegate) {
    return oldDelegate.scanProgress != scanProgress;
  }
}
