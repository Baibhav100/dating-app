import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

String baseurl = dotenv.env['BASE_URL'] ?? 'http://default-url.com';

class CreditPackage {
  final String id;
  final String name;
  final String price;
  final int credits;
  final String details;

  CreditPackage({
    required this.id,
    required this.name,
    required this.price,
    required this.credits,
    required this.details,
  });

  factory CreditPackage.fromJson(Map<String, dynamic> json) {
    return CreditPackage(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      price: json['price'] ?? '',
      credits: json['credits'] ?? 0,
      details: json['details'] ?? '',
    );
  }
}

class SubscriptionPlan {
  final String id;
  final String name;
  final String price;
  final int durationDays;
  final String details;

  SubscriptionPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.durationDays,
    required this.details,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      price: json['price'] ?? '',
      durationDays: json['duration_days'] ?? 0,
      details: json['details'] ?? '',
    );
  }
}


class AddCreditsScreen extends StatefulWidget {
  @override
  _AddCreditsScreenState createState() => _AddCreditsScreenState();
}

class _AddCreditsScreenState extends State<AddCreditsScreen> with SingleTickerProviderStateMixin {
  final _creditController = TextEditingController();
  bool _isLoading = false;
  int _availableCredits = 500;
  int _selectedCreditPlan = 0;
  int _selectedSubscriptionPlan = 0;
  List<dynamic> _currentPlan = [];
  String _currentPlanDetails = "No plan activated.";
  List<CreditPackage> _creditPackages = [];
  bool _isLoadingPackages = true;
  String? _error;

  List<SubscriptionPlan> _subscriptionPlans = [];
  bool _isLoadingSubscriptions = true;
  String? _subscriptionError;

  String? _userId;
  bool _isAvailable = false;

  @override
  void initState() {
    super.initState();
    _fetchUserId();
    _fetchSubscriptionPlans();
    _initializeBilling();
    _listenToPurchaseUpdates();
  }

  bool _isPurchaseProcessed = false;

Future<void> _initializeBilling() async {
  try {
    final bool available = await InAppPurchase.instance.isAvailable();
    print("In-app purchases available: $available"); // Print purchase availability

    setState(() {
      _isAvailable = available;
    });

    if (_isAvailable) {
      final Set<String> ids = {'sp50', 'ep200', 'vipp500'};
      ProductDetailsResponse response = await InAppPurchase.instance.queryProductDetails(ids);

      if (response.error != null) {
        return;
      }

      // Print available products
      response.productDetails.forEach((product) {
        print("Product available: ${product.id}, ${product.title}, ${product.price}");
      });

      setState(() {
        _creditPackages = response.productDetails.map((product) {
          String cleanTitle = product.title.replaceAll(RegExp(r'\(.*\)'), '').trim();
          return CreditPackage(
            id: product.id,
            name: cleanTitle,
            price: product.price,
            credits: int.tryParse(product.id.replaceAll(RegExp(r'\D'), '')) ?? 0,
            details: product.description,
          );
        }).toList();
        _isLoadingPackages = false;
      });
    }
  } catch (e, stacktrace) {
    print("Error occurred while initializing billing: $e");
    print("Stacktrace: $stacktrace");
  }
}


