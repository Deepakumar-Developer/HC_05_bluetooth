import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';

import '../function/app_function.dart';


class MyMainPage extends StatefulWidget {
  const MyMainPage({super.key});

  @override
  State<MyMainPage> createState() => _MyMainPageState();
}

class _MyMainPageState extends State<MyMainPage> {
  // Bluetooth State Variables
  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;
  BluetoothConnection? _connection;
  StreamSubscription<Uint8List>? _dataSubscription;

  // UI State Variables
  List<BluetoothDevice> _bondedDevices = [];
  String _statusMessage = "Initializing...";
  bool _isConnecting = false;
  bool _isLightOn = false; // Tracks the confirmed state of the light

  // --- IN-MEMORY LOGGING LIST ---
  // Stores the ON/OFF event and its precise time.
  List<LocalLightLog> _logHistory = [];

  static const String hc05Name = 'HC-05';
  String _dataBuffer = "";

  @override
  void initState() {
    super.initState();
    _initializeBluetooth();
  }

  void _initializeBluetooth() async {
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
    await Permission.location.request();
    // Check initial state
    FlutterBluetoothSerial.instance.state.then((state) {
      setState(() => _bluetoothState = state);
    });
    // Listen for state changes (e.g., user turns Bluetooth ON/OFF or grants permission)
    FlutterBluetoothSerial.instance.onStateChanged().listen((BluetoothState state) {
      setState(() {
        print('hi');
        print(state.toString());
        _bluetoothState = state;
        _statusMessage = "Bluetooth is ${state.toString().split('.').last}";
      });
      if (!state.isEnabled) {
        _disconnect();
      }
    });
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    _connection?.dispose();
    super.dispose();
  }

  // --- Bluetooth Communication Logic ---

  Future<void> _getBondedDevices() async {
    if (_bluetoothState == BluetoothState.STATE_OFF) {
      setState(() => _statusMessage = "Bluetooth is OFF. Please enable it.");
      return;
    }
    setState(() => _statusMessage = "Searching for paired devices...");
    try {
      List<BluetoothDevice> bonded = await FlutterBluetoothSerial.instance.getBondedDevices();
      setState(() {
        _bondedDevices = bonded;
        _statusMessage = "Found ${_bondedDevices.length} paired devices.";
      });
    } catch (e) {
      setState(() => _statusMessage = "Error getting devices: $e");
    }
  }

  void _connectToHC05() async {
    await _getBondedDevices();
    for (var val in _bondedDevices) {
      print('${val.name} - ${val.address}');
    }

    BluetoothDevice? targetDevice = _bondedDevices.firstWhere(
          (device) => device.name == hc05Name || device.address == hc05Name,
    );

    setState(() {
      _isConnecting = true;
      _statusMessage = "Connecting to ${targetDevice.name} (${targetDevice.address})...";
    });

    try {
      _connection = await BluetoothConnection.toAddress(targetDevice.address);
      setState(() {
        _statusMessage = "Connected to ${targetDevice.name}! Send commands now.";
        _isConnecting = false;
      });
      _listenForData(); // Start listening for Arduino's confirmation
    } catch (e) {
      setState(() {
        _statusMessage = "Connection failed: $e";
        _isConnecting = false;
      });
      _disconnect();
    }
  }

  Future<void> _sendData(String data) async {
    if (_connection != null && _connection!.isConnected) {
      try {
        // Send '1' or '0' command to Arduino
        print('data send');
        _connection!.output.add(Uint8List.fromList(ascii.encode(data)));
        await _connection!.output.allSent;
        // Wait for the Arduino to send confirmation ('LIGHT_ON' or 'LIGHT_OFF')
        setState(() => _statusMessage = "Command sent: $data. Waiting for confirmation...");
      } catch (e) {
        setState(() => _statusMessage = "Error sending command: $e");
      }
    } else {
      setState(() => _statusMessage = "Not connected. Cannot send data.");
    }
  }

