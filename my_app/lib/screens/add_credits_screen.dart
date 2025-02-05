import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

String baseurl = dotenv.env['BASE_URL'] ?? 'http://default-url.com';
// Model class for Credit Package
class CreditPackage {
  final String name;
  final String price;
  final int credits;
  final String details;

  CreditPackage({
    required this.name,
    required this.price,
    required this.credits,
    required this.details,
  });

  factory CreditPackage.fromJson(Map<String, dynamic> json) {
    return CreditPackage(
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

  @override
  void initState() {
    super.initState();
    _fetchUserId();
    _fetchCreditPackages();
    _fetchSubscriptionPlans();
    _fetchCurrentPlan();
  }

  Future<void> _fetchUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // _userId = prefs.getString('user_id');  // Assuming the user ID is stored in shared preferences
      _userId = "3199";  // Assuming the user ID is stored in shared preferences
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

    print("Auth Token: $authToken");
    print("User ID: $userId");

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

    print("Response status: ${response.statusCode}");
    print("Response body: ${response.body}");


    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      
      print("Fetched data: $data");

      if (data.isNotEmpty) {
        final currentPlan = data[0]; // Assuming there's only one record in the response
        print("Current Plan: $currentPlan");
        final data_credit = json.decode(response_credits.body);
        setState(() {
          _currentPlan = '${currentPlan['subscription_name']}';
          _currentPlanDetails = 'EXpires at: ${currentPlan['end_date']}';
          _availableCredits = data_credit["total_credits"];  // You can fetch available credits if you have a separate endpoint for it
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


  Future<void> _fetchCreditPackages() async {
    try {
      setState(() {
        _isLoadingPackages = true;
        _error = null;
      });

      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('access_token');

      if (authToken == null) {
        throw Exception('No auth token found');
      }

      final response = await http.get(
        Uri.parse('$baseurl/auth/credit-packages/'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _creditPackages = data.map((json) => CreditPackage.fromJson(json)).toList();
          _isLoadingPackages = false;
        });
      } else {
        throw Exception('Failed to load credit packages');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoadingPackages = false;
      });
    }
  }

  Future<void> _fetchSubscriptionPlans() async {
    try {
      setState(() {
        _isLoadingSubscriptions = true;
        _subscriptionError = null;
      });

      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('access_token');

      if (authToken == null) {
        throw Exception('No auth token found');
      }

      final response = await http.get(
        Uri.parse('$baseurl/auth/subscription-plans/'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _subscriptionPlans = data.map((json) => SubscriptionPlan.fromJson(json)).toList();
          _isLoadingSubscriptions = false;
        });
      } else {
        throw Exception('Failed to load subscription plans');
      }
    } catch (e) {
      setState(() {
        _subscriptionError = e.toString();
        _isLoadingSubscriptions = false;
      });
    }
  }
  Future<void> _refreshData() async {
  await _fetchCreditPackages();  // Refresh credit packages
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
              onPressed: _fetchCreditPackages,
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
              color: _selectedCreditPlan == index ? Colors.blue.withOpacity(0.5) : Colors.grey.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: RadioListTile<int>(
            value: index,
            groupValue: _selectedCreditPlan,
            title: Text(
              '${package.name} (₹${package.price})',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text('${package.credits} Credits - ${package.details}'),
            onChanged: (value) {
              setState(() => _selectedCreditPlan = value!);
              _creditController.text = package.credits.toString();
            },
            activeColor: Colors.blue,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSubscriptionPlansContent() {
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
              color: _selectedSubscriptionPlan == index ? Colors.blue.withOpacity(0.5) : Colors.grey.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: RadioListTile<int>(
            value: index,
            groupValue: _selectedSubscriptionPlan,
            title: Text(
              '${plan.name} (₹${plan.price})',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text('${plan.durationDays} Days - ${plan.details}'),
            onChanged: (value) {
              setState(() => _selectedSubscriptionPlan = value!);
            },
            activeColor: Colors.blue,
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Credits'),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          child: Container(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - AppBar().preferredSize.height,
            ),
            child: Column(
              children: [
                // Current Status Card
                _buildPlanCard(
                  'Current Status',
                  'Your active plan and available credits',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Plan: $_currentPlan',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Details: $_currentPlanDetails',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Available Credits: $_availableCredits',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),

                // Credit Packages
                _buildPlanCard(
                  'Choose a Credit Package',
                  'Select a package to purchase credits',
                  _buildPackagesContent(),
                ),

                // Subscription Plans
                _buildPlanCard(
                  'Choose a Subscription Plan',
                  'Select a plan to subscribe to our service',
                  _buildSubscriptionPlansContent(),
                ),

                // Add Credits Button
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton(
                    onPressed: _addCredits,
                    child: _isLoading ? CircularProgressIndicator() : Text('Add Credits'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
