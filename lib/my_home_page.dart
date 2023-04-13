import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:is_first_run/is_first_run.dart';
import 'package:test_esp32/bluetooth_devices.dart';
import 'package:test_esp32/heart_chart.dart';
import 'package:test_esp32/helpers/twatch_data.dart';
import 'package:test_esp32/percent_indicator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

import 'package:test_esp32/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/uuid.dart';
import 'package:dio/dio.dart';

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
  TWatchData? tWatch = TWatchData();
  String _URL = "192.168.43.51";
  String? _token;
  String? _uuid;
  Timer? timer;
  bool toCloud = false;
  final TextEditingController _textFieldController = TextEditingController();

  CollectionReference? _reference;

  @override
  void initState() {
    initCollection();
    checkFirstRun();
    super.initState();
    timer = Timer.periodic(
        const Duration(seconds: 15), (Timer t) => _updateCloudPi());
  }

  void checkFirstRun() async {
    print("da5al");

    bool ifr = await IsFirstRun.isFirstRun();
    if (ifr) {
      print("register");

      _register();
      print("registereeee");
    } else {
      print("login");

      _login();
      print("loginnnnnn");
    }
  }

  _login() async {
    String uuid = await getDeviceIdentifier();

    bool isIOS = true;
    if (Platform.isAndroid) {
      isIOS = false;
    }

    Dio dio = Dio();

    try {
      // var header = {'Content-type': 'application/json; charset=utf-8'};
      var resp = await dio.post(
        "http://${_URL!}:8000/api/login",
        data: {
          "email": isIOS ? "$uuid@ios.pi" : "$uuid@android.pi",
          "password": uuid,
        },
        options: Options(headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        }),
      );
      if (resp.statusCode == 200) {
        // Status is the message receiving in resp saying product
        //inserted successfully.
        setToken(resp.data['access_token']);
      } else {
        _register();
      }
    } catch (E) {
      _register();
    }
  }

  _register() async {
    String uuid = await getDeviceIdentifier();
    print("uuuuuuu $uuid");
    bool isIOS = true;
    if (Platform.isAndroid) {
      isIOS = false;
    }

    Dio dio = Dio();
    var headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    // var header = {'Content-type': 'application/json; charset=utf-8'};
    var resp = await dio.post(
      "http://${_URL!}:8000/api/register",
      data: {
        "name": uuid,
        "email": isIOS ? "$uuid@ios.pi" : "$uuid@android.pi",
        "password": uuid,
        "password_confirmation": uuid
      },
      options: Options(headers: headers),
    );

    if (resp.statusCode == 200) {
      // Status is the message receiving in resp saying product
      //inserted successfully.
      print("asdddd ${resp.data['message']}");
      setToken(resp.data['access_token']);
    } else {
      print("asdddd ${resp.data['message']}");
    }
  }

  void showToast(String resp) {
    Fluttertoast.showToast(
        msg: "${resp} .",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0);
  }

  Future<bool> setToken(String value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setString('token', value);
  }

  _updateCloudPi() {
    if ((tWatch != null) && (tWatch!.heartrate! > 50)) {
      if (toCloud) {
        _reference!.add({
          "heartrate": tWatch!.heartrate,
          "xacc": tWatch!.xacc,
          "yacc": tWatch!.yacc,
          "zacc": tWatch!.zacc,
          "timeStamp": tWatch!.timestamp.toString()
        });
      } else {
        _sendToPi();
      }
    }
  }

  Future<void> initCollection() async {
    bool isIOS = true;
    if (Platform.isAndroid) {
      isIOS = false;
    }
    String _tail = isIOS ? "@ios.pi" : "@android.pi";
    _reference = FirebaseFirestore.instance
        .collection(await getDeviceIdentifier() + _tail);
    _token = await getToken();
    _uuid = await getDeviceIdentifier();
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

    DateTime now = DateTime.now();

    // update the screen with the new data
    setState(() {
      batSOC = double.tryParse(dateList[1].trim());
      tWatch = TWatchData(
          heartrate: double.tryParse(dateList[0].trim()),
          timestamp: now,
          xacc: double.tryParse(dateList[2].trim()),
          yacc: double.tryParse(dateList[3].trim()),
          zacc: double.tryParse(dateList[4].trim()));
    });

    // print("new msg $dateList}");
  }

  //bearer token
  Future<String?> getToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  //send data to edge server
  void _sendToPi() async {
    _token = await getToken();
    bool isIOS = true;
    if (Platform.isAndroid) {
      isIOS = false;
    }

    String tail = isIOS ? "@ios.pi" : "@android.pi";
    Dio dio = Dio();
    var headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $_token',
    };
    // var header = {'Content-type': 'application/json; charset=utf-8'};
    var resp = await dio.post(
      "http://${_URL!}:8000/api/hrs",
      data: {
        "user_id": _uuid! + tail,
        "heartrate": tWatch!.heartrate,
        "xacc": tWatch!.xacc,
        "yacc": tWatch!.yacc,
        "zacc": tWatch!.zacc
      },
      options: Options(headers: headers),
    );

    if (resp.statusCode == 200) {
      // Status is the message receiving in resp saying product
      //inserted successfully.
      print(resp.data['message']);
    }
  }

  Future<void> _displayTextInputDialog(BuildContext context) async {
    return showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Enter Edge IP Address'),
            content: TextField(
              onChanged: (value) {
                setState(() {
                  _URL = value;
                });
              },
              controller: _textFieldController,
              decoration:
                  const InputDecoration(hintText: "Edge Server IP Address"),
            ),
            actions: <Widget>[
              MaterialButton(
                color: Colors.red,
                textColor: Colors.white,
                child: const Text('Cancel'),
                onPressed: () {
                  setState(() {
                    Navigator.pop(context);
                  });
                },
              ),
              MaterialButton(
                color: Colors.green,
                textColor: Colors.white,
                child: const Text('Connect'),
                onPressed: () {
                  setState(() {
                    Navigator.pop(context);
                  });
                },
              ),
            ],
          );
        });
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
            onPressed: () {
              Navigator.of(context).push(
                  CupertinoPageRoute(builder: (_) => const SettingsPage()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.network_check),
            onPressed: () {
              _displayTextInputDialog(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.cloud),
            onPressed: () {
              var ret = showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      content: StatefulBuilder(
                        builder: (BuildContext context, StateSetter setState) {
                          return SizedBox(
                            height: MediaQuery.of(context).size.height / 3,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text("Enable to connect to the cloud directly, disable to connect to Edge Server"),
                                  Switch(
                                    value: toCloud,
                                    onChanged: (value) {
                                      setState(() {
                                        toCloud = value;
                                      });
                                    },
                                    activeTrackColor: Colors.lightGreen,
                                    activeColor: Colors.green,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  });
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
              const SizedBox(
                height: 90,
              ),
              Builder(
                builder: (context) {
                  switch (_btStatus) {
                    case BluetoothConnectionState.disconnected:
                      return const PercentIndicator.disconnected();
                    case BluetoothConnectionState.connecting:
                      return PercentIndicator.connecting();
                    case BluetoothConnectionState.connected:
                      return PercentIndicator.connected(
                        percent: batSOC! / 100,
                        heartrate: tWatch!.heartrate.toString(),
                      );
                    case BluetoothConnectionState.error:
                      return const PercentIndicator.error();
                  }
                },
              ),
              Container(
                constraints: const BoxConstraints(maxWidth: 400),
                child: ListView(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  children: [
                    BuildCard(
                        icon: Icons.battery_std,
                        text: "Battery Percentage: ${batSOC!}",
                        sub: "",
                        onPress: () {
                          print("MEAW");
                        }),
                    toCloud
                        ? BuildCard(
                            icon: Icons.monitor_heart,
                            text: "Current BPM: ${tWatch!.heartrate!}",
                            sub: tWatch!.heartrate! == 0 ||
                                    tWatch!.heartrate! <= 50
                                ? "Make sure to wear the watch correctly\nGive it time to calibrate"
                                : "Beats Per Minutes",
                            onPress: () => Navigator.of(context).push(
                                CupertinoPageRoute(
                                    builder: (_) => HeartChart())))
                        : BuildCard(
                            icon: Icons.monitor_heart,
                            text: "Current BPM: ${tWatch!.heartrate!}",
                            sub: tWatch!.heartrate! == 0 ||
                                    tWatch!.heartrate! <= 50
                                ? "Make sure to wear the watch correctly\nGive it time to calibrate"
                                : "Beats Per Minutes",
                            onPress: () {
                              print("MEAW");
                            }),
                    BuildCard(
                        icon: Icons.sensor_occupied_rounded,
                        text: "Accelerometer Data",
                        sub:
                            "X Axis: ${tWatch!.xacc!}, Y Axis: ${tWatch!.yacc!}, Z Axis: ${tWatch!.zacc!}",
                        onPress: () {
                          print("MEAW");
                        }),
                  ],
                ),
              ),
              const SizedBox(
                height: 20,
              )
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

  const BuildCard(
      {Key? key,
      required this.onPress,
      required this.icon,
      required this.text,
      required this.sub})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 5,
        color: Colors.white,
        child: ListTile(
            leading: Icon(icon),
            title: Text(text),
            subtitle: Text(sub),
            trailing: Icon(Icons.arrow_forward_ios_sharp),
            onTap: () => onPress.call()));
  }
}
