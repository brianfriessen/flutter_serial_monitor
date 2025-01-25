// Flutter app to monitor serial port data using the flutter_libserialport plugin.
// The app allows you to select a serial port, configure the port settings, and send and receive data.
// Only tested on MacOS.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';

void main() => runApp(SerialMonitorApp());

class SerialMonitorApp extends StatelessWidget {
  const SerialMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Serial Port Monitor',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: SerialMonitorScreen(),
    );
  }
}

class SerialMonitorScreen extends StatefulWidget {
  const SerialMonitorScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _SerialMonitorScreenState createState() => _SerialMonitorScreenState();
}

class _SerialMonitorScreenState extends State<SerialMonitorScreen> {
  final _receivedTextController = ScrollController();
  final _inputController = TextEditingController();
  final _receivedData = StringBuffer();
  final _inputTextData = StringBuffer();
  SerialPort? _port;
  bool _isConnected = false;
  var _availablePorts = <String>[];
  String? _selectedPort;
  
  final _baudRates = [110, 300, 600, 1200, 2400, 4800, 9600, 14400, 19200, 38400, 57600, 115200];
  final _stopBits = [1, 2];
  final _dataBits = [5, 6, 7, 8];
  final _parities = [SerialPortParity.none, SerialPortParity.odd, SerialPortParity.even];
  final _flowControls = [
    SerialPortFlowControl.none,
    SerialPortFlowControl.dtrDsr,
    SerialPortFlowControl.rtsCts,
    SerialPortFlowControl.xonXoff
  ];

  int _baudRate = 115200;
  int _stopBit = 1;
  int _dataBit = 8;
  int _parity = SerialPortParity.none;
  int _flowControl = SerialPortFlowControl.none;

  StreamSubscription<Uint8List>? _subscription;
  SerialPortReader? _reader;

  @override
  void initState() {
    super.initState();
    initPorts();
  }

