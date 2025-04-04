import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';

class SavedStoriesScreen extends StatefulWidget {
  const SavedStoriesScreen({super.key});

  @override
  _SavedStoriesScreenState createState() => _SavedStoriesScreenState();
}

class _SavedStoriesScreenState extends State<SavedStoriesScreen> {
  String filter = 'Week';

  DateTime _getFilterDate() {
    final now = DateTime.now();
    if (filter == 'Week') return now.subtract(const Duration(days: 7));
    if (filter == 'Month') return now.subtract(const Duration(days: 30));
    return now.subtract(const Duration(days: 365));
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFF2F2F4)),
          onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
        ),
        title: const Text('Saved Stories'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilterButton(label: 'Week', currentFilter: filter, onTap: () => setState(() => filter = 'Week')),
                FilterButton(label: 'Month', currentFilter: filter, onTap: () => setState(() => filter = 'Month')),
                FilterButton(label: 'Year', currentFilter: filter, onTap: () => setState(() => filter = 'Year')),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: user != null
                  ? FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('saved_stories')
                      .where('date', isGreaterThan: _getFilterDate().toIso8601String())
                      .orderBy('date', descending: true)
                      .snapshots()
                  : Stream.empty(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Color(0xFFF2F2F4), fontSize: 18),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No saved stories yet',
                      style: TextStyle(color: Color(0xFFF2F2F4), fontSize: 18),
                    ),
                  );
                }
                final posts = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index].data() as Map<String, dynamic>;
                    return NewsModule(post: post);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}