import 'package:flutter/material.dart';
import 'package:flutter_carousel_widget/flutter_carousel_widget.dart';
import 'package:html/parser.dart' show parse;

class StoryDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> post;

  const StoryDetailsScreen({required this.post, super.key});

  @override
  Widget build(BuildContext context) {
    String title = post['title'] is String
        ? post['title']
        : post['title'] is Map
            ? post['title']['rendered'] ?? 'Untitled'
            : 'Untitled';

    String summary = post['content'] is String
        ? parse(post['content']).body?.text ?? 'No summary available'
        : post['content'] is Map
            ? parse(post['content']['rendered']).body?.text ?? 'No summary available'
            : 'No summary available';
    List<String> sentences = summary.split('. ').take(5).map((s) => '$s.').toList();
    summary = sentences.join(' ');

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFF2F2F4)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 18),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: ListView(
        children: [
          FlutterCarousel(
            options: CarouselOptions(
              height: 200.0,
              autoPlay: false,
              enlargeCenterPage: true,
              viewportFraction: 0.9,
              showIndicator: false,
            ),
            items: [1, 2, 3].map((i) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 8.0),
              color: const Color(0xFF2F2F2F),
              child: Center(
                child: Text(
                  'Image $i',
                  style: const TextStyle(color: Color(0xFFF2F2F4), fontSize: 20),
                ),
              ),
            )).toList(),
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
                      const Expanded(
                        child: Text(
                          'Summary',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFF2F2F4),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.save, color: Color(0xFFC5BE92)),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Saved!')),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        color: Color(0xFFF2F2F4),
                        fontSize: 16,
                        height: 1.5,
                      ),
                      children: [
                        TextSpan(text: summary.split(' ').take(5).join(' ')),
                        const TextSpan(
                          text: ' Source',
                          style: TextStyle(color: Color(0xFFC5BE92)),
                        ),
                        TextSpan(text: ' ${summary.split(' ').skip(5).join(' ')}'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}