import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

void main() => runApp(MaterialApp(home: AudioRecorder()));

class AudioRecorder extends StatefulWidget {
  @override
  _AudioRecorderState createState() => _AudioRecorderState();
}

class _AudioRecorderState extends State<AudioRecorder> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool isRecording = false;
  String _filePath = '/storage/emulated/0/Download/audio_recording.mp3';
  late IO.Socket socket;

  @override
  void initState() {
    super.initState();
    _initializeRecorder();
    _initializeSocket();
  }

  Future<void> _initializeRecorder() async {
    await Permission.microphone.request();
    await Permission.storage.request();
    await Permission.manageExternalStorage.request();
    await _recorder.openRecorder();
  }

  void _initializeSocket() {
    socket = IO.io('http://your-node-server-url:3000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });
    socket.connect();
    socket.onConnect((_) {
      print('Connected to Node.js server');
    });
    socket.onDisconnect((_) {
      print('Disconnected from server');
    });
  }

  Future<void> startRecording() async {
    // Start recording in MP3 format and save to file path
    await _recorder.startRecorder(
      toFile: _filePath,
      codec: Codec.mp3,
    );

    setState(() => isRecording = true);
  }

  Future<void> stopRecording() async {
    await _recorder.stopRecorder();
    setState(() => isRecording = false);

    // Check if storage permission is granted
    if (await _requestStoragePermission()) {
      final file = File(_filePath);
      if (await file.exists()) {
        // Read file as bytes
        final fileBytes = await file.readAsBytes();
        // Send file bytes to server
        socket.emit('audioFile', fileBytes);

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Recording sent to server as audio_recording.mp3'),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Recording file not found.'),
        ));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Storage permission denied. Cannot send recording.'),
      ));
    }
  }

  Future<bool> _requestStoragePermission() async {
    return await Permission.storage.isGranted && await Permission.manageExternalStorage.isGranted;
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    socket.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Audio Recorder')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: isRecording ? stopRecording : startRecording,
              child: Text(isRecording ? 'Stop Recording' : 'Start Recording'),
            ),
          ],
        ),
      ),
    );
  }
}