import 'package:flutter/material.dart';

class PercentIndicator extends StatelessWidget {
  final double? percent;
  final Color? color;
  final String? _message;
  final String? avgValue;
  final String? currValue;

  const PercentIndicator.connected({super.key, required this.percent, this.avgValue, this.currValue})
      : color = null,
        _message = null;

  PercentIndicator.connecting({super.key})
      : percent = null,
        avgValue = null,
        currValue = null,
        _message = 'Connecting...',
        color = Colors.grey.shade300;

  const PercentIndicator.disconnected({super.key})
      : percent = 1.0,
        avgValue = null,
        currValue = null,
      _message = 'Disconnected',
        color = Colors.purple;

  const PercentIndicator.error({super.key})
      : percent = 1.0,
        avgValue = null,
        currValue = null,
      _message = 'Error',
        color = Colors.red;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          children: [
            SizedBox(
              height: 210,
              width: 210,
              child: CircularProgressIndicator(
                value: percent,
                color: color,
              ),
            ),
            SizedBox(
              height: 210,
              width: 210,
              child: Center(
                child: Text(
                  _message != null
                      ? _message!
                      : '${((percent ?? 0) * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w200,
                  ),
                ),
              ),
            ),

          ],
        ),
        SizedBox(
          height: 10,
        ),
        Text(avgValue == null || avgValue == "0" || percent == 0
            ? "Calibration takes 10 minuts please wait"
            : "Average BPM is " + avgValue!),
        currValue == null || currValue == 0 ? Text("") : Text("Current Value is "+currValue.toString())
      ],
    );
  }
}
