import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:html/parser.dart' show parse;
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'utils/subscription.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String filter = 'Week';
  List<DocumentSnapshot> posts = [];
  List<DocumentSnapshot?> lastDocuments = [null];
  int page = 0;
  bool hasMore = true;
  bool isLoading = false;
  String searchQuery = '';
  List<DocumentSnapshot> filteredPosts = [];
  bool isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  DateTime _getFilterDate() {
    final now = DateTime.now();
    if (filter == 'Today') {
      return DateTime(now.year, now.month, now.day);
    }
    if (filter == 'Week') return now.subtract(const Duration(days: 7));
    if (filter == 'Month') return now.subtract(const Duration(days: 30));
    return now.subtract(const Duration(days: 365));
  }

  Future<void> _loadPosts({bool nextPage = false, bool previousPage = false}) async {
    if (isLoading || (!hasMore && nextPage)) return;
    setState(() {
      isLoading = true;
    });

    Query query = FirebaseFirestore.instance
        .collection('wordpress_posts')
        .where('date', isGreaterThan: _getFilterDate().toIso8601String())
        .orderBy('date', descending: true)
        .limit(5);

    if (nextPage && page < lastDocuments.length - 1 && lastDocuments[page] != null) {
      query = query.startAfterDocument(lastDocuments[page]!);
    } else if (previousPage && page > 0 && lastDocuments[page - 1] != null) {
      query = query.endBeforeDocument(lastDocuments[page - 1]!);
    }

    final snapshot = await query.get();
    setState(() {
      if (snapshot.docs.isEmpty) {
        posts = [];
        if (!isSearching) filteredPosts = [];
        hasMore = false;
        if (!nextPage && !previousPage) {
          lastDocuments = [null];
          page = 0;
        }
      } else {
        if (nextPage) {
          page++;
          posts = snapshot.docs;
          if (page >= lastDocuments.length) {
            lastDocuments.add(snapshot.docs.last);
          }
        } else if (previousPage) {
          page--;
          posts = snapshot.docs;
        } else {
          page = 0;
          posts = snapshot.docs;
          lastDocuments = [null, snapshot.docs.last];
        }
        hasMore = snapshot.docs.length == 5;
        if (!isSearching) filteredPosts = List.from(posts);
      }
      if (isSearching && searchQuery.isNotEmpty) {
        _searchPosts(searchQuery);
      } else {
        isLoading = false;
      }
    });
  }

  Future<void> _searchPosts(String query) async {
    if (query.isEmpty) {
      setState(() {
        isSearching = false;
        filteredPosts = List.from(posts);
        isLoading = false;
      });
      return;
    }

    setState(() {
      isSearching = true;
      isLoading = true;
    });

    try {
      List<DocumentSnapshot> results = [];
      final normalizedQuery = query.toLowerCase();

      void addResults(List<DocumentSnapshot> docs, String field) {
        for (var doc in docs) {
          if (!results.any((r) => r.id == doc.id)) {
            final data = doc.data() as Map<String, dynamic>;
            print('Found match in $field: ${doc.id}, title: ${data['title']}');
            results.add(doc);
          }
        }
      }

      // Title
      var titleQuery = await FirebaseFirestore.instance
          .collection('wordpress_posts')
          .where('title_lower', isGreaterThanOrEqualTo: normalizedQuery)
          .where('title_lower', isLessThanOrEqualTo: normalizedQuery + '\uf8ff')
          .limit(10)
          .get();
      print('Title query (lower: $normalizedQuery) returned ${titleQuery.docs.length} results');
      addResults(titleQuery.docs, 'title_lower');

      // Tags
      var tagsQuery = await FirebaseFirestore.instance
          .collection('wordpress_posts')
          .where('tags_lower', arrayContains: normalizedQuery)
          .limit(10)
          .get();
      print('Tags query (lower: $normalizedQuery) returned ${tagsQuery.docs.length} results');
      addResults(tagsQuery.docs, 'tags_lower');

      // Categories
      var categoriesQuery = await FirebaseFirestore.instance
          .collection('wordpress_posts')
          .where('categories_lower', arrayContains: normalizedQuery)
          .limit(10)
          .get();
      print('Categories query (lower: $normalizedQuery) returned ${titleQuery.docs.length} results');
      addResults(categoriesQuery.docs, 'categories_lower');

      // Content
      var contentQuery = await FirebaseFirestore.instance
          .collection('wordpress_posts')
          .where('content_lower', isGreaterThanOrEqualTo: normalizedQuery)
          .where('content_lower', isLessThanOrEqualTo: normalizedQuery + '\uf8ff')
          .limit(10)
          .get();
      print('Content query (lower: $normalizedQuery) returned ${contentQuery.docs.length} results');
      addResults(contentQuery.docs, 'content_lower');

      // Excerpt
      var excerptQuery = await FirebaseFirestore.instance
          .collection('wordpress_posts')
          .where('excerpt_lower', isGreaterThanOrEqualTo: normalizedQuery)
          .where('excerpt_lower', isLessThanOrEqualTo: normalizedQuery + '\uf8ff')
          .limit(10)
          .get();
      print('Excerpt query (lower: $normalizedQuery) returned ${excerptQuery.docs.length} results');
      addResults(excerptQuery.docs, 'excerpt_lower');

      setState(() {
        filteredPosts = results;
        isLoading = false;
      });
      print('Total results: ${results.length}');
    } catch (e) {
      print('Search error: $e');
      setState(() {
        isLoading = false;
        filteredPosts = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search failed: $e')),
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

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
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
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/saved');
                },
              ),
              ListTile(
                title: const Text('Profile & Settings', style: TextStyle(color: Color(0xFFF2F2F4))),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/profile');
                },
              ),
              ListTile(
                title: const Text('News Feather Ultimate', style: TextStyle(color: Color(0xFFF2F2F4))),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/ultimate');
                },
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          StreamBuilder<bool>(
            stream: isUserSubscribedStream(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    if (_debounce?.isActive ?? false) _debounce!.cancel();
                    _debounce = Timer(const Duration(milliseconds: 300), () {
                      setState(() {
                        searchQuery = value;
                        _searchPosts(value);
                      });
                    });
                  },
                  style: const TextStyle(color: Color(0xFFF2F2F4)),
                  decoration: InputDecoration(
                    hintText: 'Search stories...',
                    hintStyle: TextStyle(color: Color(0xFFF2F2F4).withOpacity(0.5)),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFFC5BE92)),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Color(0xFFC5BE92)),
                            onPressed: () {
                              setState(() {
                                searchQuery = '';
                                _searchController.clear();
                                isSearching = false;
                                filteredPosts = List.from(posts);
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFF2F2F2F),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              );
            },
          ),
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
                FilterButton(label: 'Today', currentFilter: filter, onTap: () {
                  setState(() {
                    filter = 'Today';
                    posts.clear();
                    filteredPosts.clear();
                    lastDocuments = [null];
                    page = 0;
                    hasMore = true;
                  });
                  _loadPosts();
                }),
                FilterButton(label: 'Week', currentFilter: filter, onTap: () {
                  setState(() {
                    filter = 'Week';
                    posts.clear();
                    filteredPosts.clear();
                    lastDocuments = [null];
                    page = 0;
                    hasMore = true;
                  });
                  _loadPosts();
                }),
                FilterButton(label: 'Month', currentFilter: filter, onTap: () {
                  setState(() {
                    filter = 'Month';
                    posts.clear();
                    filteredPosts.clear();
                    lastDocuments = [null];
                    page = 0;
                    hasMore = true;
                  });
                  _loadPosts();
                }),
                FilterButton(label: 'Year', currentFilter: filter, onTap: () {
                  setState(() {
                    filter = 'Year';
                    posts.clear();
                    filteredPosts.clear();
                    lastDocuments = [null];
                    page = 0;
                    hasMore = true;
                  });
                  _loadPosts();
                }),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredPosts.isEmpty
                    ? const Center(child: Text('No stories available', style: TextStyle(color: Color(0xFFF2F2F4))))
                    : StreamBuilder<bool>(
                        stream: isUserSubscribedStream(),
                        builder: (context, adSnapshot) {
                          final showAd = adSnapshot.hasData && !adSnapshot.data!;
                          final itemCount = filteredPosts.length + (showAd ? 1 : 0) + (filteredPosts.isNotEmpty && !isSearching ? 1 : 0);
                          return ListView.builder(
                            itemCount: itemCount,
                            itemBuilder: (context, index) {
                              if (showAd && index == 2 && filteredPosts.length >= 3) {
                                return Container(
                                  height: 250,
                                  width: 300,
                                  margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                                  color: const Color(0xFF3F3F3F),
                                  child: const Center(child: Text('Ad Space (300x250)', style: TextStyle(color: Color(0xFFF2F2F4)))),
                                );
                              }
                              if (!isSearching && index == itemCount - 1 && filteredPosts.isNotEmpty) {
                                return Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (page > 0) ...[
                                        ElevatedButton(
                                          onPressed: isLoading ? null : () => _loadPosts(previousPage: true),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFC5BE92),
                                            foregroundColor: const Color(0xFF000000),
                                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                          ),
                                          child: isLoading && !hasMore
                                              ? const CircularProgressIndicator(color: Color(0xFF000000))
                                              : const Text('Previous Page'),
                                        ),
                                        const SizedBox(width: 16),
                                      ],
                                      if (hasMore)
                                        ElevatedButton(
                                          onPressed: isLoading ? null : () => _loadPosts(nextPage: true),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFC5BE92),
                                            foregroundColor: const Color(0xFF000000),
                                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                          ),
                                          child: isLoading && hasMore
                                              ? const CircularProgressIndicator(color: Color(0xFF000000))
                                              : const Text('Next Page'),
                                        ),
                                    ],
                                  ),
                                );
                              }
                              final postIndex = showAd && filteredPosts.length >= 3 ? (index < 2 ? index : index - 1) : index;
                              if (postIndex >= filteredPosts.length) return const SizedBox.shrink();
                              final post = filteredPosts[postIndex].data() as Map<String, dynamic>;
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
      key: Key(post['id'].toString()),
      onTap: () => Navigator.pushNamed(context, '/story', arguments: post),
      child: Container(
        height: 450,
        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        decoration: BoxDecoration(
          color: const Color(0xFF2F2F2F),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: PageView(
            children: [
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
                          SaveIconButton(post: post),
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
                          width: double.infinity,
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

class SaveIconButton extends StatefulWidget {
  final Map<String, dynamic> post;

  const SaveIconButton({required this.post, super.key});

  @override
  _SaveIconButtonState createState() => _SaveIconButtonState();
}

class _SaveIconButtonState extends State<SaveIconButton> {
  late bool _isSaved;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkSavedState();
  }

  @override
  void didUpdateWidget(SaveIconButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post['id'] != widget.post['id']) {
      _checkSavedState();
    }
  }

  Future<void> _checkSavedState() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _isSaved = false;
        _isLoading = false;
      });
      return;
    }

    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('saved_stories')
        .doc(widget.post['id'].toString());

    try {
      final doc = await ref.get();
      if (!mounted) return;
      setState(() {
        _isSaved = doc.exists;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaved = false;
        _isLoading = false;
      });
      print('Error checking saved state: $e');
    }
  }

  Future<void> _toggleSavePost(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to save stories'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('saved_stories')
        .doc(widget.post['id'].toString());

    setState(() {
      _isSaved = !_isSaved;
    });

    try {
      if (_isSaved) {
        await ref.set(widget.post);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved!'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        await ref.delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removed from saved stories'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaved = !_isSaved;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update: $e'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return IconButton(
        icon: Icon(
          Icons.save,
          color: const Color(0xFFC5BE92).withOpacity(0.3),
        ),
        onPressed: null,
      );
    }
    return IconButton(
      icon: Icon(
        Icons.save,
        color: _isSaved ? const Color(0xFFC5BE92) : const Color(0xFFC5BE92).withOpacity(0.3),
      ),
      onPressed: () => _toggleSavePost(context),
    );
  }
}