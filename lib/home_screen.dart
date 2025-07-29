import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';

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
      InputImageRotation rotation = InputImageRotation.rotation0deg;
      final sensorOrientation = _controller!.description.sensorOrientation;
      
      if (Platform.isIOS) {
        switch (sensorOrientation) {
          case 90:
            rotation = InputImageRotation.rotation90deg;
            break;
          case 180:
            rotation = InputImageRotation.rotation180deg;
            break;
          case 270:
            rotation = InputImageRotation.rotation270deg;
            break;
          default:
            rotation = InputImageRotation.rotation0deg;
        }
      } else {
        // Android
        switch (sensorOrientation) {
          case 90:
            rotation = InputImageRotation.rotation90deg;
            break;
          case 180:
            rotation = InputImageRotation.rotation180deg;
            break;
          case 270:
            rotation = InputImageRotation.rotation270deg;
            break;
          default:
            rotation = InputImageRotation.rotation0deg;
        }
      }

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
    if (faces.length < _minFaceCount) {
      _canCaptureImage = false;
      _distanceWarning = faces.isEmpty 
          ? 'No face detected' 
          : 'Need $_minFaceCount face${_minFaceCount > 1 ? 's' : ''} (${faces.length}/$_minFaceCount)';
      return;
    }

    bool allFacesInRange = true;
    String warning = '';

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
        warning = 'Move closer to camera';
        break;
      } else if (faceAreaPercentage > _maxDistanceThreshold) {
        allFacesInRange = false;
        warning = 'Move away from camera';
        break;
      }
    }

    _canCaptureImage = allFacesInRange && faces.length >= _minFaceCount;
    _distanceWarning = _canCaptureImage ? 'Ready to capture' : warning;
  }

  Future<void> _captureImage() async {
    if (!_canCaptureImage || _controller == null || !_controller!.value.isInitialized) {
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
            });
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

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    _requestPermissions();
    _initializeCameras();
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
                              'Faces Detected: ${_faces.length}',
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
