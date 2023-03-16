import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    debugPrint(e.toString());
  }

  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Camera Playground',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const CameraScreen(),
    );
  }
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  var _isCameraInitialized = false;
  var _currentResolutionPreset = ResolutionPreset.high;
  var _currentFlashMode = FlashMode.auto;
  var _isRearCameraSelected = true;

  var _minAvailableZoom = 1.0;
  var _maxAvailableZoom = 1.0;
  var _currentZoomLevel = 1.0;

  var _minAvailableExposureOffset = 0.0;
  var _maxAvailableExposureOffset = 0.0;
  var _currentExposureOffset = 0.0;

  File? _imageFile;

  Future<void> _onCameraSelected(CameraDescription description) async {
    final cameraController = CameraController(
      description,
      _currentResolutionPreset,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await _controller?.dispose();

    if (mounted) {
      setState(() => _controller = cameraController);
    }

    cameraController.addListener(() {
      if (mounted) setState(() {});
    });

    try {
      await cameraController.initialize();
      // Controller must be initialized before we can access these values
      _minAvailableZoom = await cameraController.getMinZoomLevel();
      _maxAvailableZoom = await cameraController.getMaxZoomLevel();
      _minAvailableExposureOffset =
          await cameraController.getMinExposureOffset();
      _maxAvailableExposureOffset =
          await cameraController.getMaxExposureOffset();
    } on CameraException catch (e) {
      print('Error initializing camera: $e');
    }

    if (mounted) {
      setState(() {
        _isCameraInitialized = _controller!.value.isInitialized;
        _currentFlashMode = _controller!.value.flashMode;
      });
    }
  }

  Future<XFile?> _takePicture() async {
    final controller = _controller;

    // A capture is already pending, do nothing.
    if (controller == null || controller.value.isTakingPicture) return null;

    try {
      return controller.takePicture();
    } on CameraException catch (e) {
      print('Error occurred while taking picture: $e');
    }

    return null;
  }

  @override
  void initState() {
    super.initState();
    if (cameras.isNotEmpty) _onCameraSelected(cameras.first);
    // Hide the system status bar
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // App state changed before we got the chance to initialize
    if (_controller?.value.isInitialized ?? false) return;

    if (state == AppLifecycleState.inactive) {
      // Free up memory when camera not active
      _controller!.dispose();
    } else if (state == AppLifecycleState.resumed) {
      // Reinitialize the camera with same properties
      _onCameraSelected(_controller!.description);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                if (_isCameraInitialized) CameraPreview(_controller!),
                Positioned(
                  top: 10,
                  right: 16,
                  child: _resolutionPicker(),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 68,
                  child: _zoomSlider(),
                ),
                Positioned(
                  top: 80,
                  right: 8,
                  bottom: 100,
                  child: _exposureSlider(),
                ),
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 0,
                  child: Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _flipCameraToggle(),
                        ),
                      ),
                      Expanded(child: _captureButton()),
                      Flexible(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: _imagePreview(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _flashModeToggle(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Widget _resolutionPicker() => DropdownButton<ResolutionPreset>(
        value: _currentResolutionPreset,
        items: [
          for (final preset in ResolutionPreset.values)
            DropdownMenuItem(
              value: preset,
              child: Text(
                preset.toString().split('.')[1].toUpperCase(),
                style: const TextStyle(color: Colors.white),
              ),
            )
        ],
        onChanged: (value) {
          setState(() {
            _currentResolutionPreset = value!;
            _isCameraInitialized = false;
          });
          _onCameraSelected(_controller!.description);
        },
        dropdownColor: Colors.black87,
        hint: const Text('Select item'),
      );

  Widget _zoomSlider() => Row(
        children: [
          Expanded(
            child: Slider(
              value: _currentZoomLevel,
              min: _minAvailableZoom,
              max: _maxAvailableZoom,
              activeColor: Colors.white,
              inactiveColor: Colors.white30,
              onChanged: (value) {
                setState(() => _currentZoomLevel = value);
                _controller!.setZoomLevel(value);
              },
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.all(8),
            child: Text(
              '${_currentZoomLevel.toStringAsFixed(1)}x',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      );

  Widget _exposureSlider() => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.all(8),
            child: Text(
              '${_currentExposureOffset.toStringAsFixed(1)}x',
              style: const TextStyle(color: Colors.black),
            ),
          ),
          Expanded(
            child: RotatedBox(
              quarterTurns: 3,
              child: SizedBox(
                height: 30,
                child: Slider(
                  value: _currentExposureOffset,
                  min: _minAvailableExposureOffset,
                  max: _maxAvailableExposureOffset,
                  activeColor: Colors.white,
                  inactiveColor: Colors.white30,
                  onChanged: (value) {
                    setState(() => _currentExposureOffset = value);
                    _controller!.setExposureOffset(value);
                  },
                ),
              ),
            ),
          ),
        ],
      );

  Widget _flipCameraToggle() => RawMaterialButton(
        onPressed: () async {
          setState(() => _isCameraInitialized = false);
          await _onCameraSelected(cameras[_isRearCameraSelected ? 1 : 0]);
          setState(() => _isRearCameraSelected = !_isRearCameraSelected);
        },
        fillColor: Colors.black38,
        shape: const CircleBorder(),
        constraints: BoxConstraints.tight(const Size.square(60)),
        child: Icon(
          _isRearCameraSelected ? Icons.camera_rear : Icons.camera_front,
          color: Colors.white,
          size: 30,
        ),
      );

  Widget _captureButton() => RawMaterialButton(
        onPressed: () async {
          final rawImage = await _takePicture();
          final imageFile = File(rawImage!.path);

          final currentUnix = DateTime.now().millisecondsSinceEpoch;
          final directory = await getApplicationDocumentsDirectory();
          final fileFormat = imageFile.path.split('.').last;

          _imageFile = await imageFile
              .copy('${directory.path}/$currentUnix.$fileFormat');

          setState(() {});
        },
        fillColor: Colors.white38,
        shape: const CircleBorder(),
        constraints: BoxConstraints.tight(const Size.square(72)),
        child: const Icon(Icons.circle, color: Colors.white, size: 64),
      );

  Widget _imagePreview() => SizedBox.square(
        dimension: 60,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: (_imageFile != null)
              ? Image.file(_imageFile!, fit: BoxFit.cover)
              : null,
        ),
      );

  Widget _flashModeToggle() => ButtonBar(
        alignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final mode in FlashMode.values)
            IconButton(
              onPressed: () {
                setState(() => _currentFlashMode = mode);
                _controller!.setFlashMode(mode);
              },
              icon: Icon(
                getFlashModeIcon(mode),
                color:
                    (_currentFlashMode == mode) ? Colors.amber : Colors.white,
              ),
            ),
        ],
      );

  IconData getFlashModeIcon(FlashMode mode) {
    switch (mode) {
      case FlashMode.off:
        return Icons.flash_off;
      case FlashMode.auto:
        return Icons.flash_auto;
      case FlashMode.always:
        return Icons.flash_on;
      case FlashMode.torch:
        return Icons.highlight;
    }
  }
}
