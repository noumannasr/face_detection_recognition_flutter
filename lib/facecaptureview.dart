import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
// import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/painting.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:facesdk_plugin/facedetection_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:facesdk_plugin/facesdk_plugin.dart';
import 'person.dart';

enum ViewMode {
  MODE_NONE,
  NO_FACE_PREPARE,
  REPEAT_NO_FACE_PREPARE,
  TO_FACE_CIRCLE,
  FACE_CIRCLE_TO_NO_FACE,
  FACE_CIRCLE,
  FACE_CAPTURE_PREPARE,
  FACE_CAPTURE_DONE,
  FACE_CAPTURE_FINISHED
}

enum FaceCaptureState {
  NO_FACE,
  MULTIPLE_FACES,
  FIT_IN_CIRCLE,
  MOVE_CLOSER,
  NO_FRONT,
  FACE_OCCLUDED,
  EYE_CLOSED,
  MOUTH_OPENED,
  SPOOFED_FACE,
  CAPTURE_OK
}

const double DEFAULT_YAW_THRESHOLD = 10.0;
const double DEFAULT_ROLL_THRESHOLD = 10.0;
const double DEFAULT_PITCH_THRESHOLD = 10.0;
const double DEFAULT_OCCLUSION_THRESHOLD = 0.5;
const double DEFAULT_EYECLOSE_THRESHOLD = 0.5;
const double DEFAULT_MOUTHOPEN_THRESHOLD = 0.5;

Float32List byteArrayToFloatArray(Uint8List byteArray) {
   // Create a Float32List with half the length of the byteArray
   Float32List floatArray = Float32List(byteArray.length ~/ Float32List.bytesPerElement);

   // Iterate over the byteArray and convert each pair of bytes to a float value
   for (int i = 0; i < byteArray.length; i += Float32List.bytesPerElement) {
     // Convert bytes to a 32-bit floating point value
     floatArray[i ~/ Float32List.bytesPerElement] = byteArray.buffer.asFloat32List()[i ~/ Float32List.bytesPerElement];
   }

   return floatArray;
}

Rect getROIRect(Size frameSize) {
  double margin = frameSize.width / 6;
  double rectHeight = (frameSize.width - 2 * margin) * 6 / 5;

  return Rect.fromLTRB(
      margin,
      (frameSize.height - rectHeight) / 2,
      frameSize.width - margin,
      (frameSize.height - rectHeight) / 2 + rectHeight);
}

Rect getROIRect1(Size frameSize) {
  // Define margin and height
  double margin = frameSize.width / 6;
  double rectHeight = frameSize.width - 2 * margin;

  // Create the ROI rectangle
  Rect roiRect = Rect.fromLTRB(
      margin, // left
      (frameSize.height - rectHeight) / 2, // top
      frameSize.width - margin, // right
      (frameSize.height - rectHeight) / 2 + rectHeight // bottom
      );

  return roiRect;
}

Rect scale(Rect rect, double factor) {
  double diffHorizontal = (rect.right - rect.left) * (factor - 1);
  double diffVertical = (rect.bottom - rect.top) * (factor - 1);

  return Rect.fromLTRB(
    rect.left - diffHorizontal / 2,
    rect.top - diffVertical / 2,
    rect.right + diffHorizontal / 2,
    rect.bottom + diffVertical / 2,
  );
}

// ignore: must_be_immutable
class FaceCaptureView extends StatefulWidget {
  final List<Person> personList;
  FaceDetectionViewController? faceDetectionViewController;
  final Function(Person) insertPerson;



  FaceCaptureView(
      {super.key, required this.personList, required this.insertPerson});

  @override
  State<StatefulWidget> createState() => FaceCaptureViewState();
}

class FaceCaptureViewState extends State<FaceCaptureView> {
  TextEditingController nameController = TextEditingController();

  dynamic _faces;
  dynamic _currentFace;
  dynamic _capturedFace;
  dynamic _capturedImage;
  double _livenessThreshold = 0;
  double _identifyThreshold = 0;
  bool _recognized = false;
  String _capturedLiveness = "";
  String _capturedQuality = "";
  String _capturedLuminance = "";
  String _warningTxt = "";
  ViewMode _viewMode = ViewMode.MODE_NONE;

  // ignore: prefer_typing_uninitialized_variables
  var _identifiedFace;
  // ignore: prefer_typing_uninitialized_variables
  var _enrolledFace;
  final _facesdkPlugin = FacesdkPlugin();
  FaceDetectionViewController? faceDetectionViewController;

  // CameraController? _cameraController;
  // List<CameraDescription>? cameras;

  // @override
  // void initState() {
  //   super.initState();
  //   _initializeCamera();
  // }


  // Future<void> _setupCameraController() async {
  //   List<CameraDescription> _cameras = await availableCameras();
  //
  //   if (_cameras.isEmpty) {
  //     print("No cameras found.");
  //     return;
  //   }
  //
  //   // Find the front camera
  //   CameraDescription frontCamera = _cameras.firstWhere(
  //         (camera) => camera.lensDirection == CameraLensDirection.front,
  //     // Provide fallback if no front camera is found
  //   );
  //
  //   if (frontCamera == null) {
  //     print("No front camera found.");
  //     return;
  //   }
  //
  //   setState(() {
  //     _cameraController = CameraController(
  //       frontCamera, // Use the front camera
  //       ResolutionPreset.high,
  //     );
  //   });
  //
  //   try {
  //     await _cameraController?.initialize().timeout(Duration(seconds: 10), onTimeout: () {
  //       print("Camera initialization timed out.");
  //       // Handle timeout or show error
  //     });
  //     if (!mounted) return;
  //     setState(() {});
  //   } catch (e) {
  //     print("Error initializing camera: $e");
  //   }
  // }
  //
  // Future<void> _initializeCamera() async {
  //   // Initialize the camera list and choose the external camera (second camera)
  //   cameras = await availableCameras();
  //   if (cameras != null && cameras!.isNotEmpty) {
  //     _cameraController = CameraController(cameras![1], ResolutionPreset.high);
  //     await _cameraController?.initialize();
  //     setState(() {});
  //   }
  // }

