import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:html/parser.dart' show parse;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'utils/subscription.dart';

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
            const SnackBar(
              content: Text('Removed from saved stories'),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          await ref.set(post);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Saved!'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to save stories'),
          duration: Duration(seconds: 2),
        ),
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

  List<Widget> _buildContentParagraphs(String content, String subhead) {
    try {
      final document = parse(content);
      document.querySelectorAll('h2').forEach((element) => element.remove());
      document.querySelectorAll('a').forEach((element) => element.remove());
      document.querySelectorAll('img').forEach((element) => element.remove());
      final paragraphs = document.querySelectorAll('p');
      return paragraphs.map((p) => Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Text(
          p.text.trim(),
          style: const TextStyle(color: Color(0xFFF2F2F4), fontSize: 16),
        ),
      )).toList();
    } catch (e) {
      return [const Text('No content available', style: TextStyle(color: Color(0xFFF2F2F4), fontSize: 16))];
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = post['title'] ?? 'Untitled';
    final subhead = _extractSubhead(post['content'] ?? '');
    final imageUrls = _extractImageUrls(post['content'] ?? '');
    final sourceLinks = _extractSourceLinks(post['content'] ?? '');
    final contentParagraphs = _buildContentParagraphs(post['content'] ?? '', subhead);

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
            StreamBuilder<bool>(
              stream: isUserSubscribedStream(),
              builder: (context, adSnapshot) {
                if (!adSnapshot.hasData) {
                  return const SizedBox.shrink();
                }
                if (adSnapshot.data!) {
                  return const SizedBox.shrink(); // Hide ad for subscribers
                }
                return Container(
                  height: 50,
                  margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  color: const Color(0xFF3F3F3F),
                  child: const Center(child: Text('Ad Space', style: TextStyle(color: Color(0xFFF2F2F4)))),
                );
              },
            ),
            const SizedBox(height: 8),
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
                    Column(children: contentParagraphs),
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
                                SnackBar(
                                  content: Text('Cannot launch $url'),
                                  duration: Duration(seconds: 2),
                                ),
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