# iPhone ANGLE denemesi

iPhone'da OpenGL ES 3.0 çizimini ANGLE (Metal) üzerinden deneyen küçük bir uygulama.
Ekranda dönen bir üçgen ve kayan bir çubuk çizer; ekran kartını, ekran hızını (120 Hz) ve ölçülen kare hızını gösterir.
Ekrana dokununca 60 Hz ile ekranın en yüksek hızı arasında geçer.

- ANGLE her derlemede kaynağından derlenir (`ios/angle_surum.txt` içindeki sabit sürüm), sonra önbellekten kullanılır.
- Derleme GitHub Actions'ta (macOS) yapılır; çıktı imzasız `MSP2Deneme.ipa` dosyasıdır.
- Telefona kurulum Sideloadly ile, kullanıcının kendi Apple hesabıyla yapılır.

ANGLE lisansı uygulama paketinde `ANGLE_LICENSE` olarak bulunur.
