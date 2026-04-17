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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _chip('LIVE', const Color(0xFF28C76F)),
              _chip('SOS', Colors.redAccent),
            ],
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
              SizedBox(width: 8),
              Text(
                'EMERGENCY',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'SOS',
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: _sending ? null : _sendSOS,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 118,
              height: 118,
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
                    : const Text(
                        'SOS',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            _sending ? 'Sending emergency alert...' : 'Tap circle to send',
            style: TextStyle(fontSize: 13, color: Colors.grey[400]),
          ),
          const SizedBox(height: 12),
          Text(
            widget.controller.deviceId,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _status,
            textAlign: TextAlign.center,
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

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.65)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
