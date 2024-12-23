// ignore_for_file: depend_on_referenced_packages

import 'package:facerecognition_flutter/provider/age_gender_provider.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:facesdk_plugin/facesdk_plugin.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_exif_rotation/flutter_exif_rotation.dart';
import 'package:path/path.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite/sqflite.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;
import 'about.dart';
import 'face_detection.dart';
import 'settings.dart';
import 'person.dart';
import 'personview.dart';
import 'facedetectionview.dart';
import 'facecaptureview.dart';

void main() {
  runApp(const MyApp());
}

void requestCameraPermission() async {
  PermissionStatus status = await Permission.camera.request();
  if (status.isGranted) {
    print('Camera permission granted');
  } else {
    print('Camera permission denied');
  }
}

// class ExternalCamera {
//   static const MethodChannel _channel = MethodChannel('com.example.externalcamera');
//
//   static Future<String> connectToCamera() async {
//     try {
//       final String result = await _channel.invokeMethod('connectCamera');
//       return result;
//     } on PlatformException catch (e) {
//       return "Failed to connect to camera: '${e.message}'.";
//     }
//   }
// }

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
        title: 'Face Recognition',
        theme: ThemeData(
          // Define the default brightness and colors.
          useMaterial3: true,
          brightness: Brightness.dark,
        ),
        home: MyHomePage(title: 'Face Recognition'));
  }
}

// ignore: must_be_immutable
class MyHomePage extends StatefulWidget {
  final String title;
  var personList = <Person>[];

  MyHomePage({super.key, required this.title});

  @override
  MyHomePageState createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage> {
  String _warningState = "";
  bool _visibleWarning = false;
  final _facesdkPlugin = FacesdkPlugin();

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    loadPerson();
  }

  loadPerson() async {

    int facepluginState = -1;
    String warningState = "";
    bool visibleWarning = false;

    try {
      if (Platform.isAndroid) {
        await _facesdkPlugin
            .setActivation(
            "uv4FFhzjRNjCS5HdY4JmdTB3Rxp15p1spg5Q+DWy+kjZk5ExrLyzBIzwPcwNfYPFAnTlQkq395oT"
                "3S6/WBAGP4keZbA+XZ5PRUn+43DG+y9aQKOU03RM2/bg6SdN1bRLW0Jfc56CCH0c6+7xqCoDRauH"
                "iPIJsFMjJQdjA64MM9uZDj1hdDOF5nCHj/9Lq8Or56inZY5POs5qo9Y4kJuIfIVTCbzLMQHwSo9B"
                "urvnJFUT9jtsIhbseAhZPrHfZGVCehCyYE9HSkXLok+omARw+VUnmBeDwbS+HBy4/7DqCotK5MMK"
                "QOp4XocTLg6Vx0PYOwMF4Wdw9LCjknYhRp3/Og==")
            .then((value) => facepluginState = value ?? -1);
      }
      else {
        await _facesdkPlugin
            .setActivation(
            "mCl744lTkL7Dz3MZr2/oCwS0H5g9L8Fl6IiB/2EZ8Gz37x9rP8rnW/E1FKauvJdAEly2v6jiESZa"
                "p1OT99zvcvlZ9uI0COOrDVg9e1ytM4/6AJru4i5iSybtW3P7rRkGycFikDBxRzPytTJRuqLQuQ9r"
                "XbiiBfcN/kvgEXpY3o1r7mAQbB9wpSdrL+xeXhl86mTTo7BAoyzphfYdVd6n0l3suZSiMYMpt9t7"
                "U5AU3CaiJW7iTbibVXjp9F60D32M4/LRlontvqJfK8s2PqI5w3Eam0ElXxfP5aQTXuh0aZ/XMp7g"
                "NrR7GECzigNCg/vameeobUPkVd9OFk+lgQpVeg==")
            .then((value) => facepluginState = value ?? -1);
      }

      if (facepluginState == 0) {
        await _facesdkPlugin
            .init()
            .then((value) => facepluginState = value ?? -1);
      }
    } catch (e) {}

    List<Person> personList = await loadAllPersons();
    await SettingsPageState.initSettings();

    final prefs = await SharedPreferences.getInstance();
    int? livenessLevel = prefs.getInt("liveness_level");

    try {
      await _facesdkPlugin.setParam({
        'check_liveness_level': livenessLevel ?? 0,
        'check_eye_closeness': true,
        'check_face_occlusion': true,
        'check_mouth_opened': true,
        'estimate_age_gender': true
      });
    } catch (e) {}

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    if (facepluginState == -1) {
      warningState = "Invalid license!";
      visibleWarning = true;
    }
    else if (facepluginState == -2) {
      warningState = "License expired!";
      visibleWarning = true;
    }
    else if (facepluginState == -3) {
      warningState = "Invalid license!";
      visibleWarning = true;
    }
    else if (facepluginState == -4) {
      warningState = "No activated!";
      visibleWarning = true;
    }
    else if (facepluginState == -5) {
      warningState = "Init error!";
      visibleWarning = true;
    }

    setState(() {
      _warningState = warningState;
      _visibleWarning = visibleWarning;
      widget.personList = personList;
    });

  }

