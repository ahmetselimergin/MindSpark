# MindSpark MVP Çalışma Planı

## Güncel Main — Legacy Progress + Gameplay UI

- [x] Eski tamamlanmış current-level kaydını sonsuz sıradaki sonraki level'a uzlaştır
- [x] Home ve Gameplay'in aynı normalize edilmiş progress durumunu kullandığını test et
- [x] Beyaz Flame board'u koyu blueprint renderer'a geçir
- [x] Timer, can, image kontrolleri, stuck feedback ve Yandex banner'ı koruyarak Gameplay yerleşimini iyileştir
- [x] Küçük ekran, tam test, analyzer, Android APK ve Pixel 10 Pro görsel kapılarını çalıştır

### Legacy progress review

- Eski `{1,2,3} / current=3` kaydı state sınırında Level 4'e uzlaştırılıyor; kalıcı veri şeması ve diğer oyuncu alanları değişmiyor.
- Home Level 3'ü replay, Level 4'ü Play gösteriyor; Gameplay Level 4'ü kabul edip Level 5'i kilitli tutuyor.
- 65 odaklı ve 198 tam test geçti; `flutter analyze` ve `git diff --check` temiz tamamlandı.

### Current gameplay UI review

- Koyu alternating-cell board, grid/dot katmanı, glow yollar ve halka endpoint'ler mevcut Flame input/completion API'si korunarak uygulandı.
- Gameplay; timer, canlar, restart/home image kontrolleri, stuck feedback, Yandex banner ve save-error dallarını koruyor. Talimat board'a bitişik, uzun ekranda ikincil hedef şeridi kalan alanı dengeliyor.
- Renderer inceleme düzeltmesi iki güvenli boş hücrede exact panel/alternate renklerini doğruluyor.
- 320×568 + 2× metin ve 412×915 board-talimat yakınlığı testleri geçti; Pixel 10 Pro üzerinde bağlı yol render'ı görsel olarak incelendi.
- Son taze kapılar: `flutter analyze` temiz, `flutter test` 199/199, `flutter build apk --debug` başarılı ve `git diff --check` temiz. Build yalnız mevcut Yandex KGP gelecek-uyumluluk uyarısını üretiyor.
- Tam `ec6b117..9e02b23` incelemesi P0–P3 bulgusuz tamamlandı; güncel main üzerinde aynı 199/199 + analyzer + APK kapıları yeniden geçti. Kullanıcının `ios/` ve `assets/market/` çalışma dosyaları korunarak fast-forward merge yapıldı.

## Progression + UI Refresh

- [ ] Son level tekrarını RED regresyon testiyle yeniden üret
- [ ] Bundle içeriğini canonical çözümleri test edilen 12 level'a çıkar
- [ ] Tüm level'lar bitince açık tamamlanma ve bilinçli replay durumu göster
- [ ] Board renderer'ı koyu arcade-blueprint görsel sistemine geçir
- [ ] Home, Gameplay ve Result ekran hiyerarşisini yeniden tasarla
- [ ] 320×568 + 2× metin, tam test, analyzer ve APK kapılarını çalıştır
- [ ] Telefon boyutunda render yakala ve görsel olarak incele

## Tasarım ve Onay

- [x] Mevcut repo durumunu, belgeleri ve git geçmişini incele
- [x] Teslim kapsamını ve başarı ölçütlerini netleştir
- [x] 2-3 teknik yaklaşımı artı/eksileriyle sun
- [x] Mimari, veri akışı, hata yönetimi ve test tasarımını onaya sun
- [x] Onaylanan tasarımı `docs/superpowers/specs/` altında yaz ve öz değerlendirmesini yap
- [x] Yazılı tasarım için kullanıcı onayı al
- [x] Ayrıntılı TDD uygulama planını `docs/superpowers/plans/` altında oluştur

## Uygulama

