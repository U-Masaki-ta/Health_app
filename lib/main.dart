import 'dart:async';
import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'database/database.dart';
import 'pet.dart';
import 'dart:math';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(StepcountModelAdapter());
  await Hive.openBox('steps');
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.purple,
      ),
      home: HealthScreen(),
      routes: <String, WidgetBuilder>{
        '/pet': (BuildContext context) => new SecondRoute(),
      },
    );
  }
}

enum AppState {
  DATA_NOT_FETCHED,
  FETCHING_DATA,
  DATA_READY,
  NO_DATA,
  AUTH_NOT_GRANTED
}

class HealthScreen extends StatefulWidget {
  HealthScreen({Key key}) : super(key: key);

  @override
  _HealthScreenState createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  List<HealthDataPoint> _healthDataList = [];
  int onedaysteps = 0;
  String date;
  String tmpdate;
  AppState _state = AppState.DATA_NOT_FETCHED;
  @override
  void initState() {
    super.initState();
  }

  Future<void> fetchData() async {
    if (await Permission.contacts.request().isGranted) {
      // Either the permission was already granted before or the user just granted it.
    }
    // You can request multiple permissions at once.
    Map<Permission, PermissionStatus> statuses =
        await [Permission.activityRecognition].request();
    print(statuses[Permission.location]);

    /// Get everything from midnight until now
    DateTime endDate = DateTime.now();
    DateTime startDate = endDate.add(Duration(days: 1) * -1);
    DateFormat outputdate = DateFormat('yyyy/MM/dd');
    date = outputdate.format(endDate);
    HealthFactory health = HealthFactory();

    /// Define the types to get.
    List<HealthDataType> types = [
      HealthDataType.STEPS,
    ];
    setState(() => _state = AppState.FETCHING_DATA);

    /// You MUST request access to the data types before reading them
    bool accessWasGranted = await health.requestAuthorization(types);

    int steps = 0;

    if (accessWasGranted) {
      try {
        /// Fetch new data
        List<HealthDataPoint> healthData =
            await health.getHealthDataFromTypes(startDate, endDate, types);

        /// Save all the new data points
        _healthDataList.addAll(healthData);
      } catch (e) {
        print("Caught exception in getHealthDataFromTypes: $e");
      }

      /// Filter out duplicates
      _healthDataList = HealthFactory.removeDuplicates(_healthDataList);

      for (int i = 0; i < _healthDataList.length; i++) {
        tmpdate = outputdate.format(_healthDataList[i].dateFrom);
        if (tmpdate == date) {
          steps += _healthDataList[i].value;
        }
      }
      Hive.box('steps').put(date, steps);
      //print("Steps: $steps");

      /// Update the UI to display the results
      setState(() {
        _state =
            _healthDataList.isEmpty ? AppState.NO_DATA : AppState.DATA_READY;
      });
    } else {
      print("Authorization not granted");
      setState(() => _state = AppState.DATA_NOT_FETCHED);
    }
  }

  Widget _contentFetchingData() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Container(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(
              strokeWidth: 10,
            )),
        Text(
          'Fetching data...',
          style: TextStyle(
            fontFamily: 'Molot',
            fontSize: 20,
          ),
        )
      ],
    );
  }

  Widget _contentDataReady() {
    int _step = Hive.box('steps').get(date);
    return Stack(
      alignment: AlignmentDirectional.center,
      children: <Widget>[
        SizedBox(
          width: 150,
          height: 150,
          child: CircularProgressIndicator(
            strokeWidth: 20,
            value: _step / 5000,
          ),
        ),
        Text(
          'Steps\n $_step',
          style: TextStyle(
            fontFamily: 'Molot',
            fontSize: 25,
          ),
        ),
      ],
    );
  }

  Widget _contentNoData() {
    return Text(
      'No Data to show',
      style: TextStyle(
        fontFamily: 'Molot',
        fontSize: 16,
      ),
    );
  }

  Widget _contentNotFetched() {
    return Text(
      'Press the loading button to fetch data',
      style: TextStyle(
        fontFamily: 'Molot',
        fontSize: 16,
      ),
    );
  }

  Widget _authorizationNotGranted() {
    return Text(
      '''Authorization not given.
        For Android please check your OAUTH2 client ID is correct in Google Developer Console.
         For iOS check your permissions in Apple Health.''',
      style: TextStyle(
        fontFamily: 'Molot',
        fontSize: 16,
      ),
    );
  }

  Widget _content() {
    if (_state == AppState.DATA_READY)
      return _contentDataReady();
    else if (_state == AppState.NO_DATA)
      return _contentNoData();
    else if (_state == AppState.FETCHING_DATA)
      return _contentFetchingData();
    else if (_state == AppState.AUTH_NOT_GRANTED)
      return _authorizationNotGranted();

    return _contentNotFetched();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Health app',
          style: TextStyle(
            fontFamily: 'Molot',
            fontSize: 25,
          ),
        ),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.autorenew_sharp),
            onPressed: () {
              fetchData();
            },
          )
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: 300,
            width: double.infinity,
            child: Card(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Text(
                    'Date : $date',
                    style: TextStyle(
                      fontFamily: 'Molot',
                      fontSize: 20,
                    ),
                  ),
                  Center(
                    child: _content(),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 300,
            width: double.infinity,
            child: Card(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Text(
                    "Watching Pet",
                    style: TextStyle(
                      fontFamily: 'Molot',
                      fontSize: 20,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.play_arrow_sharp),
                    color: Colors.purple,
                    iconSize: 64,
                    onPressed: () {
                      int _steps = Hive.box('steps').get(date);
                      if (_steps >= 5000) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            settings: const RouteSettings(name: "/pet"),
                            builder: (context) => ThirdRoute(),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            settings: const RouteSettings(name: "/pet"),
                            builder: (context) => SecondRoute(),
                          ),
                        );
                      }
                    },
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CirclePainter extends CustomPainter {
  void paint(Canvas canvas, Size size) {
    Paint outerCircle = Paint()
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;

    Offset center = Offset(size.width / 2, size.height / 2);
    double radius = min(size.width / 2, size.height / 2) - 7;

    canvas.drawCircle(center, radius, outerCircle);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}
