import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../models/message.dart';
import '../../services/user_service.dart';
import 'dart:math';

class MozemineWidget extends StatefulWidget {
  final String roomCode;
  final Message message;

  const MozemineWidget({super.key, required this.roomCode, required this.message});

  @override
  State<MozemineWidget> createState() => _MozemineWidgetState();
}

class _MozemineWidgetState extends State<MozemineWidget> {
  bool _isLoading = false;

  List<String> _parseState(String text) {
    final parts = text.split('|');
    // !mine|p1Id|p2Id|mines|clicked|turnId|status
    if (parts.length < 7) {
      return ['!mine', '', '', '', '', '', 'waiting'];
    }
    return parts;
  }

  String _serializeState(String p1Id, String p2Id, List<String> mines, List<String> clicked, String turnId, String status) {
    return '!mine|$p1Id|$p2Id|${mines.join(',')}|${clicked.join(',')}|$turnId|$status';
  }

  Future<void> _joinGame(String myId, List<String> parts) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    // Fixed 50 MC bet for zero-sum economy
    bool success = await UserService.deductCoins(myId, 50);
    if (!success) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yetersiz bakiye! (50 MC gerekli)')));
      setState(() => _isLoading = false);
      return;
    }

    String p1Id = parts[1];
    
    List<int> mineIndices = [];
    while (mineIndices.length < 2) {
      int r = Random().nextInt(10);
      if (!mineIndices.contains(r)) mineIndices.add(r);
    }

    final newState = _serializeState(p1Id, myId, mineIndices.map((e) => e.toString()).toList(), [], p1Id, 'playing');
    if (mounted) await context.read<ChatProvider>().editMessage(widget.message.id, newState);

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _makeMove(int index, String myId, List<String> parts) async {
    if (_isLoading) return;
    
    String p1Id = parts[1];
    String p2Id = parts[2];
    List<String> mines = parts[3].split(',').where((e) => e.isNotEmpty).toList();
    List<String> clicked = parts[4].split(',').where((e) => e.isNotEmpty).toList();
    String turnId = parts[5];
    String status = parts[6];

    if (status != 'playing' || turnId != myId || clicked.contains(index.toString())) return;

    setState(() => _isLoading = true);

    clicked.add(index.toString());
    
    if (mines.contains(index.toString())) {
      status = myId == p1Id ? 'p2_won' : 'p1_won';
      String winnerId = myId == p1Id ? p2Id : p1Id;
      await UserService.addCoins(winnerId, 100);
    } else {
      turnId = myId == p1Id ? p2Id : p1Id;
    }

    final newState = _serializeState(p1Id, p2Id, mines, clicked, turnId, status);
    if (mounted) await context.read<ChatProvider>().editMessage(widget.message.id, newState);

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final myId = chatProvider.currentUserId;
    if (myId == null) return const SizedBox.shrink();

    final parts = _parseState(widget.message.text);
    final p1Id = parts[1];
    final p2Id = parts[2];
    final mines = parts[3].split(',').where((e) => e.isNotEmpty).toList();
    final clicked = parts[4].split(',').where((e) => e.isNotEmpty).toList();
    final turnId = parts[5];
    final status = parts[6];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2C1A1A), // Dark red tint
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.dangerous, color: Colors.redAccent),
              const SizedBox(width: 8),
              const Text("MOZEMINE", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 2)),
              const SizedBox(width: 8),
              const Icon(Icons.dangerous, color: Colors.redAccent),
            ],
          ),
          const SizedBox(height: 8),
          
          if (status == 'waiting') ...[
            if (p1Id == myId) ...[
              const Text("Giriş Ücreti: 50 MC ödendi.", style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              const CircularProgressIndicator(color: Colors.redAccent),
              const SizedBox(height: 8),
              const Text("Rakip bekleniyor...", style: TextStyle(color: Colors.white70)),
            ] else ...[
              const Text("Ödül: 100 MC", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _isLoading ? null : () => _joinGame(myId, parts),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                child: const Text("50 MC ile Katıl"),
              ),
            ]
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(p1Id == myId ? "Sen" : "Oyuncu 1", style: TextStyle(color: turnId == p1Id ? Colors.amber : Colors.white70, fontWeight: FontWeight.bold)),
                const Text("  vs  ", style: TextStyle(color: Colors.white54)),
                Text(p2Id == myId ? "Sen" : "Oyuncu 2", style: TextStyle(color: turnId == p2Id ? Colors.amber : Colors.white70, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            
            if (status == 'playing')
              Text(
                turnId == myId ? "Sıra Sende! Güvenli bir kutu seç." : "Rakibin hamlesi bekleniyor...",
                style: TextStyle(color: turnId == myId ? Colors.amber : Colors.white54, fontWeight: FontWeight.bold),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  status == 'p1_won' ? "🏆 OYUNCU 1 KAZANDI (100 MC)" : "🏆 OYUNCU 2 KAZANDI (100 MC)",
                  style: const TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: 10,
              itemBuilder: (context, index) {
                bool isClicked = clicked.contains(index.toString());
                bool isMine = mines.contains(index.toString());
                bool showMine = isClicked && isMine || (status != 'playing' && isMine);
                
                return GestureDetector(
                  onTap: () => _makeMove(index, myId, parts),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isClicked 
                          ? (isMine ? Colors.red : Colors.green.withValues(alpha: 0.3))
                          : Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Center(
                      child: Text(
                        showMine ? '💣' : (isClicked ? '✔️' : '${index + 1}'),
                        style: TextStyle(
                          fontSize: showMine ? 24 : 18, 
                          fontWeight: FontWeight.bold,
                          color: isClicked ? Colors.white : Colors.white70,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