  @override
  void dispose() {
   // _cameraController?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    loadSettings();
   // _initializeCamera();
    setState(() {
      _viewMode = ViewMode.NO_FACE_PREPARE;
    });
  }

  void setViewMode(ViewMode viewMode) {
    setState(() {
      nameController.clear();
      _viewMode = viewMode;
    });

    if (viewMode == ViewMode.FACE_CAPTURE_DONE) {
      faceDetectionViewController?.stopCamera();
    }
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    String? livenessThreshold = prefs.getString("liveness_threshold");
    String? identifyThreshold = prefs.getString("identify_threshold");
    setState(() {
      _livenessThreshold = double.parse(livenessThreshold ?? "0.7");
      _identifyThreshold = double.parse(identifyThreshold ?? "0.88");
    });
  }

  Future<void> registerFace({String? Name, BuildContext? context} ) async {
    num randomNumber =
        10000 + Random().nextInt(10000); // from 0 upto 99 included
    Person person = Person(
        name: '$Name.' + randomNumber.toString(),
        faceJpg: _capturedFace['faceJpg'],
        templates: _capturedFace['templates']);

    await widget.insertPerson(person);
    // ignore: use_build_context_synchronously
    Navigator.pop(context!, 'OK');
  }

  Future<bool> onFaceDetected(faces) async {
    if (_recognized == true) {
      return false;
    }

    if (!mounted) return false;

    setState(() {
      _faces = faces;
    });

    if (faces.length > 0) {
      setState(() {
        _currentFace = faces[0];
      });
    }

    FaceCaptureState faceCaptureState = checkFace(faces);
    if (_viewMode == ViewMode.REPEAT_NO_FACE_PREPARE) {
      if (faceCaptureState.index > FaceCaptureState.NO_FACE.index) {
        setViewMode(ViewMode.TO_FACE_CIRCLE);
      }
    } else if (_viewMode == ViewMode.FACE_CIRCLE) {
      if (faceCaptureState.index == FaceCaptureState.NO_FACE.index) {
        setState(() {
          _warningTxt = "";
        });
        setViewMode(ViewMode.FACE_CIRCLE_TO_NO_FACE);
      } else if (faceCaptureState.index ==
          FaceCaptureState.MULTIPLE_FACES.index) {
        setState(() {
          _warningTxt = "Multiple face detected!";
        });
      } else if (faceCaptureState.index ==
          FaceCaptureState.FIT_IN_CIRCLE.index) {
        setState(() {
          _warningTxt = "Fit in circle!";
        });
      } else if (faceCaptureState.index == FaceCaptureState.MOVE_CLOSER.index) {
        setState(() {
          _warningTxt = "Move closer!";
        });
      }
      // else if (faceCaptureState.index == FaceCaptureState.NO_FRONT.index) {
      //   setState(() {
      //     _warningTxt = "Not fronted face!";
      //   });
      // }
      // else if (faceCaptureState.index ==
      //     FaceCaptureState.FACE_OCCLUDED.index) {
      //   setState(() {
      //     _warningTxt = "Face occluded!";
      //   });
      // }
      else if (faceCaptureState.index == FaceCaptureState.EYE_CLOSED.index) {
        setState(() {
          _warningTxt = "Eye closed!";
        });
      } else if (faceCaptureState.index ==
          FaceCaptureState.MOUTH_OPENED.index) {
        setState(() {
          _warningTxt = "Mouth opened!";
        });
      } else if (faceCaptureState.index ==
          FaceCaptureState.SPOOFED_FACE.index) {
        setState(() {
          _warningTxt = "Spoof face";
        });
      } else {
        // createClipedImage();
        ui.Image capturedImage =
            await decodeImageFromList(_currentFace['faceJpg']);

        Rect roiRectSrc = Rect.fromLTWH(0, 0, capturedImage.width.toDouble(),
            capturedImage.height.toDouble());

        // Create a blank canvas for the bitmap
        final recorder = ui.PictureRecorder();
        final canvas1 = Canvas(recorder, roiRectSrc);

        // Define the circle path to clip
        final path = Path()
          ..addOval(Rect.fromCircle(
            center: Offset(roiRectSrc.width / 2, roiRectSrc.height / 2),
            radius: (roiRectSrc.width < roiRectSrc.height
                ? roiRectSrc.width / 2
                : roiRectSrc.height / 2),
          ));

        // Clip the canvas with the circular path
        canvas1.clipPath(path);

        // Draw the captured bitmap on the canvas
        final paint = Paint();
        canvas1.drawImageRect(
          capturedImage,
          Rect.fromLTWH(0, 0, capturedImage.width.toDouble(),
              capturedImage.height.toDouble()), // Source bitmap area
          roiRectSrc, // Destination rect
          paint,
        );

        // Complete the bitmap creation
        final picture = recorder.endRecording();
        ui.Image roiImage = await picture.toImage(
          roiRectSrc.width.toInt(),
          roiRectSrc.height.toInt(),
        );

        String livenessScore = "";
        if (_currentFace['liveness'] > _livenessThreshold) {
          livenessScore =
              "Liveness: Real, score = ${_currentFace['liveness'].toStringAsFixed(3)}";
        } else {
          livenessScore =
              "Liveness: Spoof, score = ${_currentFace['liveness'].toStringAsFixed(3)}";
        }

        String qualityScore = "";
        if (_currentFace['face_quality'] < 0.5) {
          qualityScore =
              "Quality: Low, score = ${_currentFace['face_quality'].toStringAsFixed(3)}";
        } else if (_currentFace['face_quality'] < 0.75) {
          qualityScore =
              "Quality: Medium, score = ${_currentFace['face_quality'].toStringAsFixed(3)}";
        } else {
          qualityScore =
              "Quality: High, score = ${_currentFace['face_quality'].toStringAsFixed(3)}";
        }

        String luminanceScore =
            "Luminance: ${_currentFace['face_luminance'].toStringAsFixed(3)}";

        setState(() {
          _warningTxt = "";
          _capturedImage = roiImage;
          _capturedFace = _currentFace;
          _capturedLiveness = livenessScore;
          _capturedQuality = qualityScore;
          _capturedLuminance = luminanceScore;
        });

        setViewMode(ViewMode.FACE_CAPTURE_PREPARE);
      }
    }

    return false;
  }

