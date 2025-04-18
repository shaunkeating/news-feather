import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import 'utils/subscription.dart';

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
    return ScaffoldMessenger(
      child: Scaffold(
        appBar: AppBar(
  automaticallyImplyLeading: false,
  leading: IconButton(
    icon: const Icon(Icons.arrow_back, color: Color(0xFFF2F2F4)),
    onPressed: () => Navigator.pop(context), // Changed from pushReplacementNamed
  ),
  title: const Text('Saved Stories'),
),
        body: Column(
          children: [
            StreamBuilder<bool>(
              stream: isUserSubscribedStream(),
              builder: (context, adSnapshot) {
                if (!adSnapshot.hasData) {
                  return const SizedBox.shrink();
                }
                if (adSnapshot.data!) {
                  return const SizedBox.shrink();
                }
                return Container(
                  height: 50,
                  margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  color: const Color(0xFF3F3F3F),
                  child: const Center(child: Text('Ad Space', style: TextStyle(color: Color(0xFFF2F2F4)))),
                );
              },
            ),
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
                    return Center(
                      child: Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2F2F2F),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.bookmark_border,
                              color: Color(0xFFF2F2F4),
                              size: 48.0,
                            ),
                            SizedBox(height: 16.0),
                            Text(
                              'No saved stories yet',
                              style: TextStyle(
                                color: Color(0xFFF2F2F4),
                                fontSize: 20.0,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 8.0),
                            Text(
                              'Save stories from the home screen to see them here!',
                              style: TextStyle(
                                color: Color(0xFFF2F2F4),
                                fontSize: 14.0,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
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
      ),
    );
  }
}

class FilterButton extends StatelessWidget {
  final String label;
  final String currentFilter;
  final VoidCallback onTap;

  const FilterButton({required this.label, required this.currentFilter, required this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: label == currentFilter ? const Color(0xFFC5BE92) : const Color(0xFF2F2F2F),
          foregroundColor: label == currentFilter ? const Color(0xFF000000) : const Color(0xFFF2F2F4),
        ),
        child: Text(label),
      ),
    );
  }
}