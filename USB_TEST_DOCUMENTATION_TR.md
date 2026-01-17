# USB Kamera Modülü - Kapsamlı Test Paketi

## 📋 İçindekiler
1. [Test Paketi Özeti](#test-paketi-özeti)
2. [Her Test Suite Neler Yapar](#her-test-suite-neler-yapar)
3. [Testleri Çalıştırma](#testleri-çalıştırma)
4. [Test Sonuçlarını Okuma](#test-sonuçlarını-okuma)
5. [Hata Giderme](#hata-giderme)

---

## 🎯 Test Paketi Özeti

Yazılan 3 kapsamlı test script'i var:

| Test | Dosya | Amaç | Çalışma Zamanı |
|------|-------|------|-----------------|
| **Advanced** | `test_usb_advanced.sh` | Unit tests + static analysis | ~5 dakika |
| **Integration** | `test_usb_integration.sh` | Modül entegrasyonu | ~3 dakika |
| **Real Device** | `test_usb_real_device.sh` | Hardware simulation | ~10 dakika |
| **All** | `run_all_usb_tests.sh` | Tüm testleri çalıştır | ~20 dakika |

---

## 🔍 Her Test Suite Neler Yapar

### 1️⃣ ADVANCED TESTS (`test_usb_advanced.sh`)

**Ne Test Eder:**

#### Test 1: Statik Kod Analizi
```bash
✓ Derlemede uyarı kontrolü (Warnings)
✓ Null pointer kontrolleri
✓ Buffer overflow koruması
✓ Memory leak kontrolleri
```

**Neden Önemli:** Temel C/C++ hataları yakalar, runtime crash'lerini önler.

#### Test 2: Thread Safety (İşParçacığı Güvenliği)
```bash
✓ Mutex başlatılması kontrolü
✓ Lock/Unlock dengesi (deadlock önleme)
✓ Volatile variables (race conditions önleme)
✓ Thread join kontrolü (clean shutdown)
```

**Neden Önemli:** Multi-threading uygulamalarda veri tutarlılığını sağlar.

#### Test 3: State Machine (Durum Makinesi)
```bash
✓ 5+ state enum tanımı
✓ State transitions mekanizması
✓ Invalid state kontrolleri
```

**Neden Önemli:** USB kamerasının STOPPED → STARTING → RUNNING → STOPPED döngüsü güvenli.

#### Test 4: Ring Buffer Analizi
```bash
✓ Ring buffer yapısı doğru
✓ Buffer taşma (overflow) koruması
✓ NAL unit buffer yönetimi
```

**Neden Önemli:** Video frame'leri güvenli şekilde depolar/okunur.

#### Test 5: Hata Yönetimi
```bash
✓ ERROR state'leri
✓ Resource cleanup (bellek, file descriptor)
✓ Hata takibi mekanizması
```

**Neden Önemli:** Beklenmeyen hataları düzgün yönetir, kaynakları serbest bırakır.

#### Test 6: FFmpeg Entegrasyonu
```bash
✓ FFmpeg process başlatılması
✓ Pipe reading (video akışı okuma)
✓ Komut parametreleri güvenliği
```

**Neden Önemli:** USB kamerasından video çıkışını doğru aldığını kontrol eder.

#### Test 7: H.264 Parsing
```bash
✓ Parser tanımlanması
✓ NAL unit detection (0x00 0x00 0x01)
✓ Frame type identification (SPS, PPS, I-frame, P-frame)
```

**Neden Önemli:** Video codec'inin doğru parse edildiğini garantir.

#### Test 8: Dokümantasyon
```bash
✓ Function dokümantasyonu
✓ Structure açıklamaları
```

**Neden Önemli:** Kodun anlaşılabilir ve bakımı kolay olması.

---

### 2️⃣ INTEGRATION TESTS (`test_usb_integration.sh`)

**Ne Test Eder:**

#### Test 1: API Sözleşmeleri (Contracts)
```bash
✓ Tüm public fonksiyonlar tanımlandı mı?
  - video_source_usb_start_program()
  - video_source_usb_read()
  - video_source_usb_get_state()
  - ... (15+ fonksiyon)

✓ Parametreler doğru mı?
  - Beklenen type'lar (u32, u8*, bool)
  - Beklenen işçi sayısı
```

**Neden Önemli:** Diğer modüller USB modulüne doğru şekilde erişebilir.

#### Test 2: Video Sources Entegrasyonu
```bash
✓ USB fonksiyonları video_sources.cpp'de çağrılıyor mu?
✓ USB'ye özgü kodlar şartlı derlenebiliyor mu?
✓ Return değerleri kontrol ediliyor mu?
```

**Neden Önemli:** Genel video kaynakları sistemi USB'yi tanıyor.

#### Test 3: Hardware Model Entegrasyonu
```bash
✓ CAMERA_TYPE_USB_THERMAL tanımlı mı?
✓ isActiveCameraUSB() var mı?
✓ USB kamera algılama logic doğru mı?
✓ hardware_camera.cpp USB'yi algılıyor mu?
```

**Neden Önemli:** Sistem donanım seviyesinde USB kamerayı tanıyor.

#### Test 4: Veri Akışı Bütünlüğü
```bash
✓ Ring buffer write/read operasyonları
✓ NAL unit metadata akışı
✓ Timestamp tracking
```

**Neden Önemli:** Frame'ler bozulmadan aktarılıyor.

#### Test 5: Durum Makinesi Uyumluluğu
```bash
✓ Başlat sequence: STOPPED → STARTING → RUNNING
✓ Error recovery: ERROR → STOPPED
✓ Clean shutdown: RUNNING → STOPPED
```

**Neden Önemli:** Kamera durumları tutarlı yönetiliyor.

#### Test 6: Bellek Güvenliği
```bash
✓ Statik buffer size'ları (256KB, 128KB)
✓ Array bounds kontrolleri
✓ Stack vs heap kullanımı
```

**Neden Önemli:** Bellek buffer'ı taşmıyor, heap fragmentation yok.

#### Test 7: Yapılandırma Parametreleri
```bash
✓ Video parametreleri (width, height, fps)
✓ Ring buffer config'i
✓ Device paths (/dev/video0)
```

**Neden Önemli:** Kamera ayarları doğru şekilde uygulanıyor.

#### Test 8: Performans
```bash
✓ Async operasyonlar (non-blocking)
✓ Health check mekanizması
✓ Resource cleanup timing
```

**Neden Önemli:** UI/main thread'i bloke olmuyor, responsive kalıyor.

---

### 3️⃣ REAL DEVICE TESTS (`test_usb_real_device.sh`)

**Ne Test Eder:**

#### Test 1: Ön-Uçuş Kontrolleri (Pre-Flight)
```bash
✓ Linux işletim sistemi
✓ /dev/video* cihazları
✓ FFmpeg, v4l2-ctl yüklü mü?
✓ pthread library
✓ Test binary derlenmiş mi?
```

**Neden Önemli:** Bağımlılıkların tamamı var.

#### Test 2: Device Detection
```bash
✓ V4L2 cihazları listeleniyor mu?
✓ Cihaz özellikleri alınabiliyor mu? (Driver info)
✓ Okuma izni var mı?
```

**Neden Önemli:** Sistem USB kamerayı görebiliyor.

#### Test 3: FFmpeg Komutu Doğrulama
```bash
✓ FFmpeg syntax doğru mu?
✓ libx264 codec'i var mı?
✓ Tüm parametreler destekleniyor mu?
```

**Neden Önemli:** FFmpeg komut line'ı çalışacak.

#### Test 4-5: Thread Safety & Buffer Simülasyonu
```bash
✓ Mutex stress test (4 thread × 1000 lock/unlock)
✓ Ring buffer simulation (100 write/read)
✓ Sonuç: counter == 4000? buffer == 100?
```

**Neden Önemli:** Multi-threaded ortamda data integrity garantisi.

#### Test 6-7: H.264 Parsing Simülasyonu
```bash
✓ NAL start code detection (0x00 0x00 0x00 0x01)
✓ NAL type extraction (SPS=7, PPS=8, IDR=5, etc.)
```

**Neden Önemli:** Codec parsing doğru çalışıyor.

#### Test 8: Performans & Yapılandırma
```bash
✓ Sistem belleği (RAM)
✓ CPU çekirdek sayısı
✓ Default parametreler (1280×720, 30 FPS, 8-buffer)
```

**Neden Önemli:** Sistem kaynakları yeterli.

---

## 🚀 Testleri Çalıştırma

### Seçenek 1: Tüm Testleri Bir Arada Çalıştır
```bash
cd /home/ekamar/Desktop/ruby
chmod +x code/r_tests/run_all_usb_tests.sh
./code/r_tests/run_all_usb_tests.sh
```

**Çıktı:**
- Interactive mode - her suite'ten sonra Enter'a basmalısın
- Detailed reportlar
- Final summary

### Seçenek 2: Tek Tek Çalıştır
```bash
# Sadece advanced testleri
chmod +x code/r_tests/test_usb_advanced.sh
./code/r_tests/test_usb_advanced.sh

# Sadece integration testleri
chmod +x code/r_tests/test_usb_integration.sh
./code/r_tests/test_usb_integration.sh

# Sadece device testleri
chmod +x code/r_tests/test_usb_real_device.sh
./code/r_tests/test_usb_real_device.sh
```

### Seçenek 3: Hızlı Test
```bash
# Yalnızca syntax kontrolleri (30 saniye)
cd /home/ekamar/Desktop/ruby
grep -l "video_source_usb_start_program" code/r_vehicle/*.cpp
grep -l "CAMERA_TYPE_USB_THERMAL" code/base/*.h
```

---

## 📊 Test Sonuçlarını Okuma

### Başarılı Test (✓ PASSED)
```
╔════════════════════════════════════════════════════╗
║  USB CAMERA MODULE - BUILD & CODE VERIFICATION    ║
╚════════════════════════════════════════════════════╝

[1/5] Checking required files...
  ✓ code/r_vehicle/video_source_usb.h
  ✓ code/r_vehicle/video_source_usb.cpp
  ...
```

### İkaz (⚠ WARNING)
```
  ⚠ Some features may not be fully tested
  ⚠ FFmpeg not found in PATH
```

**Ne Yapmalısın:** Uyarı, ciddi değil ama kontrol et.

### Başarısız Test (✗ FAILED)
```
  ✗ code/r_vehicle/video_source_usb.h (MISSING)
  ✗ isActiveCameraUSB() NOT found
```

**Ne Yapmalısın:** Dosya eksik veya fonksiyon tanımlanmamış - düzelt.

---

## 🐛 Hata Giderme

### Problem: "test_usb_advanced.sh: Permission denied"
```bash
chmod +x code/r_tests/test_usb_advanced.sh
```

### Problem: "FFmpeg not found"
```bash
sudo apt-get install ffmpeg
```

### Problem: "Some required files are missing"
```bash
# Dosyaların yerini kontrol et
ls -la code/r_vehicle/video_source_usb.*
ls -la code/base/hardware.h
```

### Problem: "CAMERA_TYPE_USB_THERMAL NOT found"
```bash
# hardware.h'da ekle:
grep -n "typedef enum" code/base/hardware.h
# Bulun enum içine şu satırı ekleyin:
CAMERA_TYPE_USB_THERMAL = X,
```

### Problem: "Thread test FAILED"
```bash
# Mutex kontrol et
grep -n "pthread_mutex_lock\|pthread_mutex_unlock" code/r_vehicle/video_source_usb.cpp
# Lock/unlock sayıları eşit olmalı
```

### Problem: "Ring buffer test FAILED"
```bash
# Ring buffer implementation kontrol et
grep -n "_ring_buffer_write\|_ring_buffer_read" code/r_vehicle/video_source_usb.cpp
# Index management kontrol et (modulo operatör)
```

---

## 📝 Test Sonuçlarını Kaydet

Çıktıyı dosyaya kaydet:
```bash
./code/r_tests/run_all_usb_tests.sh 2>&1 | tee usb_test_results.txt
```

**Bu ne yapar:** Tüm çıktıyı ekrana gösterir ve `usb_test_results.txt` dosyasına kaydeder.

---

## ✅ Son Kontrol Listesi

USB modülünün tamamlanması için:

- [ ] Tüm 3 test suite başarıyla çalışıyor
- [ ] Advanced testlerde 0 FAILED
- [ ] Integration testlerde 0 FAILED
- [ ] Device testlerde 0 FAILED
- [ ] Kod derlenebiliyor (`make clean && make vehicle`)
- [ ] USB kamera bağlı
- [ ] Uygulamayı çalıştırabiliyorsun

**Hepsi tamamdaysa → USB modülü üretime hazır!** 🎉

---

## 📞 Destek

Herhangi bir test başarısız olursa:
1. Hata mesajını oku
2. İlgili test dosyasını aç (`test_usb_*.sh`)
3. TEST adımını bul ve açıklamasını oku
4. Kodda ilgili kısmı kontrol et (`video_source_usb.cpp`)

---

**Yapılı Test Tarihi:** 2025-01-17
**Yazılı Dil:** Bash (Linux/Unix)
**Destek:** C++ USB Video Capture Modülü
