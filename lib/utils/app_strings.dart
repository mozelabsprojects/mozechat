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
  String get pinnedBadge => isTr ? 'SABİT' : 'PINNED';
  String get searchPlaceholder => isTr ? 'Şifreli sohbetlerde ara...' : 'Search encrypted chats...';
  String get cancel => isTr ? 'İPTAL' : 'CANCEL';
  String get close => isTr ? 'KAPAT' : 'CLOSE';
  String get apply => isTr ? 'UYGULA' : 'APPLY';
  String get ok => isTr ? 'TAMAM' : 'OK';
  String get save => isTr ? 'KAYDET' : 'SAVE';
  String get delete => isTr ? 'SİL' : 'DELETE';
  String get copy => isTr ? 'KOPYALA' : 'COPY';
  String get share => isTr ? 'PAYLAŞ' : 'SHARE';
  String get reply => isTr ? 'YANITLA' : 'REPLY';
  String get star => isTr ? 'YILDIZLA' : 'STAR';
  String get unstar => isTr ? 'YILDIZI KALDIR' : 'UNSTAR';
  String get pin => isTr ? 'BAŞA SABİTLE' : 'PIN TO TOP';
  String get unpin => isTr ? 'SABİTİ KALDIR' : 'UNPIN';
  String get clear => isTr ? 'TEMİZLE' : 'CLEAR';
  String get connect => isTr ? 'BAĞLAN' : 'CONNECT';
  String get creator => isTr ? 'KURUCU' : 'CREATOR';
  String get logout => isTr ? 'ÇIKIŞ YAP' : 'LOG OUT';
  String get notLoggedIn => isTr ? 'Oturum açılmadı' : 'Not logged in';
  String get errorPrefix => isTr ? 'HATA' : 'ERROR';
  String get calculating => isTr ? 'Hesaplanıyor...' : 'Calculating...';

  // --- LOGIN & IDENTITY RECOVERY ---
  String loginSubtitle(bool isRestore) => isRestore
      ? (isTr ? 'KİMLİK KURTARMA SİSTEMİ' : 'IDENTITY RECOVERY SYSTEM')
      : (isTr ? 'ANONİM ŞİFRELİ İLETİŞİM AĞI' : 'ANONYMOUS ENCRYPTED RELAY');
  String get agentAliasLabel => isTr ? 'KOD ADINIZ (NICKNAME)' : 'AGENT ALIAS';
  String get agentAliasHint => isTr ? 'Örn: ghost_rider' : 'e.g. ghost_rider';
  String get recoveryKeyLabel => isTr ? 'KURTARMA ANAHTARI (12 KELİME)' : 'RECOVERY KEY (12 WORDS)';
  String get recoveryKeyHint => isTr
      ? '12 kelimelik gizli yedekleme anahtarınızı aralarında boşluk bırakarak girin'
      : 'Enter your secret twelve-word backup phrase separated by spaces';
  String get initNodeBtn => isTr ? '[ YENİ KİMLİK OLUŞTUR ]' : '[ INITIALIZE NEW IDENTITY ]';
  String get restoreIdentityBtn => isTr ? '[ KİMLİĞİ GERİ YÜKLE ]' : '[ RESTORE IDENTITY ]';
  String get restoreExistingBtn => isTr ? 'MEVCUT KİMLİĞİ GERİ YÜKLE' : 'RESTORE EXISTING IDENTITY';
  String get cancelRestoreBtn => isTr ? 'KURTARMAYI İPTAL ET' : 'CANCEL RESTORE';
  String get e2eBadge => isTr ? 'UÇTAN UCA ŞİFRELİ • ANONİM' : 'E2E ENCRYPTED • ANONYMOUS';
  String get initFailed => isTr ? 'Oturum başlatılamadı' : 'Initialization failed';
  String get restoreFailed => isTr ? 'Kimlik geri yüklenemedi' : 'Restore failed';
  String get criticalBackupTitle => isTr ? 'KRİTİK YEDEKLEME' : 'CRITICAL BACKUP';
  String get criticalBackupSubtitle => isTr
      ? 'Bu 12 kelimelik kurtarma anahtarını güvenli bir yere kaydedin. Uygulamayı silerseniz kimliğinizi ve mesajlarınızı geri yüklemenin TEK yolu budur.'
      : 'Save this 12-word seed phrase securely. If you uninstall the app, this is the ONLY way to restore your identity and messages.';
  String get copyToClipboard => isTr ? 'PANOYA KOPYALA' : 'COPY TO CLIPBOARD';
  String get copiedToClipboard => isTr ? 'Panoya kopyalandı' : 'Copied to clipboard';
  String get iHaveSavedIt => isTr ? 'KAYDETTİM, DEVAM ET' : 'I HAVE SAVED IT';

  // --- ROOMS LIST & EMPTY STATES ---
  String get emptyRoomsTitle => isTr ? '// GÜVENLİ İLETİŞİM AĞI //' : '// SECURE RELAY NETWORK //';
  String get emptyRoomsSubtitle => isTr
      ? 'Aktif bir şifreli oda bulunmuyor. Yeni bir güvenli oda oluşturun veya QR ile bağlanın.'
      : 'No active encrypted rooms found. Create a new secure room or connect via QR.';
  String get noMatchingChatsTitle => isTr ? 'EŞLEŞEN SOHBET BULUNAMADI' : 'NO MATCHING CHATS FOUND';
  String get resetFiltersSubtitle => isTr
      ? 'Filtrelemeyi sıfırlamak için arama veya filtre kapsüllerine dokunun.'
      : 'Tap below to reset your active search or filter criteria.';
  String get resetFiltersBtn => isTr ? 'FİLTRELERİ SIFIRLA' : 'RESET FILTERS';
  String get createRoomBtn => isTr ? 'YENİ ODA OLUŞTUR' : 'CREATE NEW ROOM';
  String get scanQrBtn => isTr ? 'QR KOD TARA' : 'SCAN QR CODE';
  String get scanQrSubtitle => isTr
      ? 'Kamerayı açarak arkadaşınızın QR kodunu okutun'
      : 'Open camera to scan your friend\'s room QR code';
  String get createQrRoomTitle => isTr ? 'YENİ ODA QR\'I OLUŞTUR' : 'GENERATE NEW ROOM QR';
  String get createQrRoomSubtitle => isTr
      ? 'Arkadaşınızın taraması için yeni bir oda kodu ve QR oluşturun'
      : 'Generate a fresh room code and QR for a friend to scan';
  String get newSecureRoomTitle => isTr ? 'YENİ GÜVENLİ ODA' : 'NEW SECURE ROOM';
  String get roomQrTitle => isTr ? 'GÜVENLİ ODA QR KODU' : 'SECURE ROOM QR CODE';
  String get qrDialogSubtitle => isTr
      ? 'Arkadaşınız bu kodu kamerasıyla taratarak anında odaya katılabilir.'
      : 'Your friend can scan this QR code to join the encrypted room instantly.';
  String qrShareText(String code) => isTr
      ? 'Mozechat üzerinden uçtan uca şifreli odama katıl: $code'
      : 'Join my end-to-end encrypted room on Mozechat: $code';
  String get qrShareSubject => isTr ? 'Mozechat Güvenli Oda Daveti' : 'Mozechat Secure Room Invite';
  String get qrCodeTooltip => isTr ? 'QR İşlemleri' : 'QR Options';
  String get alignQrInstruction => isTr
      ? 'Arkadaşınızın Mozechat QR kodunu bu alana hizalayın'
      : 'Align your friend\'s Mozechat QR code within the frame';
  String get networkDataError => isTr ? 'AĞ VERİSİ ALINAMADI' : 'FAILED TO FETCH NETWORK DATA';

  // --- ROOM CONTEXT MENU & ALIAS ---
  String get pinChat => isTr ? 'Sohbeti Başa Sabitle' : 'Pin Chat to Top';
  String get unpinChat => isTr ? 'Sohbet Sabitlemesini Kaldır' : 'Unpin Chat';
  String get setCustomAliasTitle => isTr ? 'Özel İsim / Takma Ad Ver' : 'Set Custom Alias / Name';
  String customAliasSubtitle(String currentAlias) => currentAlias.isNotEmpty
      ? (isTr ? 'Mevcut: $currentAlias' : 'Current: $currentAlias')
      : (isTr ? 'Yalnızca sizin cihazınızda görünür' : 'Visible only on your device');
  String get showRoomQr => isTr ? 'Oda QR Kodunu Göster' : 'Show Room QR Code';
  String get deleteChat => isTr ? 'Sohbeti Sil' : 'Delete Chat';
  String get deleteChatUpper => isTr ? 'SOHBETİ SİL' : 'DELETE CHAT';
  String get deleteChatConfirmTitle => isTr ? 'SOHBETİ SİL?' : 'DELETE CHAT?';
  String get deleteChatConfirmBody => isTr
      ? 'Bu sohbeti aktif sohbetlerinizden kaldırmak istiyor musunuz?'
      : 'Do you want to remove this chat from your active conversations?';
  String get aliasDialogTitle => isTr ? 'ÖZEL İSİM / ALIAS' : 'CUSTOM ROOM ALIAS';
  String get aliasDialogDesc => isTr
      ? 'Bu isim yalnızca sizin telefonunuzda saklanır, uçtan uca şifrelemeyi etkilemez.'
      : 'This name is stored locally on your device and does not affect E2EE.';
  String get aliasDialogHint => isTr ? 'Örn: Ahmet, Zeynep, Ofis Grubu...' : 'e.g. Alice, Work Team, Project X...';

  // --- LAST MESSAGE PREVIEWS ---
  String get chatStartedPreview => isTr ? 'Sohbet başlatıldı' : 'Chat initialized';
  String get roomCreatedPreview => isTr ? 'Oda oluşturuldu' : 'Room created';
  String get voiceMsgPreview => isTr ? '🎤 Sesli mesaj' : '🎤 Voice message';
  String get photoPreview => isTr ? '📷 Fotoğraf' : '📷 Photo';
  String get videoPreview => isTr ? '🎥 Video' : '🎥 Video';
  String get mediaAlbumPreview => isTr ? '🖼️ Medya Albümü' : '🖼️ Media Album';
  String get locationPreview => isTr ? '📍 Konum paylaşıldı' : '📍 Location shared';

  // --- NEW ROOM MODAL ---
  String get newRoomModalTitle => isTr ? 'GÜVENLİ ODA BAĞLANTISI' : 'SECURE ROOM CONNECTION';
  String get newRoomModalSubtitle => isTr ? 'Uçtan uca şifreli odaya bağlanın veya üretin' : 'Connect to or generate an E2EE room';
  String get roomCodeInputLabel => isTr ? 'Oda Kodu / PIN' : 'Room Code / PIN';
  String get roomCodeInputHint => isTr ? 'Örn: alfa-77 veya özel kod' : 'e.g. alpha-77 or secret code';
  String get generateSecureCode => isTr ? 'Rastgele Güvenli Kod Üret' : 'Generate Secure Code';
  String get joinRoom => isTr ? 'ODAYA BAĞLAN' : 'CONNECT TO ROOM';
  String get roomCreatedToast => isTr ? 'Yeni güvenli oda kodu üretildi' : 'New secure room code generated';
  String get enterCodeWarning => isTr ? 'Lütfen bir oda kodu girin' : 'Please enter a room code';
  String get roomCodeCopied => isTr ? 'ODA KODU PANOYA KOPYALANDI' : 'ROOM CODE COPIED TO CLIPBOARD';

  // --- CHAT SCREEN & ACTIONS ---
  String get e2eSecured => isTr ? 'E2E KORUMALI' : 'E2E SECURED';
  String selectedCount(int count) => isTr ? '$count Seçildi' : '$count Selected';
  String get lastSeen => isTr ? 'Son görülme' : 'Last seen';
  String get typeEncryptedMsg => isTr ? 'MESAJ YAZIN...' : 'ENTER DATA...';
  String get replyingHint => isTr ? 'YANITLANIYOR...' : 'REPLYING...';
  String get burnModeHint => isTr ? 'ATEŞ MODU AKTİF...' : 'BURN MODE ACTIVE...';
  String get replyingTo => isTr ? 'YANITLANAN' : 'REPLYING TO';
  String get encryptingUploading => isTr ? 'ŞİFRELENİYOR & YÜKLENİYOR...' : 'ENCRYPTING & UPLOADING...';
  String get secureChannelConnecting => isTr ? '[ GÜVENLİ KANAL BAĞLANIYOR... ]' : '[ SECURE CHANNEL CONNECTING... ]';
  String get fetchingArchive => isTr ? '[ ARŞİV YÜKLENİYOR... ]' : '[ FETCHING ARCHIVE... ]';
  String get online => isTr ? 'ÇEVRİMİÇİ' : 'ONLINE';
  String get offline => isTr ? 'ÇEVRİMDIŞI' : 'OFFLINE';
  String get typing => isTr ? 'yazıyor...' : 'typing...';
  String get membersCount => isTr ? 'üye' : 'members';
  String get slideToCancel => isTr ? 'İPTAL İÇİN KAYDIR' : 'SLIDE TO CANCEL';
  String get recordingVoice => isTr ? 'Kayıt yapılıyor...' : 'Recording audio...';
  String get voiceShortWarning => isTr ? 'Ses kaydı çok kısa, basılı tutarak konuşun.' : 'Audio too short, hold to record.';
  String get panicCamouflageToast => isTr ? 'KAMUFLAJ MODU AKTİF' : 'CAMOUFLAGE MODE ACTIVE';
  String get leaveRoom => isTr ? 'Odadan Ayrıl' : 'Leave Room';
  String get mediaGallery => isTr ? 'Medya Galerisi' : 'Media Gallery';
  String get starredMessagesTitle => isTr ? 'Yıldızlı Mesajlar' : 'Starred Messages';
  String get noStarredMessages => isTr ? 'Henüz yıldızlı mesaj yok.' : 'No starred messages yet.';
  String get exportChat => isTr ? 'Sohbeti Dışa Aktar' : 'Export Chat';
  String get copyRoomCode => isTr ? 'Oda Kodunu Kopyala' : 'Copy Room Code';
  String get panicDecoy => isTr ? 'Hesap Makinesi Kamuflajı' : 'Calculator Decoy';
  String get calculatorTitle => isTr ? 'Hesap Makinesi' : 'Calculator';
  String get deletePermanently => isTr ? 'Kalıcı Olarak Sil' : 'Delete Permanently';
  String get selectMessages => isTr ? 'Mesajları Seç' : 'Select Messages';
  String get editMessage => isTr ? 'Mesajı Düzenle' : 'Edit Message';
  String get editMessageHint => isTr ? 'Yeni mesaj metni...' : 'New message text...';
  String get messageDeletedText => isTr ? '🚫 Bu mesaj silindi.' : '🚫 This message was deleted.';
  String get deletedOrUnavailableMsg => isTr ? 'Silinmiş veya ulaşılamayan mesaj' : 'Deleted or unavailable message';
  String get editedTag => isTr ? '(düzenlendi)' : '(edited)';
  String get tapToRetry => isTr ? 'Tekrar denemek için dokun' : 'Tap to retry';
  String get locationSignalEncrypted => isTr ? '[ ŞİFRELİ KONUM SİNYALİ ]' : '[ LOCATION SIGNAL ENCRYPTED ]';
  String get openMap => isTr ? 'HARİTADA AÇ' : 'OPEN MAP';
  String get audioLoading => isTr ? 'Ses yükleniyor...' : 'Loading audio...';
  String get audioFailed => isTr ? 'Ses gönderilemedi.' : 'Failed to send audio.';
  String get takePhoto => isTr ? 'Fotoğraf Çek' : 'Take Photo';
  String get recordVideo => isTr ? 'Video Çek' : 'Record Video';
  String get camera => isTr ? 'Kamera' : 'Camera';
  String get attachFile => isTr ? 'Medya Ekle' : 'Attach Media';
  String get sendLocation => isTr ? 'Konum Gönder' : 'Send Location';
  String get locationFailed => isTr ? 'Konum alınamadı.' : 'Failed to get location.';
  String get locationDisabledTitle => isTr ? 'Konum Kapalı' : 'Location Disabled';
  String get locationDisabledBody => isTr
      ? 'Cihazınızın konum servisi kapalı. Konum göndermek için lütfen açın.'
      : 'Your device location is disabled. Please enable it to send your location.';
  String get pickAColor => isTr ? 'Renk Seçin' : 'Pick a Color';
  String get changeNicknameLabel => isTr ? 'Kod Adını Değiştir:' : 'Change Nickname:';
  String get enterNewNicknameHint => isTr ? 'Yeni kod adı girin' : 'Enter new nickname';
  String get myBubbleColor => isTr ? 'Benim Balon Rengim:' : 'My Bubble Color:';
  String get otherBubbleColor => isTr ? 'Karşı Tarafın Balon Rengi:' : 'Other Bubble Color:';
  String screenshotWarningMsg(String nick) => isTr
      ? '⚠️ [SİSTEM UYARISI] $nick ekran görüntüsü aldı!'
      : '⚠️ [SYSTEM ALERT] $nick took a screenshot!';
  String get systemSenderName => isTr ? 'SİSTEM' : 'SYSTEM';
  String get today => isTr ? 'BUGÜN' : 'TODAY';
  String get yesterday => isTr ? 'DÜN' : 'YESTERDAY';
  String get offlineBannerText => isTr
      ? '[!] BAĞLANTI KESİLDİ - YEREL ÖNBELLEK MODU'
      : '[!] UPLINK DISCONNECTED - LOCAL CACHE MODE';

  // --- WEBRTC VOICE CALLS ---
  String get callerDefaultName => isTr ? 'Bir Kullanıcı' : 'Someone';
  String get voiceCallTitle => isTr ? 'Şifreli Sesli Arama' : 'Encrypted Voice Call';
  String get incomingVoiceCall => isTr ? 'Gelen Sesli Arama' : 'Incoming Voice Call';
  String incomingCallFrom(String caller) => isTr
      ? '$caller sesli arama başlattı'
      : '$caller started a voice call';
  String get ongoingVoiceCall => isTr ? 'Sesli Arama Devam Ediyor' : 'Voice Call in Progress';
  String get tapToReturnToCall => isTr ? 'Aramaya dönmek için dokunun' : 'Tap to return to call';
  String get joinCallBtn => isTr ? 'KATIL' : 'JOIN';
  String get declineCallBtn => isTr ? 'REDDET' : 'DECLINE';
  String get endCallBtn => isTr ? 'KAPAT' : 'END';
  String get inCallStatus => isTr ? 'Görüşmede' : 'In Call';
  String get callingStatus => isTr ? 'Aranıyor...' : 'Calling...';
  String get connectingCall => isTr ? 'Bağlanıyor...' : 'Connecting...';
  String get reconnectingCall => isTr ? 'Yeniden bağlanıyor...' : 'Reconnecting...';
  String get secureWebrtcConnection => isTr ? 'Uçtan Uca Şifreli WebRTC Ses Kanalı' : 'E2E Encrypted WebRTC Voice Channel';
  String get muteLabel => isTr ? 'Sessiz' : 'Mute';
  String get unmuteLabel => isTr ? 'Sesi Aç' : 'Unmute';
  String get speakerLabel => isTr ? 'Hoparlör' : 'Speaker';
  String get earpieceLabel => isTr ? 'Ahize' : 'Earpiece';
  String get hangupLabel => isTr ? 'Kapat' : 'End Call';
  String get callStartedMsg => isTr ? '📞 Sesli arama başlattı.' : '📞 Started a voice call.';
  String callEndedMsg(String duration) => isTr
      ? '📞 Sesli arama sonlandırıldı. Süre: $duration'
      : '📞 Voice call ended. Duration: $duration';
  String get missedCallTitle => isTr ? 'Cevapsız Arama' : 'Missed Call';
  String get callBackText => isTr ? 'Geri Ara' : 'Call Back';

  // --- MEDIA GALLERY & PREVIEW ---
  String get mediaGalleryTitle => isTr ? 'MEDYA GALERİSİ' : 'MEDIA GALLERY';
  String get photosTab => isTr ? 'FOTOĞRAFLAR' : 'PHOTOS';
  String get videosTab => isTr ? 'VİDEOLAR' : 'VIDEOS';
  String get noMediaFound => isTr ? '> MEDYA_BULUNAMADI' : '> NO_MEDIA_FOUND';
  String get editMediaTitle => isTr ? 'MEDYAYI DÜZENLE' : 'EDIT MEDIA';
  String get crop => isTr ? 'Kırp' : 'Crop';
  String get qualityNormal => isTr ? 'KALİTE: NORMAL' : 'QUALITY: NORMAL';
  String get encryptAndSend => isTr ? 'ŞİFRELE & GÖNDER' : 'ENCRYPT & SEND';
  String get savedToGallery => isTr ? 'Galeriye kaydedildi!' : 'Saved to Gallery!';
  String get downloadFailed => isTr ? 'İndirme başarısız' : 'Download failed';
  String get saveToGallery => isTr ? 'Galeriye Kaydet' : 'Save to Gallery';
  String get errorLoadingVideo => isTr ? 'Video yüklenirken hata oluştu' : 'Error loading video';

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
  String get nicknameLabel => isTr ? 'KOD ADINIZ (NICKNAME)' : 'AGENT ALIAS (NICKNAME)';
  String get nicknameHint => isTr ? 'Anonim bir kod adı girin...' : 'Enter an anonymous alias...';
  String get privacySection => isTr ? 'GİZLİLİK & GİZLİ MOD' : 'PRIVACY & STEALTH CONFIG';
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
  String get currentLanguageLabel => isTr ? 'Mevcut Dil: Türkçe 🇹🇷' : 'Current Language: English 🇺🇸';
  String get turkish => 'Türkçe';
  String get english => 'English';
  String get performanceSection => isTr ? 'PERFORMANS & PİL' : 'PERFORMANCE & BATTERY';
  String get ecoModeTitle => isTr ? 'EKO MODU (GÜÇ TASARRUFU)' : 'ECO MODE';
  String get ecoModeSubtitle => isTr
      ? 'Pil tasarrufu için animasyonları ve fizik efektlerini azaltır.'
      : 'Reduces animations and physics effects to save battery.';
  String get audioSection => isTr ? 'SES & BİLDİRİM EFEKTLERİ' : 'AUDIO & SOUND FX';
  String get outgoingSoundTitle => isTr ? 'GİDEN MESAJ SESİ' : 'OUTGOING MESSAGE SOUND';
  String get outgoingSoundSubtitle => isTr
      ? 'Mesaj gönderildiğinde bildirim sesi çalar.'
      : 'Plays sound effect when sending a message.';
  String get incomingSoundTitle => isTr ? 'GELEN MESAJ SESİ' : 'INCOMING MESSAGE SOUND';
  String get incomingSoundSubtitle => isTr
      ? 'Yeni mesaj alındığında bildirim sesi çalar.'
      : 'Plays sound effect when receiving a new message.';
  String get themeSection => isTr ? 'ARAYÜZ TEMASI' : 'INTERFACE THEME';
  String get updatesSection => isTr ? 'SİSTEM OTA GÜNCELLEMELERİ' : 'SYSTEM OTA UPDATES';
  String get otaTitle => isTr ? 'GitHub Uygulama İçi OTA' : 'GitHub In-App OTA';
  String get otaSubtitle => isTr ? 'Otomatik APK & Sürüm Denetimi' : 'Automatic APK & Version Check';
  String get checkBtn => isTr ? 'DENETLE' : 'CHECK';
  String get checkUpdatesBtn => isTr ? 'GÜNCELLEMELERİ DENETLE' : 'CHECK FOR UPDATES';
  String get checkingUpdates => isTr ? 'Denetleniyor...' : 'Checking...';
  String systemUpToDate(String ver) => isTr
      ? 'Sistem güncel: Mozechat v$ver'
      : 'System is up to date: Mozechat v$ver';
  String get storageSection => isTr ? 'VERİ & DEPOLAMA' : 'DATA & STORAGE';
  String get mediaCacheTitle => isTr ? 'Medya & Geçici Önbellek' : 'Media & Temporary Cache';
  String mediaCacheSubtitle(String size) => isTr
      ? 'Ses, resim ve video kalıntıları: $size'
      : 'Cached audio, images and videos: $size';
  String get clearCacheBtn => isTr ? 'ÖNBELLEĞİ TEMİZLE' : 'CLEAR MEDIA CACHE';
  String get cacheCleared => isTr ? '[OK] MEDYA ÖNBELLEĞİ TEMİZLENDİ' : '[OK] MEDIA CACHE CLEARED';
  String get saveConfig => isTr ? '[ YAPILANDIRMAYI KAYDET ]' : '[ SAVE CONFIGURATION ]';
  String get configSaved => isTr ? '[OK] KİMLİK BİLGİLERİ GÜNCELLENDİ' : '[OK] ALIAS & CONFIG UPDATED';
  String get developedBy => 'Developed with precision by mozelabs.com';

  // --- OTA UPDATE DIALOG ---
  String get updateAvailableTitle => isTr ? 'GÜNCELLEME MEVCUT' : 'UPDATE AVAILABLE';
  String currentVersionLabel(String ver) => isTr ? 'Mevcut: v$ver' : 'Current: v$ver';
  String newVersionLabel(String ver) => isTr ? 'Yeni: v$ver' : 'New: v$ver';
  String get releaseNotesLabel => isTr ? 'Sürüm Notları:' : 'Release Notes:';
  String get defaultChangelog => isTr
      ? 'Performans iyileştirmeleri ve kararlılık düzeltmeleri.'
      : 'Performance improvements and stability fixes.';
  String get downloadFailedError => isTr
      ? 'İndirme başarısız oldu. Lütfen internet bağlantınızı kontrol edin.'
      : 'Download failed. Please check your internet connection.';
  String downloadingProgress(String pct) => isTr ? '%$pct İndiriliyor...' : 'Downloading $pct%...';
  String remainingEta(String eta) => isTr ? 'Kalan: $eta' : 'ETA: $eta';
  String get laterBtn => isTr ? 'DAHA SONRA' : 'LATER';
  String get downloadingBtn => isTr ? 'İNDİRİLİYOR...' : 'DOWNLOADING...';
  String get updateNowBtn => isTr ? 'ŞİMDİ GÜNCELLE' : 'UPDATE NOW';
  String updateNotificationTitle(String ver) => isTr
      ? '🚀 Yeni Mozechat Güncellemesi! (v$ver)'
      : '🚀 New Mozechat Update! (v$ver)';
  String get updateNotificationBody => isTr
      ? 'Yeni sürüm hazır. Uygulama içinden doğrudan yükleyebilirsiniz.'
      : 'A new version is ready. Tap to install directly in-app.';

  // --- NOTIFICATIONS ---
  String newMessageFrom(String sender) => isTr ? 'Yeni Mesaj: $sender' : 'New Message: $sender';
  String get newMessageGenericTitle => isTr ? 'Yeni Mesaj' : 'New Message';
  String get newMessageGenericBody => isTr ? 'Uçtan uca şifreli yeni bir mesajınız var.' : 'You have a new E2E encrypted message.';
  String get replyActionLabel => isTr ? 'Yanıtla' : 'Reply';
  String get replyInputPlaceholder => isTr ? 'Mesaj yazın...' : 'Type a message...';

  // --- ALIAS GETTERS & HELPERS FOR WIDGETS/SCREENS ---
  String get unknownUser => callerDefaultName;
  String get newMessageTitle => newMessageGenericTitle;
  String get newEncryptedMessageBody => newMessageGenericBody;
  String get voiceCallStartedMsg => callStartedMsg;
  String voiceCallEndedMsg(String duration) => callEndedMsg(duration);
  String get inCallTitle => inCallStatus;
  String get callConnecting => connectingCall;
  String get unmuteMic => unmuteLabel;
  String get muteMic => muteLabel;
  String get endCallLabel => hangupLabel;
  String get speakerphone => speakerLabel;
  String get systemSender => systemSenderName;
  String get ongoingVoiceCallBanner => ongoingVoiceCall;
  String get pickColorTitle => pickAColor;
  String get applyBtn => apply;
  String get changeNickname => changeNicknameLabel;
  String get enterNewNickname => enterNewNicknameHint;
  String get anonymousVoice => anonymousVoiceTitle;
  String get tapToReveal => tapToRevealTitle;
  String get panicCamouflage => panicTitle;
  String get closeBtn => close;
  String get criticalBackup => criticalBackupTitle;
  String get criticalBackupDesc => criticalBackupSubtitle;
  String get identityRecoverySystem => isTr ? 'KİMLİK KURTARMA SİSTEMİ' : 'IDENTITY RECOVERY SYSTEM';
  String get anonymousEncryptedRelay => isTr ? 'ANONİM ŞİFRELİ İLETİŞİM AĞI' : 'ANONYMOUS ENCRYPTED RELAY';
  String get agentAlias => agentAliasLabel;
  String get initNewNode => initNodeBtn;
  String get cancelRestore => cancelRestoreBtn;
  String get restoreExistingIdentity => restoreExistingBtn;
  String get allTab => all;
  String get cropTooltip => crop;
  String get encryptAndSendBtn => encryptAndSend;
  String get downloadFailedPrefix => downloadFailed;
  String get saveToGalleryTooltip => saveToGallery;
  String get qrScannerTitle => scanQrBtn;
  String get qrScannerInstruction => alignQrInstruction;
  String get scanQrCodeTitle => scanQrBtn;
  String get scanQrCodeSubtitle => scanQrSubtitle;
  String get createNewRoomQrTitle => createQrRoomTitle;
  String get createNewRoomQrSubtitle => createQrRoomSubtitle;
  String get setCustomAlias => setCustomAliasTitle;
  String get currentAliasPrefix => isTr ? 'Mevcut' : 'Current';
  String get aliasVisibleOnlyToYou => isTr ? 'Yalnızca sizin cihazınızda görünür' : 'Visible only on your device';
  String get roomQrCodeTitle => roomQrTitle;
  String get customAliasDialogTitle => aliasDialogTitle;
  String get customAliasDialogSubtitle => aliasDialogDesc;
  String get customAliasHint => aliasDialogHint;
  String get panicTooltip => panicDecoy;
  String get settingsMenu => settingsTitle;
  String get logoutMenu => logout;
  String get noMatchingChats => noMatchingChatsTitle;
  String get secureNetworkEmptyTitle => emptyRoomsTitle;
  String get noMatchingChatsSub => resetFiltersSubtitle;
  String get secureNetworkEmptySub => emptyRoomsSubtitle;
  String get resetFilters => resetFiltersBtn;
  String get createNewRoomBtn => createRoomBtn;
  String get chatStarted => chatStartedPreview;
  String get voiceMessagePreview => voiceMsgPreview;
  String get unpinSwipe => unpin;
  String get pinSwipe => pin;
  String get deleteChatSwipe => deleteChatUpper;
  String get cacheClearedToast => cacheCleared;
  String get aliasUpdatedToast => configSaved;
  String get agentAliasSection => nicknameLabel;
  String get enterAliasHint => nicknameHint;
  String get privacyStealthSection => privacySection;
  String get performanceBatterySection => performanceSection;
  String get audioSoundSection => audioSection;
  String get interfaceThemeSection => themeSection;
  String get systemOtaSection => updatesSection;
  String get githubOtaTitle => otaTitle;
  String get githubOtaSubtitle => otaSubtitle;
  String get dataStorageSection => storageSection;
  String get calculatingCache => calculating;
  String get clearBtn => clearCacheBtn;
  String get saveConfigBtn => saveConfig;
  String get mediaAttachmentFallback => isTr ? '[Medya Eki]' : '[Media Attachment]';
  String get notifChannelName => isTr ? 'Mozechat Mesajları' : 'Mozechat Messages';
  String get notifChannelDesc => isTr ? 'Uçtan uca şifreli sohbet ve arama bildirimleri' : 'E2E encrypted chat and call notifications';
  String get replyAction => replyActionLabel;
  String get replyHint => replyInputPlaceholder;
  String get downloadFailedCheckNet => downloadFailedError;
  String downloadingPercentage(String pct) => downloadingProgress(pct);
  String get voiceRecordTooShort => voiceShortWarning;
  String get failedToGetLocation => locationFailed;
  String get replyingToPrefix => replyingTo;
  String get cameraTooltip => camera;
  String get attachFileTooltip => attachFile;
  String get sendLocationTooltip => sendLocation;
  String get burnModeActiveHint => burnModeHint;
  String get enterDataHint => typeEncryptedMsg;
  String get holdToRecordToast => voiceShortWarning;
  String get deletedOrUnavailableMessage => deletedOrUnavailableMsg;
  String get todayLabel => today;
  String get yesterdayLabel => yesterday;
  String get editedLabel => editedTag;
  String get openMapBtn => openMap;
  String get voiceUploading => audioLoading;
  String get voiceSendFailed => audioFailed;
  String get qrDialogDefaultTitle => roomQrTitle;
  String get copyBtn => copy;
  String get shareBtn => share;
  String shareRoomInviteText(String code) => qrShareText(code);
  String get shareRoomInviteSubject => qrShareSubject;
  String get uplinkDisconnected => offlineBannerText;
  String get decryptionFailedText => isTr ? '[Şifre Çözülemedi]' : '[Decryption Failed]';
  String get encryptedMessageFallback => isTr ? '[Şifreli Mesaj]' : '[Encrypted Message]';
  String get roomFullError => isTr ? 'Oda kapasitesi dolu (Maks 2 kişi).' : 'Room capacity full (Max 2 members).';
  String get nodeDestroyedError => isTr ? 'Bu oda kurucu tarafından silindi.' : 'This room has been destroyed.';
  String get kickedFromNodeError => isTr ? 'Bu odadan çıkarıldınız.' : 'You have been removed from this room.';
  String get internetDisconnectedError => isTr ? 'İnternet bağlantısı hâlâ yok.' : 'Internet is still disconnected.';
  String get exportHistorySubject => isTr ? 'Mozechat Sohbet Geçmişi' : 'Mozechat History Export';
  String get exportFailedPrefix => isTr ? 'Dışa aktarma başarısız' : 'Export failed';
  String get exportHeaderTitle => isTr ? '=== MOZECHAT SOHBET GEÇMİŞİ ===' : '=== MOZECHAT HISTORY EXPORT ===';
  String get exportRoomCodeLabel => isTr ? 'Oda Kodu' : 'Room Code';
  String get exportDateLabel => isTr ? 'Tarih' : 'Export Date';
}
