import 'package:flutter/material.dart';

class ILBApp extends StatelessWidget {
  const ILBApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ILB',
      debugShowCheckedModeBanner: false,
      home: const Scaffold(
        body: Center(
          child: Text('Intelligent Language Bridge'),
        ),
      ),
    );
  }
}