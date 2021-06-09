import 'dart:async';
import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
//import 'package:hive/hive.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

enum AppState {
  DATA_NOT_FETCHED,
  FETCHING_DATA,
  DATA_READY,
  NO_DATA,
  AUTH_NOT_GRANTED
}

class _MyAppState extends State<MyApp> {
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
    DateFormat outputdate = DateFormat('yyyy-MM-dd');
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

      onedaysteps = steps;
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
        Text('Fetching data...')
      ],
    );
  }

  Widget _contentDataReady() {
    /*
    return ListView.builder(
      itemCount: _healthDataList.length,
      itemBuilder: (_, index) {
        HealthDataPoint p = _healthDataList[index];
        DateFormat outputdate = DateFormat('yyyy-MM-dd');
        String tmpdate = outputdate.format(p.dateFrom);
        return ListTile(
          title: Text("${p.typeString}: ${p.value}"),
          subtitle: Text('$tmpdate'),
        );
      },
    );
    */
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text('Date : $date '),
        Text(' Steps : $onedaysteps'),
      ],
    );
  }

  Widget _contentNoData() {
    return Text('No Data to show');
  }

  Widget _contentNotFetched() {
    return Text('Press the loading button to fetch data');
  }

  Widget _authorizationNotGranted() {
    return Text('''Authorization not given.
        For Android please check your OAUTH2 client ID is correct in Google Developer Console.
         For iOS check your permissions in Apple Health.''');
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
    return MaterialApp(
      home: Scaffold(
          appBar: AppBar(
            title: const Text('Health app'),
            actions: <Widget>[
              IconButton(
                icon: Icon(Icons.autorenew_sharp),
                onPressed: () {
                  fetchData();
                },
              )
            ],
          ),
          body: Center(
            child: _content(),
          )),
    );
  }
}