  @override
  void dispose() {
    _closePort();
    _receivedTextController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  void initPorts() {
    setState(() {
      _availablePorts = SerialPort.availablePorts;
      _selectedPort = _availablePorts.isNotEmpty ? _availablePorts.first : null;
    });
  }

  void _showError(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _openPort() {
    if (_selectedPort == null) return;

    try {
      _port = SerialPort(_selectedPort!);
      _port!.openReadWrite();

      final config = SerialPortConfig()
        ..baudRate = _baudRate
        ..bits = _dataBit
        ..stopBits = _stopBit
        ..parity = _parity
        ..setFlowControl(_flowControl);

      _port!.config = config;

      _reader = SerialPortReader(_port!);
      _subscription = _reader!.stream.listen(
        (data) {
          setState(() {
            _receivedData.write(_formatReceivedData(utf8.decode(data)));
          });
          _scrollToBottom();
        },
        onError: (error) {
          _showError('Error', 'Serial port error: $error');
          _closePort();
        },
        onDone: () {
          _closePort();
          _showError('Disconnected', 'Serial port closed');
        },
      );

      setState(() => _isConnected = true);
    } on SerialPortError catch (err) {
      _showError('Port Error', err.message);
    } catch (err) {
      _showError('Error', err.toString());
    }
  }

  void _closePort() {
    _subscription?.cancel();
    _reader = null;
    if (_port?.isOpen == true) {
      _port!.close();
      _port = null;
    }
    setState(() => _isConnected = false);
  }

  String _formatReceivedData(String data) {
    final now = DateTime.now();
    final time = DateFormat('HH:mm:ss.SSS').format(now);
    return '[$time] $data\n';
  }

  Future<void> _scrollToBottom() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (_receivedTextController.hasClients) {
      _receivedTextController.animateTo(
        _receivedTextController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendData() {
    if (!_isConnected || _inputController.text.isEmpty) return;

    final data = _inputController.text;
    try {
      _port!.write(Uint8List.fromList(utf8.encode('$data\n')));
      setState(() {
        _inputTextData.write('$data\n');
        _inputController.clear();
      });
      _scrollToBottom();
    } on SerialPortError catch (e) {
      _showError('Send Error', e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Serial Port Monitor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: initPorts,
          ),
          IconButton(
            icon: Icon(_isConnected ? Icons.link_off : Icons.link),
            onPressed: _isConnected ? _closePort : _openPort,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Wrap(
              spacing: 16.0,
              runSpacing: 8.0,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                IntrinsicWidth(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Port:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButton<String>(
                          value: _selectedPort,
                          isExpanded: true,
                          items: _availablePorts
                              .map((port) => DropdownMenuItem(value: port, child: Text(port)))
                              .toList(),
                          onChanged: (port) => setState(() => _selectedPort = port),
                        ),
                      ),
                    ],
                  ),
                ),
                IntrinsicWidth(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Baud Rate:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButton<int>(
                          value: _baudRate,
                          isExpanded: true,
                          items: _baudRates
                              .map((rate) => DropdownMenuItem(value: rate, child: Text(rate.toString())))
                              .toList(),
                          onChanged: (rate) => setState(() => _baudRate = rate!),
                        ),
                      ),
                    ],
                  ),
                ),
                IntrinsicWidth(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Parity:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButton<int>(
                          value: _parity,
                          isExpanded: true,
                          items: _parities
                              .map((parity) => DropdownMenuItem(
                                  value: parity, 
                                  child: Text(parity == SerialPortParity.none ? 'None' : 
                                            parity == SerialPortParity.odd ? 'Odd' : 'Even')))
                              .toList(),
                          onChanged: (parity) => setState(() => _parity = parity!),
                        ),
                      ),
                    ],
                  ),
                ),
                IntrinsicWidth(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Data Bits:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButton<int>(
                          value: _dataBit,
                          isExpanded: true,
                          items: _dataBits
                              .map((dataBit) => DropdownMenuItem(
                                  value: dataBit, child: Text(dataBit.toString())))
                              .toList(),
                          onChanged: (dataBit) => setState(() => _dataBit = dataBit!),
                        ),
                      ),
                    ],
                  ),
                ),
                IntrinsicWidth(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Stop Bits:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButton<int>(
                          value: _stopBit,
                          isExpanded: true,
                          items: _stopBits
                              .map((stopBit) => DropdownMenuItem(
                                  value: stopBit, child: Text(stopBit.toString())))
                              .toList(),
                          onChanged: (stopBit) => setState(() => _stopBit = stopBit!),
                        ),
                      ),
                    ],
                  ),
                ),
                IntrinsicWidth(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Flow Control:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButton<int>(
                          value: _flowControl,
                          isExpanded: true,
                          items: _flowControls
                              .map((flowControl) => DropdownMenuItem(
                                  value: flowControl,
                                  child: Text(flowControl == SerialPortFlowControl.none ? 'None' :
                                            flowControl == SerialPortFlowControl.dtrDsr ? 'DTR/DSR' :
                                            flowControl == SerialPortFlowControl.rtsCts ? 'RTS/CTS' : 'XON/XOFF')))
                              .toList(),
                          onChanged: (flowControl) => setState(() => _flowControl = flowControl!),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _buildPanel(
                      'Received',
                      _receivedData.toString(),
                      controller: _receivedTextController,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildPanel(
                      'Sent',
                      _inputTextData.toString(),
                      textField: TextField(
                        controller: _inputController,
                        decoration: const InputDecoration(labelText: 'Enter data to send'),
                        onSubmitted: (_) => _sendData(),
                        enabled: _isConnected,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanel(
    String title,
    String content, {
    ScrollController? controller,
    Widget? textField,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: SingleChildScrollView(
              controller: controller,
              child: Text(content),
            ),
          ),
          if (textField != null) textField,
        ],
      ),
    );
  }
}