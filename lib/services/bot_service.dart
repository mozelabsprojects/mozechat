import 'dart:async';

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

  void _reply(String msg, bool isSilent) {
    if (!isSilent) sendBotMessage(msg);
  }

  Future<void> komutCalistir(String mesaj, String gonderenId, String gonderenIsim, {bool isSilent = false}) async {
    if (!mesaj.startsWith('!')) return;
    final args = mesaj.trim().split(' ');
    final komut = args[0].toLowerCase();

    if (komut == '!help') {
      _reply(
        "🤖 MOZE BOT KOMUTLARI\n\n"
        "🔹 !clear [sayı] : Son [sayı] kadar mesajı temizler.\n"
        "🔹 !note [yazı] : Güvenli ortak not ekler.\n"
        "🔹 !notes : Eklenen notları listeler.\n"
        "🔹 !remind [yazı] [sn] : Belirtilen saniye sonra hatırlatır.\n"
        "🔹 !wipe : Ekrandaki mesaj akışını temizler.",
        isSilent,
      );
      return;
    } else if (komut == '!clear') {
      if (args.length < 2) return;
      int? count = int.tryParse(args[1]);
      if (count != null) {
        clearMessages(count);
        _reply("🧹 Son $count mesaj silindi.", isSilent);
      }
      return;
    } else if (komut == '!wipe') {
      clearMessages(50);
      _reply("🚨 [WIPE] Sohbet akışı temizlendi.", isSilent);
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
        _reply("📋 Kayıtlı not bulunamadı.", isSilent);
      } else {
        String msg = "📋 Kayıtlı Notlar:\n";
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
    }
  }
}
