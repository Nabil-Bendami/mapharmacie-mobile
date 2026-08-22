import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/errors/app_error.dart';
import '../../organizations/providers/organization_providers.dart';
import '../domain/barcode_lookup_result.dart';
import '../providers/scanner_providers.dart';

enum CameraAccess { checking, granted, denied, permanentlyDenied }

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});
  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen>
    with WidgetsBindingObserver {
  late final MobileScannerController _controller;
  final _scanLock = ScanLock();
  CameraAccess _access = CameraAccess.checking;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = MobileScannerController(
      autoStart: false,
      detectionSpeed: DetectionSpeed.noDuplicates,
      detectionTimeoutMs: 750,
      formats: const [
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
        BarcodeFormat.code128,
        BarcodeFormat.qrCode,
      ],
    );
    unawaited(_requestCamera());
  }

  Future<void> _requestCamera() async {
    final status = await Permission.camera.request();
    if (!mounted) {
      return;
    }
    setState(
      () => _access = status.isGranted
          ? CameraAccess.granted
          : status.isPermanentlyDenied
          ? CameraAccess.permanentlyDenied
          : CameraAccess.denied,
    );
    if (status.isGranted) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(_controller.start()),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_access != CameraAccess.granted) {
      return;
    }
    if (state == AppLifecycleState.resumed && !_scanLock.isLocked) {
      unawaited(_controller.start());
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      unawaited(_controller.stop());
    }
  }

  Future<void> _lookup(String value) async {
    if (!_scanLock.acquire()) {
      return;
    }
    setState(() => _message = null);
    await _controller.stop();
    try {
      final access = await ref.read(currentOrganizationProvider.future);
      if (access == null) {
        throw StateError('Select an organization.');
      }
      final result = await ref
          .read(barcodeRepositoryProvider)
          .lookup(access.organization.id, value);
      if (!mounted) {
        return;
      }
      if (result.found && result.productId != null) {
        await context.push('/products/${result.productId}?from=scan');
      } else {
        await context.push(
          '/scanner/not-found?barcode=${Uri.encodeQueryComponent(result.barcode)}',
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _message = AppError.from(error).message);
      }
    } finally {
      _scanLock.release();
      if (mounted && _access == CameraAccess.granted) {
        unawaited(_controller.start());
      }
    }
  }

  void _onDetect(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.trim().isNotEmpty) {
        unawaited(_lookup(value));
        return;
      }
    }
  }

  Future<void> _manualEntry() async {
    await _controller.stop();
    if (!mounted) {
      return;
    }
    final value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ManualBarcodeSheet(),
    );
    if (value != null && value.isNotEmpty) {
      await _lookup(value);
    }
    if (mounted && !_scanLock.isLocked && _access == CameraAccess.granted) {
      unawaited(_controller.start());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_access != CameraAccess.granted) {
      return _PermissionState(access: _access, retry: _requestCamera);
    }
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            useAppLifecycleState: false,
            tapToFocus: true,
            onDetect: _onDetect,
            placeholderBuilder: (_) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            errorBuilder: (_, error) => _CameraError(
              error: error,
              retry: () => unawaited(_controller.start()),
            ),
          ),
          const _ScannerOverlay(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Scan product',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      ValueListenableBuilder<MobileScannerState>(
                        valueListenable: _controller,
                        builder: (_, state, _) => IconButton.filledTonal(
                          onPressed: _controller.toggleTorch,
                          icon: Icon(
                            state.torchState == TorchState.on
                                ? Icons.flash_on_rounded
                                : Icons.flash_off_rounded,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Text(
                    'Place the barcode inside the frame',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        _message!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.orangeAccent),
                      ),
                    ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: _manualEntry,
                      icon: const Icon(Icons.keyboard_rounded),
                      label: const Text('Enter barcode manually'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay();
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: LayoutBuilder(
      builder: (_, box) {
        final width = box.maxWidth * .76,
            height = width * .58,
            left = (box.maxWidth - width) / 2,
            top = (box.maxHeight - height) / 2 - 30;
        return Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              right: 0,
              height: top,
              child: Container(color: Colors.black54),
            ),
            Positioned(
              left: 0,
              top: top,
              width: left,
              height: height,
              child: Container(color: Colors.black54),
            ),
            Positioned(
              right: 0,
              top: top,
              width: left,
              height: height,
              child: Container(color: Colors.black54),
            ),
            Positioned(
              left: 0,
              top: top + height,
              right: 0,
              bottom: 0,
              child: Container(color: Colors.black54),
            ),
            Positioned(
              left: left,
              top: top,
              width: width,
              height: height,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 3),
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _PermissionState extends StatelessWidget {
  const _PermissionState({required this.access, required this.retry});
  final CameraAccess access;
  final Future<void> Function() retry;
  @override
  Widget build(BuildContext context) {
    final permanent = access == CameraAccess.permanentlyDenied;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              permanent
                  ? Icons.no_photography_rounded
                  : Icons.camera_alt_outlined,
              size: 50,
            ),
            const SizedBox(height: 16),
            Text(
              access == CameraAccess.checking
                  ? 'Checking camera permission…'
                  : permanent
                  ? 'Camera permission is permanently denied'
                  : 'Camera permission is required',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              permanent
                  ? 'Open device settings and allow camera access to scan products.'
                  : 'MaPharmacie uses the camera only to read product barcodes.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (access != CameraAccess.checking)
              FilledButton(
                onPressed: permanent
                    ? () => unawaited(openAppSettings())
                    : () => unawaited(retry()),
                child: Text(permanent ? 'Open settings' : 'Allow camera'),
              ),
          ],
        ),
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.error, required this.retry});
  final MobileScannerException error;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) {
    final unsupported = error.errorCode == MobileScannerErrorCode.unsupported;
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.videocam_off_rounded,
                color: Colors.white,
                size: 46,
              ),
              const SizedBox(height: 14),
              Text(
                unsupported
                    ? 'Camera scanning is unavailable on this device.'
                    : 'The camera could not start.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 14),
              if (!unsupported)
                FilledButton.tonal(
                  onPressed: retry,
                  child: const Text('Retry'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManualBarcodeSheet extends StatefulWidget {
  const _ManualBarcodeSheet();
  @override
  State<_ManualBarcodeSheet> createState() => _ManualBarcodeSheetState();
}

class _ManualBarcodeSheetState extends State<_ManualBarcodeSheet> {
  final _controller = TextEditingController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Enter barcode manually',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(labelText: 'Barcode'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Look up product'),
        ),
      ],
    ),
  );
}
