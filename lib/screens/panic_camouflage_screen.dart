import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PanicCamouflageScreen extends StatefulWidget {
  const PanicCamouflageScreen({super.key});

  @override
  State<PanicCamouflageScreen> createState() => _PanicCamouflageScreenState();
}

class _PanicCamouflageScreenState extends State<PanicCamouflageScreen> {
  String _display = '0';
  String _operation = '';
  double? _firstOperand;
  bool _shouldResetDisplay = false;

  void _onDigitPress(String digit) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_display == '0' || _shouldResetDisplay) {
        _display = digit;
        _shouldResetDisplay = false;
      } else {
        if (_display.length < 12) {
          _display += digit;
        }
      }
    });
  }

  void _onOperatorPress(String op) {
    HapticFeedback.selectionClick();
    setState(() {
      _firstOperand = double.tryParse(_display);
      _operation = op;
      _shouldResetDisplay = true;
    });
  }

  void _onEqualPress() {
    HapticFeedback.mediumImpact();
    
    // SECRET PASSCODE CHECK:
    // If user enters '0000' or '1234' and presses '=', unlock camouflage!
    if (_display == '0000' || _display == '1234') {
      Navigator.of(context).pop();
      return;
    }

    if (_firstOperand != null && _operation.isNotEmpty) {
      final secondOperand = double.tryParse(_display);
      if (secondOperand != null) {
        double result = 0;
        switch (_operation) {
          case '+':
            result = _firstOperand! + secondOperand;
            break;
          case '-':
            result = _firstOperand! - secondOperand;
            break;
          case '×':
            result = _firstOperand! * secondOperand;
            break;
          case '÷':
            result = secondOperand != 0 ? _firstOperand! / secondOperand : 0;
            break;
        }

        setState(() {
          if (result == result.roundToDouble()) {
            _display = result.toInt().toString();
          } else {
            _display = result.toStringAsFixed(4).replaceAll(RegExp(r'0*$'), '').replaceAll(RegExp(r'\.$'), '');
          }
          _operation = '';
          _firstOperand = null;
          _shouldResetDisplay = true;
        });
      }
    }
  }

  void _onClearPress() {
    HapticFeedback.lightImpact();
    setState(() {
      _display = '0';
      _operation = '';
      _firstOperand = null;
      _shouldResetDisplay = false;
    });
  }

  Widget _buildButton(String text, {Color? bgColor, Color? textColor, VoidCallback? onTap, VoidCallback? onLongPress}) {
    final bg = bgColor ?? const Color(0xFF222222);
    final fg = textColor ?? Colors.white;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(36),
          child: InkWell(
            borderRadius: BorderRadius.circular(36),
            onTap: onTap,
            onLongPress: onLongPress,
            child: Container(
              height: 72,
              alignment: Alignment.center,
              child: Text(
                text,
                style: TextStyle(
                  color: fg,
                  fontSize: 26,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
        child: Column(
          children: [
            // Secret emergency exit at top appbar (long press or double tap top to exit)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onDoubleTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 32,
                      height: 32,
                      color: Colors.transparent,
                    ),
                  ),
                  const Text(
                    'Calculator',
                    style: TextStyle(color: Colors.white38, fontSize: 13, letterSpacing: 1),
                  ),
                  GestureDetector(
                    onDoubleTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 32,
                      height: 32,
                      color: Colors.transparent,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            // Calculator Display
            Container(
              alignment: Alignment.bottomRight,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: Text(
                  _display,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 54,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
            ),
            // Calculator Keypad
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildButton(
                        'AC',
                        bgColor: const Color(0xFFA5A5A5),
                        textColor: Colors.black,
                        onTap: _onClearPress,
                        onLongPress: () {
                          // Long press AC unlocks camouflage
                          HapticFeedback.heavyImpact();
                          Navigator.of(context).pop();
                        },
                      ),
                      _buildButton('±', bgColor: const Color(0xFFA5A5A5), textColor: Colors.black, onTap: () {
                        setState(() {
                          if (_display.startsWith('-')) {
                            _display = _display.substring(1);
                          } else if (_display != '0') {
                            _display = '-$_display';
                          }
                        });
                      }),
                      _buildButton('%', bgColor: const Color(0xFFA5A5A5), textColor: Colors.black, onTap: () {
                        final val = double.tryParse(_display);
                        if (val != null) {
                          setState(() => _display = (val / 100).toString());
                        }
                      }),
                      _buildButton('÷', bgColor: const Color(0xFFFF9F0A), onTap: () => _onOperatorPress('÷')),
                    ],
                  ),
                  Row(
                    children: [
                      _buildButton('7', onTap: () => _onDigitPress('7')),
                      _buildButton('8', onTap: () => _onDigitPress('8')),
                      _buildButton('9', onTap: () => _onDigitPress('9')),
                      _buildButton('×', bgColor: const Color(0xFFFF9F0A), onTap: () => _onOperatorPress('×')),
                    ],
                  ),
                  Row(
                    children: [
                      _buildButton('4', onTap: () => _onDigitPress('4')),
                      _buildButton('5', onTap: () => _onDigitPress('5')),
                      _buildButton('6', onTap: () => _onDigitPress('6')),
                      _buildButton('-', bgColor: const Color(0xFFFF9F0A), onTap: () => _onOperatorPress('-')),
                    ],
                  ),
                  Row(
                    children: [
                      _buildButton('1', onTap: () => _onDigitPress('1')),
                      _buildButton('2', onTap: () => _onDigitPress('2')),
                      _buildButton('3', onTap: () => _onDigitPress('3')),
                      _buildButton('+', bgColor: const Color(0xFFFF9F0A), onTap: () => _onOperatorPress('+')),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(6.0),
                          child: Material(
                            color: const Color(0xFF222222),
                            borderRadius: BorderRadius.circular(36),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(36),
                              onTap: () => _onDigitPress('0'),
                              child: Container(
                                height: 72,
                                padding: const EdgeInsets.only(left: 30),
                                alignment: Alignment.centerLeft,
                                child: const Text(
                                  '0',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      _buildButton('.', onTap: () {
                        if (!_display.contains('.')) {
                          setState(() => _display += '.');
                        }
                      }),
                      _buildButton('=', bgColor: const Color(0xFFFF9F0A), onTap: _onEqualPress),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}