  Future<Database> createDB() async {
    final database = openDatabase(
      // Set the path to the database. Note: Using the `join` function from the
      // `path` package is best practice to ensure the path is correctly
      // constructed for each platform.
      join(await getDatabasesPath(), 'person.db'),
      // When the database is first created, create a table to store dogs.
      onCreate: (db, version) {
        // Run the CREATE TABLE statement on the database.
        return db.execute(
          'CREATE TABLE person(name text, faceJpg blob, templates blob)',
        );
      },
      // Set the version. This executes the onCreate function and provides a
      // path to perform database upgrades and downgrades.
      version: 1,
    );

    return database;
  }

  // A method that retrieves all the dogs from the dogs table.
  Future<List<Person>> loadAllPersons() async {
    // Get a reference to the database.
    final db = await createDB();

    // Query the table for all The Dogs.
    final List<Map<String, dynamic>> maps = await db.query('person');

    // Convert the List<Map<String, dynamic> into a List<Dog>.
    return List.generate(maps.length, (i) {
      return Person.fromMap(maps[i]);
    });
  }

  Future<void> insertPerson(Person person) async {
    // Get a reference to the database.
    final db = await createDB();

    // Insert the Dog into the correct table. You might also specify the
    // `conflictAlgorithm` to use in case the same dog is inserted twice.
    //
    // In this case, replace any previous data.
    await db.insert(
      'person',
      person.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    setState(() {
      widget.personList.add(person);
    });
  }

  Future<void> deleteAllPerson() async {
    final db = await createDB();
    await db.delete('person');

    setState(() {
      widget.personList.clear();
    });

    Fluttertoast.showToast(
        msg: "All person deleted!",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0);
  }

  Future<void> deletePerson(index) async {
    // ignore: invalid_use_of_protected_member

    final db = await createDB();
    await db.delete('person',
        where: 'name=?', whereArgs: [widget.personList[index].name]);

    // ignore: invalid_use_of_protected_member
    setState(() {
      widget.personList.removeAt(index);
    });

    Fluttertoast.showToast(
        msg: "Person removed!",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0);
  }



    alertDialog(
      TextEditingController? nameController,
      BuildContext context,
      double deviceHeight,
      double deviceWidth) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return SizedBox(
          width: deviceWidth,
          // decoration: BoxDecoration(
          //   gradient: LinearGradient(
          //     begin: Alignment.topLeft,
          //     end: Alignment.topRight,
          //     colors: colorProvider.getBgColor(),
          //   ),
          // ),
          child: AlertDialog(
            elevation: 0,
            contentPadding: EdgeInsets.zero,
            //backgroundColor: Colors.transparent,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(16.0))),
            // title: Center(
            //   child: Text(
            //     title,
            //     style: TextStyle(fontWeight: FontWeight.bold),
            //   ),
            // ),
            content: Container(
              // width: 260.0,
              height: deviceHeight * 0.5,
              width: deviceWidth,
              decoration: BoxDecoration(
                shape: BoxShape.rectangle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.topRight,
                  colors: [Color(0xFFEFFEEB), Color(0xFFBBCBE2)],
                ),
                borderRadius: const BorderRadius.all(Radius.circular(16.0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // dialog top
                  SizedBox(
                    height: deviceHeight * 0.035,
                  ),
                  Center(
                    child: Text(
                      "Enter Person Name",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,),
                    ),
                  ),
                  SizedBox(
                    height: deviceHeight * 0.035,
                  ),
                  // dialog centre
                  Padding(
                    padding:  EdgeInsets.only(left: 10, right: 10),
                    child: Container(
                        width: deviceWidth,
                        alignment: Alignment.topLeft,
                        child: Container(
                           height: deviceHeight*0.07,
                          decoration: BoxDecoration(

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
                                // textCapitalization: ,
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.only(left: 10),
                                  filled: false,
                                  counter: Offstage(),
                                  focusColor: Colors.transparent,
                                   hintText: 'Person Name',
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

                  // dialog bottom
                  SizedBox(
                      width: deviceWidth * 0.85,
                      child: SizedBox(
                        height: 40,
                        width: deviceWidth * 0.85,
                        child: ElevatedButton(
                          style: ButtonStyle(
                            elevation: MaterialStateProperty.all(0),
                            shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            minimumSize: MaterialStateProperty.all(Size(deviceWidth * 0.85, 30)),
                            backgroundColor: MaterialStateProperty.all(Colors.transparent),
                          ),
                          onPressed:enrollPerson ,
                          child: Text(
                            'Enroll',
                            style: TextStyle(fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future enrollPerson() async {
    Fluttertoast.showToast(
        msg: "Please click capture to enroll user",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0);
    // try {
    //   final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    //   if (image == null) return;
    //
    //   var rotatedImage =
    //       await FlutterExifRotation.rotateImage(path: image.path);
    //
    //   final faces = await _facesdkPlugin.extractFaces(rotatedImage.path);
    //   for (var face in faces) {
    //     num randomNumber =
    //         10000 + Random().nextInt(10000); // from 0 upto 99 included
    //     Person person = Person(
    //         name: 'Person.' + randomNumber.toString(),
    //         faceJpg: face['faceJpg'],
    //         templates: face['templates']);
    //     insertPerson(person);
    //   }
    //
    //   if (faces.length == 0) {
    //     Fluttertoast.showToast(
    //         msg: "Enroll user by capturing",
    //         toastLength: Toast.LENGTH_SHORT,
    //         gravity: ToastGravity.BOTTOM,
    //         timeInSecForIosWeb: 1,
    //         backgroundColor: Colors.red,
    //         textColor: Colors.white,
    //         fontSize: 16.0);
    //   }
    //   else {
    //     Fluttertoast.showToast(
    //         msg: "Person enrolled!",
    //         toastLength: Toast.LENGTH_SHORT,
    //         gravity: ToastGravity.BOTTOM,
    //         timeInSecForIosWeb: 1,
    //         backgroundColor: Colors.red,
    //         textColor: Colors.white,
    //         fontSize: 16.0);
    //   }
    // } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //backgroundColor: Colors.white,
      appBar: AppBar(
        //backgroundColor: Colors.white,
        title: const Text('Face Recognition', style: TextStyle(color: Colors.white),),
        toolbarHeight: 70,
        centerTitle: true,
      ),
      body: Container(
        margin: const EdgeInsets.only(left: 16.0, right: 16.0),
        child: Column(
          children: <Widget>[
            const Card(
                color: Color.fromARGB(255, 0x49, 0x45, 0x4F),
                child: ListTile(
                  leading: Icon(Icons.tips_and_updates),
                  subtitle: Text(
                    // KBY-AI offers SDKs for
                    'Face recognition, Gender and Age Estimation, liveness detection',
                    style: TextStyle(fontSize: 13),
                  ),
                )),
            const SizedBox(
              height: 6,
            ),
            Row(
              children: <Widget>[
                Expanded(
                  flex: 1,
                  child: ElevatedButton.icon(
                      label: const Text('Enroll', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),),
                      icon: const Icon(
                        Icons.person_search,
                        color: Colors.white,
                      ),
                      style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.only(top: 10, bottom: 10),
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          shape: const RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(12.0)),
                          )),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => FaceCaptureView(
                                personList: widget.personList,
                                insertPerson: insertPerson,
                              )),
                        ).then((value) {
                          loadPerson();
                        });
                      }),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                Expanded(
                  flex: 1,
                  child: ElevatedButton.icon(
                      label: const Text('Settings', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),),
                      icon: const Icon(
                        Icons.settings,
                        color: Colors.white,
                      ),
                      style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.only(top: 10, bottom: 10),
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          shape: const RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(12.0)),
                          )),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => SettingsPage(
                                    homePageState: this,
                                  )),
                        ).then((value) {
                          loadPerson();
                        });
                      }),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 1,
                  child: ElevatedButton.icon(
                      label: const Text('Identify', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),),
                      icon: const Icon(
                        color: Colors.white,
                        Icons.person_pin,
                      ),
                      style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.only(top: 10, bottom: 10),
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          shape: const RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(12.0)),
                          )),
                      onPressed: () {

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => FaceRecognitionView(
                                personList: widget.personList,
                              )),
                        ).then((value) {
                          loadPerson();
                        });


                      }),
                ),
                // GestureDetector(
                //   onTap: (){
                //     Navigator.push(
                //       context,
                //       MaterialPageRoute(
                //           builder: (context) =>CameraExampleHome(),
                //       ),
                //     );
                //   },
                //     child: Text('Test')),
              ],
            ),
            const SizedBox(
              height: 8,
            ),
            Expanded(
                child: Stack(
              children: [
                PersonView(
                  personList: widget.personList,
                  homePageState: this,
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Visibility(
                        visible: _visibleWarning,
                        child: Container(
                          width: double.infinity,
                          height: 40,
                          color: Colors.redAccent,
                          child: Center(
                            child: Text(
                              _warningState,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ))
                  ],
                )
              ],
            )),
            // const SizedBox(
            //   height: 4,
            // ),
            // const Row(
            //   mainAxisAlignment: MainAxisAlignment.center,
            //   children: [
            //     Image(
            //       image: AssetImage('assets/ic_kby.png'),
            //       height: 32,
            //     ),
            //   ],
            // ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}
