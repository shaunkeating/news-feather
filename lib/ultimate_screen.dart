import 'package:flutter/material.dart';

class NewsFeatherUltimateScreen extends StatelessWidget {
  final String currentPlan = 'Free';

  const NewsFeatherUltimateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFF2F2F4)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('News Feather Ultimate'),
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
            child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: const Color(0xFFC5BE92),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    currentPlan == 'Free' ? 'Upgrade to News Feather Ultimate' : 'Your Ultimate Plan',
                    style: const TextStyle(
                      color: Color(0xFF000000),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Ultimate subscribers are our backbone.\nGo Ultimate and see your support in action.',
                    style: TextStyle(
                      color: Color(0xFF2F2F2F),
                      fontSize: 18,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  if (currentPlan == 'Free') ...[
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '• Unlimited ad-free news',
                          style: TextStyle(
                            color: Color(0xFF2F2F2F),
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '• Exclusive, bonus content',
                          style: TextStyle(
                            color: Color(0xFF2F2F2F),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '\$2.99/month',
                      style: TextStyle(
                        color: Color(0xFF2F2F2F),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Upgrade coming soon!')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2F2F2F),
                        foregroundColor: const Color(0xFFF2F2F4),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Upgrade Now',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 16),
                    const Text(
                      '\$2.99/month',
                      style: TextStyle(
                        color: Color(0xFF2F2F2F),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Change plan coming soon!')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2F2F2F),
                        foregroundColor: const Color(0xFFF2F2F4),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Change Plan',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: const Color(0xFF2F2F2F),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Current Plan: $currentPlan',
                    style: const TextStyle(
                      color: Color(0xFFF2F2F4),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (currentPlan == 'Free') ...[
                    const SizedBox(height: 16),
                    const Text(
                      '• Unlimited ad-supported news',
                      style: TextStyle(
                        color: Color(0xFFF2F2F4),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}