- [x] Onaylanan uygulama planını test-öncelikli olarak yürüt
  - [x] Task 2 model doğrulama testlerini RED/GREEN tamamla
  - [x] Task 2 repository testlerini RED/GREEN tamamla
  - [x] Üç çözülebilir 5×5 seviyeyi bundle'a ekle
  - [x] Task 2 odaklı testleri ve analyzer'ı doğrula
  - [x] Task 2 uygulama ve test kanıtlarını commit et
  - [x] Task 2 inceleme düzeltmelerini tamamla
    - [x] `size < 2` sınırını RED/GREEN doğrula
    - [x] Eşzamanlı ilk yüklemeleri tek future üzerinde RED/GREEN birleştir
    - [x] Başarısız yüklemeden sonra yeniden denemeyi doğrula
    - [x] Odaklı test, analyzer ve diff kontrollerini çalıştır
    - [x] Düzeltmeleri commit et ve inceleme sonucunu kaydet
  - [x] Task 3 saf Dart puzzle oturumunu TDD ile tamamla
    - [x] Başlatma, uzatma ve değiştirilemez snapshot davranışlarını RED/GREEN doğrula
    - [x] Düzenleme, iptal, yeniden başlatma ve atlanan hücre reddini RED/GREEN doğrula
    - [x] Tamamlama kilidi ve tek-seferlik callback döngüsünü RED/GREEN doğrula
    - [x] Odaklı/tam testleri, analyzer ve diff kontrolünü çalıştır
    - [x] Task 3 raporunu yaz ve değişiklikleri commit et
  - [x] Task 3 inceleme düzeltmelerini tamamla
    - [x] Bağlı uçtan ileri uzatmayı reddeden ve geri izlemeyi koruyan RED/GREEN regresyonu ekle
    - [x] Aktif hareket sırasında ikinci başlangıcı reddeden ve özgün hareketi temizleyen RED/GREEN regresyonu ekle
    - [x] Odaklı/tam testleri, analyzer ve diff kontrolünü çalıştır
    - [x] Düzeltme kanıtını rapora ekle ve commit et
  - [x] Task 4 oyuncu ilerlemesi ve kalıcılığı TDD ile tamamla
    - [x] `PlayerProgress` varsayılanlarını, normalizasyonunu ve monoton güncellemelerini RED/GREEN doğrula
    - [x] Repository ve Riverpod controller yükleme/kaydetme/yeniden deneme akışını RED/GREEN doğrula
    - [x] Hive adaptörünün eksik/bozuk/geçerli kayıt davranışını RED/GREEN doğrula
    - [x] Odaklı/tam testleri, analyzer ve diff kontrolünü çalıştır
    - [x] Task 4 raporunu yaz ve değişiklikleri commit et
  - [x] Task 4 inceleme düzeltmelerini tamamla
    - [x] Controller mutasyonlarını sıralayan eşzamanlı tamamlama/yeniden deneme regresyonlarını RED/GREEN doğrula
    - [x] `completedLevelIds` sahipliğini tüm kurulum sınırlarında RED/GREEN doğrula
    - [x] Kaydetme hatasında önceki iyimser değeri koruyan `AsyncError` durumunu RED/GREEN doğrula
    - [x] Tüm desteklenmeyen `schemaVersion` değerlerini ve `bool` tamsayı reddini RED/GREEN doğrula
    - [x] Hive test temizliğini kısmi kurulum hatalarına karşı güvenli hale getir
    - [x] Odaklı/tam testleri, analyzer ve diff kontrolünü çalıştır
    - [x] Düzeltme kanıtını rapora ekle ve commit et
  - [x] Task 5 Flame renderer ve hareket adaptörünü TDD ile tamamla
    - [x] Koordinat, sınır, resize ve hızlı sürükleme testlerini RED olarak doğrula
    - [x] Doğrudan çağrılabilir pointer seam'leri ile Flame drag callback'lerini uygula
    - [x] Izgara, yuvarlatılmış yollar, uç noktalar ve renk-dışı sembolleri render et
    - [x] Restart ve tek-seferlik tamamlama callback döngüsünü doğrula
    - [x] Odaklı/tam testleri, analyzer ve diff kontrolünü çalıştır
    - [x] Task 5 raporunu yaz ve değişiklikleri commit et
  - [x] Task 5 inceleme düzeltmelerini tamamla
    - [x] Ters yönlü yatay/dikey baskın, negatif/eşit ve tam geri izleme regresyonlarını public pointer seam'leri üzerinden RED doğrula
    - [x] Kanonik uç sıralamasından tek rota üretip ters yönde tam tersini döndüren minimal düzeltmeyi uygula
    - [x] Flame olay kurulumunun gerçek API uygunluğunu incele; mümkünse pointer-ID yaşam döngüsünü üretim callback'leriyle test et
    - [x] Odaklı/tam testleri, analyzer ve diff kontrolünü çalıştır
    - [x] Task 5 rapor kronolojisini git/test kanıtına göre düzelt, sonuçları kaydet ve commit et
  - [x] Task 5 kısmi ters izleme düzeltmesini tamamla
    - [x] Çoklu kısmi ters pointer örneklerinin yolu monoton küçülttüğünü public seam üzerinden RED doğrula
    - [x] Ters izleme sonrası yön değişiminin yeni bir ileri segment oluşturduğunu RED doğrula
    - [x] Yalnız kabul edilen sentetik hücreleri tutan minimal segment geçmişi ve negatif projeksiyon uzlaştırmasını uygula
    - [x] End/restart/yeni başlangıç/pointer-ID ve mevcut ters izleme regresyonlarını doğrula
    - [x] Odaklı/tam testleri, analyzer ve diff kontrolünü çalıştır; raporu düzelt ve commit et
  - [x] Task 5 reddedilen ileri segment geçmişi düzeltmesini tamamla
    - [x] Bağlı yol sonrası reddedilen ileri örneğin önceki segmenti koruduğunu public seam ile RED doğrula
    - [x] Yeni segmenti yalnız en az bir domain kabulünden sonra kuran minimal düzeltmeyi uygula
    - [x] Odaklı/tam testleri, analyzer ve diff kontrolünü çalıştır; raporu güncelle ve commit et
  - [x] Task 6 inceleme düzeltmelerini tamamla
    - [x] Hive bootstrap hata→yeniden dene→başarı akışını widget RED/GREEN ile doğrula
    - [x] Kilitli/eksik seviye rota yetkilendirmesini ve güvenli hata eylemlerini RED/GREEN doğrula
    - [x] Kaydetme yeniden denemesini gerçek kalıcılık kanıtına bağlayan regresyonları RED/GREEN doğrula
    - [x] Küçük ekran + 2.0 metin ölçeğinde Home/Gameplay/Result taşmamasını RED/GREEN doğrula
    - [x] Play/Next/Home geçişlerini anında kilitleyen çift tetikleme regresyonlarını RED/GREEN doğrula
    - [x] Odaklı/tam testleri, analyzer ve diff kontrolünü çalıştır
    - [x] Task 6 raporuna kanıt ekle ve düzeltmeleri commit et
    - [x] Yeniden denemede korunan eski `AsyncValue` verisinin hata durumunu başarı saymadığını RED/GREEN doğrula
    - [x] Bootstrap yeniden deneme geri çağrılarını eşzamanlı kilit ve deneme kimliğiyle tek başlatma olarak RED/GREEN doğrula
