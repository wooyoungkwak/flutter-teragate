import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:beacons_plugin/beacons_plugin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:teragate_test/models/beacon_model.dart';
import 'package:teragate_test/services/network_service.dart';
import 'package:teragate_test/services/work_service.dart';

//íėŽėę°
import 'package:date_format/date_format.dart';
import 'package:timer_builder/timer_builder.dart';

import 'package:teragate_test/config/env.dart';
import 'package:teragate_test/states/login_state.dart';
import 'package:teragate_test/states/webview_state.dart';
import 'package:teragate_test/utils/alarm_util.dart';

class Beacon extends StatefulWidget {
  const Beacon({Key? key}) : super(key: key);

  @override
  BeaconState createState() => BeaconState();
}

class BeaconState extends State<Beacon> with WidgetsBindingObserver {
  // DateTime now = DateTime.now();
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  int _nrMessagesReceived = 0;
  final _results = [];

  final String _tag = "Beacons Plugin";
  var isRunning = false;
  bool _isInForeground = true;
  String? deviceip = "00";
  String? userId = "1";
  String? name = "test";
  var flutterSecureStorage = const FlutterSecureStorage();
  String? id = "test1"; //id
  String? pw = "test2"; //pw
  var workSucces = false;

  late DateTime alert;
  final StreamController<String> beaconEventsController = StreamController<String>.broadcast();

  @override
  void initState() {
    init();
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initPlatformState();
    
    const duration = Duration(seconds: 10);
    alert = DateTime.now().add(duration);

    // initialise the plugin. app_icon needs to be a added as a drawable resource to the Android head project
    var initializationSettingsAndroid = const AndroidInitializationSettings('app_icon');
    var initializationSettingsIOS = const IOSInitializationSettings(onDidReceiveLocalNotification: null);
    var initializationSettings = InitializationSettings( android: initializationSettingsAndroid, iOS: initializationSettingsIOS);
    flutterLocalNotificationsPlugin.initialize(initializationSettings, onSelectNotification: null);
  }

