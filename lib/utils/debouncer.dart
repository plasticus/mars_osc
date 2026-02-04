import 'dart:async';
import 'package:flutter/material.dart';

class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({required this.delay});

  void run(VoidCallback action) {
    _timer?.cancel(); // Cancel the old timer if it's still running
    _timer = Timer(delay, action); // Start a new one
  }

  // Optional: A method to manually cancel if you ever need to dispose of it
  void cancel() {
    _timer?.cancel();
  }
}