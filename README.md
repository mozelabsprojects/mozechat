# ⚡ MOZECHAT

> **Zero-Knowledge, Uçtan Uca Şifreli (E2EE) ve Minimalist Siber Mesajlaşma Platformu**  
> *Developed with precision & passion by **[mozelabs.com](https://mozelabs.com)***

---

<p align="center">
  <a href="https://github.com/mozelabsprojects/mozechat/releases/latest/download/app-release.apk">
    <img src="https://img.shields.io/badge/⚡_DOWNLOAD_LATEST_APK-Android-159D87?style=for-the-badge&logo=android&logoColor=white" alt="Download Latest APK" height="48" />
  </a>
</p>

<p align="center">
  <a href="https://github.com/mozelabsprojects/mozechat/releases/latest">
    <img src="https://img.shields.io/github/v/release/mozelabsprojects/mozechat?color=00FF9D&style=flat-square&label=Son%20S%C3%BCr%C3%BCm" alt="Latest Release" />
  </a>
  <a href="https://github.com/mozelabsprojects/mozechat/actions">
    <img src="https://img.shields.io/github/actions/workflow/status/mozelabsprojects/mozechat/release.yml?style=flat-square&label=Build%20Durumu&color=159D87" alt="Build Status" />
  </a>
  <img src="https://img.shields.io/badge/G%C3%BCvenlik-AES--GCM%20E2EE-blue?style=flat-square" alt="Security" />
  <img src="https://img.shields.io/badge/Geli%C5%9Ftirici-mozelabs.com-orange?style=flat-square" alt="Mozelabs" />
</p>

---

## 📥 Uygulamayı İndir ve Kur

Mozechat'in en güncel Android sürümünü doğrudan cihazınıza indirebilirsiniz. Yapılan her güncellemede aşağıdaki bağlantı ve GitHub Releases otomatik olarak en son derlemeyi barındırır:

* 🚀 **[Doğrudan APK İndir (En Son Sürüm)](https://github.com/mozelabsprojects/mozechat/releases/latest/download/app-release.apk)**
* 📦 **[Tüm Sürümler ve Değişiklik Günlüğü (Releases)](https://github.com/mozelabsprojects/mozechat/releases)**

> [!TIP]
> **Uygulama İçi Otomatik Güncelleme:** Mozechat yüklendikten sonra yeni bir sürüm çıktığında uygulama açılışında otomatik olarak tespit edilir veya `Ayarlar > Güncellemeleri Denetle` sekmesinden tek tıkla doğrudan uygulama içinden güncellenebilir.

---

## 🛡️ Mozechat Nedir?

**Mozechat**, geleneksel mesajlaşma uygulamalarının aksine kullanıcı gizliliğini en radikal düzeyde korumak için tasarlanmış siberpunk/minimalist bir gizli iletişim aracıdır.

Sunucularda hiçbir açık mesaj, resim, ses veya kimlik kaydı tutulmaz. Odalar geçici ve şifrelidir; ayrılma veya yok etme durumunda geride hiçbir dijital ayak izi kalmaz.

### 🌟 Öne Çıkan Özellikler

* **🔐 Uçtan Uca Şifreleme (E2EE):** Tüm metinler, fotoğraflar, videolar, ses kayıtları ve konum verileri cihazda AES-GCM ile şifrelenir. Anahtar yalnızca oda üyelerinin elindedir.
* **🧮 Panik Kamuflaj Modu:** Acil bir durumda tek dokunuşla tüm ekran çalışan bir **Hesap Makinesine** dönüşür. Fiziksel geri tuşları mühürlüdür; yalnızca sizin bildiğiniz gizli PIN kodu (`0000` veya `1234` girilip `=`) tuşlandığında sohbet arayüzüne geri dönülür.
* **👁️ Tap to Reveal (Dokun & Göster):** Omuz üzerinden ekran gözetlemelerini engellemek için mesajlar varsayılan olarak buğulanır (blur). Yalnızca mesaja basılı tutulduğunda içerik netleşir; parmağınızı çektiğiniz anda tekrar gizlenir.
* **🎙️ Robotik / Anonim Ses Modülasyonu:** Gönderdiğiniz ses kayıtları kimliğinizi korumak için anında robotik/düşük frekans modülasyonu ile maskelenir.
* **⚡ 60-120 FPS Ultra Akıcı UI:** Telegram benzeri elastik *Swipe-to-Reply*, çift dokunuşla kalkan (`🛡️`) reaksiyonu, Matrix yağmuru ve canlı partikül ızgarası ile donanım hızlandırmalı pürüzsüz arayüz.
* **📡 Sıfır İz WebRTC Çağrıları:** P2P şifreli canlı sesli ve görüntülü arama altyapısı.
* **📷 QR Kod İle Odaya Katılma:** Tek kullanımlık veya kalıcı güvenli odalara kamera ile QR kod okutarak anında şifreli giriş.

---

## 🛠️ Kurulum & Geliştirici Ortamı

Kaynak koddan derlemek isteyen geliştiriciler için:

```bash
# Depoyu klonlayın
git clone https://github.com/mozelabsprojects/mozechat.git
cd mozechat

# Paket bağımlılıklarını yükleyin
flutter pub get

# Hata ve lint denetimi yapın
flutter analyze

# Release APK derleyin
flutter build apk --release
```

Derlenen APK çıktısı `build/app/outputs/flutter-apk/app-release.apk` dizininde oluşturulacaktır.

---

## 🏢 Geliştirici & Telif Hakkı

Mozechat, **[mozelabs.com](https://mozelabs.com)** tarafından yüksek gizlilik standartları ve modern mobil mimarilerle geliştirilmektedir.

* **Resmi Web Sitesi:** [https://mozelabs.com](https://mozelabs.com)
* **GitHub Organizasyonu:** [@mozelabsprojects](https://github.com/mozelabsprojects)
* **Destek & İletişim:** [contact@mozelabs.com](mailto:contact@mozelabs.com)

---

<p align="center">
  <sub>© 2026 <b>Mozelabs</b>. Tüm hakları saklıdır. Gizliliğiniz taviz verilemez bir haktır.</sub>
</p>
