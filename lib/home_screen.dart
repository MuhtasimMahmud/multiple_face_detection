import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'face_detection_painter.dart';
import 'settings_screen.dart';
import 'gallery_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  final FaceDetector _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
    enableClassification: true,
    enableTracking: true,
    performanceMode: FaceDetectorMode.fast,
  ));

  bool _isDetecting = false;
  List<Face> _faces = [];
  List<CameraDescription> cameras = [];
  int _selectedCameraIndex = 0;
  bool _canCaptureImage = false;
  String _distanceWarning = '';
  DeviceOrientation _deviceOrientation = DeviceOrientation.portraitUp;
  
  // User-configurable settings
  int _minFaceCount = 1;
  double _minDistanceThreshold = 0.05; // 5% of image area
  double _maxDistanceThreshold = 0.4;  // 40% of image area
  
  // Captured images storage
  List<String> _capturedImages = [];

  Future<void> _requestPermissions() async {
    final status = await Permission.camera.request();
    if (status != PermissionStatus.granted) {
      debugPrint("Permission Denied");
    }
  }

  Future<void> _initializeCameras() async {
    try {
      cameras = await availableCameras();
      if (cameras.isEmpty) {
        debugPrint("No camera found");
        return;
      }

      _selectedCameraIndex = cameras.indexWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back);

      if (_selectedCameraIndex == -1) {
        _selectedCameraIndex = 0;
      }

      await _initializeCamera(cameras[_selectedCameraIndex]);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> _initializeCamera(CameraDescription cameraDescription) async {
    final controller = CameraController(
      cameraDescription,
      ResolutionPreset.ultraHigh,
      enableAudio: false,
      imageFormatGroup:
          Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.yuv420,
    );

    _controller = controller;
    _initializeControllerFuture = controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {
        _startFaceDetection();
      });
    }).catchError((error) {
      debugPrint(error.toString());
    });
  }

  void _toggleCamera() async {
    if (cameras.isEmpty || cameras.length < 2) {
      debugPrint("Can't toggle camera. not enough cameras available");
      return;
    }

    if (_controller != null && _controller!.value.isStreamingImages) {
      await _controller!.stopImageStream();
    }

    _selectedCameraIndex = (_selectedCameraIndex + 1) % cameras.length;

    setState(() {
      _faces = [];
    });

    await _initializeCamera(cameras[_selectedCameraIndex]);
  }

  void _startFaceDetection() {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }

    _controller!.startImageStream((CameraImage image) async {
      if (_isDetecting) return;

      _isDetecting = true;

      final inputImage = _convertCameraImageToInputImage(image);

      if (inputImage == null) {
        _isDetecting = false;
        return;
      }

      try {
        final List<Face> faces = await _faceDetector.processImage(inputImage);

        if (mounted) {
          setState(() {
            _faces = faces;
            _checkFaceDistance(faces);
          });
        }
      } catch (e) {
        debugPrint(e.toString());
      } finally {
        _isDetecting = false;
      }
    });
  }

  InputImage? _convertCameraImageToInputImage(CameraImage image) {
    if (_controller == null) return null;

    try {
      final format =
          Platform.isIOS ? InputImageFormat.bgra8888 : InputImageFormat.nv21;
      
      // Get the correct rotation based on camera orientation and device orientation
      final sensorOrientation = _controller!.description.sensorOrientation;
      final lensDirection = _controller!.description.lensDirection;
      
      InputImageRotation rotation = _getInputImageRotation(
        sensorOrientation, 
        _deviceOrientation,
        lensDirection
      );

      final inputImageMetadata = InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: image.planes[0].bytesPerRow);
      final bytes = _concatenatePlanes(image.planes);

      return InputImage.fromBytes(bytes: bytes, metadata: inputImageMetadata);
    } catch (e) {
      debugPrint(e.toString());
      return null;
    }
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    final allBytes = WriteBuffer();
    for (Plane plane in planes) {
      allBytes.putUint8List(plane.bytes);
    }

    return allBytes.done().buffer.asUint8List();
  }

  void _checkFaceDistance(List<Face> faces) {
    // Debug logging
    debugPrint('Checking faces: detected=${faces.length}, required=$_minFaceCount');
    
    // First check: Do we have enough faces?
    if (faces.length < _minFaceCount) {
      _canCaptureImage = false;
      if (faces.isEmpty) {
        _distanceWarning = 'No face detected';
      } else if (_minFaceCount == 1) {
        _distanceWarning = 'Detecting face...';
      } else {
        _distanceWarning = 'Only ${faces.length} face${faces.length > 1 ? 's' : ''} detected - Need $_minFaceCount faces';
      }
      debugPrint('Insufficient faces: $_distanceWarning');
      return;
    }

    // Second check: Are all faces in the correct distance range?
    bool allFacesInRange = true;
    String warning = '';
    int facesOutOfRange = 0;

    for (Face face in faces) {
      // Calculate face size relative to image dimensions
      final faceWidth = face.boundingBox.width;
      final faceHeight = face.boundingBox.height;
      final imageWidth = _controller?.value.previewSize?.width ?? 1;
      final imageHeight = _controller?.value.previewSize?.height ?? 1;
      
      // Calculate face area percentage
      final faceAreaPercentage = (faceWidth * faceHeight) / (imageWidth * imageHeight);
      
      if (faceAreaPercentage < _minDistanceThreshold) {
        allFacesInRange = false;
        facesOutOfRange++;
        warning = facesOutOfRange == 1 ? 'Move closer to camera' : 'All faces need to move closer';
      } else if (faceAreaPercentage > _maxDistanceThreshold) {
        allFacesInRange = false;
        facesOutOfRange++;
        warning = facesOutOfRange == 1 ? 'Move away from camera' : 'All faces need to move away';
      }
    }

    // Final decision: Can capture only if we have enough faces AND all are in range
    _canCaptureImage = allFacesInRange && faces.length >= _minFaceCount;
    
    if (_canCaptureImage) {
      _distanceWarning = faces.length == _minFaceCount 
          ? 'Perfect! Ready to capture' 
          : 'Ready to capture ${faces.length} faces';
    } else {
      _distanceWarning = warning;
    }
  }

  Future<void> _captureImage() async {
    // Triple verification: Must have required face count AND be in capture state
    if (!_canCaptureImage || 
        _controller == null || 
        !_controller!.value.isInitialized ||
        _faces.length < _minFaceCount) {
      
      // Show warning if user somehow tries to capture with insufficient faces
      if (_faces.length < _minFaceCount) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot capture: Need $_minFaceCount face${_minFaceCount > 1 ? 's' : ''}, only ${_faces.length} detected'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      final XFile image = await _controller!.takePicture();
      if (mounted) {
        setState(() {
          _capturedImages.add(image.path);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image captured! Total: ${_capturedImages.length}'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () => _navigateToGallery(),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error capturing image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          minFaceCount: _minFaceCount,
          minDistanceThreshold: _minDistanceThreshold,
          maxDistanceThreshold: _maxDistanceThreshold,
          onSettingsChanged: (minFaces, minDist, maxDist) {
            setState(() {
              _minFaceCount = minFaces;
              _minDistanceThreshold = minDist;
              _maxDistanceThreshold = maxDist;
              // Force immediate re-evaluation of current faces
              _checkFaceDistance(_faces);
            });
            
            // Save settings to persistent storage
            _saveSettings();
            
            // Debug print to verify settings are updated
            debugPrint('Settings updated: minFaces=$_minFaceCount, minDist=$_minDistanceThreshold, maxDist=$_maxDistanceThreshold');
          },
        ),
      ),
    );
  }

  void _navigateToGallery() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GalleryScreen(
          capturedImages: _capturedImages,
          onDeleteImage: (imagePath) {
            setState(() {
              _capturedImages.remove(imagePath);
            });
            // Delete the actual file
            try {
              File(imagePath).deleteSync();
            } catch (e) {
              debugPrint('Error deleting file: $e');
            }
          },
        ),
      ),
    );
  }

  InputImageRotation _getInputImageRotation(
      int sensorOrientation, 
      DeviceOrientation deviceOrientation,
      CameraLensDirection lensDirection) {
    
    int rotationDegrees = 0;
    
    // Calculate base rotation from sensor orientation
    switch (deviceOrientation) {
      case DeviceOrientation.portraitUp:
        rotationDegrees = sensorOrientation;
        break;
      case DeviceOrientation.landscapeLeft:
        rotationDegrees = Platform.isIOS 
            ? (sensorOrientation + 90) % 360
            : (sensorOrientation + 270) % 360;
        break;
      case DeviceOrientation.portraitDown:
        rotationDegrees = (sensorOrientation + 180) % 360;
        break;
      case DeviceOrientation.landscapeRight:
        rotationDegrees = Platform.isIOS 
            ? (sensorOrientation + 270) % 360
            : (sensorOrientation + 90) % 360;
        break;
    }
    
    // Adjust for front camera on iOS
    if (Platform.isIOS && lensDirection == CameraLensDirection.front) {
      rotationDegrees = (360 - rotationDegrees) % 360;
    }
    
    // Convert to InputImageRotation
    switch (rotationDegrees) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  void _onOrientationChanged() {
    // Get current device orientation
    final orientation = MediaQuery.of(context).orientation;
    
    DeviceOrientation newOrientation;
    switch (orientation) {
      case Orientation.portrait:
        newOrientation = DeviceOrientation.portraitUp;
        break;
      case Orientation.landscape:
        newOrientation = DeviceOrientation.landscapeLeft;
        break;
    }
    
    if (_deviceOrientation != newOrientation) {
      setState(() {
        _deviceOrientation = newOrientation;
      });
      
      // Restart face detection with new orientation
      if (_controller != null && _controller!.value.isInitialized) {
        _restartFaceDetection();
      }
    }
  }
  
  void _restartFaceDetection() async {
    if (_controller != null && _controller!.value.isStreamingImages) {
      await _controller!.stopImageStream();
    }
    
    // Small delay to ensure stream is properly stopped
    await Future.delayed(Duration(milliseconds: 100));
    
    if (mounted && _controller != null && _controller!.value.isInitialized) {
      _startFaceDetection();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _requestPermissions();
    _initializeCameras();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _minFaceCount = prefs.getInt('minFaceCount') ?? 1;
      _minDistanceThreshold = prefs.getDouble('minDistanceThreshold') ?? 0.05;
      _maxDistanceThreshold = prefs.getDouble('maxDistanceThreshold') ?? 0.4;
    });
    debugPrint('Settings loaded: minFaces=$_minFaceCount, minDist=$_minDistanceThreshold, maxDist=$_maxDistanceThreshold');
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('minFaceCount', _minFaceCount);
    await prefs.setDouble('minDistanceThreshold', _minDistanceThreshold);
    await prefs.setDouble('maxDistanceThreshold', _maxDistanceThreshold);
    debugPrint('Settings saved: minFaces=$_minFaceCount, minDist=$_minDistanceThreshold, maxDist=$_maxDistanceThreshold');
  }

  @override
  void dispose() {
    // TODO: implement dispose
    _controller?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Update device orientation when build is called
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onOrientationChanged();
    });
    return Scaffold(
      appBar: AppBar(
        title: const Text("Face Detection"),
        actions: [
          // Gallery button
          IconButton(
            onPressed: _navigateToGallery,
            icon: Badge(
              isLabelVisible: _capturedImages.isNotEmpty,
              label: Text(_capturedImages.length.toString()),
              child: const Icon(Icons.photo_library),
            ),
            tooltip: 'Gallery',
          ),
          // Settings button
          IconButton(
            onPressed: _navigateToSettings,
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
          ),
          // Camera toggle button
          if (cameras.length > 1)
            IconButton(
              onPressed: _toggleCamera,
              icon: const Icon(CupertinoIcons.switch_camera_solid),
              color: Colors.blueAccent,
              tooltip: 'Switch Camera',
            ),
        ],
      ),
      body: _initializeControllerFuture == null
          ? Center(
              child: Text("No Camera Available"),
            )
          : FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done &&
                    _controller != null &&
                    _controller!.value.isInitialized) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      // Mirror front camera preview for natural selfie experience
                      _controller!.description.lensDirection == CameraLensDirection.front
                          ? Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()..rotateY(3.14159),
                              child: CameraPreview(_controller!),
                            )
                          : CameraPreview(_controller!),
                      CustomPaint(
                        painter: FaceDetectionPainter(
                          faces: _faces,
                          imageSize: Size(
                              _controller!.value.previewSize!.height,
                              _controller!.value.previewSize!.width),
                          cameraLenseDirection:
                              _controller!.description.lensDirection,
                          previewSize: Size(
                            MediaQuery.of(context).size.width,
                            MediaQuery.of(context).size.height - 
                            AppBar().preferredSize.height - 
                            MediaQuery.of(context).padding.top,
                          ),
                          canCaptureImage: _canCaptureImage,
                          sensorOrientation: _controller!.description.sensorOrientation,
                          minDistanceThreshold: _minDistanceThreshold,
                          maxDistanceThreshold: _maxDistanceThreshold,
                          deviceOrientation: _deviceOrientation,
                        ),
                      ),
                      // Distance warning message
                      Positioned(
                        top: 50,
                        left: 20,
                        right: 20,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            color: _canCaptureImage ? Colors.green.withValues(alpha: 0.8) : Colors.red.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _distanceWarning,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      // Face count and capture button
                      Positioned(
                        bottom: 100,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Faces: ${_faces.length}/$_minFaceCount',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Capture button
                      Positioned(
                        bottom: 30,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: GestureDetector(
                            onTap: _canCaptureImage ? _captureImage : null,
                            child: Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _canCaptureImage ? Colors.white : Colors.grey,
                                border: Border.all(
                                  color: _canCaptureImage ? Colors.blue : Colors.grey,
                                  width: 4,
                                ),
                              ),
                              child: Icon(
                                Icons.camera_alt,
                                size: 30,
                                color: _canCaptureImage ? Colors.blue : Colors.grey[600],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                } else if (snapshot.hasError) {
                  return Center(
                    child: Text('Error'),
                  );
                } else {
                  return Center(
                    child: CircularProgressIndicator(
                      color: Colors.blueAccent,
                    ),
                  );
                }
              },
            ),
    );
  }
}
