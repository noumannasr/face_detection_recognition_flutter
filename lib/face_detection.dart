//
// import 'package:camera/camera.dart';
// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';
//
// // class CameraExampleHome extends StatefulWidget {
// //   const CameraExampleHome({super.key});
// //
// //   @override
// //   State<CameraExampleHome> createState() => _CameraExampleHomeState();
// // }
// //
// // class _CameraExampleHomeState extends State<CameraExampleHome> {
// //   List<CameraDescription> cameras = [];
// //   CameraController? cameraController;
// //   @override
// //   void initState() {
// //     // TODO: implement initState
// //     super.initState();
// //     _setupCameraController();
// //   }
// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       body: _buildUI(),
// //     );
// //   }
// //   Widget _buildUI() {
// //     if(cameraController == null || cameraController?.value.isInitialized == false) {
// //       return Center(
// //       child: CircularProgressIndicator(),
// //       );
// //
// //     }
// //     return SafeArea(
// //       child: SizedBox.expand(
// //         child: Column(
// //           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
// //           crossAxisAlignment: CrossAxisAlignment.center,
// //           children: [
// //             SizedBox(
// //                 height: 200,
// //                 width: 200,
// //                 child: CameraPreview(cameraController!)),
// //           ],
// //         ),
// //       ),
// //     );
// //
// //   }
// //
// //   Future<void> _setupCameraController() async {
// //     List<CameraDescription> _cameras = await availableCameras();
// //
// //     if (_cameras.isEmpty) {
// //       print("No cameras found.");
// //       return;
// //     }
// //
// //     // Find the front camera
// //     CameraDescription frontCamera = _cameras.firstWhere(
// //           (camera) => camera.lensDirection == CameraLensDirection.front,
// //        // Provide fallback if no front camera is found
// //     );
// //
// //     if (frontCamera == null) {
// //       print("No front camera found.");
// //       return;
// //     }
// //
// //     setState(() {
// //       cameraController = CameraController(
// //         frontCamera, // Use the front camera
// //         ResolutionPreset.high,
// //       );
// //     });
// //
// //     try {
// //       await cameraController?.initialize().timeout(Duration(seconds: 10), onTimeout: () {
// //         print("Camera initialization timed out.");
// //         // Handle timeout or show error
// //       });
// //       if (!mounted) return;
// //       setState(() {});
// //     } catch (e) {
// //       print("Error initializing camera: $e");
// //     }
// //   }
// //
// //
// // }
//
// import 'package:flutter/material.dart';
// import 'package:camera/camera.dart';
//
// class CameraExampleHome extends StatefulWidget {
//   const CameraExampleHome({super.key});
//
//   @override
//   State<CameraExampleHome> createState() => _CameraExampleHomeState();
// }
//
// class _CameraExampleHomeState extends State<CameraExampleHome> {
//   List<CameraDescription> cameras = [];
//   CameraController? cameraController;
//
//   @override
//   void initState() {
//     super.initState();
//     _setupCameraController();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: _buildUI(),
//     );
//   }
//
//   Widget _buildUI() {
//     if (cameraController == null || !cameraController!.value.isInitialized) {
//       return const Center(child: CircularProgressIndicator());
//     }
//
//     return SafeArea(
//       child: SizedBox.expand(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//           crossAxisAlignment: CrossAxisAlignment.center,
//           children: [
//             SizedBox(
//               height: 200,
//               width: 200,
//               child: CameraPreview(cameraController!),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Future<void> _setupCameraController() async {
//     try {
//       cameras = await availableCameras();
//
//       if (cameras.isEmpty) {
//         print("No cameras found.");
//         return;
//       }
//
//       // Check for external cameras, including front cameras
//       CameraDescription? selectedCamera;
//
//       // Try to find an external camera first
//       selectedCamera = cameras.firstWhere(
//             (camera) => camera.lensDirection == CameraLensDirection.external,
//         orElse: () {
//           // Fallback: Use front camera if no external camera is found
//           return cameras.firstWhere(
//                 (camera) => camera.lensDirection == CameraLensDirection.front,
//             orElse: () => cameras.first, // Fallback to the first available camera
//           );
//         },
//       );
//
//       setState(() {
//         cameraController = CameraController(
//           selectedCamera!,
//           ResolutionPreset.high,
//         );
//       });
//
//       await cameraController?.initialize().timeout(Duration(seconds: 10), onTimeout: () {
//         print("Camera initialization timed out.");
//       });
//
//       if (!mounted) return;
//
//       setState(() {});
//     } catch (e) {
//       print("Error initializing camera: $e");
//     }
//   }
// }
//