  Future init() async {
    //ėŽėĐíë ęļ°ęļ°ė IP ę°ė ļėĪęļ°
    final Map<String, dynamic> wifiInfo = await WifiInfo.getIPAddress();
    if (!mounted) return;
    deviceip = wifiInfo["ip"];
    if(Env.isDebug) debugPrint(deviceip);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _isInForeground = state == AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    beaconEventsController.close();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    if (Platform.isAndroid) {
      //Prominent disclosure
      await BeaconsPlugin.setDisclosureDialogMessage(
          title: "Background Locations",
          message:
              "[This app] collects location data to enable [feature], [feature], & [feature] even when the app is closed or not in use");

      //Only in case, you want the dialog to be shown again. By Default, dialog will never be shown if permissions are granted.
      //await BeaconsPlugin.clearDisclosureDialogShowFlag(false);
    }

    BeaconsPlugin.listenToBeacons(beaconEventsController);

    if (Platform.isAndroid) {
      BeaconsPlugin.channel.setMethodCallHandler((call) async {
        if(Env.isDebug) debugPrint("Method: ${call.method}");
        if (call.method == 'scannerReady') {
          _showNotification("Beacons monitoring started..");
          await BeaconsPlugin.startMonitoring();
          setState(() {
            isRunning = true;
          });
        } else if (call.method == 'isPermissionDialogShown') {
          _showNotification(
              "Prominent disclosure message is shown to the user!");
        }
      });
    } else if (Platform.isIOS) {
      _showNotification("Beacons monitoring started..");
      await BeaconsPlugin.startMonitoring();
      setState(() {
        isRunning = true;
      });
    }

    /* BeaconsPlugin.addRegion("myBeacon", "01022022-f88f-0000-00ae-9605fd9bb620");
    BeaconsPlugin.addRegion("iBeacon", "12345678-1234-5678-8f0c-720eaf059935");
 */

    await BeaconsPlugin.addRegion(
        "Teraenergy", "12345678-1234-5678-8f0c-720eaf059935");

     BeaconsPlugin.addBeaconLayoutForAndroid(
        "m:2-3=beac,i:4-19,i:20-21,i:22-23,p:24-24,d:25-25");
      BeaconsPlugin.addBeaconLayoutForAndroid(
          "m:2-3=0215,i:4-19,i:20-21,i:22-23,p:24-24");
     

    BeaconsPlugin.setForegroundScanPeriodForAndroid(foregroundScanPeriod: 2200, foregroundBetweenScanPeriod: 10);

    BeaconsPlugin.setBackgroundScanPeriodForAndroid(backgroundScanPeriod: 2200, backgroundBetweenScanPeriod: 10);

    beaconEventsController.stream.listen(
        (data) async {
          if (data.isNotEmpty && isRunning) {
            //if (_nrMessagesReceived <= 2) {
              setState(() {
                _results.add("ėķę·ž ėēëĶŽ ėĪėëëĪ");
                _showNotification("ėķę·ž ėēëĶŽ ėĪėëëĪ.");
                _nrMessagesReceived++;
              });

              if (!_isInForeground) {
                _showNotification("Beacons DataReceived: " + data);
              }

              if(Env.isDebug) debugPrint("Beacons DataReceived: " + data);
            //}
            if (!workSucces) {
              _nrMessagesReceived = 0;
              BeaconsPlugin.stopMonitoring(); //ëŠĻëí°ë§ ėĒëĢ
              setState(() {
                //ėĪėš ėĒëĢ
                isRunning = !isRunning;
              });

              Map<String, dynamic> userMap = jsonDecode(data);
              if(Env.isDebug) debugPrint(userMap.toString());
              var iBeacon = BeaconData.fromJson(userMap);
              
              if(Env.isDebug) debugPrint('ėëíėļė, ${iBeacon.name} íėŽ!');
              if(Env.isDebug) debugPrint('${iBeacon.minor} ėĪëė ėļėĶ key ėëëĪ(ëđė―)');

              String beaconKey = iBeacon.minor; // ëđė―ė key ę°
              bool keySucces = false; // key ėžėđėŽëķ íėļ

              //DBėė key ę°ė ļėĪęļ°
/*               var url = Uri.parse("${Env.SERVER_URL}/keyCheck");
              var response = await http.get(url);
              var result = utf8.decode(response.bodyBytes);
              Map<String, dynamic> keyMap = jsonDecode(result);
              var cheak_key = keyinfo.fromJson(keyMap);
              if(Env.isDebug) debugPrint('DB key :' + '${cheak_key.commute_key}');
              String dbKey = '${cheak_key.commute_key}'; ėėė ęą° */

              String dbKey = '50000'; //ėėëĄ ęģ ė 

              userId = await flutterSecureStorage.read(key: 'user_id');
              name = await flutterSecureStorage.read(key: 'kr_name');
              id = await flutterSecureStorage.read(key: 'LOGIN_ID');
              pw = await flutterSecureStorage.read(key: 'LOGIN_PW');

              if (beaconKey == dbKey) {
                keySucces = true;
              } else {
                keySucces = false;
              }

              if (keySucces) {
                checkOverlapForGetIn(userId);
                //DB:ėķę·ž ęļ°ëĄ íėļ

                if (true) {
                  //ėķę·ž
                  if(Env.isDebug) debugPrint("#############ėķę·žė§ė############");
                  getIn(userId, deviceip).then((data) {
                    //ėķę·žė ëí ė ëģī dbė ėĨ
                    debugPrint(data);
                    flutterDialog(context, "ėķę·žíėĻėĩëëĪ $nameë!"); //ëĪėīėžëĄę·ļė°―
                    setState(() {
                      _results.add("msg: $nameë ėķę·ž");
                      alert = DateTime.now().add(const Duration(seconds: 10));
                      _showNotification("ėķę·žíėĻėĩëëĪ");
                      workSucces = true;
                    });
                  });
                }
/*                      else {
                      if(Env.isDebug) debugPrint(data.success);
                      flutterDialog(context, " ${name}ë ėīëŊļ ėķę·žíėĻėĩëëĪ."); //ëĪėīėžëĄę·ļė°―
                      setState(() {
                        _results.add("msg: ${name}ë ėīëŊļ ėķę·ž íėĻėĩëëĪ");
                      });
                    } */

              } else {
                flutterDialog(context, "Keyę°ėī ëĪëĶëëĪ. ėŽėë íīėĢžėļė!"); //ëĪėīėžëĄę·ļė°―
              }
              _nrMessagesReceived = 0;
              keySucces = false;
            }
          }
        },
        onDone: () {},
        onError: (error) {
          if(Env.isDebug) debugPrint("Error: $error");
        });

    //Send 'true' to run in background
    await BeaconsPlugin.runInBackground(true);

    if (!mounted) return;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('TERA GATE ėķíīę·ž'),
          automaticallyImplyLeading: false,
          actions: <Widget>[
            IconButton(
              onPressed: () {
                logoutBtn();

              },
              icon: const Icon(
                Icons.logout_rounded,
              ),
            ),
          ],
        ),
        body: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[              
           Container(
            child: const Text("ę·ží íėļ", style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.blue,) ,),
            margin: const EdgeInsets.all(8.0),
          ),
          const SizedBox(
            height: 20.0,
            ),
              Expanded(child: comuteItem()), // ëģęē― ui ėķë Ĩ íėĪíļ
              TimerBuilder.periodic(
                const Duration(seconds: 1),
                builder: (context) {
                  return Text(
                    formatDate(DateTime.now(), [hh, ':', nn, ':', ss, ' ', am]),
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w200,
                    ),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.all(2.0),
                child: ElevatedButton(
                  onPressed: () async {
                    if (isRunning) {
                      await BeaconsPlugin.stopMonitoring(); //ëđė― ėĪėš ėė
                    } else {
                      initPlatformState();
                      await BeaconsPlugin.startMonitoring(); //ëđė― ėĪėš ėĒëĢ
                    }
                    setState(() {
                      isRunning = !isRunning;
                    });
                  },
                  child: Text(isRunning ? 'ėķę·ž ėēëĶŽėĪ' : 'ėķ ę·ž',
                      style: const TextStyle(fontSize: 20)),
                ),
              ),
              Visibility(
                visible: _results.isNotEmpty,
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: ElevatedButton(
                    onPressed: () async {
                      leaveWork();
                    },
                    child: const Text("íī ę·ž", style: TextStyle(fontSize: 20)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(2.0),
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => WebView(id!, pw!, null)));
                  },
                  child: const Text('ę·ļëĢđėĻėī ', style: TextStyle(fontSize: 20)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(2.0),
                child: ElevatedButton(
                  onPressed: () async {
                    logoutBtn();
                  },
                  child: const Text('ëĄę·ļėė ', style: TextStyle(fontSize: 20)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(2.0),
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => WebView(id!, pw!, null)));
                  },
                  child: const Text('ėė ', style: TextStyle(fontSize: 20)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(2.0),
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => WebView(id!, pw!, null)));
                  },
                  child: const Text('ėĪė§ ', style: TextStyle(fontSize: 20)),
                ),
              ),

              
            ],
          ),
        ),
      ),
    );
  }

  Future logoutBtn() {
    return showDialog(
        context: context,
        barrierDismissible: false, // ë°ęđĨ ėė­ í°ėđė ëŦėė§ ėŽëķ
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('ëĄę·ļėė'),
            content: SingleChildScrollView(
              child: ListBody(
                children: const <Widget>[
                  Text('ëĄę·ļėļ íėīė§ëĄ ėīëíėęē ėĩëęđ?'),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('ok'),
                onPressed: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const Login()));
                },
              ),
              TextButton(
                child: const Text('cancel'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        });
  }

  //íīę·ž ęļ°ëĨ
  void leaveWork() {
    getOut(userId, deviceip).then((data) {
      if (data.success) {
        if(Env.isDebug) debugPrint("#############íīę·žė§ė############");
        flutterDialog(context, "íīę·žíėĻėĩëëĪ $nameë!"); //ëĪėīėžëĄę·ļė°―
      } else {
        flutterDialog(context, "íīę·žėēëĶŽę° ėëĐëëĪ"); //ëĪėīėžëĄę·ļė°―
      }
      setState(() {
        _results.add("msg: $nameë íīę·ž");
      });
    });
  }

  void _showNotification(String subtitle) {
    var rng = Random();
    Future.delayed(const Duration(seconds: 5)).then((result) async {
      var androidPlatformChannelSpecifics = const AndroidNotificationDetails(
          'your channel id', 'your channel name',
          importance: Importance.high,
          priority: Priority.high,
          ticker: 'ticker');
      var iOSPlatformChannelSpecifics = const IOSNotificationDetails();
      var platformChannelSpecifics = NotificationDetails(
          android: androidPlatformChannelSpecifics,
          iOS: iOSPlatformChannelSpecifics);
      await flutterLocalNotificationsPlugin.show(
          rng.nextInt(100000), _tag, subtitle, platformChannelSpecifics,
          payload: 'item x');
    });
  }

  // void flutterDialog(context, String text) {
  //   showDialog(
  //       context: context,
  //       //barrierDismissible - DialogëĨž ė ėļí ëĪëĨļ íëĐī í°ėđ x
  //       barrierDismissible: false,
  //       builder: (BuildContext context) {
  //         return AlertDialog(
  //           // RoundedRectangleBorder - Dialog íëĐī ëŠĻėëĶŽ ëĨęļęē ėĄ°ė 
  //           shape: RoundedRectangleBorder(
  //               borderRadius: BorderRadius.circular(10.0)),
  //           //Dialog Main Title
  //           title: Column(
  //             children: const <Widget>[
  //               Text("Dialog Title"),
  //             ],
  //           ),
  //           //
  //           content: Column(
  //             mainAxisSize: MainAxisSize.min,
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: <Widget>[
  //               Text(
  //                 text,
  //               ),
  //             ],
  //           ),
  //           actions: <Widget>[
  //             FlatButton(
  //               child: const Text("íėļ"),
  //               onPressed: () {
  //                 Navigator.pop(context);
  //               },
  //             ),
  //           ],
  //         );
  //       });
  // }

  Widget comuteItem() {
    return Scaffold(
      body: Column(
      crossAxisAlignment:  CrossAxisAlignment.start,

        children: <Widget>[
                    Container(
            child: Text("ėīëĶ : $name", style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.blue,) ,),
            margin: const EdgeInsets.all(8.0),
          ),
          Container(
            child: Text("ė ė ėėīë : $userId", style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.blue,) ,),
            margin: const EdgeInsets.all(8.0),
          ),
          Container(
            child: Text("ëë°ėīėĪ ėėīíž : $deviceip", style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.blue,) ,),
            margin: const EdgeInsets.all(8.0),
          ),
          Container(
            child: Text("ė ėėę° : $alert", style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.blue,) ,),
            margin: const EdgeInsets.all(8.0),
          )
      ]),

    );
  }


}

