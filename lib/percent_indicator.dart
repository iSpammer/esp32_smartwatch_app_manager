import 'package:flutter/material.dart';

class PercentIndicator extends StatelessWidget {
  final double? percent;
  final Color? color;
  final String? _message;
  final String? avgValue;
  final String? currValue;

  const PercentIndicator.connected({super.key, required this.percent, this.avgValue, this.currValue})
      : color = Colors.green,
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
        color = Colors.black38;

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
             Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _message == 'Disconnected' ? Container(child: Text("Connect to the Watch"),) :Container(
                      //margin: EdgeInsets.all(20),
                      width: 200,
                      height: 205,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        image: DecorationImage(
                          image: AssetImage(
                              'assets/twatch.jpeg'),
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children:[ SizedBox(
                      height: 210,
                      width: 210,
                      child: CircularProgressIndicator(
                        value: percent,
                        color: (percent!*100) < 20 ? Colors.red : (percent!*100) <35 && (percent!*100) > 20 ? Colors.orange : color,
                      ),
                    ),

                    ]
                ),
              ],
            ),


            // SizedBox(
            //   height: 210,
            //   width: 210,
            //   child: CircularProgressIndicator(
            //     value: percent,
            //     color: color,
            //   ),
            // ),


        SizedBox(
          height: 10,
        ),

      ],
    );
  }
}
