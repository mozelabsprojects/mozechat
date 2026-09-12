import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../models/message.dart';
import '../../services/user_service.dart';
import 'dart:math';

class BlackjackWidget extends StatefulWidget {
  final String roomCode;
  final Message message;

  const BlackjackWidget({super.key, required this.roomCode, required this.message});

  @override
  State<BlackjackWidget> createState() => _BlackjackWidgetState();
}

class _BlackjackWidgetState extends State<BlackjackWidget> {
  bool _isLoading = false;

  List<String> _parseState(String text) {
    final parts = text.split('|');
    // !bj|p1Id|p2Id|bet|deck|p1Hand|p2Hand|turnId|status
    if (parts.length < 9) {
      return ['!bj', '', '', '0', '', '', '', '', 'waiting'];
    }
    return parts;
  }

  String _serializeState(String p1Id, String p2Id, int bet, List<String> deck, List<String> p1Hand, List<String> p2Hand, String turnId, String status) {
    return '!bj|$p1Id|$p2Id|$bet|${deck.join(',')}|${p1Hand.join(',')}|${p2Hand.join(',')}|$turnId|$status';
  }

  List<String> _generateDeck() {
    List<String> suits = ['♦️', '♣️', '♥️', '♠️'];
    List<String> ranks = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A'];
    List<String> deck = [];
    for (var s in suits) {
      for (var r in ranks) {
        deck.add('$s$r');
      }
    }
    deck.shuffle(Random());
    return deck;
  }

  int _calcHand(List<String> hand) {
    int total = 0;
    int aces = 0;
    for (var card in hand) {
      if (card.isEmpty) continue;
      String rank = card.substring(2);
      if (['J', 'Q', 'K'].contains(rank)) {
        total += 10;
      } else if (rank == 'A') {
        aces++;
        total += 11;
      } else {
        total += int.tryParse(rank) ?? 0;
      }
    }
    while (total > 21 && aces > 0) {
      total -= 10;
      aces--;
    }
    return total;
  }

