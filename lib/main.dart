import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:is_first_run/is_first_run.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/uuid.dart';
import 'my_home_page.dart';
import 'package:fluttertoast/fluttertoast.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp( const MyApp());
}
  

// tst
class MyApp extends StatelessWidget {

  const MyApp({super.key});



  @override
  Widget build(BuildContext context) {

    return MaterialApp(
      title: 'Watch',
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      home:  const MyHomePage(title: 'OssWatch'),
    );
  }
}
