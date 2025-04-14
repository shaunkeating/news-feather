import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<bool> isUserSubscribed() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;
  final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
  return doc.data()?['isSubscribed'] ?? false;
}

Stream<bool> isUserSubscribedStream() {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value(false);
  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((doc) => doc.data()?['isSubscribed'] ?? false);
}