- [x] Analiz, test ve Android derleme doğrulamalarını çalıştır
- [x] Sonuçları ve kapsam kontrolünü bu dosyanın inceleme bölümüne kaydet

## Task 7 — Kabul doğrulaması ve dokümantasyon

- [x] Aynı `InMemoryProgressRepository` ile iki ayrı `ProviderScope` arasında tamamlama, yeniden oluşturma ve tekrar oynama akışını widget testiyle doğrula
- [x] Ürün kapsamını, mimari sahipliği, önkoşulları, kesin komutları, çevrimdışı çalışmayı ve sonraki fazları README'de belgele
- [x] `dart format lib test` ve `git diff --check` kontrollerini çalıştır
- [x] `flutter pub get`, `flutter analyze`, `flutter test` ve `flutter build apk --debug` kapılarını taze çalıştır
- [x] APK yolunu ve boyutunu doğrula; kesin sonuçları Task 7 raporuna ve inceleme bölümüne kaydet
- [x] Yalnız tüm kapılar geçtikten sonra Task 7 değişikliklerini commit et

## İnceleme

## Final branch review fixes

- [x] Result ekranı toplam skoru kalıcı provider durumundan göstersin; ilk tamamlama, tekrar ve kompakt widget RED/GREEN kanıtlarını ekle
- [x] Kalıcı kayıtlar için tipli hata veren atomik katı ayrıştırma sınırı ve tek-seferlik tanı callback'i ekle; RED/GREEN model/Hive kanıtlarını ekle
- [x] README bozulma politikasını ve izlenen görev inceleme sonuçlarını güncelle
- [x] Odaklı testler, tam paket, analyzer, debug APK ve diff kontrollerini çalıştır
- [x] Yok sayılan `.superpowers/sdd/final-review-fix-report.md` raporuna TDD/doğrulama kanıtını yaz ve kapsamlı diff incelemesi yap
- [x] Yalnız tüm kapılar geçtikten sonra scoped değişiklikleri commit et

