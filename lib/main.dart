//ignore_for_file: public_member_api_docs

import 'dart:html';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  runApp(CameraApp());
}

class CameraApp extends StatefulWidget {
  @override
  _CameraAppState createState() => _CameraAppState();
}

class _CameraAppState extends State<CameraApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        home: Scaffold(
      appBar: AppBar(title: Text('Camera test')),
      body: AppBody(),
    ));
  }
}

class AppBody extends StatefulWidget {
  @override
  _AppBodyState createState() => _AppBodyState();
}

class _AppBodyState extends State<AppBody> {
  bool cameraAccess = false;
  String? error;
  List<CameraDescription>? cameras;

  @override
  void initState() {
    getCameras();
    super.initState();
  }

  Future<void> getCameras() async {
    try {
      await window.navigator.mediaDevices!
          .getUserMedia({'video': true, 'audio': false});
      setState(() {
        cameraAccess = true;
      });
      final cameras = await availableCameras();
      setState(() {
        this.cameras = cameras;
      });
    } on DomException catch (e) {
      setState(() {
        error = '${e.name}: ${e.message}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Center(child: Text('Error: $error'));
    }
    if (!cameraAccess) {
      return Center(child: Text('Camera access not granted yet.'));
    }
    if (cameras == null) {
      return Center(child: Text('Reading cameras'));
    }
    return CameraView(cameras: cameras!);
  }
}

class CameraView extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CameraView({Key? key, required this.cameras}) : super(key: key);

  @override
  _CameraViewState createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  String? error;
  CameraController? controller;
  double? zoomLevel;
  late CameraDescription cameraDescription = widget.cameras[0];

  double? minZoom;
  double? maxZoom;

  double? minExposure;
  double? maxExposure;
  double? exposure;

  bool recording = false;
  bool flashLight = false;
  bool orientationLocked = false;

  Future<void> initCam(CameraDescription description) async {
    setState(() {
      controller = CameraController(description, ResolutionPreset.max);
    });

    try {
      await controller!.initialize();

      final minZoom = await controller!.getMinZoomLevel();
      final maxZoom = await controller!.getMaxZoomLevel();

      final minExposure = await controller!.getMinExposureOffset();
      final maxExposure = await controller!.getMaxExposureOffset();

      print(maxExposure);
      print(minExposure);
      setState(() {
        this.minZoom = minZoom;
        this.maxZoom = maxZoom;
        this.zoomLevel = 0;

        this.minExposure = minExposure;
        this.maxExposure = maxExposure;
        this.exposure = 1;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    initCam(cameraDescription);
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    if (error != null) {
      return Center(
        child: Text('Initializing error: $error\nCamera list:'),
      );
    }
    if (controller == null) {
      return Center(child: Text('Loading controller...'));
    }
    if (!controller!.value.isInitialized) {
      return Center(child: Text('Initializing camera...'));
    }

    return SingleChildScrollView(
      child: Column(children: [
        AspectRatio(aspectRatio: 16 / 9, child: CameraPreview(controller!)),
        Material(
          child: DropdownButton<CameraDescription>(
            value: cameraDescription,
            icon: const Icon(Icons.arrow_downward),
            iconSize: 24,
            elevation: 16,
            onChanged: (CameraDescription? newValue) async {
              if (controller != null) {
                await controller!.dispose();
              }
              setState(() {
                controller = null;
                cameraDescription = newValue!;
              });

              await initCam(newValue!);
            },
            items: widget.cameras
                .map<DropdownMenuItem<CameraDescription>>((value) {
              return DropdownMenuItem<CameraDescription>(
                value: value,
                child: Text('${value.name}: ${value.lensDirection}'),
              );
            }).toList(),
          ),
        ),
        if (!recording)
          ElevatedButton(
            onPressed: controller == null
                ? null
                : () async {
                    await controller!.startVideoRecording();
                    setState(() {
                      recording = true;
                    });
                  },
            child: Text('Record video'),
          ),
        if (recording)
          ElevatedButton(
            onPressed: () async {
              final file = await controller!.stopVideoRecording();
              final bytes = await file.readAsBytes();
              final uri =
                  Uri.dataFromBytes(bytes, mimeType: 'video/webm;codecs=vp8');

              final link = AnchorElement(href: uri.toString());
              link.download = 'recording.webm';
              link.click();
              link.remove();
              setState(() {
                recording = false;
              });
            },
            child: Text('Stop recording'),
          ),
        SizedBox(height: 10),
        ElevatedButton(
          onPressed: controller == null
              ? null
              : () async {
                  final file = await controller!.takePicture();
                  final bytes = await file.readAsBytes();

                  final link = AnchorElement(
                      href: Uri.dataFromBytes(bytes, mimeType: 'image/png')
                          .toString());

                  link.download = 'picture.png';
                  link.click();
                  link.remove();
                },
          child: Text('Take picture'),
        ),
        SizedBox(height: 10),
        if (!orientationLocked)
          ElevatedButton(
              onPressed: () {
                controller!.lockCaptureOrientation();
                setState(() {
                  orientationLocked = true;
                });
              },
              child: Text('Lock orientation')),
        if (orientationLocked)
          ElevatedButton(
              onPressed: () {
                controller!.unlockCaptureOrientation();
                setState(() {
                  orientationLocked = false;
                });
              },
              child: Text('Unlock orientation')),
        SizedBox(height: 10),
        if (!flashLight)
          ElevatedButton(
              onPressed: () {
                controller!.setFlashMode(FlashMode.always);
                setState(() {
                  flashLight = true;
                });
              },
              child: Text('Turn flashlight on')),
        if (flashLight)
          ElevatedButton(
              onPressed: () {
                controller!.setFlashMode(FlashMode.off);
                setState(() {
                  flashLight = false;
                });
              },
              child: Text('Turn flashlight off')),
        SizedBox(height: 10),
        if (zoomLevel != null && maxZoom != null)
          Text('Zoom level: $zoomLevel/$maxZoom'),
        if (zoomLevel != null && minZoom != null && maxZoom != null)
          Slider(
            value: zoomLevel!,
            onChanged: (newValue) {
              setState(() {
                zoomLevel = newValue;
              });
              controller!.setZoomLevel(newValue);
            },
            min: minZoom!,
            max: maxZoom!,
          ),
        if (exposure != null && maxExposure != null)
          Text('Exposure offset: $exposure/$maxExposure'),
        if (exposure != null && minExposure != null && maxExposure != null)
          Slider(
            value: exposure!,
            onChanged: (newValue) {
              setState(() {
                exposure = newValue;
              });
              controller!.setExposureOffset(newValue);
            },
            min: minExposure!,
            max: maxExposure!,
          ),
        SizedBox(height: 10),
      ]),
    );
  }
}