  Future<void> _setBet(int betAmount, String myId, List<String> parts) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    bool success = await UserService.deductCoins(myId, betAmount);
    if (!success) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yetersiz bakiye!')));
      setState(() => _isLoading = false);
      return;
    }

    final newState = _serializeState(parts[1], parts[2], betAmount, [], [], [], '', 'waiting');
    if (mounted) await context.read<ChatProvider>().editMessage(widget.message.id, newState);
    
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _joinGame(String myId, List<String> parts) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    int betAmount = int.parse(parts[3]);
    if (betAmount > 0) {
      bool success = await UserService.deductCoins(myId, betAmount);
      if (!success) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yetersiz bakiye!')));
        setState(() => _isLoading = false);
        return;
      }
    }

    List<String> deck = _generateDeck();
    List<String> p1Hand = [deck.removeLast(), deck.removeLast()];
    List<String> p2Hand = [deck.removeLast(), deck.removeLast()];

    final newState = _serializeState(parts[1], myId, betAmount, deck, p1Hand, p2Hand, parts[1], 'playing');
    if (mounted) await context.read<ChatProvider>().editMessage(widget.message.id, newState);

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _hit(String myId, List<String> parts) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    String p1Id = parts[1];
    String p2Id = parts[2];
    int bet = int.parse(parts[3]);
    List<String> deck = parts[4].split(',').where((e) => e.isNotEmpty).toList();
    List<String> p1Hand = parts[5].split(',').where((e) => e.isNotEmpty).toList();
    List<String> p2Hand = parts[6].split(',').where((e) => e.isNotEmpty).toList();
    String turnId = parts[7];
    String status = parts[8];

    if (deck.isEmpty) deck = _generateDeck();
    String newCard = deck.removeLast();

    if (myId == p1Id) {
      p1Hand.add(newCard);
      if (_calcHand(p1Hand) > 21) {
        status = 'p2_won';
        await UserService.addCoins(p2Id, bet * 2);
      }
    } else {
      p2Hand.add(newCard);
      if (_calcHand(p2Hand) > 21) {
        status = 'p1_won';
        await UserService.addCoins(p1Id, bet * 2);
      }
    }

    final newState = _serializeState(p1Id, p2Id, bet, deck, p1Hand, p2Hand, status == 'playing' ? turnId : '', status);
    if (mounted) await context.read<ChatProvider>().editMessage(widget.message.id, newState);

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _stand(String myId, List<String> parts) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    String p1Id = parts[1];
    String p2Id = parts[2];
    int bet = int.parse(parts[3]);
    List<String> deck = parts[4].split(',');
    List<String> p1Hand = parts[5].split(',');
    List<String> p2Hand = parts[6].split(',');
    String status = parts[8];

    if (myId == p1Id) {
      // P1 stands, turn to P2
      final newState = _serializeState(p1Id, p2Id, bet, deck, p1Hand, p2Hand, p2Id, 'playing');
      if (mounted) await context.read<ChatProvider>().editMessage(widget.message.id, newState);
    } else {
      // P2 stands, game over
      int p1Score = _calcHand(p1Hand);
      int p2Score = _calcHand(p2Hand);

      if (p1Score > p2Score) {
        status = 'p1_won';
        await UserService.addCoins(p1Id, bet * 2);
      } else if (p2Score > p1Score) {
        status = 'p2_won';
        await UserService.addCoins(p2Id, bet * 2);
      } else {
        status = 'draw';
        await UserService.addCoins(p1Id, bet);
        await UserService.addCoins(p2Id, bet);
      }

      final newState = _serializeState(p1Id, p2Id, bet, deck, p1Hand, p2Hand, '', status);
      if (mounted) await context.read<ChatProvider>().editMessage(widget.message.id, newState);
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Widget _buildHand(String title, List<String> hand, bool isActive) {
    return Column(
      children: [
        Text(title, style: TextStyle(color: isActive ? Colors.amber : Colors.white70, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: hand.map((card) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.black26),
            ),
            child: Text(
              card,
              style: TextStyle(
                color: (card.startsWith('♥️') || card.startsWith('♦️')) ? Colors.red : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          )).toList(),
        ),
        const SizedBox(height: 4),
        Text("Toplam: ${_calcHand(hand)}", style: const TextStyle(color: Colors.white54, fontSize: 12)),
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
    final bet = int.parse(parts[3]);
    final p1Hand = parts[5].split(',').where((e) => e.isNotEmpty).toList();
    final p2Hand = parts[6].split(',').where((e) => e.isNotEmpty).toList();
    final turnId = parts[7];
    final status = parts[8];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A2F), // Casino green
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.5), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.casino, color: Colors.amber),
              const SizedBox(width: 8),
              const Text("BLACKJACK", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 2)),
              const SizedBox(width: 8),
              const Icon(Icons.casino, color: Colors.amber),
            ],
          ),
          const SizedBox(height: 12),
          if (status == 'waiting') ...[
            if (p1Id == myId && bet == 0) ...[
              const Text("Bahis Seçin", style: TextStyle(color: Colors.white)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [50, 100, 500].map((b) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : () => _setBet(b, myId, parts),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                    child: Text("$b MC"),
                  ),
                )).toList(),
              ),
            ] else if (p1Id == myId && bet > 0) ...[
              Text("Bahis: $bet MC", style: const TextStyle(color: Colors.amber, fontSize: 16)),
              const SizedBox(height: 8),
              const CircularProgressIndicator(color: Colors.amber),
              const SizedBox(height: 8),
              const Text("Rakip bekleniyor...", style: TextStyle(color: Colors.white70)),
            ] else if (p1Id != myId && bet > 0) ...[
              Text("Bahis: $bet MC", style: const TextStyle(color: Colors.amber, fontSize: 16)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _isLoading ? null : () => _joinGame(myId, parts),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
                child: const Text("Oyuna Katıl"),
              ),
            ]
          ] else ...[
            Text("Bahis Havuzu: ${bet * 2} MC", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            
            _buildHand(p1Id == myId ? "Sen (P1)" : "Oyuncu 1", p1Hand, turnId == p1Id),
            const SizedBox(height: 16),
            const Text("VS", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildHand(p2Id == myId ? "Sen (P2)" : "Oyuncu 2", p2Hand, turnId == p2Id),
            
            const SizedBox(height: 16),
            if (status == 'playing') ...[
              if (turnId == myId)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: _isLoading ? null : () => _hit(myId, parts),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      child: const Text("Kart Çek"),
                    ),
                    ElevatedButton(
                      onPressed: _isLoading ? null : () => _stand(myId, parts),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                      child: const Text("Bekle"),
                    ),
                  ],
                )
              else
                const Text("Rakibin hamlesi bekleniyor...", style: TextStyle(color: Colors.amber)),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  status == 'draw' ? "🤝 BERABERE! Bahisler iade edildi." :
                  status == 'p1_won' ? "🏆 OYUNCU 1 KAZANDI!" : "🏆 OYUNCU 2 KAZANDI!",
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
