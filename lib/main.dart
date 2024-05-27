import 'package:flutter/material.dart';
import 'dart:async';

import 'package:effects_sdk/effects_sdk.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_webrtc/flutter_webrtc.dart';

void main() {
  runApp(const EffectsSDKSampleApp());
}

void stopTracks(MediaStream? stream) {
  if (stream == null) return;
  for (final track in stream.getTracks()) {
    track.stop();
  }
}

class EffectsSDKSampleApp extends StatefulWidget {
  const EffectsSDKSampleApp({super.key});

  @override
  State<EffectsSDKSampleApp> createState() => _EffectsSDKSampleAppState();
}

class _EffectsSDKSampleAppState extends State<EffectsSDKSampleApp> {
  final RTCVideoRenderer _rtcVideoRenderer = RTCVideoRenderer();
  late EffectsSDK _effectsSDK;

  String? _currentCameraID;
  MediaStream? _currentCameraStream;
  MediaStream? _currentSdkOutput;

  bool _cameraSelectionEnabled = false;
  List<MediaDeviceInfo> _cameraInfoList = [];

  @override
  void initState() {
    super.initState();
    _rtcVideoRenderer.initialize();
    _effectsSDK = EffectsSDK("MY_CUSTOMER_ID");
    initEffectsSDK();
  }

  Future<void> initEffectsSDK() async {
    final cameraInfos = await enumerateVideoInputs();
    if (cameraInfos.isEmpty) return;
    switchCamera(cameraInfos.first.deviceId);
  }

  Future<void> switchCamera(String deviceID) async {
    if (_currentCameraID == deviceID) return;

    try {
      final inputStream = await getVideoStream(deviceID);
      _effectsSDK.clear();
      _effectsSDK.useStream(inputStream);

      final outputStream = _effectsSDK.getStream();
      _rtcVideoRenderer.srcObject = outputStream;

      _effectsSDK.onReady = () {
        _effectsSDK.run();
        _effectsSDK.setBackgroundColor(Colors.greenAccent.value);
      };

      _currentCameraID = deviceID;
      stopTracks(_currentCameraStream);
      _currentCameraStream = inputStream;
      stopTracks(_currentSdkOutput);
      _currentSdkOutput = outputStream;
    } catch (e) {
      print('Error switching camera: $e');
    }
  }

  Future<List<MediaDeviceInfo>> enumerateVideoInputs() async {
    final devices = await navigator.mediaDevices.enumerateDevices();
    return devices.where((device) => device.kind == 'videoinput').toList();
  }

  Future<MediaStream> getVideoStream(String deviceID) async {
    final constraints = kIsWeb
        ? {
            'video': {'deviceId': deviceID}
          }
        : {
            'video': {
              'optional': [
                {'sourceId': deviceID}
              ]
            }
          };
    return navigator.mediaDevices.getUserMedia(constraints);
  }

  @override
  void dispose() {
    _rtcVideoRenderer.dispose();
    stopTracks(_currentCameraStream);
    stopTracks(_currentSdkOutput);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('EffectsSDK Example App'),
        ),
        body: _cameraSelectionEnabled
            ? buildCameraSelector()
            : buildVideoPreview(),
      ),
    );
  }

  Widget buildVideoPreview() {
    return Column(
      children: [
        Expanded(child: RTCVideoView(_rtcVideoRenderer)),
        TextButton(
          onPressed: () async {
            final infos = await enumerateVideoInputs();
            setState(() {
              _cameraInfoList = infos;
              _cameraSelectionEnabled = true;
            });
          },
          child: Container(
            padding: const EdgeInsets.all(6.0),
            margin: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(border: Border.all(width: 1)),
            child: const Text("Switch Camera"),
          ),
        ),
      ],
    );
  }

  Widget buildCameraSelector() {
    return Column(
      children: [
        Expanded(child: buildCameraList()),
        TextButton(
          onPressed: () {
            setState(() {
              _cameraInfoList = [];
              _cameraSelectionEnabled = false;
            });
          },
          child: Container(
            padding: const EdgeInsets.all(24),
            child: const Text("Cancel"),
          ),
        ),
      ],
    );
  }

  Widget buildCameraList() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _cameraInfoList.length,
      itemBuilder: (context, index) {
        return buildCameraItem(_cameraInfoList[index]);
      },
    );
  }

  Widget buildCameraItem(MediaDeviceInfo deviceInfo) {
    return TextButton(
      onPressed: () {
        switchCamera(deviceInfo.deviceId);
        setState(() {
          _cameraInfoList = [];
          _cameraSelectionEnabled = false;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12.0),
        child: Text(deviceInfo.label),
      ),
    );
  }
}
