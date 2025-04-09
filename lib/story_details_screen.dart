import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:html/parser.dart' show parse;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

class StoryDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> post;

  const StoryDetailsScreen({required this.post, super.key});

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

  List<String> _extractSourceLinks(String content) {
    try {
      final document = parse(content);
      final links = document.querySelectorAll('a');
      return links.map((link) => link.attributes['href'] ?? '').where((url) => url.isNotEmpty).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = post['title'] ?? 'Untitled';
    final subhead = _extractSubhead(post['content'] ?? '');
    final contentText = parse(post['content'] ?? '').body?.text ?? 'No content available';
    final imageUrls = _extractImageUrls(post['content'] ?? '');
    final sourceLinks = _extractSourceLinks(post['content'] ?? '');

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFF2F2F4)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 18, color: Color(0xFFF2F2F4)),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrls.isNotEmpty)
              SizedBox(
                height: 200,
                child: PageView(
                  children: imageUrls.map((url) => CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) => const Center(child: Icon(Icons.error)),
                  )).toList(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF2F2F2F),
                  borderRadius: BorderRadius.circular(8),
                ),
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
                              fontSize: 24,
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
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          subhead,
                          style: const TextStyle(
                            fontSize: 20,
                            fontStyle: FontStyle.italic,
                            color: Color(0xFFF2F2F4),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      contentText,
                      style: const TextStyle(color: Color(0xFFF2F2F4), height: 1.5),
                    ),
                    if (sourceLinks.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Sources:',
                        style: TextStyle(color: Color(0xFFF2F2F4), fontWeight: FontWeight.bold),
                      ),
                      ...sourceLinks.map((url) => Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: GestureDetector(
                          onTap: () async {
                            final uri = Uri.parse(url);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Cannot launch $url')),
                              );
                            }
                          },
                          child: Text(url, style: const TextStyle(color: Color(0xFFC5BE92))),
                        ),
                      )),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}