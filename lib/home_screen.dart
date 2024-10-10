import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_stripe/flutter_stripe.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? paymentIntent;
  final cardEditingController = CardFormEditController();

  @override
  Widget build(BuildContext context) {
    CardFieldInputDetails? paymentDetails;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stripe Payment'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CardFormField(
                controller: cardEditingController,
                onCardChanged: (details) {
                  paymentDetails = details;
                },
                style: CardFormStyle(placeholderColor: Colors.red),
              ),
              ElevatedButton(
                onPressed: () async {
                  await pay();
                },
                child: Text("Pay"),
              ),
              SizedBox(height: 50),
              TextButton(
                child: const Text('Make Payment'),
                onPressed: () async {
                  await makePayment();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> pay() async {
    try {
      paymentIntent = await createPaymentIntent('1000', "USD");

      final clientSecret = paymentIntent?['client_secret'];

      debugPrint(
          "--------------------- client Secret $paymentIntent  ------------------");

      // Confirm the payment
      await Stripe.instance.confirmPayment(
        paymentIntentClientSecret: clientSecret,
        data: PaymentMethodParams.card(
          paymentMethodData: PaymentMethodData(),
        ),
      );

      paymentIntent = null;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment Successful')),
      );
    } catch (e, s) {
      debugPrint("--------------------- e $e ------------------");
      debugPrint("--------------------- s $s ------------------");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment failed: $e')),
      );
    }
  }

  Future<void> makePayment() async {
    try {
      paymentIntent = await createPaymentIntent('100', 'USD');

      //STEP 2: Initialize Payment Sheet
      await Stripe.instance
          .initPaymentSheet(
            paymentSheetParameters: SetupPaymentSheetParameters(
                paymentIntentClientSecret: paymentIntent![
                    'client_secret'], //Gotten from payment intent
                style: ThemeMode.dark,
                merchantDisplayName: 'Ikay'),
          )
          .then((value) {});

      //STEP 3: Display Payment sheet
      await displayPaymentSheet();
    } catch (err) {
      throw Exception(err);
    }
  }

  Future<void> displayPaymentSheet() async {
    try {
      await Stripe.instance.presentPaymentSheet().then((value) async {
        await showDialog(
            context: context,
            builder: (_) => AlertDialog(
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 100.0,
                      ),
                      SizedBox(height: 10.0),
                      Text("Payment Successful!"),
                    ],
                  ),
                ));

        paymentIntent = null;
      }).onError((error, stackTrace) {
        throw Exception(error);
      });
    } on StripeException catch (e) {
      print('Error is:---> $e');
      AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: const [
                Icon(
                  Icons.cancel,
                  color: Colors.red,
                ),
                Text("Payment Failed"),
              ],
            ),
          ],
        ),
      );
    } catch (e) {
      print('$e');
    }
  }

  Future<Map<String, dynamic>> createPaymentIntent(
      String amount, String currency) async {
    try {
      //Request body
      Map<String, dynamic> body = {
        'amount': calculateAmount(amount),
        'currency': currency,
      };

      //Make post request to Stripe
      var response = await http.post(
        Uri.parse('https://api.stripe.com/v1/payment_intents'),
        headers: {
          'Authorization': 'Bearer ${dotenv.env['STRIPE_SECRET']}',
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: body,
      );
      return json.decode(response.body);
    } catch (err) {
      throw Exception(err.toString());
    }
  }

  String calculateAmount(String amount) {
    final calculatedAmout = (int.parse(amount)) * 100;
    return calculatedAmout.toString();
  }
}