  FaceCaptureState checkFace(faces) {
    if (faces.length == 0) return FaceCaptureState.NO_FACE;
    if (faces.length > 1) return FaceCaptureState.MULTIPLE_FACES;

    var face = faces[0];
    double faceLeft = double.infinity;
    double faceRight = 0.0;
    double faceBottom = 0.0;

    try {
      if (Platform.isAndroid) {
        List landmarks_68 = face['landmarks_68'];
    
        for (int i = 0; i < 68; i++) {
          faceLeft =
              faceLeft < landmarks_68[i * 2] ? faceLeft : landmarks_68[i * 2];
          faceRight =
              faceRight > landmarks_68[i * 2] ? faceRight : landmarks_68[i * 2];
          faceBottom = faceBottom > landmarks_68[i * 2 + 1]
              ? faceBottom
              : landmarks_68[i * 2 + 1];
        }
      } else {
        List landmarks_68 = byteArrayToFloatArray(Uint8List.fromList(face['landmarks_68']));
    
        for (int i = 0; i < 68; i++) {
          faceLeft =
              faceLeft < landmarks_68[i * 2] ? faceLeft : landmarks_68[i * 2];
          faceRight =
              faceRight > landmarks_68[i * 2] ? faceRight : landmarks_68[i * 2];
          faceBottom = faceBottom > landmarks_68[i * 2 + 1]
              ? faceBottom
              : landmarks_68[i * 2 + 1];      
        }
      }

    } catch (e) {}
    
    if(true) {
    } else {
    }

    const double sizeRate = 0.30;
    const double interRate = 0.03;
    Size frameSize =
        const Size(720, 1280); // Replace with your actual frame size

    Rect roiRect = getROIRect(frameSize);
    double centerY = (face['y2'] + face['y1']) / 2;
    double topY = centerY - (face['y2'] - face['y1']) * 2 / 3;
    double interX = (roiRect.left - faceLeft).clamp(0.0, double.infinity) +
        (faceRight - roiRect.right).clamp(0.0, double.infinity);
    double interY = (roiRect.top - topY).clamp(0.0, double.infinity) +
        (faceBottom - roiRect.bottom).clamp(0.0, double.infinity);

    if (interX / roiRect.width > interRate ||
        interY / roiRect.height > interRate) {
      return FaceCaptureState.FIT_IN_CIRCLE;
    }

    if ((face['y2'] - face['y1']) * (face['x2'] - face['x1']) <
        roiRect.width * roiRect.height * sizeRate) {
      return FaceCaptureState.MOVE_CLOSER;
    }

    if (face['yaw'].abs() > DEFAULT_YAW_THRESHOLD ||
        face['roll'].abs() > DEFAULT_ROLL_THRESHOLD ||
        face['pitch'].abs() > DEFAULT_PITCH_THRESHOLD) {
      return FaceCaptureState.NO_FRONT;
    }

    if (face['face_occlusion'] > DEFAULT_OCCLUSION_THRESHOLD) {
      return FaceCaptureState.FACE_OCCLUDED;
    }

    if (face['left_eye_closed'] > DEFAULT_EYECLOSE_THRESHOLD ||
        face['right_eye_closed'] > DEFAULT_EYECLOSE_THRESHOLD) {
      return FaceCaptureState.EYE_CLOSED;
    }

    if (face['mouth_opened'] > DEFAULT_MOUTHOPEN_THRESHOLD) {
      return FaceCaptureState.MOUTH_OPENED;
    }

    return FaceCaptureState.CAPTURE_OK;
  }

