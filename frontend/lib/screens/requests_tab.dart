import 'package:flutter/material.dart';
import '../theme/colors.dart';

class RequestsTab extends StatelessWidget {
  const RequestsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(title: const Text('Requests')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.sageLight, shape: BoxShape.circle),
                child: const Icon(Icons.handshake_outlined, size: 32, color: AppColors.sage),
              ),
              const SizedBox(height: 18),
              const Text(
                'No requests yet',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink),
              ),
              const SizedBox(height: 6),
              const Text(
                'When you ask a neighbor for help — or someone asks you — it\'ll show up here.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.inkSoft, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}