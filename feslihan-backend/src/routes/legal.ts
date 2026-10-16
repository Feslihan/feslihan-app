import express from "express";

// Public legal pages (Kullanım Koşulları, Gizlilik Politikası, KVKK
// Aydınlatma Metni). Served unauthenticated — they are linked from the
// sign-up screen and App Store listing, where no session exists.
//
// NOT: Bu metinler uygulamanın gerçek veri pratiklerine göre hazırlanmış
// taslaklardır; yayına almadan önce bir hukukçuya gözden geçirtmek önerilir.

const LAST_UPDATED = "16 Ekim 2026";

function page(title: string, body: string): string {
  return `<!doctype html>
<html lang="tr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title} — Feslihan</title>
<style>
  :root { color-scheme: light dark; }
  body { font-family: -apple-system, "Segoe UI", Roboto, sans-serif; margin: 0; color: #111; background: #fff; }
  @media (prefers-color-scheme: dark) { body { color: #eee; background: #111; } }
  main { max-width: 680px; margin: 0 auto; padding: 48px 22px 80px; }
  .brand { display: flex; align-items: center; gap: 8px; color: #23834A; font-weight: 600; }
  h1 { font-family: Georgia, "Times New Roman", serif; font-size: 34px; margin: 18px 0 4px; }
  .date { color: #767676; font-size: 14px; margin-bottom: 32px; }
  h2 { font-family: Georgia, serif; font-size: 21px; margin-top: 36px; border-bottom: 1px solid #e5e5e5; padding-bottom: 6px; }
  p, li { line-height: 1.65; font-size: 16px; }
  a { color: #23834A; }
  footer { margin-top: 56px; color: #767676; font-size: 14px; border-top: 1px solid #e5e5e5; padding-top: 16px; }
</style>
</head>
<body>
<main>
  <div class="brand">🌿 Feslihan</div>
  <h1>${title}</h1>
  <div class="date">Son güncelleme: ${LAST_UPDATED}</div>
  ${body}
  <footer>Feslihan — Annenin yemek defteri, her zaman cebinde.<br>
  İletişim: <a href="mailto:destek@feslihan.app">destek@feslihan.app</a></footer>
</main>
</body>
</html>`;
}

const TERMS = page("Kullanım Koşulları", `
<p>Feslihan uygulamasını ("Uygulama") kullanarak aşağıdaki koşulları kabul etmiş olursunuz.</p>

<h2>1. Hizmetin Tanımı</h2>
<p>Feslihan; tarif kaydetme, yapay zekâ destekli tarif analizi ve haftalık yemek planlama, kiler ve alışveriş listesi yönetimi ile arkadaşlar arasında tarif paylaşımı sunan bir mobil uygulamadır.</p>

<h2>2. Hesap</h2>
<p>Uygulamayı kullanmak için bir hesap oluşturmanız gerekir. Hesabınızın güvenliğinden siz sorumlusunuz. Hesabınızı dilediğiniz an Ayarlar → Hesabı Sil adımıyla kalıcı olarak silebilirsiniz.</p>

<h2>3. Abonelik ve Ücretlendirme</h2>
<p>Uygulamanın bazı özellikleri (yapay zekâ ile tarif tarama ve haftalık plan oluşturma) aylık kullanım hakkıyla sınırlıdır; ek haklar App Store üzerinden abonelikle sunulur. Abonelikler Apple hesabınız üzerinden yönetilir ve iptal edilir. Yeni hesaplara tanımlanan deneme hakları süre sonunda otomatik olarak sona erer; deneme süresince ücret alınmaz.</p>

<h2>4. İçerik</h2>
<p>Uygulamaya eklediğiniz tarif bağlantıları üzerinden oluşturulan tarif içerikleri, kaynağına atıf korunarak uygulama kataloğunda saklanır. Yorumlarınız diğer kullanıcılar tarafından görülebilir. Hukuka aykırı, hakaret içeren veya üçüncü kişilerin haklarını ihlal eden içerik paylaşılamaz; bu tür içerikler kaldırılabilir.</p>

<h2>5. Sorumluluk Sınırı</h2>
<p>Tarif ve besin değeri bilgileri yapay zekâ desteğiyle üretilir ve bilgilendirme amaçlıdır; doğruluğu garanti edilmez. Alerji, diyet veya sağlıkla ilgili kararlar için uzmana danışınız.</p>

<h2>6. Değişiklikler</h2>
<p>Bu koşullar güncellenebilir; önemli değişiklikler uygulama içinden duyurulur. Güncel sürüm her zaman bu sayfada yayımlanır.</p>

<h2>7. Uygulanacak Hukuk</h2>
<p>Bu koşullar Türkiye Cumhuriyeti hukukuna tabidir. Uyuşmazlıklarda İstanbul (Anadolu) Mahkemeleri ve İcra Daireleri yetkilidir.</p>
`);