### Final branch review fixes — review

- Result toplam skoru route ödülünden hesaplamıyor; izlenen `appProgressControllerProvider` değerini gösteriyor. İlk tamamlama `+100 / Total Score: 100`, tekrar `+0 / Total Score: 100` ve 320×568 + 2.0 metin ölçeği testleri doğrulandı.
- `PlayerProgress.fromMap` normalizasyonu korundu. Yeni `fromPersistedMap` sınırı şema, alan tipleri, benzersiz pozitif ID'ler, değişmez sahiplik, skor ve kilit tutarlılığını atomik olarak doğruluyor.
- Hive eksik anahtar için varsayılanı tanısız döndürüyor; bozuk kaydı bir `ProgressFormatException` ve stack ile tam bir kez tanılıyor; gerçek box okuma hatasını yüzeye çıkarıyor.
- Odaklı model/Hive/widget paketi 38/38, tam paket 103/103 geçti; `flutter analyze` sıfır sorun bildirdi; `git diff --check` temizdi.
- `main` üzerinde temiz debug APK başarıyla yeniden üretildi: `build/app/outputs/flutter-apk/app-debug.apk`, 153.137.035 byte. Worktree'de görülen 174.329.326 byte ölçümünün build-cache/toolchain durumuna bağlı olduğu doğrulandı.

- Onaylanan oynanabilir çekirdek kapsamı tamamlandı.
- Task 2: 11 odaklı test geçti; `flutter analyze` sıfır sorunla tamamlandı.
- Task 2: Seviye 1 yatay satırlar, seviye 2 dikey sütunlar, seviye 3 ise üst satır ve iki serpantin yol ile çözülebilir.
- Task 2 inceleme düzeltmeleri: 14 odaklı test geçti; `size < 2`, eşzamanlı ilk yükleme ve hata sonrası yeniden deneme davranışları doğrulandı.
- Task 3: 16 odaklı domain testi ve 31 testlik tam paket geçti; `flutter analyze` sıfır sorunla tamamlandı.
- Task 3 inceleme düzeltmeleri: 18 odaklı domain testi ve 33 testlik tam paket geçti; bağlı uç terminal davranışı ve aktif hareket yeniden girişi doğrulandı.
- Task 4: 14 odaklı ilerleme/kalıcılık testi ve 47 testlik tam paket geçti; `flutter analyze` sıfır sorunla tamamlandı.
- Task 4 inceleme düzeltmeleri: 20 odaklı ilerleme/kalıcılık testi ve 53 testlik tam paket geçti; sıralı mutasyonlar, değişmez model sahipliği, önceki değerli hata durumu, şema sabitleme ve güvenli Hive temizliği doğrulandı.
- Task 5 commit durumu: `91166b4` 11 odaklı Flame adaptör testini birlikte ekledi; 53 testlik ebeveyn durumundan 64 testlik tam pakete çıktı. Ayrı bir 10-test commit'i yoktur; önceki rapordaki pre-regresyon `+11` kronolojisi hatalıydı.
- Task 5 inceleme düzeltmeleri: 16 odaklı Flame adaptör testi ve 69 testlik tam paket geçti; iki yönlü kanonik ortogonal rota, tam hızlı geri izleme ve gerçek Flame olaylarıyla pointer-ID yaşam döngüsü doğrulandı. `flutter analyze` ve `git diff --check` sıfır sorunla tamamlandı.
- Task 5 kısmi ters izleme düzeltmesi: 18 odaklı Flame adaptör testi ve 71 testlik tam paket geçti; kabul edilen sentetik segment geçmişi, negatif projeksiyonla çoklu kısmi geri izleme ve yön değişiminde yeni segment doğrulandı. `flutter analyze` ve `git diff --check` sıfır sorunla tamamlandı.
- Task 5 reddedilen ileri segment düzeltmesi: 19 odaklı Flame adaptör testi ve 72 testlik tam paket geçti; yeni segmentin yalnız domain kabulünden sonra kurulması ve reddedilen bağlı-yol hareketinden sonra önceki geri izleme geçmişinin korunması doğrulandı. `flutter analyze` ve `git diff --check` sıfır sorunla tamamlandı.

