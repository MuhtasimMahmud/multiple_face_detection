import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final DeviceOrientation deviceOrientation;

  FaceDetectionPainter({
    required this.faces,
    required this.imageSize,
    required this.cameraLenseDirection,
    required this.previewSize,
    required this.canCaptureImage,
    required this.sensorOrientation,
    required this.minDistanceThreshold,
    required this.maxDistanceThreshold,
    required this.deviceOrientation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (faces.isEmpty) return;

    // Determine effective image dimensions based on orientation
    Size effectiveImageSize = _getEffectiveImageSize();
    
    // Calculate scaling factors - use the actual preview size ratio
    final double scaleX = size.width / effectiveImageSize.width;
    final double scaleY = size.height / effectiveImageSize.height;
    
    // Use the smaller scale to maintain aspect ratio
    final double scale = scaleX < scaleY ? scaleX : scaleY;
    
    // Calculate offsets to center the scaled image
    final double offsetX = (size.width - effectiveImageSize.width * scale) / 2;
    final double offsetY = (size.height - effectiveImageSize.height * scale) / 2;


    final Paint landMarkPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.red;

    final Paint textBackgroundPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.black87;

    for (var i = 0; i < faces.length; i++) {
      final Face face = faces[i];
      
      // Transform coordinates for face bounding box with orientation support
      final transformedBounds = _transformBoundingBox(
        face.boundingBox, 
        scale, 
        offsetX, 
        offsetY,
        effectiveImageSize
      );
      
      final double left = transformedBounds.left;
      final double top = transformedBounds.top;
      final double right = transformedBounds.right;
      final double bottom = transformedBounds.bottom;

      // Draw face bounding rectangle with different colors based on distance
      final Paint currentFacePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;
      
      // Check individual face distance for color coding
      final faceWidth = face.boundingBox.width;
      final faceHeight = face.boundingBox.height;
      final faceAreaPercentage = (faceWidth * faceHeight) / (effectiveImageSize.width * effectiveImageSize.height);
      
      if (faceAreaPercentage < minDistanceThreshold || faceAreaPercentage > maxDistanceThreshold) {
        currentFacePaint.color = Colors.red;
      } else {
        currentFacePaint.color = Colors.green;
      }
      
      canvas.drawRect(Rect.fromLTRB(left, top, right, bottom), currentFacePaint);

      // Function to draw facial landmarks with orientation support
      void drawLandmark(FaceLandmarkType type) {
        if (face.landmarks[type] != null) {
          final point = face.landmarks[type]!.position;
          
          final transformedPoint = _transformPoint(
            point, 
            scale, 
            offsetX, 
            offsetY,
            effectiveImageSize
          );

          canvas.drawCircle(
            Offset(transformedPoint.dx, transformedPoint.dy), 
            3.0, 
            landMarkPaint
          );
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

  Size _getEffectiveImageSize() {
    // Adjust image size based on device orientation
    switch (deviceOrientation) {
      case DeviceOrientation.landscapeLeft:
      case DeviceOrientation.landscapeRight:
        return Size(imageSize.height, imageSize.width);
      default:
        return imageSize;
    }
  }
  
  Rect _transformBoundingBox(
      Rect boundingBox, 
      double scale, 
      double offsetX, 
      double offsetY,
      Size effectiveSize) {
    
    double left, top, right, bottom;
    
    // Base coordinate transformation
    switch (deviceOrientation) {
      case DeviceOrientation.landscapeLeft:
        left = boundingBox.top * scale + offsetX;
        right = boundingBox.bottom * scale + offsetX;
        top = (effectiveSize.height - boundingBox.right) * scale + offsetY;
        bottom = (effectiveSize.height - boundingBox.left) * scale + offsetY;
        break;
      case DeviceOrientation.landscapeRight:
        left = (effectiveSize.width - boundingBox.bottom) * scale + offsetX;
        right = (effectiveSize.width - boundingBox.top) * scale + offsetX;
        top = boundingBox.left * scale + offsetY;
        bottom = boundingBox.right * scale + offsetY;
        break;
      case DeviceOrientation.portraitDown:
        left = (effectiveSize.width - boundingBox.right) * scale + offsetX;
        right = (effectiveSize.width - boundingBox.left) * scale + offsetX;
        top = (effectiveSize.height - boundingBox.bottom) * scale + offsetY;
        bottom = (effectiveSize.height - boundingBox.top) * scale + offsetY;
        break;
      default: // portraitUp
        left = boundingBox.left * scale + offsetX;
        right = boundingBox.right * scale + offsetX;
        top = boundingBox.top * scale + offsetY;
        bottom = boundingBox.bottom * scale + offsetY;
    }
    
    // Apply front camera mirroring
    if (cameraLenseDirection == CameraLensDirection.front) {
      final double tempLeft = left;
      left = offsetX + (offsetX + effectiveSize.width * scale - right);
      right = offsetX + (offsetX + effectiveSize.width * scale - tempLeft);
    }
    
    return Rect.fromLTRB(left, top, right, bottom);
  }
  
  Offset _transformPoint(
      Point<int> point, 
      double scale, 
      double offsetX, 
      double offsetY,
      Size effectiveSize) {
    
    double pointX, pointY;
    
    // Base coordinate transformation
    switch (deviceOrientation) {
      case DeviceOrientation.landscapeLeft:
        pointX = point.y * scale + offsetX;
        pointY = (effectiveSize.height - point.x) * scale + offsetY;
        break;
      case DeviceOrientation.landscapeRight:
        pointX = (effectiveSize.width - point.y) * scale + offsetX;
        pointY = point.x * scale + offsetY;
        break;
      case DeviceOrientation.portraitDown:
        pointX = (effectiveSize.width - point.x) * scale + offsetX;
        pointY = (effectiveSize.height - point.y) * scale + offsetY;
        break;
      default: // portraitUp
        pointX = point.x * scale + offsetX;
        pointY = point.y * scale + offsetY;
    }
    
    // Apply front camera mirroring
    if (cameraLenseDirection == CameraLensDirection.front) {
      pointX = offsetX + (offsetX + effectiveSize.width * scale - pointX);
    }
    
    return Offset(pointX, pointY);
  }

  @override
  bool shouldRepaint(FaceDetectionPainter oldDelegate) {
    return oldDelegate.faces != faces || 
           oldDelegate.canCaptureImage != canCaptureImage ||
           oldDelegate.minDistanceThreshold != minDistanceThreshold ||
           oldDelegate.maxDistanceThreshold != maxDistanceThreshold ||
           oldDelegate.deviceOrientation != deviceOrientation;
  }
}
