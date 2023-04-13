import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:test_esp32/helpers/twatch_data.dart';

import 'helpers/uuid.dart';

class HeartChart extends StatefulWidget {
  HeartChart({super.key});

  List<Color> get availableColors => const <Color>[
    Color(0xFF6E1BFF) , Color(0xFFFFC300),
    Color(0xFF2196F3),
    Color(0xFFFF683B),
    Color(0xFFFF3AF2),
    Color(0xFFE80054),
  ];

  final Color barBackgroundColor = Colors.black.withOpacity(0.3);
  final Color barColor = Colors.black;
  final Color touchedBarColor = Color(0xFF3BFF49);

  @override
  State<StatefulWidget> createState() => HeartChartState();
}

class HeartChartState extends State<HeartChart> {
  final Duration animDuration = const Duration(milliseconds: 250);
  List<double>? histogramData = [];
  List<TWatchData>? myList = [];
  int touchedIndex = -1;

  bool isPlaying = false;
  CollectionReference? _reference;

  @override
  void initState() {
    initCollection();
    super.initState();
  }

  Future<void> initCollection() async {
    getData();
  }

  //get the data from the firebase firestore server, saves into an arraylist
  Future<void> getData() async {
    print("id: ${await getDeviceIdentifier()}");
    bool isIOS = true;
    if(Platform.isAndroid){
      isIOS = false;
    }
    String tail =   isIOS ? "@ios.pi" : "@android.pi";
    QuerySnapshot querySnapshot = await FirebaseFirestore.instance.collection(await getDeviceIdentifier()+tail).limit(25).orderBy("timeStamp").get();
    // Get docs from collection reference
    // QuerySnapshot querySnapshot = await _reference!.get();

    // Get data from docs and convert map to List

    setState(() {

      myList = querySnapshot.docs
          .map(
            (doc) => TWatchData.fromJson(doc.data() as Map<String, dynamic>),
      )
          .toList();
      
      while (myList!.length >25){
        myList!.removeAt(0);
      }
      histogramData = List<double>.from(myList!.map((e) => e.heartrate));
    });
    // print(querySnapshot.docs.first.data());
    print("meawww ${myList!.first.heartrate}");
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Color(0x44000000),
          elevation: 0,
          title: const Text("Health Data"),

        ),
        body: Center(
            child: myList!.length == 0 ? const CircularProgressIndicator() : Container(
                child: SfCartesianChart(
                    primaryXAxis: CategoryAxis(),
                    series: <ChartSeries>[
                      BarSeries<TWatchData, String>(
                          dataSource: myList!,
                          // display the data
                          xValueMapper: (TWatchData data, _) => data.timestamp.toString(),
                          yValueMapper: (TWatchData data, _) => data.heartrate
                      )
                    ]
                )
            )
        )
    );
  }


}