
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:test_esp32/bluetooth_devices.dart';
import 'package:test_esp32/percent_indicator.dart';

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
  double? percentValue;
  double? avgvalue = 0;
  double? currvalue = 0;
  double? temp = 0;
  double? batSOC = 0;

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

    // Create message if there is new line character
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

    // calculate percentage from message
    // analog 10 bit
    if (message.isEmpty) return; // to avoid fomrmat exception
    var dateList = message.split(" ");
    double? analogMessage = double.tryParse(dateList[0].trim());
    double? analogMessage2 = double.tryParse(dateList[1].trim());
    double? analogMessage3 = double.tryParse(dateList[2].trim());
    double? analogMessage4 = double.tryParse(dateList[3].trim());
    setState(() {
      var percent = (analogMessage ?? 0) / 220;
      percentValue = percent; // inverse percent
      avgvalue = analogMessage;
      currvalue = analogMessage2;
      batSOC = analogMessage3;
      temp = analogMessage4;
    });

    print("new msg $dateList perc ${percentValue!}");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_bluetooth),
            onPressed: () async {
              BluetoothDevice? device = await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BluetoothDevices()));

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
        ],
      ),
      body: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            const SizedBox(height: 20,),
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
                      avgValue: avgvalue!.toString(),
                    );
                  case BluetoothConnectionState.error:
                    return const PercentIndicator.error();
                }
              },
            ),
            const SizedBox(height: 50),
            Card(child: ListTile(leading: Icon(Icons.battery_std) ,title: Text("Battery Percentage: ${batSOC!}"),),),
            Card(child: ListTile(leading: Icon(Icons.monitor_heart) ,title: Text("Current BPM: ${currvalue!}"),),),
            Card(child: ListTile(leading: Icon(Icons.monitor_heart_outlined) ,title: Text("AVG BPM: ${avgvalue!}"),),),
            Card(child: ListTile(leading: Icon(Icons.sunny) ,title: Text("Current Temperature: ${temp!}"),),),

          ],
        ),
      ),
    );
  }
}
