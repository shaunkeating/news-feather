import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class NewsFeatherUltimateScreen extends StatefulWidget {
  const NewsFeatherUltimateScreen({super.key});

  @override
  _NewsFeatherUltimateScreenState createState() => _NewsFeatherUltimateScreenState();
}

class _NewsFeatherUltimateScreenState extends State<NewsFeatherUltimateScreen> {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late Stream<List<PurchaseDetails>> _purchaseStream;
  bool _isAvailable = false;
  bool _isSubscribed = false;
  List<ProductDetails> _products = [];
  bool _loading = true;

  static const Set<String> _productIds = {'monthly_subscription'};

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await Future.wait([
      _initializePurchases(),
      _checkSubscriptionStatus(),
    ]);
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _initializePurchases() async {
    _isAvailable = true;
    setState(() {
      _products = [
        ProductDetails(
          id: 'monthly_subscription',
          title: 'News Feather Ultimate Monthly',
          description: 'Unlimited ad-free news and exclusive content',
          price: '\$2.99',
          rawPrice: 2.99,
          currencyCode: 'USD',
        ),
      ];
    });
    _purchaseStream = _inAppPurchase.purchaseStream;
    _purchaseStream.listen(_handlePurchaseUpdate);
  }

  Future<void> _checkSubscriptionStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _isSubscribed = false;
          _loading = false;
        });
      }
      return;
    }

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (mounted) {
      setState(() {
        _isSubscribed = doc.data()?['isSubscribed'] ?? false;
        _loading = false;
      });
    }
  }

  Future<void> _handlePurchaseUpdate(List<PurchaseDetails> purchases) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign in to subscribe'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased) {
        try {
          if (purchase.purchaseID != 'test_purchase') {
            await _inAppPurchase.completePurchase(purchase);
          }
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({'isSubscribed': true}, SetOptions(merge: true));
          if (mounted) {
            setState(() => _isSubscribed = true);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Subscription successful!'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to update subscription: $e'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      } else if (purchase.status == PurchaseStatus.error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Purchase error: ${purchase.error?.message ?? "Unknown error"}'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  void _buyProduct(ProductDetails product) {
    if (!_isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Purchases not available'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    _handlePurchaseUpdate([
      PurchaseDetails(
        purchaseID: 'test_purchase',
        productID: product.id,
        status: PurchaseStatus.purchased,
        transactionDate: DateTime.now().toString(),
        verificationData: PurchaseVerificationData(
          localVerificationData: 'mock_data',
          serverVerificationData: 'mock_data',
          source: 'mock',
        ),
      ),
    ]);
  }

  Future<void> _endSubscription() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign in to manage subscriptions'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'isSubscribed': false}, SetOptions(merge: true));
      if (mounted) {
        setState(() => _isSubscribed = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subscription ended'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to end subscription: $e'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
  automaticallyImplyLeading: false,
  leading: IconButton(
    icon: const Icon(Icons.arrow_back, color: Color(0xFFF2F2F4)),
    onPressed: () => Navigator.pop(context), // Changed from pushReplacementNamed
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
                    _isSubscribed ? 'Your Ultimate Plan' : 'Upgrade to News Feather Ultimate',
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
                  if (!_isSubscribed) ...[
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
                    Text(
                      _products.isNotEmpty ? _products[0].price + '/month' : '\$2.99/month',
                      style: const TextStyle(
                        color: Color(0xFF2F2F2F),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _products.isEmpty
                          ? null
                          : () => _buyProduct(_products[0]),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2F2F2F),
                        foregroundColor: const Color(0xFFF2F2F4),
                        minimumSize: const Size(double.infinity, 50),
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
                    Text(
                      _products.isNotEmpty ? _products[0].price + '/month' : '\$2.99/month',
                      style: const TextStyle(
                        color: Color(0xFF2F2F2F),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2F2F2F),
                        foregroundColor: const Color(0xFFF2F2F4).withOpacity(0.5),
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Subscribed',
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
                    'Current Plan: ${_isSubscribed ? 'Ultimate' : 'Free'}',
                    style: const TextStyle(
                      color: Color(0xFFF2F2F4),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (!_isSubscribed) ...[
                    const SizedBox(height: 16),
                    const Text(
                      '• Unlimited ad-supported news',
                      style: TextStyle(
                        color: Color(0xFFF2F2F4),
                        fontSize: 16,
                      ),
                    ),
                  ],
                  if (_isSubscribed) ...[
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _endSubscription,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC5BE92),
                        foregroundColor: const Color(0xFF000000),
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'End Subscription',
                        style: TextStyle(fontSize: 16),
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