  @override
  Widget build(BuildContext context) {
    final deviceHeight = MediaQuery.of(context).size.height;
    final deviceWidth = MediaQuery.of(context).size.width;
    return WillPopScope(
      onWillPop: () async {
        faceDetectionViewController?.stopCamera();
        return true;
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title: const Text('Face Recognition'),
          toolbarHeight: 30,
          centerTitle: true,
        ),
        body: _viewMode.index >= ViewMode.FACE_CAPTURE_DONE.index ?
        Stack(
          alignment: Alignment.topCenter,
          children: <Widget>[
            // if (_cameraController != null && _cameraController!.value.isInitialized)
            //   Positioned.fill(
            //     child: CameraPreview(_cameraController!),
            //   ),

            // Your existing code for Face Recognition Views
            _viewMode.index >= ViewMode.FACE_CAPTURE_DONE.index
                ?
           // FaceCaptureDetectionView(faceRecognitionViewState: this),
           //  Visibility(
           //      visible: _viewMode == ViewMode.NO_FACE_PREPARE,
           //      child: SizedBox(
           //          width: double.infinity,
           //          height: double.infinity,
           //          child: CaptureView(
           //            animateStart: 1.4,
           //            animateEnd: 0.88,
           //            duration: 800,
           //            repeat: false,
           //            viewMode: _viewMode,
           //            setViewMode: setViewMode,
           //            currentFace: _currentFace,
           //          ))),
           //  Visibility(
           //      visible: _viewMode == ViewMode.REPEAT_NO_FACE_PREPARE,
           //      child: SizedBox(
           //          width: double.infinity,
           //          height: double.infinity,
           //          child: CaptureView(
           //            animateStart: 0.88,
           //            animateEnd: 0.92,
           //            duration: 1300,
           //            repeat: true,
           //            viewMode: _viewMode,
           //            setViewMode: setViewMode,
           //            currentFace: _currentFace,
           //          ))),
           //  Visibility(
           //      visible: _viewMode == ViewMode.TO_FACE_CIRCLE,
           //      child: SizedBox(
           //          width: double.infinity,
           //          height: double.infinity,
           //          child: CaptureView(
           //            animateStart: 1.4,
           //            animateEnd: 0,
           //            duration: 800,
           //            repeat: false,
           //            viewMode: _viewMode,
           //            setViewMode: setViewMode,
           //            currentFace: _currentFace,
           //          ))),
           //  Visibility(
           //      visible: _viewMode == ViewMode.FACE_CIRCLE,
           //      child: SizedBox(
           //          width: double.infinity,
           //          height: double.infinity,
           //          child: CaptureView(
           //            animateStart: 0,
           //            animateEnd: 0,
           //            duration: 0,
           //            repeat: false,
           //            viewMode: _viewMode,
           //            setViewMode: setViewMode,
           //            currentFace: _currentFace,
           //          ))),
           //  Visibility(
           //      visible: _viewMode == ViewMode.FACE_CIRCLE_TO_NO_FACE,
           //      child: SizedBox(
           //          width: double.infinity,
           //          height: double.infinity,
           //          child: CaptureView(
           //            animateStart: 0,
           //            animateEnd: 1.0,
           //            duration: 600,
           //            repeat: false,
           //            viewMode: _viewMode,
           //            setViewMode: setViewMode,
           //            currentFace: _currentFace,
           //          ))),
           //  Visibility(
           //      visible: _viewMode == ViewMode.FACE_CAPTURE_PREPARE,
           //      child: SizedBox(
           //          width: double.infinity,
           //          height: double.infinity,
           //          child: CaptureView(
           //            animateStart: 0,
           //            animateEnd: 1.0,
           //            duration: 500,
           //            repeat: false,
           //            viewMode: _viewMode,
           //            setViewMode: setViewMode,
           //            currentFace: _capturedFace,
           //          ))),

            Visibility(
                visible: _viewMode.index >= ViewMode.FACE_CAPTURE_DONE.index,
                child: Padding(
                  padding: const EdgeInsets.only(top: 0),
                  child: SizedBox(
                      width: 100,
                      height: 500,
                      child: Transform.rotate(
                        angle: 30,
                        child: CaptureView(
                          color: Colors.transparent,
                          animateStart: 0,
                          animateEnd: 1.0,
                          duration: 500,
                          repeat: false,
                          viewMode: _viewMode,
                          setViewMode: setViewMode,
                          currentFace: _capturedImage,
                        ),
                      )),
                )): Container(
              color: Colors.red,
            ),
            Padding(
              padding:  EdgeInsets.only(left: 10, right: 10,top: 450),
              child: Container(
                  width: deviceWidth,
                  alignment: Alignment.topLeft,
                  child: Container(
                    height: deviceHeight*0.07,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.topRight,
                        colors: [Color(0xFFEFFEEB), Color(0xFFBBCBE2)],
                      ),
                      borderRadius:
                      BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Center(
                        child: TextFormField(

                          controller: nameController,
                          textInputAction: TextInputAction.done,
                          keyboardType: TextInputType.text,
                          style: TextStyle(color: Colors.black),
                          // textCapitalization: ,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.only(left: 10),
                            filled: false,
                            counter: Offstage(),
                            focusColor: Colors.transparent,
                            hintText: 'Enter Person Name',
                            hintStyle: TextStyle(color: Colors.black),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                  )),
            ),

            SizedBox(
              height: deviceHeight * 0.04,
            ),
            Container(
              margin: const EdgeInsets.only(right: 20, top: 64),
              alignment: Alignment.topRight,
              child: Text(
                _warningTxt, // Equivalent to android:text=""
                style: const TextStyle(
                  color: Colors
                      .redAccent, // Equivalent to android:textColor="@android:color/holo_red_light"
                  fontSize: 16, // Equivalent to android:textSize="16sp"
                ),
              ), // Equivalent to constraintEnd_toEndOf and constraintTop_toTopOf
            ),
            Visibility(
                visible:
                    _viewMode.index == ViewMode.FACE_CAPTURE_FINISHED.index,
                child: Container(
                  width: double.infinity,
                 // height: double.infinity,
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        const SizedBox(
                          height: 330,
                        ),

                        Row(
                          children: [
                            const SizedBox(
                              width: 16,
                            ),
                            Text(
                              _capturedLiveness,
                              style: const TextStyle(fontSize: 18),
                            )
                          ],
                        ),
                        const SizedBox(
                          height: 10,
                        ),
                        Row(
                          children: [
                            const SizedBox(
                              width: 16,
                            ),
                            Text(
                              _capturedQuality,
                              style: const TextStyle(fontSize: 18),
                            )
                          ],
                        ),
                        const SizedBox(
                          height: 10,
                        ),
                        Row(
                          children: [
                            const SizedBox(
                              width: 16,
                            ),
                            Text(
                              _capturedLuminance,
                              style: const TextStyle(fontSize: 18),
                            )
                          ],
                        ),
                        const SizedBox(
                          height: 16,
                        ),

                      ]),
                )),
            Padding(
              padding: EdgeInsets.only(top: 570),
              child: Visibility(
                visible:
                _viewMode.index == ViewMode.FACE_CAPTURE_FINISHED.index,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SizedBox(
                    width: deviceWidth,
                    height: 50,
                    child: ElevatedButton(

                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                      ),
                      onPressed: () {
                        if(nameController.text.isNotEmpty) {
                          registerFace(Name: nameController.text ,context: context);
                          //enrollPerson(Name:  nameController.text, context: context);
                        } else {
                          Fluttertoast.showToast(
                              msg: "Please enter person name",
                              toastLength: Toast.LENGTH_SHORT,
                              gravity: ToastGravity.BOTTOM,
                              timeInSecForIosWeb: 1,
                              backgroundColor: Colors.red,
                              textColor: Colors.white,
                              fontSize: 16.0);
                        }
                        // registerFace(context);
                      },
                      child: const Text('Enroll', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),),
                    ),
                  ),
                ),
              ),
            ),
          ],
        )
        :

        Stack(
          children: <Widget>[
            FaceCaptureDetectionView(faceRecognitionViewState: this),
            Visibility(
                visible: _viewMode == ViewMode.NO_FACE_PREPARE,
                child: SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                    child: CaptureView(
                      animateStart: 1.4,
                      animateEnd: 0.88,
                      duration: 800,
                      repeat: false,
                      viewMode: _viewMode,
                      setViewMode: setViewMode,
                      currentFace: _currentFace,
                    ))),
            Visibility(
                visible: _viewMode == ViewMode.REPEAT_NO_FACE_PREPARE,
                child: SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                    child: CaptureView(
                      animateStart: 0.88,
                      animateEnd: 0.92,
                      duration: 1300,
                      repeat: true,
                      viewMode: _viewMode,
                      setViewMode: setViewMode,
                      currentFace: _currentFace,
                    ))),
            Visibility(
                visible: _viewMode == ViewMode.TO_FACE_CIRCLE,
                child: SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                    child: CaptureView(
                      animateStart: 1.4,
                      animateEnd: 0,
                      duration: 800,
                      repeat: false,
                      viewMode: _viewMode,
                      setViewMode: setViewMode,
                      currentFace: _currentFace,
                    ))),
            Visibility(
                visible: _viewMode == ViewMode.FACE_CIRCLE,
                child: SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                    child: CaptureView(
                      animateStart: 0,
                      animateEnd: 0,
                      duration: 0,
                      repeat: false,
                      viewMode: _viewMode,
                      setViewMode: setViewMode,
                      currentFace: _currentFace,
                    ))),
            Visibility(
                visible: _viewMode == ViewMode.FACE_CIRCLE_TO_NO_FACE,
                child: SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                    child: CaptureView(
                      animateStart: 0,
                      animateEnd: 1.0,
                      duration: 600,
                      repeat: false,
                      viewMode: _viewMode,
                      setViewMode: setViewMode,
                      currentFace: _currentFace,
                    ))),
            Visibility(
                visible: _viewMode == ViewMode.FACE_CAPTURE_PREPARE,
                child: SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                    child: CaptureView(
                      animateStart: 0,
                      animateEnd: 1.0,
                      duration: 500,
                      repeat: false,
                      viewMode: _viewMode,
                      setViewMode: setViewMode,
                      currentFace: _capturedFace,
                    ))),
            Visibility(
                visible: _viewMode.index >= ViewMode.FACE_CAPTURE_DONE.index,
                child: SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                    child: CaptureView(
                      animateStart: 0,
                      animateEnd: 1.0,
                      duration: 500,
                      repeat: false,
                      viewMode: _viewMode,
                      setViewMode: setViewMode,
                      currentFace: _capturedImage,
                    ))),
            Container(
              margin: const EdgeInsets.only(right: 20, top: 64),
              alignment: Alignment.topRight,
              child: Text(
                _warningTxt, // Equivalent to android:text=""
                style: const TextStyle(
                  color: Colors
                      .redAccent, // Equivalent to android:textColor="@android:color/holo_red_light"
                  fontSize: 16, // Equivalent to android:textSize="16sp"
                ),
              ), // Equivalent to constraintEnd_toEndOf and constraintTop_toTopOf
            ),
            Visibility(
                visible:
                _viewMode.index == ViewMode.FACE_CAPTURE_FINISHED.index,
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        const SizedBox(
                          height: 400,
                        ),
                        Row(
                          children: [
                            const SizedBox(
                              width: 16,
                            ),
                            Text(
                              _capturedLiveness,
                              style: const TextStyle(fontSize: 18),
                            )
                          ],
                        ),
                        const SizedBox(
                          height: 10,
                        ),
                        Row(
                          children: [
                            const SizedBox(
                              width: 16,
                            ),
                            Text(
                              _capturedQuality,
                              style: const TextStyle(fontSize: 18),
                            )
                          ],
                        ),
                        const SizedBox(
                          height: 10,
                        ),
                        Row(
                          children: [
                            const SizedBox(
                              width: 16,
                            ),
                            Text(
                              _capturedLuminance,
                              style: const TextStyle(fontSize: 18),
                            )
                          ],
                        ),
                        const SizedBox(
                          height: 16,
                        ),
                        // ElevatedButton(
                        //   style: ElevatedButton.styleFrom(
                        //     backgroundColor:
                        //     Theme.of(context).colorScheme.primaryContainer,
                        //   ),
                        //   onPressed: () => registerFace(context),
                        //   child: const Text('Enroll'),
                        // ),
                      ]),
                )),
          ],
        ),
      )
    );
  }
}

