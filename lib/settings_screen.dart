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
  late int _tempMinFaceCount;
  late double _tempMinDistanceThreshold;
  late double _tempMaxDistanceThreshold;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _tempMinFaceCount = widget.minFaceCount;
    _tempMinDistanceThreshold = widget.minDistanceThreshold;
    _tempMaxDistanceThreshold = widget.maxDistanceThreshold;
  }

  void _markAsChanged() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  void _applySettings() {
    widget.onSettingsChanged(
      _tempMinFaceCount,
      _tempMinDistanceThreshold,
      _tempMaxDistanceThreshold,
    );
    setState(() {
      _hasChanges = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings saved successfully!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _resetSettings() {
    setState(() {
      _tempMinFaceCount = widget.minFaceCount;
      _tempMinDistanceThreshold = widget.minDistanceThreshold;
      _tempMaxDistanceThreshold = widget.maxDistanceThreshold;
      _hasChanges = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detection Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_hasChanges) {
              _showDiscardDialog();
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: SingleChildScrollView(
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
                            value: _tempMinFaceCount.toDouble(),
                            min: 1,
                            max: 10,
                            divisions: 9,
                            label: _tempMinFaceCount.toString(),
                            onChanged: (value) {
                              setState(() {
                                _tempMinFaceCount = value.round();
                                _markAsChanged();
                              });
                            },
                          ),
                        ),
                        Container(
                          width: 50,
                          child: Text(
                            _tempMinFaceCount.toString(),
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
                            value: _tempMinDistanceThreshold,
                            min: 0.01,
                            max: 0.15,
                            divisions: 14,
                            label: '${(_tempMinDistanceThreshold * 100).toInt()}%',
                            onChanged: (value) {
                              setState(() {
                                _tempMinDistanceThreshold = value;
                                if (_tempMinDistanceThreshold >= _tempMaxDistanceThreshold) {
                                  _tempMaxDistanceThreshold = _tempMinDistanceThreshold + 0.05;
                                }
                                _markAsChanged();
                              });
                            },
                          ),
                        ),
                        Container(
                          width: 50,
                          child: Text(
                            '${(_tempMinDistanceThreshold * 100).toInt()}%',
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
                            value: _tempMaxDistanceThreshold,
                            min: 0.1,
                            max: 0.6,
                            divisions: 50,
                            label: '${(_tempMaxDistanceThreshold * 100).toInt()}%',
                            onChanged: (value) {
                              setState(() {
                                _tempMaxDistanceThreshold = value;
                                if (_tempMaxDistanceThreshold <= _tempMinDistanceThreshold) {
                                  _tempMinDistanceThreshold = _tempMaxDistanceThreshold - 0.05;
                                }
                                _markAsChanged();
                              });
                            },
                          ),
                        ),
                        Container(
                          width: 50,
                          child: Text(
                            '${(_tempMaxDistanceThreshold * 100).toInt()}%',
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
            const SizedBox(height: 20),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _hasChanges ? _resetSettings : null,
                    child: const Text('Reset'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _hasChanges ? _applySettings : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _hasChanges ? Colors.blue : Colors.grey,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDiscardDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text('You have unsaved changes. Do you want to discard them?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close settings screen
            },
            child: const Text('Discard', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}