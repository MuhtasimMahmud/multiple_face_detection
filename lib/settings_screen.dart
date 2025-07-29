import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  final int minFaceCount;
  final double minDistanceThreshold;
  final double maxDistanceThreshold;
  final Function(int, double, double) onSettingsChanged;

  const SettingsScreen({
    super.key,
    required this.minFaceCount,
    required this.minDistanceThreshold,
    required this.maxDistanceThreshold,
    required this.onSettingsChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late int _minFaceCount;
  late double _minDistanceThreshold;
  late double _maxDistanceThreshold;

  @override
  void initState() {
    super.initState();
    _minFaceCount = widget.minFaceCount;
    _minDistanceThreshold = widget.minDistanceThreshold;
    _maxDistanceThreshold = widget.maxDistanceThreshold;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detection Settings'),
        actions: [
          TextButton(
            onPressed: () {
              widget.onSettingsChanged(
                _minFaceCount,
                _minDistanceThreshold,
                _maxDistanceThreshold,
              );
              Navigator.pop(context);
            },
            child: const Text(
              'Save',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Minimum Face Count Setting
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Minimum Face Count',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Minimum number of faces required to enable capture',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: _minFaceCount.toDouble(),
                            min: 1,
                            max: 10,
                            divisions: 9,
                            label: _minFaceCount.toString(),
                            onChanged: (value) {
                              setState(() {
                                _minFaceCount = value.round();
                              });
                            },
                          ),
                        ),
                        Container(
                          width: 50,
                          child: Text(
                            _minFaceCount.toString(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Distance Settings
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Distance Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Configure face distance thresholds for optimal detection',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    
                    // Minimum Distance
                    const Text(
                      'Minimum Distance (Too Far Threshold)',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: _minDistanceThreshold,
                            min: 0.01,
                            max: 0.15,
                            divisions: 14,
                            label: '${(_minDistanceThreshold * 100).toInt()}%',
                            onChanged: (value) {
                              setState(() {
                                _minDistanceThreshold = value;
                                if (_minDistanceThreshold >= _maxDistanceThreshold) {
                                  _maxDistanceThreshold = _minDistanceThreshold + 0.05;
                                }
                              });
                            },
                          ),
                        ),
                        Container(
                          width: 50,
                          child: Text(
                            '${(_minDistanceThreshold * 100).toInt()}%',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Maximum Distance
                    const Text(
                      'Maximum Distance (Too Close Threshold)',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: _maxDistanceThreshold,
                            min: 0.1,
                            max: 0.6,
                            divisions: 50,
                            label: '${(_maxDistanceThreshold * 100).toInt()}%',
                            onChanged: (value) {
                              setState(() {
                                _maxDistanceThreshold = value;
                                if (_maxDistanceThreshold <= _minDistanceThreshold) {
                                  _minDistanceThreshold = _maxDistanceThreshold - 0.05;
                                }
                              });
                            },
                          ),
                        ),
                        Container(
                          width: 50,
                          child: Text(
                            '${(_maxDistanceThreshold * 100).toInt()}%',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Info Card
            Card(
              color: Colors.blue.withValues(alpha: 0.1),
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'How it works',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Face count: Number of faces needed before capture is enabled\n'
                      '• Min distance: If face area is below this %, shows "move closer"\n'
                      '• Max distance: If face area is above this %, shows "move away"\n'
                      '• Green boxes appear when faces are in the optimal range',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}