import 'dart:ffi';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:bluetooth_classic/bluetooth_classic.dart';
import 'package:bluetooth_classic/models/device.dart';
import 'dart:async';

import 'package:flutter_joystick/flutter_joystick.dart';

void main() {
  runApp(const BluetoothApp());
}

class BluetoothApp extends StatelessWidget {
  const BluetoothApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          ),
        ),
      ),
      home: const BluetoothHomePage(),
    );
  }
}

class BluetoothHomePage extends StatefulWidget {
  const BluetoothHomePage({super.key});

  @override
  State<BluetoothHomePage> createState() => _BluetoothHomePageState();
}

class _BluetoothHomePageState extends State<BluetoothHomePage> {
  final _bluetoothClassic = BluetoothClassic();
  double currentX = 90;
  double currentY = 90;
  double currentSpeed = 0.0;
  bool _isSpeedReceived = false;

  List<Device> _devices = [];
  Uint8List _receivedData = Uint8List(0);
  bool _isScanning = false;
  bool _isConnected = false;
  String _connectedDeviceAddress = "";
  String message = "";
  bool isSended = false;

  // Stream-related
  Stream<Device>? _discoveryStream;
  StreamSubscription<Device>? _discoverySubscription;
  StreamSubscription<Uint8List>? _dataSubscription;

  @override
  void initState() {
    super.initState();
    _initPermissions();
    _listenToData();
    _discoveryStream =
        _bluetoothClassic.onDeviceDiscovered().asBroadcastStream();
  }

  Future<void> _initPermissions() async {
    await _bluetoothClassic.initPermissions();
  }

  void _listenToData() {
    _dataSubscription =
      _bluetoothClassic.onDeviceDataReceived().listen((Uint8List event) {
      setState(() {
      _receivedData = Uint8List.fromList([..._receivedData, ...event]);
      });
      String mess = String.fromCharCodes(_receivedData);
      _receivedData = Uint8List.fromList([]);
      switch (mess) {
      case "R":
       setState(() {
          message = "Right";
        });
        break;
      case "L":
        setState(() {
           message = "Left";
        });
       
        break;
      case "B":
        setState(() {
           message = "Bottom";
        });
        break;
      case "F":
        setState(() {
           message = "Front";
        });
        break;
      case "S":
        setState(() {
           message = "Stop";
        });
        break;
      default:
        setState(() {
           currentSpeed = double.parse(mess).clamp(0, 9);
           isSended = true;
        });
      }
    });
  }

  Future<void> _scanDevices() async {
    setState(() {
      _devices.clear();
      _isScanning = true;
    });

    _discoverySubscription = _discoveryStream?.listen((device) {
      setState(() {
        if (!_devices.any((d) => d.address == device.address)) {
          _devices.add(device);
        }
      });
    });

    await _bluetoothClassic.startScan();
    await Future.delayed(const Duration(seconds: 5));
    await _bluetoothClassic.stopScan();

    await _discoverySubscription?.cancel();
    _discoverySubscription = null;

    setState(() {
      _isScanning = false;
    });
  }

  Future<void> _connectToDevice(Device device) async {
    try {
      const serialUUID = "00001101-0000-1000-8000-00805f9b34fb";
      await _bluetoothClassic.connect(device.address, serialUUID);

      setState(() {
        _isConnected = true;
        _connectedDeviceAddress = device.address;
        _isSpeedReceived = false;
      });

      _sendData("hello");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Đã kết nối tới ${device.name}")),
      );
    } catch (e) {
      print("Kết nối thất bại: $e");
    }
  }

  Future<void> _sendData(String message) async {
    if (!_isConnected) {
      print("Not connected");
      return;
    }

    try {
      await _bluetoothClassic.write(message);
      print("Data sent successfully");
    } catch (e) {
      print("Write error: $e");
    }
  }

  Future<void> _disconnect() async {
    await _bluetoothClassic.disconnect();
    setState(() {
      _isConnected = false;
      _connectedDeviceAddress = "";
      _receivedData = Uint8List(0);
    });
  }

  @override
  void dispose() {
    _bluetoothClassic.disconnect();
    _dataSubscription?.cancel();
    _discoverySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Bluetooth Classic - HC-05"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Nút quét thiết bị
            ElevatedButton.icon(
              onPressed: _isScanning ? null : _scanDevices,
              icon: const Icon(Icons.search, size: 24),
              label: Text(
                _isScanning ? "Đang quét..." : "Quét thiết bị",
                style: const TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Danh sách thiết bị
            Expanded(
              child: _devices.isEmpty
                  ? const Center(
                      child: Text(
                        "Không tìm thấy thiết bị nào.",
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _devices.length,
                      itemBuilder: (context, index) {
                        final device = _devices[index];
                        return Card(
                          elevation: 4,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading:
                                const Icon(Icons.bluetooth, color: Colors.blue),
                            title: Text(
                              device.name ?? "Không rõ tên",
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(device.address),
                            trailing: ElevatedButton(
                              onPressed: () => _connectToDevice(device),
                              child: const Text("Kết nối"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Hiển thị khi đã kết nối
            if (_isConnected) ...[
              const Divider(),
              Text(
                "Đã kết nối với: $_connectedDeviceAddress",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Joystick điều khiển Servo",
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),

              // Joystick
              Center(
                child: Joystick(
                  mode: JoystickMode.all,
                  listener: (details) {
                    double rawX = (details.x + 1) * 90;
                    double rawY = (-details.y + 1) * 90;

                    rawX = rawX.clamp(0, 180);
                    rawY = rawY.clamp(0, 180);

                    int x = (rawX - currentX).abs() > 55
                        ? (rawX > currentX ? 1 : -1)
                        : 0;
                    int y = (rawY - currentY).abs() > 55
                        ? (rawY > currentY ? 1 : -1)
                        : 0;

                    if (x == 1 && y == 0) _sendData("R");
                    if (x == -1 && y == 0) _sendData("L");
                    if (y == 1 && x == 0) _sendData("F");
                    if (y == -1 && x == 0) _sendData("B");
                    // cheo tren
                    if (x == 1 && y == 1) _sendData("J");
                    if (x == 1 && y == -1) _sendData("I");
                    // cheo duoi
                    if (x == -1 && y == 1) _sendData("M");
                    if (x == -1 && y == -1) _sendData("N");
                    // stop
                    if (x == 0 && y == 0) _sendData("S");
                  },
                ),
              ),
              const SizedBox(height: 20),
              // Thanh trượt điều chỉnh tốc độ
              const Text(
                "Điều chỉnh tốc độ:",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Slider(
                value: currentSpeed,
                min: 0,
                max: 9,
                divisions: 10,
                label: currentSpeed.toStringAsFixed(0),
                activeColor: Colors.blue,
                inactiveColor: Colors.grey.shade300,
                onChanged: (value) {
                  setState(() {
                    currentSpeed = value;
                    int speedrun = currentSpeed.toInt();
                    String command = "$speedrun";
                    if(isSended){
                      isSended = false;
                    }
                    else{
                      _sendData(command);
                    }
                    
                  });
                },
              ),
              const SizedBox(height: 20),

              // Nút ngắt kết nối
              ElevatedButton.icon(
                onPressed: _disconnect,
                icon: const Icon(Icons.bluetooth_disabled),
                label: const Text("Ngắt kết nối"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Hiển thị dữ liệu nhận được
              const Text(
                "Dữ liệu nhận được:",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                width: double.infinity,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    message,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
