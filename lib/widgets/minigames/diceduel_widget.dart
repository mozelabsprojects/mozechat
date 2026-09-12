import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../models/message.dart';
import '../../services/user_service.dart';
import 'dart:math';

class DiceDuelWidget extends StatefulWidget {
  final String roomCode;
  final Message message;

  const DiceDuelWidget({super.key, required this.roomCode, required this.message});

  @override
  State<DiceDuelWidget> createState() => _DiceDuelWidgetState();
}

class _DiceDuelWidgetState extends State<DiceDuelWidget> {
  bool _isLoading = false;

  List<String> _parseState(String text) {
    final parts = text.split('|');
    // !dice|p1Id|p2Id|hp1|hp2|turnId|status
    if (parts.length < 7) {
      return ['!dice', '', '', '100', '100', '', 'waiting'];
    }
    return parts;
  }

  String _serializeState(String p1Id, String p2Id, int hp1, int hp2, String turnId, String status) {
    return '!dice|$p1Id|$p2Id|$hp1|$hp2|$turnId|$status';
  }

  Future<void> _joinGame(String myId, List<String> parts) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    bool success = await UserService.deductCoins(myId, 50);
    if (!success) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yetersiz bakiye! (50 MC gerekli)')));
      setState(() => _isLoading = false);
      return;
    }

    String p1Id = parts[1];
    final newState = _serializeState(p1Id, myId, 100, 100, p1Id, 'playing');
    if (mounted) await context.read<ChatProvider>().editMessage(widget.message.id, newState);

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _attack(String myId, List<String> parts) async {
    if (_isLoading) return;
    
    String p1Id = parts[1];
    String p2Id = parts[2];
    int hp1 = int.parse(parts[3]);
    int hp2 = int.parse(parts[4]);
    String turnId = parts[5];
    String status = parts[6];

    if (status != 'playing' || turnId != myId) return;

    setState(() => _isLoading = true);

    int attackRoll = Random().nextInt(20) + 1;
    int defendRoll = Random().nextInt(20) + 1;
    int diff = (attackRoll - defendRoll).abs();
    
    String attackMsg = "";

    if (attackRoll > defendRoll) {
      if (myId == p1Id) {
        hp2 -= diff;
      } else {
        hp1 -= diff;
      }
      attackMsg = "Sen ($attackRoll) vs Rakip ($defendRoll). Hasar: $diff!";
    } else if (defendRoll > attackRoll) {
      if (myId == p1Id) {
        hp1 -= diff;
      } else {
        hp2 -= diff;
      }
      attackMsg = "Sen ($attackRoll) vs Rakip ($defendRoll). Saldırı tepti! Hasar: $diff.";
    } else {
      attackMsg = "Berabere ($attackRoll)! Hasar yok.";
    }

    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(attackMsg)));

    if (hp1 <= 0 || hp2 <= 0) {
      status = hp1 <= 0 ? 'p2_won' : 'p1_won';
      String winnerId = hp1 <= 0 ? p2Id : p1Id;
      await UserService.addCoins(winnerId, 100);
    } else {
      turnId = myId == p1Id ? p2Id : p1Id;
    }

    final newState = _serializeState(p1Id, p2Id, hp1, hp2, turnId, status);
    if (mounted) await context.read<ChatProvider>().editMessage(widget.message.id, newState);

    if (mounted) setState(() => _isLoading = false);
  }

  Widget _buildHpBar(String title, int hp, bool isMyTurn) {
    double hpPercent = max(0, hp) / 100.0;
    Color barColor = hp > 50 ? Colors.green : (hp > 20 ? Colors.orange : Colors.red);
    return Column(
      children: [
        Text(title, style: TextStyle(color: isMyTurn ? Colors.amber : Colors.white70, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Container(
          width: 120,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white24),
          ),
          child: Stack(
            children: [
              FractionallySizedBox(
                widthFactor: hpPercent,
                child: Container(
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Center(child: Text("$hp HP", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final myId = chatProvider.currentUserId;
    if (myId == null) return const SizedBox.shrink();

    final parts = _parseState(widget.message.text);
    final p1Id = parts[1];
    final p2Id = parts[2];
    final hp1 = int.parse(parts[3]);
    final hp2 = int.parse(parts[4]);
    final turnId = parts[5];
    final status = parts[6];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E213A), // Dark blue
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.5), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.casino, color: Colors.blueAccent),
              const SizedBox(width: 8),
              const Text("DICEDUEL", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 2)),
              const SizedBox(width: 8),
              const Icon(Icons.casino, color: Colors.blueAccent),
            ],
          ),
          const SizedBox(height: 12),
          
          if (status == 'waiting') ...[
            if (p1Id == myId) ...[
              const Text("Giriş Ücreti: 50 MC ödendi.", style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              const CircularProgressIndicator(color: Colors.blueAccent),
              const SizedBox(height: 8),
              const Text("Rakip bekleniyor...", style: TextStyle(color: Colors.white70)),
            ] else ...[
              const Text("Ödül: 100 MC", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _isLoading ? null : () => _joinGame(myId, parts),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                child: const Text("50 MC ile Katıl"),
              ),
            ]
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildHpBar(p1Id == myId ? "Sen" : "Oyuncu 1", hp1, turnId == p1Id),
                const Text("VS", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                _buildHpBar(p2Id == myId ? "Sen" : "Oyuncu 2", hp2, turnId == p2Id),
              ],
            ),
            const SizedBox(height: 16),
            
            if (status == 'playing') ...[
              if (turnId == myId)
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : () => _attack(myId, parts),
                  icon: const Icon(Icons.sports_kabaddi),
                  label: const Text("SALDIR (1-20 Zar At)"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                )
              else
                const Text("Rakibin saldırması bekleniyor...", style: TextStyle(color: Colors.amber)),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  status == 'p1_won' ? "🏆 OYUNCU 1 KAZANDI (100 MC)" : "🏆 OYUNCU 2 KAZANDI (100 MC)",
                  style: const TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ]
          ],
        ],
      ),
    );
  }
}
