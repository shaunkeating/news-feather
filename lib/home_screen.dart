import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:html/parser.dart' show parse;
import 'package:cached_network_image/cached_network_image.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String filter = 'Week';

  DateTime _getFilterDate() {
    final now = DateTime.now();
    if (filter == 'Week') return now.subtract(const Duration(days: 7));
    if (filter == 'Month') return now.subtract(const Duration(days: 30));
    return now.subtract(const Duration(days: 365));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Today's Stories"),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Color(0xFFF2F2F4)),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      endDrawer: Drawer(
        child: Container(
          color: const Color(0xFF2F2F2F),
          child: ListView(
            children: [
              ListTile(
                title: const Text('Saved Stories', style: TextStyle(color: Color(0xFFF2F2F4))),
                onTap: () => Navigator.pushNamed(context, '/saved'),
              ),
              ListTile(
                title: const Text('Profile & Settings', style: TextStyle(color: Color(0xFFF2F2F4))),
                onTap: () => Navigator.pushNamed(context, '/profile'),
              ),
              ListTile(
                title: const Text('News Feather Ultimate', style: TextStyle(color: Color(0xFFF2F2F4))),
                onTap: () => Navigator.pushNamed(context, '/ultimate'),
              ),
            ],
          ),
        ),
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
              stream: FirebaseFirestore.instance
                  .collection('wordpress_posts')
                  .where('date', isGreaterThan: _getFilterDate().toIso8601String())
                  .orderBy('date', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                }
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
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

class NewsModule extends StatelessWidget {
  final Map<String, dynamic> post;

  const NewsModule({required this.post, super.key});

  Future<void> _toggleSavePost(BuildContext context, bool isSaved) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await user.reload();
        user = FirebaseAuth.instance.currentUser;
        final ref = FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('saved_stories')
            .doc(post['id'].toString());
        
        if (isSaved) {
          await ref.delete();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Removed from saved stories')),
          );
        } else {
          await ref.set(post);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Saved!')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to save stories')),
      );
    }
  }

  String _extractSubhead(String content) {
    try {
      final document = parse(content);
      final h2 = document.querySelector('h2');
      return h2?.text ?? '';
    } catch (e) {
      return '';
    }
  }

  List<String> _extractImageUrls(String content) {
    try {
      final document = parse(content);
      final images = document.querySelectorAll('img');
      return images.map((img) => img.attributes['src'] ?? '').where((url) => url.isNotEmpty).toList();
    } catch (e) {
      return [];
    }
  }

  List<Widget> _buildExcerptLines(String excerpt) {
    try {
      final document = parse(excerpt);
      final paragraphs = document.querySelectorAll('p');
      final lines = paragraphs.expand((p) => p.text.split('<br />')).where((line) => line.trim().isNotEmpty).toList();
      return lines.take(5).map((line) => Padding(
        padding: const EdgeInsets.only(bottom: 4.0),
        child: Text(
          line.trim(),
          style: const TextStyle(color: Color(0xFFF2F2F4), height: 1.5),
        ),
      )).toList();
    } catch (e) {
      return [const Text('No summary available', style: TextStyle(color: Color(0xFFF2F2F4)))];
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = post['title'] ?? 'Untitled';
    final subhead = _extractSubhead(post['content'] ?? '');
    final excerptLines = _buildExcerptLines(post['excerpt'] ?? 'No summary available');
    final imageUrls = _extractImageUrls(post['content'] ?? '');

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/story', arguments: post),
      child: Container(
        height: 450,  // Increased to fit content
        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        decoration: BoxDecoration(
          color: const Color(0xFF2F2F2F),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: PageView(
            children: [
              // Page 1: Text and Carousel
              SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFF2F2F4),
                              ),
                            ),
                          ),
                          StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseAuth.instance.currentUser != null
                                ? FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(FirebaseAuth.instance.currentUser!.uid)
                                    .collection('saved_stories')
                                    .doc(post['id'].toString())
                                    .snapshots()
                                : null,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return IconButton(
                                  icon: Icon(
                                    Icons.save,
                                    color: const Color(0xFFC5BE92).withOpacity(0.3),
                                  ),
                                  onPressed: null,
                                );
                              }
                              bool isSaved = snapshot.hasData && snapshot.data!.exists;
                              return IconButton(
                                icon: Icon(
                                  Icons.save,
                                  color: isSaved
                                      ? const Color(0xFFC5BE92)
                                      : const Color(0xFFC5BE92).withOpacity(0.3),
                                ),
                                onPressed: () => _toggleSavePost(context, isSaved),
                              );
                            },
                          ),
                        ],
                      ),
                      if (subhead.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            subhead,
                            style: const TextStyle(
                              color: Color(0xFFF2F2F4),
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      if (imageUrls.isNotEmpty)
                        Container(
                          height: 200,
                          width: double.infinity,  // Constrain width
                          child: PageView(
                            children: imageUrls.map((url) => CachedNetworkImage(
                              imageUrl: url,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                              errorWidget: (context, url, error) => const Center(child: Icon(Icons.error)),
                            )).toList(),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Column(children: excerptLines),
                    ],
                  ),
                ),
              ),
              // Additional Pages: Fullscreen Images
              ...imageUrls.map((url) => CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                errorWidget: (context, url, error) => const Center(child: Icon(Icons.error)),
              )),
            ],
          ),
        ),
      ),
    );
  }
}