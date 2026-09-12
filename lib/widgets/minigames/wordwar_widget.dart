import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../models/message.dart';
import '../../services/user_service.dart';
import 'dart:math';

class WordWarWidget extends StatefulWidget {
  final String roomCode;
  final Message message;

  const WordWarWidget({super.key, required this.roomCode, required this.message});

  @override
  State<WordWarWidget> createState() => _WordWarWidgetState();
}

class _WordWarWidgetState extends State<WordWarWidget> {
  bool _isLoading = false;
  final TextEditingController _wordController = TextEditingController();

  @override
  void dispose() {
    _wordController.dispose();
    super.dispose();
  }

  List<String> _parseState(String text) {
    final parts = text.split('|');
    // !ww|p1Id|p2Id|category|turnId|usedWords|status
    if (parts.length < 7) {
      return ['!ww', '', '', '', '', '', 'waiting'];
    }
    return parts;
  }

  String _serializeState(String p1Id, String p2Id, String category, String turnId, List<String> usedWords, String status) {
    return '!ww|$p1Id|$p2Id|$category|$turnId|${usedWords.join(',')}|$status';
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
    List<String> categories = ["Gezegenler", "Araba Markaları", "Meyveler", "Ülkeler", "Hayvanlar", "Renkler", "Spor Dalları"];
    String category = categories[Random().nextInt(categories.length)];

    final newState = _serializeState(p1Id, myId, category, p1Id, [], 'playing');
    if (mounted) await context.read<ChatProvider>().editMessage(widget.message.id, newState);

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _submitWord(String myId, List<String> parts) async {
    String word = _wordController.text.trim().toLowerCase();
    if (word.isEmpty || _isLoading) return;

    String p1Id = parts[1];
    String p2Id = parts[2];
    String category = parts[3];
    String turnId = parts[4];
    List<String> usedWords = parts[5].split(',').where((e) => e.isNotEmpty).toList();
    String status = parts[6];

    if (status != 'playing' || turnId != myId) return;

    setState(() => _isLoading = true);

    if (usedWords.contains(word)) {
      status = myId == p1Id ? 'p2_won' : 'p1_won';
      String winnerId = myId == p1Id ? p2Id : p1Id;
      await UserService.addCoins(winnerId, 100);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("'$word' daha önce kullanıldı! Kaybettin.")));
    } else {
      usedWords.add(word);
      turnId = myId == p1Id ? p2Id : p1Id;
      _wordController.clear();
    }

    final newState = _serializeState(p1Id, p2Id, category, turnId, usedWords, status);
    if (mounted) await context.read<ChatProvider>().editMessage(widget.message.id, newState);

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _claimTimeout(String myId, List<String> parts) async {
    if (_isLoading) return;
    
    String p1Id = parts[1];
    String p2Id = parts[2];
    String category = parts[3];
    String turnId = parts[4];
    List<String> usedWords = parts[5].split(',').where((e) => e.isNotEmpty).toList();
    String status = parts[6];

    if (status != 'playing' || turnId == myId) return;

    setState(() => _isLoading = true);

    status = myId == p1Id ? 'p1_won' : 'p2_won';
    await UserService.addCoins(myId, 100);

    final newState = _serializeState(p1Id, p2Id, category, turnId, usedWords, status);
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
    final category = parts[3];
    final turnId = parts[4];
    final usedWords = parts[5].split(',').where((e) => e.isNotEmpty).toList();
    final status = parts[6];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1B38), // Dark purple
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.5), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.rocket_launch, color: Colors.purpleAccent),
              const SizedBox(width: 8),
              const Text("WORD WAR", style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 2)),
              const SizedBox(width: 8),
              const Icon(Icons.rocket_launch, color: Colors.purpleAccent),
            ],
          ),
          const SizedBox(height: 12),
          
          if (status == 'waiting') ...[
            if (p1Id == myId) ...[
              const Text("Giriş Ücreti: 50 MC ödendi.", style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              const CircularProgressIndicator(color: Colors.purpleAccent),
              const SizedBox(height: 8),
              const Text("Rakip bekleniyor...", style: TextStyle(color: Colors.white70)),
            ] else ...[
              const Text("Ödül: 100 MC", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _isLoading ? null : () => _joinGame(myId, parts),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent, foregroundColor: Colors.white),
                child: const Text("50 MC ile Katıl"),
              ),
            ]
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(8)),
              child: Text("Kategori: $category", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(p1Id == myId ? "Sen" : "Oyuncu 1", style: TextStyle(color: turnId == p1Id ? Colors.amber : Colors.white70, fontWeight: FontWeight.bold)),
                const Text("  vs  ", style: TextStyle(color: Colors.white54)),
                Text(p2Id == myId ? "Sen" : "Oyuncu 2", style: TextStyle(color: turnId == p2Id ? Colors.amber : Colors.white70, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            
            if (usedWords.isNotEmpty) ...[
              const Text("Kullanılan Kelimeler:", style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: usedWords.map((w) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                  child: Text(w, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                )).toList(),
              ),
              const SizedBox(height: 16),
            ],
            
            if (status == 'playing') ...[
              if (turnId == myId) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _wordController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Kelime girin...",
                          hintStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.black26,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        ),
                        onSubmitted: (_) => _submitWord(myId, parts),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isLoading ? null : () => _submitWord(myId, parts),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
                      child: const Icon(Icons.send, color: Colors.white),
                    ),
                  ],
                ),
              ] else ...[
                const Text("Rakibin kelime girmesi bekleniyor...", style: TextStyle(color: Colors.amber)),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _isLoading ? null : () => _claimTimeout(myId, parts),
                  icon: const Icon(Icons.timer_off, size: 16),
                  label: const Text("Süre Bitti (Kazan)"),
                  style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                ),
              ],
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