## Task 6 — Flutter application flow

### Design specification

- Audience/job: Android casual-puzzle players in short sessions; orient quickly and enter the current puzzle with one dominant action.
- Colors: Midnight Ink `#10152B`, Deep Circuit `#1B2340`, Spark Yellow `#FFD166`, Electric Cyan `#4CC9F0`, Coral Pulse `#FF6B6B`, Frost `#F7F8FF`.
- Type: system `sans-serif-condensed` heavy for display numerals and titles; system `sans-serif` medium for body and actions.
- Layout: quiet centered stack, oversized current-level numeral, compact score label, maximum square game board, restrained controls.
- Signature: one simple reusable three-node connected spark-trail painter on splash, home, and result.
- Motion: no decorative animation; stable test-safe screens and reduced-motion compatible by construction.

### Implementation checklist

- [x] Write splash/home widget tests and capture RED.
- [x] Implement bootstrap, provider seams, routes, theme, splash, and home; capture GREEN.
- [x] Write gameplay/result tests and capture RED.
- [x] Implement one-game gameplay lifecycle, persistence gating, result order, and safe routes.
- [x] Run focused widget tests.
- [x] Run full suite, analyzer, and diff review.
- [x] Write report and prepare commit.

### Review

- Task 6: 9 focused widget tests and the 80-test full suite passed; `flutter analyze` and `git diff --check` completed cleanly. Splash initialization, explicit retry, one-game gameplay lifetime, once-only completion, retryable save failure, repository-order next-level navigation, final-level Home behavior, and safe invalid-route handling are covered.
- Task 6 inceleme düzeltmeleri: 22 odaklı widget testi ve 93 testlik tam paket geçti; Hive açılış yeniden denemesi, kilitli/eksik rota koruması, kaydetme kanıtı, 320×568 + 2.0 metin ölçeği ve çift geçiş kilitleri doğrulandı. `flutter analyze` ve `git diff --check` temiz tamamlandı.
- Task 6 kalan inceleme düzeltmeleri: 24 odaklı widget testi ve 95 testlik tam paket geçti; korunan eski verili `AsyncError` Splash'ta kalıyor ve hızlı bootstrap yeniden denemeleri yalnız tek initializer/repository mount üretiyor. Analyzer ve diff kontrolü temiz tamamlandı.
- Task 7: Yeni kalıcılık kabul testi mevcut üretim bağlantıları üzerinde ilk çalıştırmada geçti; önceki görevlerdeki birim-seviyesi TDD sonrasında eklenen kabul kapsamıdır ve üretim kodunda düzeltme gerektirmedi.
- Task 7 kalıcılık akışı: Aynı `InMemoryProgressRepository`, dispose edilen iki ayrı `ProviderScope` arasında Level 1 tamamlamasını, 100 puanı ve Level 2 kilit açmasını korudu; yetkili Level 1 tekrarında puan 100 kaldı.
- Task 7 kapsam incelemesi: Üç çözülebilir 5×5 asset, tam-grid gerektirmeyen tamamlanma, çakışma/dolu hücre/yabancı uç reddi, restart, tamamlama kilidi, tek-seferlik callback, idempotent puan, çevrimdışı Home → Game → Result → next/home ve pasif fakat kalıcı lives mevcut testlerle doğrulandı. Sonraki faz sistemleri eklenmedi.
- Task 7 son kapıları: `dart format lib test` 31 dosyayı başarıyla biçimlendirdi; `git diff --check` temizdi; `flutter pub get` başarılıydı; `flutter analyze` sıfır sorun bildirdi; `flutter test` 96/96 geçti; `flutter build apk --debug` exit 0 ile tamamlandı.
- Task 7 APK: `build/app/outputs/flutter-apk/app-debug.apk` mevcut, 153.135.091 byte.
