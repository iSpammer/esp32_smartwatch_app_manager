import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:test_esp32/widgets/single_section.dart';
import 'widgets/listile.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {

  _showAlert(BuildContext context){
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('AlertDialog Title'),
        content: const Text('AlertDialog description'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, 'Cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'OK'),
            child: const Text('OK'),
          ),
        ],
      ),);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      backgroundColor: const Color(0xfff6f6f6),
      body: Align(
        alignment: Alignment.topCenter,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          child: ListView(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            children: [
              SingleSection(
                title: "General",
                children: [
                  CustomListTile(

                      title: "About Watch",
                      icon: Icons.watch,
                      onTap: ()  {
                        _showAlert(context);

                      }),
                  CustomListTile(
                      onTap: (){
                        _showAlert(context);
                      },
                      title: "Dark Mode",
                      icon: CupertinoIcons.moon,
                      trailing:
                          CupertinoSwitch(value: false, onChanged: (value) {})),
                  CustomListTile(
                    onTap: () {

                    },
                    title: "System Updater",
                    icon: CupertinoIcons.cloud_download,
                  ),
                  CustomListTile(
                      onTap: () {

                      },
                      title: "Security Status",
                      icon: CupertinoIcons.lock_shield),
                  CustomListTile(
                      onTap: () {

                      },
                      title: "Date and Time",
                      icon: CupertinoIcons.time),
                ],
              ),
              SingleSection(
                title: "Network",
                children: [
                  CustomListTile(
                      onTap: () {

                      },
                      title: "SIM Cards and Networks",
                      icon: Icons.sd_card_outlined),
                  CustomListTile(
                    onTap: () {

                    },
                    title: "Wi-Fi",
                    icon: CupertinoIcons.wifi,
                    trailing:
                        CupertinoSwitch(value: false, onChanged: (val) {}),
                  ),
                  CustomListTile(
                    onTap: () {

                    },
                    title: "Bluetooth",
                    icon: CupertinoIcons.bluetooth,
                    trailing: CupertinoSwitch(value: true, onChanged: (val) {}),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

}