  void _listenForData() {
    _dataSubscription = _connection!.input!.listen((Uint8List data) {
      String incoming = ascii.decode(data);
      _dataBuffer += incoming;

      int newlineIndex;
      while ((newlineIndex = _dataBuffer.indexOf('\n')) != -1) {
        String completePacket = _dataBuffer.substring(0, newlineIndex + 1);
        _dataBuffer = _dataBuffer.substring(newlineIndex + 1);
        String trimmedPacket = completePacket.trim();

        // --- Process Confirmation Signal from Arduino ---
        if (trimmedPacket == "LIGHT_ON") {
          setState(() {
            _isLightOn = true;
            _statusMessage = "Light turned ON (Confirmed by HC-05)";
          });
          _logLightStatus("ON");
        } else if (trimmedPacket == "LIGHT_OFF") {
          setState(() {
            _isLightOn = false;
            _statusMessage = "Light turned OFF (Confirmed by HC-05)";
          });
          _logLightStatus("OFF");
        } else {
          debugPrint("Received unexpected data: $trimmedPacket");
        }
      }

    }, onDone: () {
      setState(() {
        _statusMessage = "Disconnected by remote device.";
      });
      _disconnect();
    }, onError: (e) {
      setState(() {
        _statusMessage = "Connection error: $e";
      });
      _disconnect();
    });
  }

  void _disconnect() {
    _dataSubscription?.cancel();
    _connection?.dispose();
    _connection = null;
    setState(() {
      _isConnecting = false;
    });
  }

  // --- Local Logging Logic ---

  void _logLightStatus(String status) {
    // 1. Create a new log entry
    final logEntry = LocalLightLog(status, DateTime.now());

    // 2. Add it to the front of the list (to show newest entries first)
    setState(() {
      _logHistory.insert(0, logEntry);
    });
  }


  // --- UI Building ---

  @override
  Widget build(BuildContext context) {
    bool isConnected = _connection != null && _connection!.isConnected;
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(onTap:(){
          // print(BluetoothState.);
        },child: const Text('HC-05 Light Controller')),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _buildStatusCard(isConnected),
            const SizedBox(height: 20),

            // LIGHT CONTROL PANEL
            _buildLightControlPanel(isConnected),
            const SizedBox(height: 20),

            // CONNECTION BUTTONS
            isConnected
                ? _buildDisconnectButton()
                : _buildConnectButton(),

            const SizedBox(height: 30),

            // LOGGING HISTORY
            _buildLogHistory(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(bool isConnected) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isConnected ? Colors.green.shade50 : Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              isConnected ? 'BLUETOOTH STATUS: CONNECTED' : 'BLUETOOTH STATUS: DISCONNECTED',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isConnected ? Colors.green.shade800 : Colors.red.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLightControlPanel(bool isConnected) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text(
              'Light Control',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.indigo.shade700,
              ),
            ),
            const SizedBox(height: 20),
            Icon(
              _isLightOn ? Icons.lightbulb_sharp : Icons.lightbulb_outline,
              size: 100,
              color: _isLightOn ? Colors.amber.shade700 : Colors.grey.shade400,
            ),
            const SizedBox(height: 20),
            Text(
              _isLightOn ? 'Light is ON' : 'Light is OFF',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: _isLightOn ? Colors.green.shade600 : Colors.red.shade600,
              ),
            ),
            const SizedBox(height: 20),
            Switch.adaptive(
              value: _isLightOn,
              onChanged: isConnected ? (value) {
                // Send '1' for ON, '0' for OFF. Wait for confirmation to update _isLightOn
                _sendData(value ? '1' : '0');
              } : null,
              activeColor: Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisconnectButton() {
    return ElevatedButton.icon(
      onPressed: _disconnect,
      icon: const Icon(Icons.bluetooth_disabled),
      label: const Text('DISCONNECT', style: TextStyle(fontSize: 18)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red.shade600,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
      ),
    );
  }

  Widget _buildConnectButton() {
    return ElevatedButton.icon(
      onPressed: _isConnecting ? null : _connectToHC05,
      icon: _isConnecting
          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : const Icon(Icons.bluetooth_connected),
      label: Text(_isConnecting ? 'CONNECTING...' : 'CONNECT TO $hc05Name', style: const TextStyle(fontSize: 18)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
      ),
    );
  }

  Widget _buildLogHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Light Timing Log (Local Memory)',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo),
        ),
        const Divider(),
        if (_logHistory.isEmpty)
          const Center(child: Text("No light activity recorded yet. Turn the light ON/OFF to begin logging.", style: TextStyle(color: Colors.grey)))
        else
        // List of log entries
          ..._logHistory.map((log) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                Icon(
                  log.status == 'ON' ? Icons.lightbulb_sharp : Icons.lightbulb_outline,
                  color: log.status == 'ON' ? Colors.amber.shade700 : Colors.grey,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    // Format timestamp to local time without milliseconds
                    '${log.status} at ${log.timestamp.toLocal().toString().substring(0, 19)}',
                    style: TextStyle(
                      fontWeight: log.status == 'ON' ? FontWeight.bold : FontWeight.normal,
                      color: log.status == 'ON' ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ),
          )).toList(),
      ],
    );
  }
}
