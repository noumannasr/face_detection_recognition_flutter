// import 'package:flutter/material.dart';
//
// class AgeProvider extends ChangeNotifier {
//   double ageData = 0.0;
//   int genderData = 2;
//
//   AgeProvider() {
//     clearData();
//   }
//
//   clearData() {
//     ageData = 0.0;
//     genderData = 2;
//     notifyListeners();
//   }
//
//   setAge(double age) {
//     ageData = age;
//     notifyListeners();
//     print('we are in set Age $ageData');
//
//   }
//
//   setGender(int gender) {
//     // if(genderData == '') {
//     genderData = gender;
//     notifyListeners();
//     // }
//
//     print('we are in set Age $genderData');
//
//   }
//
//
// }