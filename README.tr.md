# Redmine Dashboard

Kayıtlı bir iş sorgusunun güncel sonucundan istatistik panosu oluşturur.

[English](README.md)

## Yenilikler

* 0.1.0: İlk sürüm. Ayrıntılar [CHANGELOG](CHANGELOG.md) dosyasında.

## Ne yapar

* Kayıtlı iş sorgularından birini seçersiniz. Sayılar o sorgunun süzgeçlerine uyar ve işler değiştikçe güncellenir.
* Özet kartlarda toplam, açık, kapalı ve atanmamış sayıları durur.
* Panolarda öncelik, atanan, durum, iş tipi, sürüm, yazar ve birden fazla proje varsa proje dağılımı gösterilir. Örnek: P1 12, Furkan 15.
* Her satırda çubuk, adet ve toplam içindeki pay vardır.
* Sayfa üst menüde ve proje sekmesinde açılır. Proje içinde genel bir sorgu o projeyle sınırlanır.

## Redmine sürümü

* 4.2.x ~ 6.x

Veritabanı göçü, ek gem ve asset derlemesi gerekmez.

## Kurulum

1. Redmine `plugins` dizininde:

```bash
git clone https://github.com/oten52/Redmine.Dashboard.git
```

Klasör adı `Redmine.Dashboard` olarak kalabilir.

2. Redmine'ı yeniden başlatın.

Üst menüden Pano'yu açın veya projenin içindeki Pano sekmesine girin. Kayıtlı bir sorgu seçin.

## Kaldırma

1. `Redmine.Dashboard` klasörünü silin.
2. Redmine'ı yeniden başlatın.

## Yazar

Niltek Arge — https://github.com/oten52

## Lisans

GNU General Public License v3.0 veya sonrası. Ayrıntı için [LICENSE](LICENSE).

Bu eklentiyi değiştirip dağıtırsanız telif bildirimlerini koruyun, değişikliklerinizi belirtin ve
sürümünüzü aynı lisansla dağıtın.