  Future<void> _fetchUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getString('user_id');
    });
    if (_userId != null) {
      await _fetchCurrentPlan();
    }
  }

  Future<void> _fetchCurrentPlan() async {
    try {
      setState(() {
        _isLoadingSubscriptions = true;
        _subscriptionError = null;
      });

      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('access_token');
      final userId = prefs.getString('user_id');
      if (authToken == null || userId == null) {
        throw Exception('No auth token or user_id found');
      }

      final response_credits = await http.get(
        Uri.parse('$baseurl/auth/user-credits/'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
      );
      final response = await http.get(
        Uri.parse('$baseurl/auth/subscribe/?user_id=$userId'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          final data_credit = json.decode(response_credits.body);
          setState(() {
            _currentPlan = data;
            _availableCredits = data_credit["total_credits"];
            _isLoadingSubscriptions = false;
          });
        } else {
          setState(() {
            _currentPlanDetails = "No active subscription found";
            _isLoadingSubscriptions = false;
          });
        }
      } else {
        throw Exception('Failed to load subscription plan');
      }
    } catch (e) {
      setState(() {
        _subscriptionError = e.toString();
        _isLoadingSubscriptions = false;
      });
    }
  }

  Future<void> _fetchSubscriptionPlans() async {
    try {
      setState(() {
        _isLoadingSubscriptions = true;
        _subscriptionError = null;
      });

      final bool available = await InAppPurchase.instance.isAvailable();
      if (!available) {
        throw Exception('Google Play Billing is not available');
      }

      final Set<String> ids = {'24hu', 'wp7', 'me30'};

      final ProductDetailsResponse response = await InAppPurchase.instance.queryProductDetails(ids);

      if (response.error != null) {
        throw Exception('Error fetching subscription plans: ${response.error!.message}');
      }

      if (response.productDetails.isEmpty) {
        throw Exception('No subscription plans found. Please check your product IDs.');
      }

      setState(() {
        _subscriptionPlans = response.productDetails.map((product) {
          String cleanTitle = product.title.replaceAll(RegExp(r'\(.*\)'), '').trim();
          return SubscriptionPlan(
            id: product.id,
            name: cleanTitle,
            price: product.price,
            durationDays: _extractDurationFromId(product.id),
            details: product.description,
          );
        }).toList();
        _isLoadingSubscriptions = false;
      });
    } catch (e) {
      setState(() {
        _subscriptionError = e.toString();
        _isLoadingSubscriptions = false;
      });
    }
  }

  void _listenToPurchaseUpdates() {
    final Set<String> inAppIds = {'sp50', 'ep200', 'vipp500'};
    final Set<String> subscriptionIds = {'24hu', 'wp7', 'me30'};

    final Stream<List<PurchaseDetails>> purchaseUpdated = InAppPurchase.instance.purchaseStream;

    purchaseUpdated.listen((purchases) {
      for (var purchase in purchases) {
        if (!_isPurchaseProcessed && purchase.status == PurchaseStatus.purchased) {
          _isPurchaseProcessed = true;

          if (inAppIds.contains(purchase.productID)) {
            _deliverInAppProduct(purchase);
          } else if (subscriptionIds.contains(purchase.productID)) {
            _deliverSubscription(purchase);
          }
        } else if (purchase.status == PurchaseStatus.error) {
          print('Purchase failed for product ID: ${purchase.productID}, Error: ${purchase.error}');
        } else if (purchase.status == PurchaseStatus.canceled) {
          print('Purchase was canceled by the user for product ID: ${purchase.productID}');
        }
      }
    }, onDone: () {
      print('Purchase stream closed.');
    }, onError: (error) {
      print('Error in purchase stream: $error');
    });
  }

  void _deliverInAppProduct(PurchaseDetails purchase) {
    _sendInAppPurchaseDataToBackend(purchase);

    if (purchase.pendingCompletePurchase) {
      InAppPurchase.instance.completePurchase(purchase);
    }
  }

  void _deliverSubscription(PurchaseDetails purchase) {
    _sendSubsPurchaseDataToBackend(purchase);

    if (purchase.pendingCompletePurchase) {
      InAppPurchase.instance.completePurchase(purchase);
    }
  }

  Future<void> _sendInAppPurchaseDataToBackend(PurchaseDetails purchase) async {
    try {
      print("sending to the backend for purchase: ${purchase.productID}");
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('access_token');

      if (authToken == null) {
        throw Exception('No auth token found');
      }

      final Map<String, dynamic> purchaseData = {
        'product_id': purchase.productID,
        'purchase_token': purchase.purchaseID,
        'purchase_time': DateTime.now().toIso8601String(),
        'user_id': prefs.getString('user_id'),
        'status': purchase.status.toString().split('.').last,
      };

      final response = await http.post(
        Uri.parse('$baseurl/verify/purchase/'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(purchaseData),
      );

      if (response.statusCode == 201) {
        print('Purchase verified and updated successfully on backend.');
      } else {
        print('Failed to verify purchase on backend. Response code: ${response.statusCode}, Response body: ${response.body}');
      }
    } catch (e) {
      print('Error sending purchase data to backend: $e');
    }
  }

  Future<void> _sendSubsPurchaseDataToBackend(PurchaseDetails purchase) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('access_token');

      if (authToken == null) {
        throw Exception('No auth token found');
      }

      final Map<String, dynamic> purchaseData = {
        'product_id': purchase.productID,
        'purchase_token': purchase.purchaseID,
        'purchase_time': DateTime.now().toIso8601String(),
        'user_id': prefs.getString('user_id'),
        'status': purchase.status.toString().split('.').last,
      };

      final response = await http.post(
        Uri.parse('$baseurl/verify/verify-subscription/'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(purchaseData),
      );

      if (response.statusCode == 201) {
        print('Purchase verified and updated successfully on backend.');
      } else {
        print('Failed to verify purchase on backend. Response code: ${response.statusCode}, Response body: ${response.body}');
      }
    } catch (e) {
      print('Error sending purchase data to backend: $e');
    }
  }

  int _extractDurationFromId(String productId) {
    switch (productId) {
      case '24hu':
        return 1;
      case 'me30':
        return 30;
      case 'wp7':
        return 7;
      default:
        return 30;
    }
  }

  Future<void> _purchaseCreditPackage(CreditPackage package) async {
  print("Purchase function triggered for package: ${package.id}");

  try {
    final ProductDetailsResponse response =
        await InAppPurchase.instance.queryProductDetails({package.id});

    // Print the full response
    print("ProductDetailsResponse: $response");
    print("Not Found IDs: ${response.notFoundIDs}");
    print("Product Details List: ${response.productDetails}");

    if (response.notFoundIDs.isNotEmpty) {
      print("Product ID not found: ${response.notFoundIDs}");
      return;
    }

    if (response.productDetails.isEmpty) {
      print("Product details list is empty.");
      return;
    }

    final productDetails = response.productDetails.first;
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);

    print("Initiating purchase for: ${productDetails.id}");
    InAppPurchase.instance.buyConsumable(purchaseParam: purchaseParam);
  } catch (e) {
    print('An error occurred during purchase: $e');
  }
}

  Future<void> _purchaseSubscriptionPlan(SubscriptionPlan plan) async {
    try {
      final ProductDetailsResponse response = await InAppPurchase.instance.queryProductDetails({plan.id});
  
      if (response.notFoundIDs.isNotEmpty) {
        return;
      }
  
      if (response.productDetails.isEmpty) {
        return;
      }
  
      final productDetails = response.productDetails.first;
      final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);
  
      InAppPurchase.instance.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      print('An error occurred during subscription purchase: $e');
    }
  }

  Future<void> _refreshData() async {
    await _fetchSubscriptionPlans();
    await _fetchCurrentPlan();
  }

  @override
  void dispose() {
    _creditController.dispose();
    super.dispose();
  }

  void _addCredits() {
    final creditAmount = int.tryParse(_creditController.text);
    if (creditAmount != null && creditAmount > 0) {
      setState(() => _isLoading = true);
      Future.delayed(Duration(seconds: 2), () {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$creditAmount credits added successfully!')),
        );
        Navigator.pop(context);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid number of credits.')),
      );
    }
  }

  Widget _buildPlanCard(String title, String content, Widget child) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.9,
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: const Color.fromARGB(255, 58, 57, 57),
                ),
              ),
              SizedBox(height: 8),
              Text(
                content,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPackagesContent() {
    if (_isLoadingPackages) {
      return Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_error'),
            ElevatedButton(
              onPressed: _initializeBilling,
              child: Text('Retry'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
      children: _creditPackages.map((package) {
        final index = _creditPackages.indexOf(package) + 1;
        return AnimatedContainer(
        duration: Duration(milliseconds: 300),
        margin: EdgeInsets.symmetric(horizontal: 8),
        transform: Matrix4.translationValues(
          0,
          _selectedCreditPlan == index ? -10 : 0,
          0,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
          colors: [const Color.fromARGB(255, 97, 28, 161), const Color.fromARGB(255, 32, 32, 32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          ),
          boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
          ],
        ),
        child: Container(
          width: 200,
          child: ListTile(
          title: Text(
            package.name,
            style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 18,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            ...package.details.split(',').map((detail) {
              return Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white70, size: 16),
                SizedBox(width: 8),
                Expanded(
                child: Text(
                  detail.trim(),
                  style: TextStyle(color: Colors.white70),
                ),
                ),
              ],
              );
            }).toList(),
            SizedBox(height: 8),
            Text(
              package.price,
              style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 16,
              ),
            ),
            ],
          ),
        onTap: () {
        print("onTap triggered for package: ${package.id}");
        setState(() {
          _selectedCreditPlan = index;
        });
        _purchaseCreditPackage(package);
          },

          ),
        ),
        );
      }).toList(),
      ),
    );
  }

  Widget _buildSubscriptionContent() {
    if (_isLoadingSubscriptions) {
      return Center(child: CircularProgressIndicator());
    }

    if (_subscriptionError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_subscriptionError'),
            ElevatedButton(
              onPressed: _fetchSubscriptionPlans,
              child: Text('Retry'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
      children: _subscriptionPlans.map((plan) {
        final index = _subscriptionPlans.indexOf(plan) + 1;
        return AnimatedContainer(
        duration: Duration(milliseconds: 300),
        margin: EdgeInsets.symmetric(horizontal: 8),
        transform: Matrix4.translationValues(
          0,
          _selectedSubscriptionPlan == index ? -10 : 0,
          0,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
          colors: [Colors.pinkAccent, const Color.fromARGB(255, 32, 32, 32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          ),
          boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
          ],
        ),
        child: Container(
          width: 200,
          child: ListTile(
          title: Text(
            plan.name,
            style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 18,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            ...plan.details.split(',').map((detail) {
              return Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white70, size: 16),
                SizedBox(width: 8),
                Expanded(
                child: Text(
                  detail.trim(),
                  style: TextStyle(color: Colors.white70),
                ),
                ),
              ],
              );
            }).toList(),
            SizedBox(height: 8),
            Text(
              plan.price,
              style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 16,
              ),
            ),
            ],
          ),
          onTap: () {
            setState(() {
            _selectedSubscriptionPlan = index;
            });
            _purchaseSubscriptionPlan(plan);
          },
          ),
        ),
        );
      }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          "Add Credits and Subscription Plans",
          style: TextStyle(
           
            fontSize: 18,
           color: Color.fromARGB(255, 65, 64, 64),
          ),
        ),
        elevation: 10,
        shadowColor: Colors.black45,
        centerTitle: true,
      ),
      body: Container(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Active Plans:',
                  style: TextStyle(fontSize:15,color: const Color.fromARGB(255, 44, 44, 44)),
                ),
                SizedBox(height: 8),
                _currentPlan != null && _currentPlan.isNotEmpty
                    ? Column(
                        children: _currentPlan.map<Widget>((plan) {
                          return Card(
                            color: Colors.grey[900],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ListTile(
                                title: ShaderMask(
                                shaderCallback: (bounds) => LinearGradient(
                                  colors: [Colors.pinkAccent, const Color.fromARGB(255, 45, 24, 104)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ).createShader(bounds),
                                child: Text(
                                  plan['subscription_name'] ?? 'No Name',
                                  style: TextStyle(color: const Color.fromARGB(255, 95, 94, 94)),
                                ),
                                ),
                              subtitle: Text(
                                'Start Date: ${plan['start_date']}\nEnd Date: ${plan['end_date']}',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          );
                        }).toList(),
                      )
                    : Text(_currentPlanDetails, style: TextStyle(color: const Color.fromARGB(255, 105, 104, 104))),
                SizedBox(height: 20),
                _buildPlanCard(
                  'Subscription Plans',
                  'Choose your subscription plan',
                  _buildSubscriptionContent(),
                ),
                SizedBox(height: 20),
                _buildPlanCard(
                  'Credit Packages',
                  'Choose your credit package',
                  _buildPackagesContent(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}