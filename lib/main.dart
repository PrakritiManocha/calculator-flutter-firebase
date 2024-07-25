import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/firebase_options.dart';
import 'package:math_expressions/math_expressions.dart';
import 'dart:math' as math;


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(CalculatorApp());
}

class CalculatorApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calculator',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      debugShowCheckedModeBanner: false,
      home: CalculatorHomePage(),
    );
  }
}

class CalculatorHomePage extends StatefulWidget {
  @override
  _CalculatorHomePageState createState() => _CalculatorHomePageState();
}

class _CalculatorHomePageState extends State<CalculatorHomePage> {
  String displayText = '';
  String resultText = '';
  List<String> history = [];
  bool showHistory = false;
  bool isScientificMode = false;

  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  void _evaluateExpression() {
    Parser p = Parser();
    Expression exp;
    try {
      String expression = displayText;

      expression = expression.replaceAll('π', math.pi.toString());
      expression = expression.replaceAll('e', math.e.toString());

      expression = expression.replaceAllMapped(
          RegExp(r'(sin|cos|tan|sqrt|ln|e)\(([^)]+)\)'), (match) {
        String function = match.group(1)!;
        String value = match.group(2)!;

        if (function == 'sin' || function == 'cos' || function == 'tan') {
          return '$function(${(double.parse(value) * math.pi / 180).toString()})';
        }
        return '$function($value)';
      });

      exp = p.parse(expression);
      ContextModel cm = ContextModel();
      double eval = exp.evaluate(EvaluationType.REAL, cm);
      setState(() {
        resultText = eval.toString();
        history.add(displayText + ' = ' + resultText);
        firestore.collection('history').add({
          'expression': displayText,
          'result': resultText,
        });
      });
    } catch (e) {
      setState(() {
        resultText = 'Error';
      });
    }
  }

  Widget buildButton(String text, {Color color = Colors.grey, Color textColor = Colors.white}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(2.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: textColor,
            padding: EdgeInsets.all(10.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6.0),
            ),
          ),
          onPressed: () {
            setState(() {
              if (text == 'C') {
                displayText = '';
                resultText = '';
              } else if (text == '=') {
                _evaluateExpression();
              } else if (text == 'CE') {
                if (displayText.isNotEmpty) {
                  displayText = displayText.substring(0, displayText.length - 1);
                }
              } else if (text == 'sin' || text == 'cos' || text == 'tan' ||
                  text == 'sqrt' || text == 'ln') {
                displayText += text + '(';
              } else if (text == 'Sci') {
                isScientificMode = true;
              } else if (text == 'Basic') {
                isScientificMode = false;
              } else {
                displayText += text;
              }
            });
          },
          child: Text(
            text,
            style: TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }

  Widget buildHistoryItem(String expression, String result) {
    return ListTile(
      title: Text(
        '$expression = $result',
        style: TextStyle(color: Colors.black, fontSize: 18),
      ),
      onTap: () {
        setState(() {
          displayText = expression;
        });
      },
    );
  }

  Widget buildHistory() {
  return Drawer(
    child: Container(
      color: Colors.grey[300],
      child: Column(
        children: [
          AppBar(
            title: Text('History'),
            backgroundColor: Colors.black87,
            automaticallyImplyLeading: false,
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: firestore.collection('history').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('No history available.'));
                }

                final historyDocs = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: historyDocs.length,
                  itemBuilder: (context, index) {
                    final historyItem = historyDocs[index];
                    final expression = historyItem['expression'] as String;
                    final result = historyItem['result'] as String;

                    return buildHistoryItem(expression, result);
                  },
                );
              },
            ),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                history.clear();
              });
              _clearHistoryFromFirestore();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Clear History'),
          ),
        ],
      ),
    ),
  );
}

void _clearHistoryFromFirestore() {
  firestore.collection('history').get().then((snapshot) {
    for (var doc in snapshot.docs) {
      doc.reference.delete();
    }
  });
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Calculator', style: TextStyle(color: Colors.white),),
        backgroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: Icon(
              showHistory ? Icons.clear : Icons.history,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                showHistory = !showHistory;
              });
            },
          ),
          IconButton(
            icon: Icon(
              isScientificMode ? Icons.functions : Icons.calculate,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                isScientificMode = !isScientificMode;
              });
            },
          ),
        ],
      ),
      drawer: showHistory ? buildHistory() : null,
      body: Column(
        children: <Widget>[
          Expanded(
            child: Container(
              color: Colors.black,
              alignment: Alignment.bottomRight,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    displayText,
                    style: TextStyle(color: Colors.white, fontSize: 24),
                  ),
                  Text(
                    resultText,
                    style: TextStyle(color: Colors.greenAccent, fontSize: 48),
                  ),
                ],
              ),
            ),
          ),
          Column(
            children: <Widget>[
              if (isScientificMode) ...[
                Row(
                  children: <Widget>[
                    buildButton('sin', color: Colors.grey[850]!),
                    buildButton('cos', color: Colors.grey[850]!),
                    buildButton('tan', color: Colors.grey[850]!),
                    buildButton('sqrt', color: Colors.grey[850]!),
                  ],
                ),
                Row(
                  children: <Widget>[
                    buildButton('ln', color: Colors.grey[850]!),
                    buildButton('e', color: Colors.grey[850]!),
                    buildButton('π', color: Colors.grey[850]!),
                    buildButton('^', color: Colors.grey[850]!),
                  ],
                ),
              ],
              Row(
                children: <Widget>[
                  buildButton('7', color: Colors.grey[850]!),
                  buildButton('8', color: Colors.grey[850]!),
                  buildButton('9', color: Colors.grey[850]!),
                  buildButton('/', color: Colors.orange, textColor: Colors.white),
                ],
              ),
              Row(
                children: <Widget>[
                  buildButton('4', color: Colors.grey[850]!),
                  buildButton('5', color: Colors.grey[850]!),
                  buildButton('6', color: Colors.grey[850]!),
                  buildButton('*', color: Colors.orange, textColor: Colors.white),
                ],
              ),
              Row(
                children: <Widget>[
                  buildButton('1', color: Colors.grey[850]!),
                  buildButton('2', color: Colors.grey[850]!),
                  buildButton('3', color: Colors.grey[850]!),
                  buildButton('-', color: Colors.orange, textColor: Colors.white),
                ],
              ),
              Row(
                children: <Widget>[
                  buildButton('0', color: Colors.grey[850]!),
                  buildButton('.', color: Colors.grey[850]!),
                  buildButton('CE', color: Colors.red, textColor: Colors.white),
                  buildButton('+', color: Colors.orange, textColor: Colors.white),
                ],
              ),
              Row(
                children: <Widget>[
                  buildButton('C', color: Colors.red, textColor: Colors.white),
                  buildButton('(', color: Colors.grey[850]!),
                  buildButton(')', color: Colors.grey[850]!),
                  buildButton('=', color: Colors.blue, textColor: Colors.white),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
