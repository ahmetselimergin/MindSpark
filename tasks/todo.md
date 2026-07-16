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
