
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:test_esp32/bluetooth_devices.dart';
import 'package:test_esp32/heart_chart.dart';
import 'package:test_esp32/helpers/twatch_data.dart';
import 'package:test_esp32/percent_indicator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

import 'package:test_esp32/settings_page.dart';

import 'helpers/uuid.dart';


enum BluetoothConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  BluetoothConnectionState _btStatus = BluetoothConnectionState.disconnected;
  BluetoothConnection? connection;
  String _messageBuffer = '';
  double? batSOC = 0;
  double? isCharging = 0;
  TWatchData? twatch = TWatchData();


  CollectionReference? _reference;

  @override
  void initState() {
    initCollection();
    super.initState();
  }

  Future<void> initCollection() async {
    _reference = FirebaseFirestore.instance.collection(await getDeviceIdentifier());
  }


  // read input data from serial bluetooth connection
  void _onDataReceived(Uint8List data) {
    // Allocate buffer for parsed data
    int backspacesCounter = 0;
    data.forEach((byte) {
      if (byte == 8 || byte == 127) {
        backspacesCounter++;
      }
    });
    Uint8List buffer = Uint8List(data.length - backspacesCounter);
    int bufferIndex = buffer.length;

    // Apply backspace control character
    backspacesCounter = 0;
    for (int i = data.length - 1; i >= 0; i--) {
      if (data[i] == 8 || data[i] == 127) {
        backspacesCounter++;
      } else {
        if (backspacesCounter > 0) {
          backspacesCounter--;
        } else {
          buffer[--bufferIndex] = data[i];
        }
      }
    }
    String dataString = String.fromCharCodes(buffer);
    int index = buffer.indexOf(13);
    var message = '';
    if (~index != 0) {
      message = backspacesCounter > 0
          ? _messageBuffer.substring(
              0, _messageBuffer.length - backspacesCounter)
          : _messageBuffer + dataString.substring(0, index);
      _messageBuffer = dataString.substring(index);
    } else {
      _messageBuffer = (backspacesCounter > 0
          ? _messageBuffer.substring(
              0, _messageBuffer.length - backspacesCounter)
          : _messageBuffer + dataString);
    }

    // saves the data into variables
    if (message.isEmpty) return; // to avoid fomrmat exception
    var dateList = message.split(" ");
    double? anabeatAVG = double.tryParse(dateList[0].trim());
    double? anaBeatsPerMins = double.tryParse(dateList[1].trim());
    double? anaBeatSOC = double.tryParse(dateList[2].trim());
    int? anaTemp = int.tryParse(dateList[3].trim());
    double? anaIsCharging = double.tryParse(dateList[4].trim());
    double? anaxAcc = double.tryParse(dateList[5].trim());
    double? anayAcc = double.tryParse(dateList[6].trim());
    double? anazAcc = double.tryParse(dateList[7].trim());
    double? anaUVA = double.tryParse(dateList[8].trim());
    double? anaUVB = double.tryParse(dateList[9].trim());
    double? anaUVIndx = double.tryParse(dateList[10].trim());
    DateTime now = DateTime.now();



    // update the screen with the new data
    setState(() {
      batSOC = anaBeatSOC;

      isCharging =anaIsCharging;
      twatch = TWatchData( avgHR: anabeatAVG, currHR: anaBeatsPerMins, temp: anaTemp, uva: anaUVA, uvb: anaUVB, uvindx: anaUVIndx, timestamp: now, xacc: anaxAcc, yacc: anayAcc, zacc: anazAcc);


    });
    if(twatch!.currHR != 0 && twatch!.avgHR!= 0) {
      _reference!.add({"avgHR": anabeatAVG , "currHR": anaBeatsPerMins, "temp": twatch!.temp, "xacc": twatch!.xacc, "yacc": twatch!.yacc, "zacc": twatch!.zacc, "uva": twatch!.uva, "uvb": twatch!.uvb, "uvindx": twatch!.uvindx, "timeStamp": twatch!.timestamp.toString()});
    }
    // print("new msg $dateList}");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Color(0x44000000),
        elevation: 0,
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_bluetooth),
            onPressed: () async {
              BluetoothDevice? device = await Navigator.of(context).push(
                  CupertinoPageRoute(builder: (_) => const BluetoothDevices()));

              if (device == null) return;

              print('Connecting to device...');
              setState(() {
                _btStatus = BluetoothConnectionState.connecting;
              });

              BluetoothConnection.toAddress(device.address).then((_connection) {
                print('Connected to the device');
                connection = _connection;
                setState(() {
                  _btStatus = BluetoothConnectionState.connected;
                });

                connection!.input!.listen(_onDataReceived).onDone(() {
                  setState(() {
                    _btStatus = BluetoothConnectionState.disconnected;
                  });
                });
              }).catchError((error) {
                print('Cannot connect, exception occured');
                print(error);
                setState(() {
                  _btStatus = BluetoothConnectionState.error;
                });
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: ()  {
              Navigator.of(context).push(
                  CupertinoPageRoute(builder: (_) => const SettingsPage()));
            },
          ),
        ],
      ),
      body: SizedBox(
        width: double.infinity,
        child: SingleChildScrollView(
          physics: const ScrollPhysics(),
          child: Column(
            children: [
              const SizedBox(height: 90,),
              Builder(
                builder: (context) {
                  switch (_btStatus) {
                    case BluetoothConnectionState.disconnected:
                      return const PercentIndicator.disconnected();
                    case BluetoothConnectionState.connecting:
                      return PercentIndicator.connecting();
                    case BluetoothConnectionState.connected:
                      return PercentIndicator.connected(
                        percent: batSOC!/100 ,
                        avgValue: twatch!.avgHR.toString(),
                      );
                    case BluetoothConnectionState.error:
                      return const PercentIndicator.error();
                  }
                },
              ),
              Container(
                constraints: const BoxConstraints(maxWidth: 400),

                child: ListView(
                  physics: NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  children: [

                    BuildCard(icon: Icons.battery_std, text: "Battery Percentage: ${batSOC!}", sub: isCharging! == 0 ? "Status: Discharging" : "Status: Charging", onPress: (){print("MEAW");}),
                    BuildCard(icon : Icons.monitor_heart, text: "Current BPM: ${twatch!.currHR!}", sub: twatch!.currHR == 0 ? "Make sure to wear the watch correctly" :"Beats Per Minutes", onPress: ()=>
                      Navigator.of(context).push(
                          CupertinoPageRoute(builder: (_) =>  HeartChart()))
                    ),
                    BuildCard(icon: Icons.monitor_heart_outlined, text: "AVG BPM: ${twatch!.avgHR!}", sub: twatch!.currHR == 0 ? "Make sure to wear the watch correctly" : "Average in 10 minutes", onPress: (){print("MEAW");}),
                    BuildCard(icon: Icons.sunny, text: "Current Temperature", sub: "${twatch!.temp!} Celsius degree", onPress: (){print("MEAW");}),
                    BuildCard(icon: Icons.sensor_occupied_rounded, text: "Accelerometer Data", sub: "X Axis: ${twatch!.xacc!}, Y Axis: ${twatch!.yacc!}, Z Axis: ${twatch!.zacc!}", onPress: (){print("MEAW");}),
                    BuildCard( icon: Icons.sensors_rounded, text: "UV Rating",sub: "UVA: ${twatch!.uva!}, UVB: ${twatch!.uvb!}, UV Index: ${twatch!.uvindx!}", onPress: (){print("MEAW");}),
                  ],
                ),
              ),
              const SizedBox(height: 20,)

            ],
          ),
        ),
      ),
    );
  }


}

class BuildCard extends StatelessWidget {
  final Function onPress;
  final IconData icon;
  final String text;
  final String sub;
  const BuildCard({Key? key, required this.onPress, required this.icon, required this.text, required this.sub}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), elevation: 5, color: Colors.white, child: ListTile(leading:  Icon(icon) ,title: Text(text),subtitle:  Text(sub), trailing: Icon(Icons.arrow_forward_ios_sharp),
    onTap: ()=> onPress.call()));
  }
}
