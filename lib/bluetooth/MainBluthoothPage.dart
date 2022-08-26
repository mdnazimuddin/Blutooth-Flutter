// ignore_for_file: library_private_types_in_public_api, file_names

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

// import './helpers/LineChart.dart';

class MainBluthoothPage extends StatefulWidget {
  const MainBluthoothPage({Key? key}) : super(key: key);

  @override
  _MainBluthoothPage createState() => _MainBluthoothPage();
}

class _MainBluthoothPage extends State<MainBluthoothPage> {
  BluetoothDevice server =
      const BluetoothDevice(address: "30:C6:F7:29:35:E6", name: "ESP32");

  @override
  void initState() {
    super.initState();

    Future.doWhile(() async {
      // Wait if adapter not enabled
      if ((await FlutterBluetoothSerial.instance.isEnabled) ?? false) {
        return false;
      }
      await Future.delayed(const Duration(milliseconds: 0xDD));
      return true;
    }).then((_) {
      // Update the address field
    });

    startBluthooth();
  }

  BluetoothConnection? connectionDevice;

  late String _messageBuffer = '';

  bool isConnecting = true;
  bool get isConnected => (connectionDevice?.isConnected ?? false);

  bool isDisconnecting = false;
  startBluthooth() async {
    await FlutterBluetoothSerial.instance.requestEnable();
    // FlutterBluetoothSerial.instance
    //     .setPairingRequestHandler((BluetoothPairingRequest request) {
    //   print("Trying to auto-pair with Pin 1234");
    //   if (request.pairingVariant == PairingVariant.Pin) {
    //     return Future.value("1234");
    //   }
    //   return Future.value(null);
    // });

    BluetoothConnection.toAddress(server.address).then((connection) {
      print('Connected to the device');
      setState(() {
        connectionDevice = connection;
        isConnecting = false;
        isDisconnecting = false;
      });

      connection.input!.listen(_onDataReceived).onDone(() {
        if (isDisconnecting) {
          print('Disconnecting locally!');
        } else {
          print('Disconnected remotely!');
        }
        if (mounted) {
          setState(() {});
        }
      });
      if (isConnected) {
        _sendMessage('open');
      }
    }).catchError((error) {
      print('Cannot connect, exception occured');
      print(error);
    });
  }

  void _onDataReceived(Uint8List data) {
    // Allocate buffer for parsed data
    int backspacesCounter = 0;
    for (var byte in data) {
      if (byte == 8 || byte == 127) {
        backspacesCounter++;
      }
    }
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
    print(dataString);
    int index = buffer.indexOf(13);
    if (~index != 0) {
      setState(() {
        _messageBuffer = dataString.substring(index);
      });
    } else {
      _messageBuffer = (backspacesCounter > 0
          ? _messageBuffer.substring(
              0, _messageBuffer.length - backspacesCounter)
          : _messageBuffer + dataString);
    }
  }

  @override
  void dispose() {
    FlutterBluetoothSerial.instance.setPairingRequestHandler(null);
    if (isConnected) {
      isDisconnecting = true;
      connectionDevice?.dispose();
      connectionDevice = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Bluetooth Serial'),
      ),
      body: Center(
        child: TextButton.icon(
            label: const Text("Open Door"),
            onPressed: (() => startBluthooth()),
            icon: const Icon(Icons.swipe)),
      ),
    );
  }

  void _sendMessage(String text) async {
    text = text.trim();
    if (text.isNotEmpty) {
      try {
        connectionDevice!.output
            .add(Uint8List.fromList(utf8.encode("$text\r\n")));
        await connectionDevice!.output.allSent;

        // await FlutterBluetoothSerial.instance.requestDisable();
        if (isConnected) {
          isDisconnecting = true;
          connectionDevice?.dispose();
          connectionDevice = null;
        }
      } catch (e) {
        // Ignore error, but notify state
        setState(() {});
      }
    }
  }
}