class FaceCaptureDetectionView extends StatefulWidget
    implements FaceDetectionInterface {
  FaceCaptureViewState faceRecognitionViewState;

  FaceCaptureDetectionView({super.key, required this.faceRecognitionViewState});

  @override
  Future<void> onFaceDetected(faces) async {
    await faceRecognitionViewState.onFaceDetected(faces);
  }

  @override
  State<StatefulWidget> createState() => _FaceCaptureDetectionViewState();
}

class _FaceCaptureDetectionViewState extends State<FaceCaptureDetectionView> {
  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidView(
        viewType: 'facedetectionview',
        onPlatformViewCreated: _onPlatformViewCreated,
      );
    } else {
      return UiKitView(
        viewType: 'facedetectionview',
        onPlatformViewCreated: _onPlatformViewCreated,
      );
    }
  }

  void _onPlatformViewCreated(int id) async {
    final prefs = await SharedPreferences.getInstance();
    var cameraLens = prefs.getInt("camera_lens");

    widget.faceRecognitionViewState.faceDetectionViewController =
        FaceDetectionViewController(id, widget);

    await widget.faceRecognitionViewState.faceDetectionViewController
        ?.initHandler();

    int? livenessLevel = prefs.getInt("liveness_level");
    await widget.faceRecognitionViewState._facesdkPlugin.setParam({
      'check_liveness_level': livenessLevel ?? 0,
      'check_eye_closeness': true,
      'check_face_occlusion': true,
      'check_mouth_opened': true,
      'estimate_age_gender': true
    });

    await widget.faceRecognitionViewState.faceDetectionViewController
        ?.startCamera(cameraLens ?? 1);
  }
}

