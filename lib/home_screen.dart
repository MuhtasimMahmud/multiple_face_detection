import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';

import 'face_detection_painter.dart';

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
          (camera) => camera.lensDirection == CameraLensDirection.front);

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
      final inputImageMetadata = InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: InputImageRotation.values.firstWhere(
              (element) =>
                  element.rawValue ==
                  _controller!.description.sensorOrientation,
              orElse: () => InputImageRotation.rotation0deg),
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
        title: Text("Face Detection"),
        actions: [
          if (cameras.length > 1)
            IconButton(
              onPressed: _toggleCamera,
              icon: Icon(CupertinoIcons.switch_camera_solid),
              color: Colors.blueAccent,
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
                      CameraPreview(_controller!),
                      CustomPaint(
                        painter: FaceDetectionPainter(
                          faces: _faces,
                          imageSize: Size(
                              _controller!.value.previewSize!.height,
                              _controller!.value.previewSize!.width),
                          cameraLenseDirection:
                              _controller!.description.lensDirection,
                        ),
                      ),
                      Positioned(
                          bottom: 20,
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
                                'Faces Detected : ${_faces.length}',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          )),
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
