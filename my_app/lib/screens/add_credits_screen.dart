import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:in_app_purchase/in_app_purchase.dart'; // Import the in_app_purchase package

String baseurl = dotenv.env['BASE_URL'] ?? 'http://default-url.com';

// Model class for Credit Package
class CreditPackage {
  final String id;       // Product ID from Google Play Console
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

// Model class for Subscription Plan
class SubscriptionPlan {
  final String name;
  final String price;
  final int durationDays;
  final String details;

  SubscriptionPlan({
    required this.name,
    required this.price,
    required this.durationDays,
    required this.details,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
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
  int _selectedCreditPlan = 0;  // Separate variable for Credit Package selection
  int _selectedSubscriptionPlan = 0;  // Separate variable for Subscription Plan selection
  String _currentPlan = "None";
  String _currentPlanDetails = "No plan activated.";
  List<CreditPackage> _creditPackages = [];
  bool _isLoadingPackages = true;
  String? _error;

  List<SubscriptionPlan> _subscriptionPlans = [];
  bool _isLoadingSubscriptions = true;
  String? _subscriptionError;

  // Add a variable for the user ID (replace with the actual user ID)
  String? _userId;
  bool _isAvailable = false;
  @override
  void initState() {
    super.initState();
    _fetchUserId();
    _fetchSubscriptionPlans();
    _initializeBilling();
    _listenToPurchaseUpdates(); // Start listening to purchase updates
  }
  bool _isPurchaseProcessed = false;
  Future<void> _initializeBilling() async {
    // Check if Google Play Billing is available
    final bool available = await InAppPurchase.instance.isAvailable();
    setState(() {
      _isAvailable = available;
    });

    if (_isAvailable) {
      // Fetch the product details from Google Play Console
      final Set<String> ids = {'sp50', 'ep200', 'vipp500'}; // Add your product IDs
      ProductDetailsResponse response = await InAppPurchase.instance.queryProductDetails(ids);

      if (response.error != null) {
        return;
      }

      // Convert the fetched products into CreditPackage objects
      setState(() {
        _creditPackages = response.productDetails.map((product) {
          String cleanTitle = product.title.replaceAll(RegExp(r'\(.*\)'), '').trim();
          return CreditPackage(
            id: product.id,  // Include the product ID here
            name: cleanTitle,
            price: product.price,
            credits: int.tryParse(product.id.replaceAll(RegExp(r'\D'), '')) ?? 0,
            details: product.description,
          );
        }).toList();
        _isLoadingPackages = false;
      });

    } else {
      print("Google Play Billing is not available.");
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
      print("Starting to fetch current plan...");

      setState(() {
        _isLoadingSubscriptions = true;
        _subscriptionError = null;
      });

      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('access_token');
      final userId = prefs.getString('user_id'); // Assuming user_id is stored in SharedPreferences
      if (authToken == null || userId == null) {
        throw Exception('No auth token or user_id found');
      }

      final response_credits = await http.get(
        Uri.parse('$baseurl/auth/user-credits/'),
        headers: {
          'Authorization': 'Bearer $authToken', // Use the token for authentication
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
          final currentPlan = data[0]; // Assuming there's only one record in the response
          final data_credit = json.decode(response_credits.body);
          setState(() {
            _currentPlan = '${currentPlan['subscription_name']}';
            _currentPlanDetails = 'Expires at: ${currentPlan['end_date']}';
            _availableCredits = data_credit["total_credits"];
            _isLoadingSubscriptions = false;
          });
        } else {
          setState(() {
            _currentPlan = "None";
            _currentPlanDetails = "No active subscription found";
            _isLoadingSubscriptions = false;
          });
        }
      } else {
        throw Exception('Failed to load subscription plan');
      }
    } catch (e) {
      print("Error occurred: $e");
      setState(() {
        _subscriptionError = e.toString();
        _isLoadingSubscriptions = false;
      });
    }
  }

  Future<void> _fetchSubscriptionPlans() async {
    print("Subscription initialization started...");

    try {
      setState(() {
        _isLoadingSubscriptions = true;
        _subscriptionError = null;
      });

      // Check if Google Play Billing is available
      final bool available = await InAppPurchase.instance.isAvailable();
      if (!available) {
        throw Exception('Google Play Billing is not available');
      }

      // Set the subscription plan IDs from your Google Play Console
      final Set<String> ids = {'24hu','wp7','me30'}; // Add your product IDs

      // Query available products
      final ProductDetailsResponse response = await InAppPurchase.instance.queryProductDetails(ids);

      if (response.error != null) {
        throw Exception('Error fetching subscription plans: ${response.error!.message}');
      }

      if (response.productDetails.isEmpty) {
        throw Exception('No subscription plans found. Please check your product IDs.');
      }
      print("this is the response : ${response.productDetails}");
      // Map the response to SubscriptionPlan models
      setState(() {
        _subscriptionPlans = response.productDetails.map((product) {
          return SubscriptionPlan(
            name: product.id,
            price: product.price,
            durationDays: _extractDurationFromId(product.id), // Optional dynamic duration extraction
            details: product.description,
          );
        }).toList();
        _isLoadingSubscriptions = false;
      });

      // Print subscription products for debugging
      response.productDetails.forEach((product) {
        print('Product ID: ${product.id}');
        print('Title: ${product.title}');
        print('Price: ${product.price}');
        print('Description: ${product.description}');
      });

    } catch (e) {
      setState(() {
        _subscriptionError = e.toString();
        _isLoadingSubscriptions = false;
      });
      print('Error fetching subscription plans: $_subscriptionError');
    }
  }
  void _listenToPurchaseUpdates() {
    final Set<String> inAppIds = {'sp50', 'ep200', 'vipp500'};
    final Set<String> subscriptionIds = {'24hu', 'wp7', 'me30'};

    final Stream<List<PurchaseDetails>> purchaseUpdated = InAppPurchase.instance.purchaseStream;
    
    purchaseUpdated.listen((purchases) {
      for (var purchase in purchases) {
        if (!_isPurchaseProcessed && purchase.status == PurchaseStatus.purchased) {
          _isPurchaseProcessed = true;  // Prevent further processing of this purchase

          if (inAppIds.contains(purchase.productID)) {
            print("In-app product purchased: ${purchase.productID}");
            _deliverInAppProduct(purchase);
          } else if (subscriptionIds.contains(purchase.productID)) {
            print("Subscription purchased: ${purchase.productID}");
            _deliverSubscription(purchase);
          } else {
            print("Unknown product purchased: ${purchase.productID}");
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
    // Send purchase details to your backend for verification
    _sendInAppPurchaseDataToBackend(purchase);
    
    if (purchase.pendingCompletePurchase) {
      InAppPurchase.instance.completePurchase(purchase);
    }
  }

  void _deliverSubscription(PurchaseDetails purchase) {
    // Logic for activating subscription
    _sendSubsPurchaseDataToBackend(purchase);
    
    if (purchase.pendingCompletePurchase) {
      InAppPurchase.instance.completePurchase(purchase);
    }
  }

  Future<void> _sendInAppPurchaseDataToBackend(PurchaseDetails purchase) async {
    try {
      // Retrieve auth token from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('access_token');

      if (authToken == null) {
        throw Exception('No auth token found');
      }

      // Prepare the purchase data to send to the backend
      final Map<String, dynamic> purchaseData = {
        'product_id': purchase.productID,
        'purchase_token': purchase.purchaseID,
        'purchase_time': DateTime.now().toIso8601String(),
        'user_id': prefs.getString('user_id'),
        'status': purchase.status.toString().split('.').last,
      };

      print('Sending purchase data to backend: $purchaseData');

      // Send the data to your Django backend
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
      // Retrieve auth token from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('access_token');

      if (authToken == null) {
        throw Exception('No auth token found');
      }

      // Prepare the purchase data to send to the backend
      final Map<String, dynamic> purchaseData = {
        'product_id': purchase.productID,
        'purchase_token': purchase.purchaseID,
        'purchase_time': DateTime.now().toIso8601String(),
        'user_id': prefs.getString('user_id'),
        'status': purchase.status.toString().split('.').last,
      };

      print('Sending purchase data to backend: $purchaseData');

      // Send the data to your Django backend
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


  // Optional function to dynamically set duration based on product ID
  int _extractDurationFromId(String productId) {
    switch (productId) {
      case '24hu':
        return 1; // 1 day
      case 'me30':
        return 30; // 30 days
      case 'wp7':
        return 7; // 7 days
      default:
        return 30; // Default to 30 days if not matched
    }
  }

Future<void> _purchaseCreditPackage(CreditPackage package) async {
  try {
    print('Attempting to purchase package with ID: ${package.id}');
    
    // Query product details from Google Play Console
    final ProductDetailsResponse response = await InAppPurchase.instance.queryProductDetails({package.id});
    
    print('Query completed. Found products: ${response.productDetails.length}');
    print('Not found product IDs: ${response.notFoundIDs}');
    
    if (response.notFoundIDs.isNotEmpty) {
      print('Product not found in Google Play Console: ${package.id}');
      return;
    }

    if (response.productDetails.isEmpty) {
      print('No product details returned for package ID: ${package.id}');
      return;
    }

    final productDetails = response.productDetails.first;    
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);
    
    // Start the purchase flow
    print('Starting purchase flow...');
    InAppPurchase.instance.buyConsumable(purchaseParam: purchaseParam);
    
    print('Purchase flow initiated for product ID: ${productDetails.id}');
  } catch (e) {
    print('An error occurred during purchase: $e');
  }
}

Future<void> _purchaseSubscriptionPlan(SubscriptionPlan plan) async {
  try {
    print('Attempting to purchase subscription with ID: ${plan.name}');
    
    // Query product details from Google Play Console using the plan name as the ID
    final ProductDetailsResponse response = await InAppPurchase.instance.queryProductDetails({plan.name});
    
    print('Query completed. Found products: ${response.productDetails.length}');
    print('Not found product IDs: ${response.notFoundIDs}');
    
    if (response.notFoundIDs.isNotEmpty) {
      print('Subscription plan not found in Google Play Console: ${plan.name}');
      return;
    }

    if (response.productDetails.isEmpty) {
      print('No product details returned for plan ID: ${plan.name}');
      return;
    }

    final productDetails = response.productDetails.first;    
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);
    
    // Start the purchase flow for the subscription
    print('Starting purchase flow for subscription...');
    InAppPurchase.instance.buyNonConsumable(purchaseParam: purchaseParam);  // Subscriptions are non-consumable
    
    print('Purchase flow initiated for subscription ID: ${productDetails.id}');
  } catch (e) {
    print('An error occurred during subscription purchase: $e');
  }
}


  Future<void> _refreshData() async {
    await _fetchSubscriptionPlans();  // Refresh subscription plans
    await _fetchCurrentPlan();  // Refresh current plan
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
    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.grey.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 8),
              Text(
                content,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
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

    return Column(
      children: _creditPackages.map((package) {
        final index = _creditPackages.indexOf(package) + 1;
        return AnimatedContainer(
          duration: Duration(milliseconds: 300),
          margin: EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.grey.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: ListTile(
            title: Text(package.name),
            subtitle: Text(package.details),
            trailing: Text(package.price),
            onTap: () {
              setState(() {
                _selectedCreditPlan = index;
              });
              print('Selected Credit Package ID: ${package.id}'); // Print the tapped package ID
              _purchaseCreditPackage(package); // Trigger purchase
            },
          ),
        );
      }).toList(),
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

    return Column(
      children: _subscriptionPlans.map((plan) {
        final index = _subscriptionPlans.indexOf(plan) + 1;
        return AnimatedContainer(
          duration: Duration(milliseconds: 300),
          margin: EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.grey.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: ListTile(
            title: Text(plan.name),
            subtitle: Text(plan.details),
            trailing: Text(plan.price),
            onTap: () {
              setState(() {
                _selectedSubscriptionPlan = index;
              });
              // Implement subscription selection or purchase flow
              _purchaseSubscriptionPlan(plan);
            },
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Add Credits and Subscription Plans"),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Plan: $_currentPlan',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(_currentPlanDetails),
              SizedBox(height: 20),
              _buildPlanCard('Subscription Plans', 'Choose your subscription plan', _buildSubscriptionContent()),
              SizedBox(height: 20),
              _buildPlanCard('Credit Packages', 'Choose your credit package', _buildPackagesContent()),
              SizedBox(height: 20),
              TextField(
                controller: _creditController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Enter Credit Amount',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _addCredits,
                child: _isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text('Add Credits'),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
}
