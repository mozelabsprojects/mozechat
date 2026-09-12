import 'dart:math';
import 'dart:async';
import 'user_service.dart';

class BotService {
  final Function(String message) sendBotMessage;
  final Function(int n) clearMessages;
  final Function(String note) addNote;
  final List<String> Function() getNotes;
  final Function(String message, int seconds) scheduleReminder;

  BotService({
    required this.sendBotMessage,
    required this.clearMessages,
    required this.addNote,
    required this.getNotes,
    required this.scheduleReminder,
  });

  final Map<String, Map<String, dynamic>> _activeGames = {};

  void _reply(String msg, bool isSilent) {
    if (!isSilent) sendBotMessage(msg);
  }

  int _drawCard() => Random().nextInt(10) + 2;

  Future<void> _startBlackjack(String userId, String userName, int bet) async {
    bool deducted = await UserService.deductCoins(userId, bet);
    if (!deducted) {
      _reply("⚠️ Yeterli MozeCoin'iniz yok.", false);
      return;
    }
    
    int p1 = _drawCard() + _drawCard();
    int b1 = _drawCard();

    _activeGames[userId] = {
      'game': 'bj',
      'bet': bet,
      'player': p1,
      'bot': b1,
    };

    _reply("🃏 Blackjack başladı!\nSizin Eliniz: $p1\nBotun Açık Kartı: $b1\n\nHamleniz nedir? (!hit veya !stand)", false);
  }


  Future<void> komutCalistir(String mesaj, String gonderenId, String gonderenIsim, {bool isSilent = false}) async {
    if (!mesaj.startsWith('!')) return;
    final args = mesaj.trim().split(' ');
    final komut = args[0].toLowerCase();

    if (komut == '!help') {
      _reply("🤖 Moze Bot\n\nSistem:\n🔹 !clear [sayı] : Mesaj siler.\n🔹 !note [yazı] : Not ekler.\n🔹 !notes : Notları gösterir.\n🔹 !remind [yazı] [sn] : Alarm.\n🔹 !daily : Günlük ödül.\n🔹 !coin : Bakiye.\n\nOyunlar:\n🔹 !gamedetails : Oyun komutları.\n🔹 !play bj [bahis] : Blackjack başlatır.", isSilent);
      return;
    } else if (komut == '!clear') {
      if (args.length < 2) return;
      int? count = int.tryParse(args[1]);
      if (count != null) {
        clearMessages(count);
        _reply("🧹 Son $count mesaj silindi.", isSilent);
      }
      return;
    } else if (komut == '!note') {
      if (args.length < 2) return;
      final noteMsg = args.sublist(1).join(" ");
      addNote(noteMsg);
      _reply("📌 Not eklendi: \"$noteMsg\"", isSilent);
      return;
    } else if (komut == '!notes') {
      final notes = getNotes();
      if (notes.isEmpty) {
        _reply("📋 Not bulunamadı.", isSilent);
      } else {
        String msg = "📋 Ortak Notlar:\n";
        for (int i = 0; i < notes.length; i++) {
          msg += "${i + 1}. ${notes[i]}\n";
        }
        _reply(msg.trimRight(), isSilent);
      }
      return;
    } else if (komut == '!remind') {
      if (args.length < 3) return;
      int? secs = int.tryParse(args.last);
      if (secs != null) {
        final reminderMsg = args.sublist(1, args.length - 1).join(" ");
        scheduleReminder(reminderMsg, secs);
        _reply("⏰ $secs saniye sonra hatırlatılacak: \"$reminderMsg\"", isSilent);
      }
      return;
    } else if (komut == '!coin') {
      if (!isSilent) {
        final coins = await UserService.getCoins(gonderenId);
        _reply("💎 $gonderenIsim, bakiyen: $coins MozeCoin.", isSilent);
      }
      return;
    } else if (komut == '!daily') {
      if (!isSilent) {
        final res = await UserService.claimDaily(gonderenId);
        if (res['success'] == true) {
          _reply("🚀 100 MozeCoin eklendi! Bakiye: ${res['newBalance']} 💎", isSilent);
        } else {
          _reply("⚠️ ${res['hoursLeft']} saat sonra tekrar gel $gonderenIsim.", isSilent);
        }
      }
      return;
    }

    // 2. OYUN LOBISI
    if (komut == '!gamedetails' || komut == '!game') {
      _reply("🎮 Moze Games\n\nOyunlar:\n🃏 Blackjack (!play bj [bahis])", isSilent);
      return;
    } else if (komut == '!play') {
      if (args.length < 3) {
        _reply("⚠️ Kullanım: !play [bj/dice] [bahis]", isSilent);
        return;
      }
      final gameName = args[1].toLowerCase();
      int? bet = int.tryParse(args[2]);

      if (bet == null || bet <= 0) {
        _reply("⚠️ Geçerli bir bahis girin.", isSilent);
        return;
      }

      if (gameName == 'bj' || gameName == 'blackjack') {
        await _startBlackjack(gonderenId, gonderenIsim, bet);
      } else {
        _reply("⚠️ Bilinmeyen oyun. Sadece 'bj' (blackjack) oynanabilir.", isSilent);
      }
      return;
    } else if (komut == '!hit') {
      final state = _activeGames[gonderenId];
      if (state == null || state['game'] != 'bj') return;
      int card = _drawCard();
      state['player'] += card;
      int p = state['player'];
      if (p > 21) {
        _reply("🃏 Kart çektin: $card. Toplam: $p\n\n💥 BUST! Kaybettin.", isSilent);
        _activeGames.remove(gonderenId);
      } else {
        _reply("🃏 Kart çektin: $card. Toplam: $p\n\n!hit veya !stand?", isSilent);
      }
      return;
    } else if (komut == '!stand') {
      final state = _activeGames[gonderenId];
      if (state == null || state['game'] != 'bj') return;
      int p = state['player'];
      int b = state['bot'];
      
      while (b < 17) {
        b += _drawCard();
      }

      int bet = state['bet'];
      _activeGames.remove(gonderenId);

      if (b > 21) {
        await UserService.addCoins(gonderenId, bet * 2);
        _reply("🃏 Bot El: $b\n\n💥 Bot BUST oldu! Kazandın! +${bet*2} MozeCoin", isSilent);
      } else if (p > b) {
        await UserService.addCoins(gonderenId, bet * 2);
        _reply("🃏 Sen: $p 🆚 Bot: $b\n\n🎉 Kazandın! +${bet*2} MozeCoin", isSilent);
      } else if (p < b) {
        _reply("🃏 Sen: $p 🆚 Bot: $b\n\n💀 Kaybettin! -$bet MozeCoin", isSilent);
      } else {
        await UserService.addCoins(gonderenId, bet);
        _reply("🃏 Sen: $p 🆚 Bot: $b\n\n🤝 Berabere! Paranı geri aldın.", isSilent);
      }
      return;
    }
  }
}