class CaptureView extends StatefulWidget {
  final double animateStart;
  final double animateEnd;
  final int duration;
  final bool repeat;
  final ViewMode viewMode;
  final Function(ViewMode) setViewMode;
  final dynamic currentFace;
  final Color color;

  const CaptureView(
      {super.key,
      required this.animateStart,
      required this.animateEnd,
      required this.duration,
      required this.repeat,
      required this.viewMode,
      required this.setViewMode,
      required this.currentFace,
  this.color = Colors.black
}
);

  @override
  _CaptureViewState createState() => _CaptureViewState();
}

class _CaptureViewState extends State<CaptureView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    // Initialize AnimationController and Tween for scaling the circle
    _controller = AnimationController(
      duration: Duration(milliseconds: widget.duration),
      vsync: this,
    );

    _animation =
        Tween<double>(begin: widget.animateStart, end: widget.animateEnd)
            .animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ))
          ..addListener(() {
            setState(() {});
          })
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              // Animation has finished
              _handleAnimationEnd();
              // You can add any code to be executed when the animation finishes here
            } else if (status == AnimationStatus.dismissed) {
              // Animation is dismissed (goes back to the starting point)
            }
          });
    // Start the animation
    if (widget.repeat == true)
      _controller.repeat(reverse: widget.repeat);
    else
      _controller.forward();
  }

  void _handleAnimationEnd() {
    if (widget.viewMode == ViewMode.NO_FACE_PREPARE) {
      setState(() {
        widget.setViewMode(ViewMode.REPEAT_NO_FACE_PREPARE);
      });
    } else if (widget.viewMode == ViewMode.TO_FACE_CIRCLE) {
      setState(() {
        widget.setViewMode(ViewMode.FACE_CIRCLE);
      });
    } else if (widget.viewMode == ViewMode.FACE_CIRCLE_TO_NO_FACE) {
      setState(() {
        widget.setViewMode(ViewMode.NO_FACE_PREPARE);
      });
    } else if (widget.viewMode == ViewMode.FACE_CAPTURE_PREPARE) {
      setState(() {
        widget.setViewMode(ViewMode.FACE_CAPTURE_DONE);
      });
    } else if (widget.viewMode == ViewMode.FACE_CAPTURE_DONE) {
      widget.setViewMode(ViewMode.FACE_CAPTURE_FINISHED);
    }
  }

  @override
  void dispose() {
    _controller.dispose(); // Dispose the controller to prevent memory leaks
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter:
          CapturePainter(_animation.value, widget.viewMode, widget.currentFace, widget.color),
      child: Container(),
    );
  }
}

class CapturePainter extends CustomPainter {
  final double animateValue;
  final ViewMode viewMode;
  bool scrimInited = false;
  final Paint eraserPaint;
  final dynamic currentFace;
  late ui.Image roiImage;
  final Color color;

  CapturePainter(this.animateValue, this.viewMode, this.currentFace, this.color)
      : eraserPaint = Paint()
          ..color = Colors.transparent
          ..blendMode = BlendMode.clear;

