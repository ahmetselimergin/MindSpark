# MindSpark MVP Çalışma Planı

## Tasarım ve Onay

- [x] Mevcut repo durumunu, belgeleri ve git geçmişini incele
- [x] Teslim kapsamını ve başarı ölçütlerini netleştir
- [x] 2-3 teknik yaklaşımı artı/eksileriyle sun
- [x] Mimari, veri akışı, hata yönetimi ve test tasarımını onaya sun
- [x] Onaylanan tasarımı `docs/superpowers/specs/` altında yaz ve öz değerlendirmesini yap
- [x] Yazılı tasarım için kullanıcı onayı al
- [x] Ayrıntılı TDD uygulama planını `docs/superpowers/plans/` altında oluştur

## Uygulama

- [ ] Onaylanan uygulama planını test-öncelikli olarak yürüt
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
- [ ] Analiz, test ve Android derleme doğrulamalarını çalıştır
- [ ] Sonuçları ve kapsam kontrolünü bu dosyanın inceleme bölümüne kaydet

## İnceleme

- Tasarım aşaması devam ediyor.
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
