import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  _ProfileSettingsScreenState createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  File? _image;
  String _photoUrl = '';
  String _displayName = 'Loading...';
  bool _isSubscribed = false;
  bool _isLoading = false;
  final picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _displayName = 'Unknown';
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!mounted) return;
      setState(() {
        _photoUrl = doc.data()?.toString().contains('photo_url') == true ? doc['photo_url'] ?? '' : '';
        _displayName = user.displayName ??
            '${doc['firstName'] ?? ''} ${doc['lastName'] ?? ''}'.trim() ??
            user.email ??
            'Unknown';
        _isSubscribed = doc.data()?.toString().contains('isSubscribed') == true ? doc['isSubscribed'] ?? false : false;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load user data: $e')),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null && mounted) {
      setState(() {
        _image = File(pickedFile.path);
      });
      await _uploadImage();
    }
  }

  Future<void> _uploadImage() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (_image == null || user == null) return;

    setState(() => _isLoading = true);
    try {
      Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('users/${user.uid}/avatar.jpg');
      await storageRef.putFile(_image!);
      String downloadUrl = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'photo_url': downloadUrl}, SetOptions(merge: true));

      if (mounted) {
        setState(() {
          _photoUrl = downloadUrl;
          _image = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
		  const SnackBar(
		    content: Text('Avatar updated!'),
		    duration: Duration(seconds: 2),
		 ),
	   );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update avatar: $e')),
        );
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _updateEmail() async {
    TextEditingController emailController = TextEditingController(
      text: FirebaseAuth.instance.currentUser?.email ?? '',
    );
    TextEditingController passwordController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2F2F2F),
        title: const Text('Update Email', style: TextStyle(color: Color(0xFFF2F2F4))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              style: const TextStyle(color: Color(0xFFF2F2F4)),
              decoration: InputDecoration(
                labelText: 'New Email',
                labelStyle: const TextStyle(color: Color(0xFFC5BE92)),
                filled: true,
                fillColor: const Color(0xFF3F3F3F),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: passwordController,
              obscureText: true,
              style: const TextStyle(color: Color(0xFFF2F2F4)),
              decoration: InputDecoration(
                labelText: 'Password',
                labelStyle: const TextStyle(color: Color(0xFFC5BE92)),
                filled: true,
                fillColor: const Color(0xFF3F3F3F),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFFC5BE92))),
          ),
          TextButton(
            onPressed: () async {
              User? user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                setState(() => _isLoading = true);
                try {
                  AuthCredential credential = EmailAuthProvider.credential(
                    email: user.email!,
                    password: passwordController.text,
                  );
                  await user.reauthenticateWithCredential(credential);
                  await user.updateEmail(emailController.text.trim());
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .set(
                    {
                      'email': emailController.text.trim(),
                      'email_verified': user.emailVerified,
                    },
                    SetOptions(merge: true),
                  );
                  Navigator.pop(context);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
					  const SnackBar(
						content: Text('Email updated!'),
						duration: Duration(seconds: 2),
					  ),
					);
                    await _loadUserData();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to update email: $e')),
                    );
                  }
                }
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text('Save', style: TextStyle(color: Color(0xFFC5BE92))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
  automaticallyImplyLeading: false,
  leading: IconButton(
    icon: const Icon(Icons.arrow_back, color: Color(0xFFF2F2F4)),
    onPressed: () => Navigator.pop(context), // Changed from pushReplacementNamed
  ),
  title: const SizedBox.shrink(),
  actions: [
    const Padding(
      padding: EdgeInsets.only(right: 16.0),
      child: Center(
        child: Text(
          'Profile & Settings',
          style: TextStyle(color: Color(0xFFF2F2F4), fontSize: 18),
        ),
      ),
    ),
  ],
),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: _pickImage,
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundColor: const Color(0xFF2F2F2F),
                                backgroundImage: _photoUrl.isNotEmpty ? NetworkImage(_photoUrl) : null,
                                child: _photoUrl.isEmpty
                                    ? const Icon(Icons.person, size: 40, color: Color(0xFFF2F2F4))
                                    : null,
                              ),
                              Positioned(
                                child: Container(
                                  padding: const EdgeInsets.all(4.0),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFC5BE92),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.edit, size: 16, color: Color(0xFF000000)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _displayName,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFF2F2F4)),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
                  child: Container(
                    height: 170,
                    decoration: BoxDecoration(
                      color: const Color(0xFFC5BE92),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Current Plan: ${_isSubscribed ? 'Ultimate' : 'Free'}',
                                  style: const TextStyle(
                                    color: Color(0xFF000000),
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (!_isSubscribed) ...[
                                  const Text(
                                    'Upgrade to News Feather Ultimate and go ad-free',
                                    style: TextStyle(color: Color(0xFF000000)),
                                  ),
                                  const SizedBox(height: 8),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pushNamed(context, '/ultimate'),
                                    style: ElevatedButton.styleFrom(
  backgroundColor: const Color(0xFF2F2F2F),
  foregroundColor: const Color(0xFFF2F2F4),
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(8),
  ),
),
                                    child: const Text(
                                      'Upgrade Now',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ] else ...[
                                  ElevatedButton(
                                    onPressed: () => Navigator.pushNamed(context, '/ultimate'),
                                    style: ElevatedButton.styleFrom(
  backgroundColor: const Color(0xFF2F2F2F),
  foregroundColor: const Color(0xFFF2F2F4),
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(8),
  ),
),
                                    child: const Text(
                                      'Change Plan',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(right: 16.0),
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: Color(0xFF2F2F2F),
                            child: Icon(Icons.image, size: 50, color: Color(0xFFF2F2F4)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 15.0),
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF2F2F2F),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            title: const Text('Email', style: TextStyle(color: Color(0xFFF2F2F4))),
                            trailing: const Icon(Icons.edit, size: 16, color: Color(0xFFF2F2F4)),
                            subtitle: Text(
                              FirebaseAuth.instance.currentUser?.email ?? 'Loading...',
                              style: const TextStyle(color: Color(0xFFF2F2F4)),
                            ),
                            onTap: _updateEmail,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF2F2F2F),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            title: const Text('Privacy Settings', style: TextStyle(color: Color(0xFFF2F2F4))),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFFF2F2F4)),
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Privacy settings coming soon!')),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF2F2F2F),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            title: const Text('Notifications Settings', style: TextStyle(color: Color(0xFFF2F2F4))),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFFF2F2F4)),
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Notifications settings coming soon!')),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF2F2F2F),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            title: const Text('Dark Mode', style: TextStyle(color: Color(0xFFF2F2F4))),
                            trailing: Switch(
                              value: true,
                              onChanged: (value) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Theme toggle coming soon!')),
                                );
                              },
                              activeColor: const Color(0xFFC5BE92),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF2F2F2F),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            title: const Text('Sign Out', style: TextStyle(color: Color(0xFFF2F2F4))),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFFF2F2F4)),
                            onTap: () async {
                              await GoogleSignIn().signOut();
                              await FirebaseAuth.instance.signOut();
                              await Future.delayed(const Duration(milliseconds: 100));
                              if (mounted) {
                                Navigator.pushReplacementNamed(context, '/login');
                              }
                            },
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