  @override
  void paint(Canvas canvas, Size size) async {
    final Paint overlayPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Draw a full-screen rectangle with overlay paint
    Path overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    Paint outSideActiveRoundPaint = Paint()
      ..style = PaintingStyle.stroke // Equivalent to Paint.Style.STROKE in Java
      ..strokeWidth = 4 // Set stroke width
      ..color = const Color(
          0xFFE6E1E5) // Set the color (use the actual color value or from your theme)
      ..isAntiAlias = true; // Equivalent to setAntiAlias(true) in Java

    Size frameSize = const Size(720, 1280);
    Rect roiRect = getROIRect1(frameSize);

    double ratioView = size.width / size.height;
    double ratioFrame = frameSize.width / frameSize.height;

    Rect roiViewRect;

    if (ratioView < ratioFrame) {
      double dx = ((size.height * ratioFrame) - size.width) / 2;
      double dy = 0;
      double ratio = size.height / frameSize.height;

      double x1 = roiRect.left * ratio - dx;
      double y1 = roiRect.top * ratio - dy;
      double x2 = roiRect.right * ratio - dx;
      double y2 = roiRect.bottom * ratio - dy;

      roiViewRect = Rect.fromLTRB(x1, y1, x2, y2);
    } else {
      double dx = 0;
      double dy = ((size.width / ratioFrame) - size.height) / 2;
      double ratio = size.height / frameSize.height;

      double x1 = roiRect.left * ratio - dx;
      double y1 = roiRect.top * ratio - dy;
      double x2 = roiRect.right * ratio - dx;
      double y2 = roiRect.bottom * ratio - dy;

      roiViewRect = Rect.fromLTRB(x1, y1, x2, y2);
    }

    if (viewMode == ViewMode.FACE_CIRCLE ||
        viewMode == ViewMode.FACE_CAPTURE_PREPARE ||
        viewMode.index >= ViewMode.FACE_CAPTURE_DONE.index ||
        (viewMode == ViewMode.TO_FACE_CIRCLE && animateValue < 1.0) ||
        viewMode == ViewMode.FACE_CIRCLE_TO_NO_FACE) {
      if (viewMode == ViewMode.FACE_CIRCLE_TO_NO_FACE) {
      } else {}

      double startWidth = 0.8 * roiViewRect.width * 0.5 / cos(45 * pi / 180);

      double centerX = roiViewRect.center.dx;
      double centerY = roiViewRect.center.dy;
      double left = centerX -
          (roiViewRect.width / 2 * (1 - animateValue) +
              startWidth * animateValue);
      double top = centerY -
          (roiViewRect.width / 2 * (1 - animateValue) +
              startWidth * animateValue);
      double right = centerX +
          (roiViewRect.width / 2 * (1 - animateValue) +
              startWidth * animateValue);
      double bottom = centerY +
          (roiViewRect.width / 2 * (1 - animateValue) +
              startWidth * animateValue);

      if ((viewMode == ViewMode.TO_FACE_CIRCLE && animateValue < 1.0) ||
          viewMode == ViewMode.FACE_CIRCLE_TO_NO_FACE) {}

      if (viewMode != ViewMode.FACE_CAPTURE_PREPARE) {
        Rect eraseRect = Rect.fromLTWH(left, top, right - left, bottom - top);
        Path circlePath = Path()
          ..addOval(
            Rect.fromCircle(
              center: eraseRect.center,
              radius: eraseRect.width / 2,
            ),
          );

        if (viewMode.index < ViewMode.FACE_CAPTURE_DONE.index) {
          overlayPath =
              Path.combine(PathOperation.difference, overlayPath, circlePath);
        }
        canvas.drawPath(overlayPath, overlayPaint);
      } else if (viewMode == ViewMode.FACE_CAPTURE_PREPARE) {
        Rect borderRect = scale(roiViewRect, 1.04);

        // Paint for the border circle
        final borderPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = const Color(0xFF492532) // Replace with the correct color
          ..isAntiAlias = true;

        // Create a path for the circular shape using borderRect
        Path circlePath = Path()
          ..addOval(Rect.fromCircle(
            center: Offset(borderRect.center.dx, borderRect.center.dy),
            radius: borderRect.width / 2,
          ));

        // Define innerRect and scale it based on animateValue
        Rect innerRect = scale(roiViewRect, 1.0 - animateValue);
        Path circlePath1 = Path()
          ..addOval(
            Rect.fromCircle(
              center: innerRect.center,
              radius: innerRect.width / 2,
            ),
          );

        circlePath =
            Path.combine(PathOperation.difference, circlePath, circlePath1);

        overlayPath =
            Path.combine(PathOperation.difference, overlayPath, circlePath1);

        canvas.drawPath(overlayPath, overlayPaint);
        canvas.drawPath(circlePath, borderPaint);
      }
    }

    if (viewMode == ViewMode.NO_FACE_PREPARE ||
        viewMode == ViewMode.REPEAT_NO_FACE_PREPARE ||
        viewMode == ViewMode.TO_FACE_CIRCLE ||
        viewMode == ViewMode.FACE_CIRCLE_TO_NO_FACE) {
      Rect scaleRect = roiViewRect;
      if (viewMode == ViewMode.NO_FACE_PREPARE ||
          viewMode == ViewMode.REPEAT_NO_FACE_PREPARE ||
          (viewMode == ViewMode.TO_FACE_CIRCLE && animateValue > 1.0)) {
        scaleRect = scale(roiViewRect, animateValue);
      }

      double lineWidth1 = scaleRect.width / 5;
      double lineWidthOffset1 = 0;
      if (viewMode == ViewMode.FACE_CIRCLE ||
          (viewMode == ViewMode.TO_FACE_CIRCLE && animateValue < 1.0) ||
          viewMode == ViewMode.FACE_CIRCLE_TO_NO_FACE) {
        lineWidth1 = lineWidth1 * animateValue;
        lineWidthOffset1 = scaleRect.width / 2 * (1 - animateValue);
      }

      double lineHeight1 = scaleRect.height / 5;
      double lineHeightOffset1 = 0;
      if (viewMode == ViewMode.FACE_CIRCLE ||
          (viewMode == ViewMode.TO_FACE_CIRCLE && animateValue < 1.0) ||
          viewMode == ViewMode.FACE_CIRCLE_TO_NO_FACE) {
        lineHeight1 = lineHeight1 * animateValue;
        lineHeightOffset1 = scaleRect.height / 2 * (1 - animateValue);
      }

      double quadR1 = scaleRect.width / 12;
      if (viewMode == ViewMode.FACE_CIRCLE ||
          (viewMode == ViewMode.TO_FACE_CIRCLE && animateValue < 1.0) ||
          viewMode == ViewMode.FACE_CIRCLE_TO_NO_FACE) {
        quadR1 = scaleRect.width / 12 +
            (scaleRect.width / 2 - scaleRect.width / 12) * (1 - animateValue) -
            20;
      }

      Paint paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..color = const Color(0xFFEADDFF)
        ..isAntiAlias = true;

      if (viewMode == ViewMode.NO_FACE_PREPARE ||
          (viewMode == ViewMode.TO_FACE_CIRCLE && animateValue > 1.0)) {
        int alpha = (min(255, ((1.4 - animateValue) / 0.4 * 255))).toInt();
        paint.color = paint.color.withAlpha(alpha);
      } else {
        paint.color = paint.color.withAlpha(255);
      }

      if (viewMode == ViewMode.NO_FACE_PREPARE ||
          viewMode == ViewMode.REPEAT_NO_FACE_PREPARE ||
          viewMode == ViewMode.TO_FACE_CIRCLE ||
          viewMode == ViewMode.FACE_CIRCLE_TO_NO_FACE) {
        Path path1 = Path();
        path1.moveTo(
            scaleRect.left, scaleRect.top + lineHeight1 + lineHeightOffset1);
        path1.lineTo(scaleRect.left, scaleRect.top + quadR1);
        path1.arcTo(
            Rect.fromLTWH(
                scaleRect.left, scaleRect.top, quadR1 * 2, quadR1 * 2),
            pi,
            pi / 2,
            false);
        path1.lineTo(
            scaleRect.left + lineWidth1 + lineWidthOffset1, scaleRect.top);
        canvas.drawPath(path1, paint);

        Path path2 = Path();
        path2.moveTo(
            scaleRect.right, scaleRect.top + lineHeight1 + lineHeightOffset1);
        path2.lineTo(scaleRect.right, scaleRect.top + quadR1);
        path2.arcTo(
            Rect.fromLTWH(scaleRect.right - quadR1 * 2, scaleRect.top,
                quadR1 * 2, quadR1 * 2),
            0,
            -pi / 2,
            false);
        path2.lineTo(
            scaleRect.right - lineWidth1 - lineWidthOffset1, scaleRect.top);
        canvas.drawPath(path2, paint);

        Path path3 = Path();
        path3.moveTo(scaleRect.right,
            scaleRect.bottom - lineHeight1 - lineHeightOffset1);
        path3.lineTo(scaleRect.right, scaleRect.bottom - quadR1);
        path3.arcTo(
            Rect.fromLTWH(scaleRect.right - quadR1 * 2,
                scaleRect.bottom - quadR1 * 2, quadR1 * 2, quadR1 * 2),
            0,
            pi / 2,
            false);
        path3.lineTo(
            scaleRect.right - lineWidth1 - lineWidthOffset1, scaleRect.bottom);
        canvas.drawPath(path3, paint);

        Path path4 = Path();
        path4.moveTo(
            scaleRect.left, scaleRect.bottom - lineHeight1 - lineHeightOffset1);
        path4.lineTo(scaleRect.left, scaleRect.bottom - quadR1);
        path4.arcTo(
            Rect.fromLTWH(scaleRect.left, scaleRect.bottom - quadR1 * 2,
                quadR1 * 2, quadR1 * 2),
            pi,
            -pi / 2,
            false);
        path4.lineTo(
            scaleRect.left + lineWidth1 + lineWidthOffset1, scaleRect.bottom);
        canvas.drawPath(path4, paint);
      }
    }

    if (viewMode == ViewMode.FACE_CIRCLE) {
      double centerX = roiViewRect.center.dx;
      double centerY = roiViewRect.center.dy;

      // Loop to draw lines
      for (int i = 0; i < 360; i += 5) {
        double a1 = roiViewRect.width / 2 + 4;
        double b1 = roiViewRect.height / 2 + 4;
        double a2 = roiViewRect.width / 2 + 16;
        double b2 = roiViewRect.height / 2 + 16;

        double th = i * pi / 180;
        double x1 = a1 * b1 / sqrt(pow(b1, 2) + pow(a1, 2) * tan(th) * tan(th));
        double x2 = a2 * b2 / sqrt(pow(b2, 2) + pow(a2, 2) * tan(th) * tan(th));
        double y1 = sqrt(1 - (x1 / a1) * (x1 / a1)) * b1;
        double y2 = sqrt(1 - (x1 / a1) * (x1 / a1)) * b2;

        // Adjust x1, x2 for angles between 90° and 270°
        if ((i % 360) > 90 && (i % 360) < 270) {
          x1 = -x1;
          x2 = -x2;
        }

        // Adjust y1, y2 for angles between 180° and 360°
        if ((i % 360) > 180 && (i % 360) < 360) {
          y1 = -y1;
          y2 = -y2;
        }
        // Draw the lines
        canvas.drawLine(Offset(centerX + x1, centerY - y1),
            Offset(centerX + x2, centerY - y2), outSideActiveRoundPaint);
      }

      if (currentFace != null) {
        final Paint paint1 = Paint()
          ..style = PaintingStyle.fill
          ..strokeWidth = 6
          ..color = const Color(
              0x80EADDFF) // Replace with actual color value or use a theme color
          ..isAntiAlias = true;

        var yaw = currentFace['yaw'];
        var pitch = currentFace['pitch'];

        // Create Path1
        final Path path1 = Path()
          ..moveTo(roiViewRect.center.dx, roiViewRect.top)
          ..quadraticBezierTo(
            roiViewRect.center.dx - roiViewRect.width * (sin(yaw * pi / 180)),
            roiViewRect.center.dy,
            roiViewRect.center.dx,
            roiViewRect.bottom,
          )
          ..quadraticBezierTo(
            roiViewRect.center.dx -
                roiViewRect.width * (sin(yaw * pi / 180)) / 3,
            roiViewRect.center.dy,
            roiViewRect.center.dx,
            roiViewRect.top,
          );
        canvas.drawPath(path1, paint1);

        // Create Path2
        final Path path2 = Path()
          ..moveTo(roiViewRect.left, roiViewRect.center.dy)
          ..quadraticBezierTo(
            roiViewRect.center.dx,
            roiViewRect.center.dy + roiViewRect.width * (sin(pitch * pi / 180)),
            roiViewRect.right,
            roiViewRect.center.dy,
          )
          ..quadraticBezierTo(
            roiViewRect.center.dx,
            roiViewRect.center.dy +
                roiViewRect.width * (sin(pitch * pi / 180)) / 3,
            roiViewRect.left,
            roiViewRect.center.dy,
          );
        canvas.drawPath(path2, paint1);
      }
    } else if (viewMode.index >= ViewMode.FACE_CAPTURE_DONE.index) {
      if (currentFace != null) {
        Rect borderRect = scale(roiViewRect, 0.8);

        // Paint for drawing the circle
        final Paint paint1 = Paint()
          ..style = PaintingStyle.stroke
          ..color = Colors.tealAccent // Replace with your actual color
          ..strokeWidth = 7
          ..isAntiAlias = true;

        // Translate canvas based on animateValue
        canvas.translate(0, (size.width / 5 - roiViewRect.top) * animateValue);

        //   final ui.Image capturedImage =
        //       await decodeImageFromList(currentFace['faceJpg']);
        // //Draw the bitmap (roiBitmap)
        canvas.drawImageRect(
          currentFace,
          Rect.fromLTWH(0, 0, currentFace.width.toDouble(),
              currentFace.height.toDouble()),
          borderRect,
          Paint(),
        );

        // Draw the circle in the center of the borderRect
        canvas.drawCircle(
          Offset(borderRect.center.dx, borderRect.center.dy),
          borderRect.width / 2,
          paint1,
        );
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true; // Repaint whenever animation updates
  }
}