const PRIVACY = page("Gizlilik Politikası", `
<p>Bu politika, Feslihan uygulamasını kullandığınızda hangi verilerin, hangi amaçla işlendiğini açıklar.</p>

<h2>1. İşlenen Veriler</h2>
<ul>
  <li><strong>Hesap bilgileri:</strong> ad, e-posta adresi, profil fotoğrafı (kimlik sağlayıcımız Clerk aracılığıyla).</li>
  <li><strong>Uygulama verileri:</strong> kaydettiğiniz tarifler, kiler ve alışveriş listeleriniz, yemek planlarınız, tarif yorum ve puanlarınız, arkadaşlık bağlantılarınız ve tarif paylaşımlarınız.</li>
  <li><strong>Bildirim verileri:</strong> bildirim izni verdiyseniz cihazınıza ait anonim bildirim adresi (APNs token).</li>
  <li><strong>Abonelik durumu:</strong> satın alma ve abonelik durumu (RevenueCat ve Apple aracılığıyla; ödeme bilgileriniz bize ulaşmaz).</li>
</ul>

<h2>2. İşleme Amaçları</h2>
<p>Veriler; hizmetin sunulması (tarif saklama, plan oluşturma, paylaşım), yapay zekâ destekli analizlerin yapılması, bildirim gönderimi ve kullanım haklarının takibi amacıyla işlenir. Verileriniz reklam amaçlı üçüncü taraflarla paylaşılmaz ve satılmaz.</p>

<h2>3. Hizmet Sağlayıcılar</h2>
<p>Verileriniz, hizmetin çalışması için gereken altyapı sağlayıcılarında barındırılır veya işlenir: Clerk (kimlik), Vercel ve Neon (sunucu ve veritabanı), Amazon Web Services (görsel depolama), Anthropic (yapay zekâ analizi — yalnızca tarif içeriği iletilir), RevenueCat ve Apple (abonelik), Apple Push Notification servisi (bildirim).</p>

<h2>4. Saklama ve Silme</h2>
<p>Verileriniz hesabınız açık kaldığı sürece saklanır. Ayarlar → Hesabı Sil adımıyla hesabınızı sildiğinizde kişisel verileriniz (profil, listeler, planlar, yorumlar, bağlantılar, paylaşımlar ve bildirim adresleri) kalıcı olarak silinir. Ayarlar → Verilerimi İndir ile verilerinizin bir kopyasını alabilirsiniz.</p>

<h2>5. Haklarınız</h2>
<p>Verilerinize erişme, düzeltme, silme ve işlemeye itiraz haklarınız için <a href="mailto:destek@feslihan.app">destek@feslihan.app</a> adresine yazabilirsiniz. KVKK kapsamındaki ayrıntılar için <a href="/kvkk">KVKK Aydınlatma Metni</a>'ne bakınız.</p>
`);

const KVKK = page("KVKK Aydınlatma Metni", `
<p>6698 sayılı Kişisel Verilerin Korunması Kanunu ("KVKK") uyarınca, veri sorumlusu sıfatıyla Dilara Halavurt (İstanbul, Türkiye — <a href="mailto:destek@feslihan.app">destek@feslihan.app</a>) tarafından kişisel verileriniz aşağıda açıklanan kapsamda işlenmektedir.</p>

<h2>1. İşlenen Kişisel Veriler</h2>
<p>Kimlik ve iletişim verileri (ad, e-posta, profil görseli); uygulama kullanım verileri (tarifler, listeler, planlar, yorumlar, arkadaşlık bağlantıları, paylaşımlar); cihaz bildirim tanımlayıcısı; abonelik durumu.</p>

<h2>2. İşleme Amaçları ve Hukuki Sebepler</h2>
<p>Veriler; sözleşmenin kurulması ve ifası (KVKK m.5/2-c), hukuki yükümlülüklerin yerine getirilmesi (m.5/2-ç) ve meşru menfaat (m.5/2-f — hizmet güvenliği ve kullanım haklarının takibi) hukuki sebeplerine dayanılarak, hizmetin sunulması ve geliştirilmesi amacıyla işlenir.</p>

<h2>3. Aktarım</h2>
<p>Verileriniz, hizmetin teknik olarak sunulabilmesi için yurt dışında sunucuları bulunan hizmet sağlayıcılara (Clerk, Vercel, Neon, Amazon Web Services, Anthropic, RevenueCat, Apple) KVKK m.9 kapsamında açık rızanıza dayanılarak aktarılır. Uygulamayı kullanarak bu aktarıma açık rıza vermiş olursunuz; rızanızı hesabınızı silerek her zaman geri alabilirsiniz.</p>

<h2>4. Toplama Yöntemi</h2>
<p>Veriler, uygulama üzerinden elektronik ortamda, otomatik yollarla toplanır.</p>

<h2>5. KVKK m.11 Kapsamındaki Haklarınız</h2>
<p>Kişisel verilerinizin işlenip işlenmediğini öğrenme, işlenmişse bilgi talep etme, amacına uygun kullanılıp kullanılmadığını öğrenme, eksik/yanlış işlenmişse düzeltilmesini isteme, silinmesini veya yok edilmesini isteme, aktarıldığı üçüncü kişileri bilme, otomatik sistemlerle analiz sonucu aleyhinize bir sonucun ortaya çıkmasına itiraz etme ve zarara uğramanız hâlinde tazminat talep etme haklarına sahipsiniz.</p>
<p>Başvurularınızı <a href="mailto:destek@feslihan.app">destek@feslihan.app</a> adresine iletebilirsiniz; başvurular en geç 30 gün içinde yanıtlanır. Ayrıca uygulama içinden Ayarlar → Verilerimi İndir ve Ayarlar → Hesabı Sil adımlarıyla erişim ve silme haklarınızı doğrudan kullanabilirsiniz.</p>
`);

export function createLegalRouter(): express.Router {
  const router = express.Router();
  router.get("/kosullar", (_req, res) => res.type("html").send(TERMS));
  router.get("/gizlilik", (_req, res) => res.type("html").send(PRIVACY));
  router.get("/kvkk", (_req, res) => res.type("html").send(KVKK));
  return router;
}
