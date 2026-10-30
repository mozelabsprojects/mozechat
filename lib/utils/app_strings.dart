class AppStrings {
  final String languageCode;
  AppStrings(this.languageCode);

  bool get isTr => languageCode == 'tr';

  // --- GENERAL & NAVIGATION ---
  String get appTitle => 'Mozechat';
  String get chats => isTr ? 'SOHBETLER' : 'CHATS';
  String get all => isTr ? 'TÜMÜ' : 'ALL';
  String get pinned => isTr ? 'SABİTLER' : 'PINNED';
  String get groups => isTr ? 'GRUPLAR' : 'GROUPS';
  String get searchPlaceholder => isTr ? 'Sohbetlerde ara...' : 'Search encrypted chats...';
  String get cancel => isTr ? 'İPTAL' : 'CANCEL';
  String get ok => isTr ? 'TAMAM' : 'OK';
  String get save => isTr ? 'KAYDET' : 'SAVE';
  String get delete => isTr ? 'SİL' : 'DELETE';
  String get copy => isTr ? 'KOPYALA' : 'COPY';
  String get reply => isTr ? 'YANITLA' : 'REPLY';
  String get star => isTr ? 'YILDIZLA' : 'STAR';
  String get unstar => isTr ? 'YILDIZI KALDIR' : 'UNSTAR';
  String get pin => isTr ? 'BAŞA SABİTLE' : 'PIN TO TOP';
  String get unpin => isTr ? 'SABİTİ KALDIR' : 'UNPIN';
  String get clear => isTr ? 'TEMİZLE' : 'CLEAR';
  String get connect => isTr ? 'BAĞLAN' : 'CONNECT';
  String get creator => isTr ? 'KURUCU' : 'CREATOR';

  // --- EMPTY STATES ---
  String get emptyRoomsTitle => isTr ? 'RADAR AKTİF // ODA YOK' : 'RADAR ACTIVE // NO ROOMS';
  String get emptyRoomsSubtitle => isTr
      ? 'Henüz aktif bir şifreli oda bulunmuyor. Yeni bir oda oluşturun veya bir oda koduna bağlanın.'
      : 'No active encrypted rooms found. Create a new room or connect via code.';
  String get emptySearchSubtitle => isTr ? 'Eşleşen sohbet bulunamadı.' : 'No matching chats found.';
  String get createRoomBtn => isTr ? 'YENİ ODA KUR' : 'NEW ROOM';
  String get scanQrBtn => isTr ? 'QR KOD TARA' : 'SCAN QR';

  // --- NEW ROOM MODAL ---
  String get newRoomModalTitle => isTr ? 'GÜVENLİ ODA BAĞLANTISI' : 'SECURE ROOM CONNECTION';
  String get newRoomModalSubtitle => isTr ? 'Uçtan uca şifreli odaya bağlanın veya üretin' : 'Connect to or generate an E2EE room';
  String get roomCodeInputLabel => isTr ? 'Oda Kodu / PIN' : 'Room Code / PIN';
  String get roomCodeInputHint => isTr ? 'Örn: alfa-77 veya özel kod' : 'E.g. alpha-77 or secret code';
  String get generateSecureCode => isTr ? 'Rastgele Güvenli Kod Üret' : 'Generate Secure Code';
  String get joinRoom => isTr ? 'ODAYA BAĞLAN' : 'CONNECT TO ROOM';
  String get roomCreatedToast => isTr ? 'Yeni güvenli oda kodu üretildi' : 'New secure room code generated';
  String get enterCodeWarning => isTr ? 'Lütfen bir oda kodu girin' : 'Please enter a room code';

  // --- CHAT SCREEN & ACTIONS ---
  String get typeEncryptedMsg => isTr ? 'Şifreli bir mesaj yazın...' : 'Type an encrypted message...';
  String get online => isTr ? 'ÇEVRİMİÇİ' : 'ONLINE';
  String get offline => isTr ? 'ÇEVRİMDIŞI' : 'OFFLINE';
  String get typing => isTr ? 'yazıyor...' : 'typing...';
  String get membersCount => isTr ? 'üye' : 'members';
  String get slideToCancel => isTr ? 'İptal etmek için sola kaydırın' : 'Slide left to cancel';
  String get recordingVoice => isTr ? 'Kayıt yapılıyor...' : 'Recording audio...';
  String get voiceShortWarning => isTr ? 'Ses kaydı çok kısa, basılı tutarak konuşun.' : 'Audio too short, hold to record.';
  String get panicCamouflageToast => isTr ? 'KAMUFLAJ MODU AKTİF' : 'CAMOUFLAGE MODE ACTIVE';
  String get leaveRoom => isTr ? 'Odadan Ayrıl' : 'Leave Node';
  String get mediaGallery => isTr ? 'Medya Galerisi' : 'Media Gallery';
  String get exportChat => isTr ? 'Sohbeti Dışa Aktar' : 'Export Chat';
  String get commands => isTr ? 'Komutlar' : 'Commands';
  String get copyRoomCode => isTr ? 'Oda Kodunu Kopyala' : 'Copy Room Code';
  String get panicDecoy => isTr ? 'Hesap Makinesi Kamuflajı' : 'Calculator Decoy';

  // --- TAP TO REVEAL ---
  String get tapToRevealActiveToast => isTr
      ? '👁️ TAP TO REVEAL AKTİF: Mesajları okumak için üzerlerine basılı tutun.'
      : '👁️ TAP TO REVEAL ACTIVE: Touch and hold messages to reveal.';
  String get tapToRevealHintBubble => isTr
      ? '👁️ Gizlilik Kalkanı: Mesajları okumak için üzerlerine basılı tutun.'
      : '👁️ Privacy Shield: Touch and hold messages to reveal.';

  // --- SETTINGS SCREEN ---
  String get settingsTitle => isTr ? 'AYARLAR' : 'SETTINGS';
  String get identitySection => isTr ? 'KİMLİK & GÖRÜNÜM' : 'IDENTITY & APPEARANCE';
  String get nicknameLabel => isTr ? 'KOD ADINIZ (NICKNAME)' : 'YOUR CODENAME (NICKNAME)';
  String get nicknameHint => isTr ? 'Anonim bir ad girin' : 'Enter an anonymous handle';
  String get privacySection => isTr ? 'GİZLİLİK & GÜVENLİK' : 'PRIVACY & SECURITY';
  String get tapToRevealTitle => isTr ? 'Tap to Reveal (Dokun & Göster)' : 'Tap to Reveal (Hold to Show)';
  String get tapToRevealSubtitle => isTr
      ? 'Mesajlar buğulanır; sadece basılı tutulduğunda görünür.'
      : 'Messages stay blurred; visible only while held.';
  String get panicTitle => isTr ? 'Panik Kamuflaj Modu' : 'Panic Camouflage Decoy';
  String get panicSubtitle => isTr
      ? 'Sohbet ekranında hesap makinesi kamuflajı butonunu gösterir.'
      : 'Enables quick calculator decoy in chat header.';
  String get anonymousVoiceTitle => isTr ? 'Anonim Robotik Ses' : 'Anonymous Robotic Voice';
  String get anonymousVoiceSubtitle => isTr
      ? 'Ses kayıtlarını robotik modülasyonla maskeleyerek gönderir.'
      : 'Masks audio notes with robotic pitch modulation.';
  String get languageSection => isTr ? 'DİL / LANGUAGE' : 'LANGUAGE / DİL';
  String get turkish => 'Türkçe';
  String get english => 'English';
  String get updatesSection => isTr ? 'SİSTEM GÜNCELLEMELERİ' : 'SYSTEM UPDATES';
  String get checkUpdatesBtn => isTr ? 'GÜNCELLEMELERİ DENETLE' : 'CHECK FOR UPDATES';
  String get checkingUpdates => isTr ? 'Denetleniyor...' : 'Checking...';
  String get systemUpToDate => isTr ? 'Sisteminiz güncel' : 'Your system is up to date';
  String get storageSection => isTr ? 'VERİ & DEPOLAMA' : 'DATA & STORAGE';
  String get clearCacheBtn => isTr ? 'ÖNBELLEĞİ TEMİZLE' : 'CLEAR MEDIA CACHE';
  String get cacheCleared => isTr ? 'Medya önbelleği temizlendi' : 'Media cache cleared';
  String get saveConfig => isTr ? '[ YAPILANDIRMAYI KAYDET ]' : '[ SAVE CONFIGURATION ]';
  String get configSaved => isTr ? 'Yapılandırma başarıyla kaydedildi' : 'Configuration saved successfully';
  String get developedBy => 'Developed with precision by mozelabs.com';
}
