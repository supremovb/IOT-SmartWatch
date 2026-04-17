import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/watch_data.dart';

class SOSScreen extends StatefulWidget {
  final WatchController controller;
  const SOSScreen({super.key, required this.controller});

  @override
  State<SOSScreen> createState() => _SOSScreenState();
}

class _SOSScreenState extends State<SOSScreen> {
  bool _sending = false;
  bool _sent = false;
  String _status = 'Ready';

  static const String _supabaseUrl = 'https://cnktjnchyyttjvslvdpr.supabase.co';
  static const String _supabaseKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNua3RqbmNoeXl0dGp2c2x2ZHByIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU4NzkyMzksImV4cCI6MjA5MTQ1NTIzOX0.HMF3yowDRciupe3BO-9gn-1vE5IWm7NYQWpQKDmqd4g';

  Future<void> _sendSOS() async {
    if (_sending) return;

    setState(() {
      _sending = true;
      _status = 'Sending...';
    });

    try {
      final url = Uri.parse('$_supabaseUrl/rest/v1/alerts');
      final response = await http.post(
        url,
        headers: {
          'apikey': _supabaseKey,
          'Authorization': 'Bearer $_supabaseKey',
          'Content-Type': 'application/json',
          'Prefer': 'return=minimal',
        },
        body: jsonEncode({
          'id': 'APP-${DateTime.now().millisecondsSinceEpoch}',
          'title': 'SOS Emergency Alert',
          'patient': 'SmartWatch User',
          'severity': 'critical',
          'status': 'new',
          'timestamp': DateTime.now().toIso8601String(),
          'value': 'Emergency SOS triggered from SmartWatch App',
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        setState(() {
          _sent = true;
          _status = 'SOS SENT!';
        });

        Future.delayed(const Duration(seconds: 10), () {
          if (mounted) {
            setState(() {
              _sent = false;
              _status = 'Ready';
            });
          }
        });
      } else {
        setState(() {
          _status = 'Failed (${response.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Connection Error';
      });
    } finally {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.controller.accentColor;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black, Colors.red.withOpacity(0.08)],
        ),
        border: Border.all(color: Colors.red, width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
              SizedBox(width: 8),
              Text(
                'EMERGENCY',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'SOS',
            style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 22),
          GestureDetector(
            onTap: _sending ? null : _sendSOS,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 122,
              height: 122,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _sent ? Colors.green : Colors.red,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: (_sent ? Colors.green : Colors.red).withOpacity(0.35),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Center(
                child: _sending
                    ? const SizedBox(
                        width: 34,
                        height: 34,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : Icon(
                        _sent ? Icons.check_rounded : Icons.health_and_safety_rounded,
                        size: 46,
                        color: Colors.white,
                      ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            _sending ? 'Sending emergency alert...' : 'Tap to send SOS alert',
            style: TextStyle(fontSize: 13, color: Colors.grey[400]),
          ),
          const SizedBox(height: 12),
          Text(
            _status,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _sent ? Colors.green : (_status == 'Ready' ? accent : Colors.orange),
            ),
          ),
        ],
      ),
    );
  }
}
