import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/cyber_grid.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _nameController = TextEditingController();

  bool _isLoading = false;
  UserModel? _userModel;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        _userModel = UserModel.fromMap(doc.data()!);
        _nameController.text = _userModel!.displayName;
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
    }
    setState(() => _isLoading = false);
  }

  Future<void> _updateProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      await _firestore.collection('users').doc(user.uid).update({
        'displayName': _nameController.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('[OK] ALIAS UPDATED')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('[ERROR] $e')),
      );
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final accentColor = themeProvider.accentColor;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: accentColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Icon(Icons.settings_outlined, color: accentColor, size: 20),
            const SizedBox(width: 10),
            Text(
              'SYSTEM CONFIG',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
                fontSize: 16,
                color: accentColor,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.black.withValues(alpha: 0.5)),
          ),
        ),
      ),
      body: Stack(
        children: [
          CyberGrid(accentColor: accentColor),
          SafeArea(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: accentColor, strokeWidth: 2))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Display name section
                        Row(
                          children: [
                            Icon(Icons.chevron_right, color: accentColor, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'AGENT ALIAS',
                              style: TextStyle(
                                color: accentColor.withValues(alpha: 0.5),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                            child: TextField(
                              controller: _nameController,
                              style: TextStyle(
                                fontSize: 16, 
                                color: accentColor,
                                fontFamily: 'Courier',
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: InputDecoration(
                                prefixIcon: Icon(Icons.terminal, color: accentColor.withValues(alpha: 0.4)),
                                hintText: 'Enter alias...',
                                hintStyle: TextStyle(color: accentColor.withValues(alpha: 0.2)),
                                filled: true,
                                fillColor: Colors.black.withValues(alpha: 0.5),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: accentColor.withValues(alpha: 0.2)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: accentColor),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // UID display
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            'UID: ${_auth.currentUser?.uid ?? "—"}',
                            style: TextStyle(
                              fontSize: 10,
                              color: accentColor.withValues(alpha: 0.3),
                              letterSpacing: 1,
                              fontFamily: 'Courier',
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Eco Mode section
                        Row(
                          children: [
                            Icon(Icons.battery_charging_full, color: accentColor, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'PERFORMANCE & BATTERY',
                              style: TextStyle(
                                color: accentColor.withValues(alpha: 0.5),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: accentColor.withValues(alpha: 0.2),
                                ),
                              ),
                              child: SwitchListTile(
                                title: Text(
                                  'ECO MODE',
                                  style: TextStyle(
                                    color: accentColor,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Text(
                                  'Disables animations and physics engine to save battery.',
                                  style: TextStyle(
                                    color: accentColor.withValues(alpha: 0.5),
                                    fontSize: 10,
                                  ),
                                ),
                                value: !themeProvider.animationsEnabled,
                                activeThumbColor: accentColor,
                                inactiveTrackColor: Colors.black45,
                                onChanged: (value) {
                                  themeProvider.setAnimationsEnabled(!value);
                                },
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Theme section
                        Row(
                          children: [
                            Icon(Icons.chevron_right, color: accentColor, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'INTERFACE THEME',
                              style: TextStyle(
                                color: accentColor.withValues(alpha: 0.5),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: AppThemeMode.values.map((mode) {
                            final isActive = themeProvider.currentMode == mode;
                            return GestureDetector(
                              onTap: () => themeProvider.setTheme(mode),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: isActive
                                      ? accentColor.withValues(alpha: 0.2)
                                      : Colors.black.withValues(alpha: 0.5),
                                  border: Border.all(
                                    color: isActive
                                        ? accentColor.withValues(alpha: 0.8)
                                        : accentColor.withValues(alpha: 0.2),
                                    width: isActive ? 1.5 : 1.0,
                                  ),
                                  boxShadow: isActive ? [
                                    BoxShadow(
                                      color: accentColor.withValues(alpha: 0.2),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    )
                                  ] : [],
                                ),
                                child: Text(
                                  mode.name.toUpperCase(),
                                  style: TextStyle(
                                    color: isActive
                                        ? accentColor
                                        : accentColor.withValues(alpha: 0.5),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 40),

                        // Save button
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _updateProfile,
                                splashColor: accentColor.withValues(alpha: 0.3),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: Colors.black.withValues(alpha: 0.5),
                                    border: Border.all(
                                      color: accentColor.withValues(alpha: 0.5),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '[ SAVE CONFIGURATION ]',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 2,
                                        color: accentColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
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
