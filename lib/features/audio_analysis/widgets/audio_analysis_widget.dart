import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:emg_mobile_analyzer/features/core_ml/services/core_ml_service.dart';
import 'package:fl_chart/fl_chart.dart';

class AudioAnalysisWidget extends ConsumerStatefulWidget {
  const AudioAnalysisWidget({super.key});

  @override
  ConsumerState<AudioAnalysisWidget> createState() =>
      _AudioAnalysisWidgetState();
}

class _AudioAnalysisWidgetState extends ConsumerState<AudioAnalysisWidget> {
  bool _isAnalyzing = false;
  List<ClassificationResult> _currentClassifications = [];
  String _errorMessage = '';
  List<double> _waveformData = [];
  final int _maxWaveformPoints = 200;

  @override
  void dispose() {
    if (_isAnalyzing) {
      CoreMLService.stopAudioClassification();
    }
    super.dispose();
  }

  Future<void> _toggleAnalysis() async {
    if (_isAnalyzing) {
      final success = await CoreMLService.stopAudioClassification();
      if (success) {
        setState(() {
          _isAnalyzing = false;
          _currentClassifications = [];
          _waveformData = [];
          _errorMessage = '';
        });
      }
    } else {
      final success = await CoreMLService.startAudioClassification(
        onClassification: (classifications) {
          setState(() {
            _currentClassifications = classifications;
            _errorMessage = '';
          });
        },
        onError: (error) {
          setState(() {
            _errorMessage = error;
          });
        },
        onWaveform: (waveform) {
          setState(() {
            _waveformData = waveform;
            if (_waveformData.length > _maxWaveformPoints) {
              _waveformData = _waveformData.sublist(
                _waveformData.length - _maxWaveformPoints,
              );
            }
          });
        },
      );

      if (success) {
        setState(() {
          _isAnalyzing = true;
          _errorMessage = '';
        });
      } else {
        setState(() {
          _errorMessage = '音声分類の開始に失敗しました';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('音声分析')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // コントロールカード
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isAnalyzing ? Icons.mic : Icons.mic_off,
                          size: 48,
                          color: _isAnalyzing ? Colors.red : Colors.grey,
                        ),
                        const SizedBox(width: 16),
                        Text(
                          _isAnalyzing ? '分析中...' : '停止中',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _toggleAnalysis,
                      icon: Icon(_isAnalyzing ? Icons.stop : Icons.play_arrow),
                      label: Text(_isAnalyzing ? '停止' : '開始'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isAnalyzing ? Colors.red : Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // エラーメッセージ
            if (_errorMessage.isNotEmpty)
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // 波形表示
            if (_waveformData.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '音声波形',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: LineChart(
                          LineChartData(
                            lineBarsData: [
                              LineChartBarData(
                                spots:
                                    _waveformData
                                        .asMap()
                                        .entries
                                        .map(
                                          (e) =>
                                              FlSpot(e.key.toDouble(), e.value),
                                        )
                                        .toList(),
                                isCurved: false,
                                barWidth: 1,
                                color: Colors.blue,
                                dotData: FlDotData(show: false),
                              ),
                            ],
                            minY: -1.0,
                            maxY: 1.0,
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 0.5,
                                  getTitlesWidget: (value, meta) {
                                    return Text(
                                      value.toStringAsFixed(1),
                                      style: const TextStyle(fontSize: 10),
                                    );
                                  },
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                            ),
                            gridData: FlGridData(
                              show: true,
                              horizontalInterval: 0.5,
                              getDrawingHorizontalLine: (value) {
                                return FlLine(
                                  color: Colors.grey.withOpacity(0.3),
                                  strokeWidth: 1,
                                );
                              },
                            ),
                            borderData: FlBorderData(
                              show: true,
                              border: Border.all(color: Colors.grey, width: 1),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // 分類結果
            if (_currentClassifications.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '分類結果',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ..._currentClassifications.map(
                        (result) => Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      result.identifier,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${(result.confidence * 100).toStringAsFixed(1)}%',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              LinearProgressIndicator(
                                value: result.confidence,
                                backgroundColor: Colors.grey[300],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _getColorForConfidence(result.confidence),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // 説明カード
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        const Text(
                          '使い方',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• 「開始」ボタンを押すとリアルタイム音声分析が始まります\n'
                      '• マイクから音声を入力してください\n'
                      '• 音声波形と分類結果がリアルタイムで表示されます\n'
                      '• 「停止」ボタンで分析を終了できます',
                      style: TextStyle(fontSize: 14),
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

  Color _getColorForConfidence(double confidence) {
    if (confidence > 0.7) {
      return Colors.green;
    } else if (confidence > 0.4) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}
