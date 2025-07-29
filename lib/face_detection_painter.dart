import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceDetectionPainter extends CustomPainter {
  final List<Face> faces;
  final Size imageSize;
  final CameraLensDirection cameraLenseDirection;
  final Size previewSize;
  final bool canCaptureImage;
  final int sensorOrientation;
  final double minDistanceThreshold;
  final double maxDistanceThreshold;

  FaceDetectionPainter({
    required this.faces,
    required this.imageSize,
    required this.cameraLenseDirection,
    required this.previewSize,
    required this.canCaptureImage,
    required this.sensorOrientation,
    required this.minDistanceThreshold,
    required this.maxDistanceThreshold,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (faces.isEmpty) return;

    // Calculate scaling factors - use the actual preview size ratio
    final double scaleX = size.width / imageSize.width;
    final double scaleY = size.height / imageSize.height;
    
    // Use the smaller scale to maintain aspect ratio
    final double scale = scaleX < scaleY ? scaleX : scaleY;
    
    // Calculate offsets to center the scaled image
    final double offsetX = (size.width - imageSize.width * scale) / 2;
    final double offsetY = (size.height - imageSize.height * scale) / 2;


    final Paint landMarkPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.red;

    final Paint textBackgroundPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.black87;

    for (var i = 0; i < faces.length; i++) {
      final Face face = faces[i];
      
      // Transform coordinates for face bounding box
      double left, top, right, bottom;
      
      // Apply coordinate transformation based on camera orientation
      if (cameraLenseDirection == CameraLensDirection.front) {
        // For front camera, mirror the coordinates horizontally
        left = (imageSize.width - face.boundingBox.right) * scale + offsetX;
        right = (imageSize.width - face.boundingBox.left) * scale + offsetX;
        top = face.boundingBox.top * scale + offsetY;
        bottom = face.boundingBox.bottom * scale + offsetY;
      } else {
        // For back camera, use coordinates as-is
        left = face.boundingBox.left * scale + offsetX;
        right = face.boundingBox.right * scale + offsetX;
        top = face.boundingBox.top * scale + offsetY;
        bottom = face.boundingBox.bottom * scale + offsetY;
      }

      // Draw face bounding rectangle with different colors based on distance
      final Paint currentFacePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;
      
      // Check individual face distance for color coding
      final faceWidth = face.boundingBox.width;
      final faceHeight = face.boundingBox.height;
      final faceAreaPercentage = (faceWidth * faceHeight) / (imageSize.width * imageSize.height);
      
      if (faceAreaPercentage < minDistanceThreshold || faceAreaPercentage > maxDistanceThreshold) {
        currentFacePaint.color = Colors.red;
      } else {
        currentFacePaint.color = Colors.green;
      }
      
      canvas.drawRect(Rect.fromLTRB(left, top, right, bottom), currentFacePaint);

      // Function to draw facial landmarks
      void drawLandmark(FaceLandmarkType type) {
        if (face.landmarks[type] != null) {
          final point = face.landmarks[type]!.position;
          
          double pointX, pointY;
          
          if (cameraLenseDirection == CameraLensDirection.front) {
            // Mirror X coordinate for front camera
            pointX = (imageSize.width - point.x) * scale + offsetX;
            pointY = point.y * scale + offsetY;
          } else {
            // Use coordinates as-is for back camera
            pointX = point.x * scale + offsetX;
            pointY = point.y * scale + offsetY;
          }

          canvas.drawCircle(Offset(pointX, pointY), 3.0, landMarkPaint);
        }
      }

      // Draw all facial landmarks
      drawLandmark(FaceLandmarkType.leftEye);
      drawLandmark(FaceLandmarkType.rightEye);
      drawLandmark(FaceLandmarkType.noseBase);
      drawLandmark(FaceLandmarkType.leftMouth);
      drawLandmark(FaceLandmarkType.rightMouth);
      drawLandmark(FaceLandmarkType.bottomMouth);

      // Add face ID label
      final TextSpan faceIdSpan = TextSpan(
        text: 'Face ${i + 1}',
        style: const TextStyle(
          color: Colors.white, 
          fontSize: 14, 
          fontWeight: FontWeight.bold
        )
      );

      final TextPainter textPainter = TextPainter(
        text: faceIdSpan,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );

      textPainter.layout();

      // Position label above the face bounding box
      final double labelX = left;
      final double labelY = top - textPainter.height - 10;

      final textRect = Rect.fromLTWH(
        labelX, 
        labelY, 
        textPainter.width + 12, 
        textPainter.height + 6
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(textRect, const Radius.circular(8)),
        textBackgroundPaint
      );

      textPainter.paint(canvas, Offset(labelX + 6, labelY + 3));
    }
  }

  @override
  bool shouldRepaint(FaceDetectionPainter oldDelegate) {
    return oldDelegate.faces != faces || 
           oldDelegate.canCaptureImage != canCaptureImage ||
           oldDelegate.minDistanceThreshold != minDistanceThreshold ||
           oldDelegate.maxDistanceThreshold != maxDistanceThreshold;
  }
}
