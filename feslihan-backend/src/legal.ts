// Static legal pages served at feslihan.app/kosullar and feslihan.app/gizlilik.
// Linked from the iOS app's SettingsView and reviewed by the App Store team, so
// they must be served live (no auth) on the app domain. Content is in Turkish;
// the privacy policy covers KVKK (Law No. 6698) obligations for Turkish users.

const SUPPORT_EMAIL = "destek@feslihan.app";
const LAST_UPDATED = "15 Ekim 2026";

// Shared document shell: mobile-friendly, self-contained (no external assets so
// it renders even if the request can't reach S3/CDN), basil-green accent.
function page(title: string, body: string): string {
  return `<!DOCTYPE html>
<html lang="tr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="index, follow">
<title>${title} · Feslihan</title>
<style>
  :root { --green: #4a7c59; --ink: #22302a; --muted: #5b6b63; --cream: #fbfaf5; }
  * { box-sizing: border-box; }
  body {
    margin: 0;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    color: var(--ink);
    background: var(--cream);
    line-height: 1.65;
  }
  .wrap { max-width: 720px; margin: 0 auto; padding: 32px 20px 64px; }
  header { border-bottom: 2px solid var(--green); padding-bottom: 16px; margin-bottom: 24px; }
  h1 { color: var(--green); font-size: 1.7rem; margin: 0 0 4px; }
  h2 { color: var(--green); font-size: 1.2rem; margin: 32px 0 8px; }
  h3 { font-size: 1.02rem; margin: 20px 0 6px; }
  p, li { color: var(--ink); }
  ul { padding-left: 20px; }
  li { margin: 4px 0; }
  a { color: var(--green); }
  .meta { color: var(--muted); font-size: 0.9rem; }
  footer { margin-top: 40px; padding-top: 16px; border-top: 1px solid #e3e0d4; color: var(--muted); font-size: 0.85rem; }
</style>
</head>
<body>
  <div class="wrap">
    <header>
      <h1>${title}</h1>
      <p class="meta">Son güncelleme: ${LAST_UPDATED}</p>
    </header>
    ${body}
    <footer>
      <p>Sorularınız için: <a href="mailto:${SUPPORT_EMAIL}">${SUPPORT_EMAIL}</a></p>
      <p>© 2026 Feslihan. Tüm hakları saklıdır.</p>
    </footer>
  </div>
</body>
</html>`;
}

export const privacyPolicyHtml = page("Gizlilik Politikası", `
  <p>Bu Gizlilik Politikası, Feslihan mobil uygulamasını ("Uygulama") kullanımınız sırasında
  kişisel verilerinizin nasıl toplandığını, işlendiğini ve korunduğunu açıklar. Kullanıcılarımızın
  önemli bir bölümü Türkiye'de bulunduğundan, verileriniz 6698 sayılı Kişisel Verilerin Korunması
  Kanunu ("KVKK") ve ilgili mevzuata uygun olarak işlenir.</p>

  <h2>1. Veri Sorumlusu</h2>
  <p>KVKK kapsamında veri sorumlusu, Feslihan uygulamasını işleten ekiptir. Kişisel verilerinizle
  ilgili her türlü talep ve soru için <a href="mailto:${SUPPORT_EMAIL}">${SUPPORT_EMAIL}</a>
  adresinden bize ulaşabilirsiniz.</p>

  <h2>2. İşlediğimiz Kişisel Veriler</h2>
  <ul>
    <li><strong>Kimlik ve iletişim verileri:</strong> Adınız, e-posta adresiniz ve profil
    fotoğrafınız (hesap oluşturduğunuzda kimlik doğrulama sağlayıcımız aracılığıyla).</li>
    <li><strong>Hesap ve kullanım verileri:</strong> Kaydettiğiniz tarifler, oluşturduğunuz
    yemek planları, kiler ve alışveriş listeleri, klasörler ve favoriler.</li>
    <li><strong>Abonelik verileri:</strong> Satın alma ve abonelik durumu bilgileri (ödeme kartı
    bilgileri bizimle paylaşılmaz; ödemeler App Store üzerinden gerçekleşir).</li>
    <li><strong>İçerik verileri:</strong> Uygulamaya aktardığınız tarif bağlantıları, görseller ve
    metinler.</li>
    <li><strong>Teknik veriler:</strong> Cihaz türü, uygulama sürümü ve hizmetin çalışması için
    gereken temel günlük (log) kayıtları.</li>
  </ul>

  <h2>3. İşleme Amaçları</h2>
  <ul>
    <li>Hesabınızı oluşturmak ve güvenli oturum açmanızı sağlamak,</li>
    <li>Tarif, yemek planı ve alışveriş listesi gibi temel özellikleri sunmak,</li>
    <li>Yapay zekâ destekli tarif ve besin değeri analizini gerçekleştirmek,</li>
    <li>Abonelik haklarınızı yönetmek ve satın alımları doğrulamak,</li>
    <li>Destek taleplerinizi yanıtlamak ve hizmet kalitesini iyileştirmek.</li>
  </ul>

  <h2>4. İşlemenin Hukuki Sebepleri (KVKK m. 5)</h2>
  <p>Kişisel verileriniz; bir sözleşmenin kurulması veya ifasıyla doğrudan ilgili olması, hukuki
  yükümlülüklerimizin yerine getirilmesi, temel hak ve özgürlüklerinize zarar vermemek kaydıyla
  meşru menfaatlerimiz ve gerektiğinde açık rızanız hukuki sebeplerine dayanılarak işlenir.</p>

  <h2>5. Verilerin Aktarılması</h2>
  <p>Hizmetin sunulabilmesi için kişisel verileriniz, yalnızca ilgili amaçla sınırlı olarak aşağıdaki
  hizmet sağlayıcılarla paylaşılabilir:</p>
  <ul>
    <li><strong>Kimlik doğrulama</strong> – oturum açma ve hesap yönetimi,</li>
    <li><strong>Abonelik yönetimi ve App Store</strong> – satın alımların doğrulanması,</li>
    <li><strong>Bulut altyapısı ve depolama</strong> – verilerin ve görsellerin barındırılması,</li>
    <li><strong>Yapay zekâ servisi</strong> – tarif ve besin analizi için gönderilen içerik.</li>
  </ul>
  <p>Bu sağlayıcıların bir kısmı yurt dışında bulunabilir; bu durumda aktarım KVKK m. 9 kapsamında,
  gerekli güvenlik tedbirleri alınarak gerçekleştirilir. Verileriniz pazarlama amacıyla üçüncü
  taraflara satılmaz.</p>

  <h2>6. Saklama Süresi</h2>
  <p>Kişisel verileriniz, hesabınız aktif olduğu sürece ve ilgili mevzuatın öngördüğü süreler
  boyunca saklanır. Hesabınızı sildiğinizde, verileriniz makul bir süre içinde ve yasal saklama
  yükümlülükleri saklı kalmak kaydıyla silinir veya anonim hâle getirilir.</p>

  <h2>7. İlgili Kişi Olarak Haklarınız (KVKK m. 11)</h2>
  <p>KVKK uyarınca; kişisel verilerinizin işlenip işlenmediğini öğrenme, işlenmişse buna ilişkin
  bilgi talep etme, işlenme amacını öğrenme, yurt içinde veya yurt dışında aktarıldığı üçüncü
  kişileri bilme, eksik veya yanlış işlenmişse düzeltilmesini isteme, silinmesini veya yok
  edilmesini isteme, işlemenin münhasıran otomatik sistemlerle analizi sonucu aleyhinize bir
  sonucun ortaya çıkmasına itiraz etme ve zararın giderilmesini talep etme haklarına sahipsiniz.</p>
  <p>Hesabınızı ve ilişkili verilerinizi doğrudan Uygulama içindeki Ayarlar bölümünden silebilir;
  diğer taleplerinizi <a href="mailto:${SUPPORT_EMAIL}">${SUPPORT_EMAIL}</a> adresine
  iletebilirsiniz.</p>

  <h2>8. Veri Güvenliği</h2>
  <p>Verilerinizi yetkisiz erişime, kayba ve kötüye kullanıma karşı korumak için şifreli iletişim ve
  erişim kontrolleri gibi uygun teknik ve idari tedbirleri uygularız.</p>

  <h2>9. Çocukların Gizliliği</h2>
  <p>Uygulama 13 yaşından küçük çocuklara yönelik değildir ve bilerek bu yaş grubundan kişisel veri
  toplamayız.</p>

  <h2>10. Değişiklikler</h2>
  <p>Bu politikayı zaman zaman güncelleyebiliriz. Önemli değişikliklerde Uygulama üzerinden veya
  bu sayfada bilgilendirme yaparız. Güncel sürümün yürürlük tarihi sayfanın başında belirtilir.</p>

  <h2>11. İletişim</h2>
  <p>Gizlilikle ilgili tüm soru ve talepleriniz için:
  <a href="mailto:${SUPPORT_EMAIL}">${SUPPORT_EMAIL}</a></p>
`);

export const termsHtml = page("Kullanım Koşulları", `
  <p>Feslihan mobil uygulamasını ("Uygulama") kullanarak aşağıdaki Kullanım Koşullarını kabul
  etmiş olursunuz. Lütfen Uygulamayı kullanmadan önce bu koşulları dikkatlice okuyun.</p>

  <h2>1. Hizmetin Tanımı</h2>
  <p>Feslihan; tarif kaydetme, yemek planlama, kiler ve alışveriş listesi yönetimi ile yapay zekâ
  destekli tarif ve besin değeri analizi sunan bir yemek planlama uygulamasıdır. Hizmet özellikleri
  zaman zaman güncellenebilir.</p>

  <h2>2. Hesap</h2>
  <p>Uygulamanın bazı özelliklerini kullanmak için bir hesap oluşturmanız gerekir. Hesap bilgilerinizin
  gizliliğinden ve hesabınız üzerinden gerçekleştirilen işlemlerden siz sorumlusunuz. Verdiğiniz
  bilgilerin doğru ve güncel olmasını sağlamalısınız.</p>

  <h2>3. Abonelik ve Ödemeler</h2>
  <ul>
    <li>Uygulama, ücretli abonelik ("Premium") özellikleri sunabilir.</li>
    <li>Ödemeler Apple App Store üzerinden tahsil edilir ve App Store koşullarına tabidir.</li>
    <li>Abonelikler, mevcut dönem bitmeden iptal edilmediği sürece otomatik olarak yenilenir.</li>
    <li>Aboneliğinizi App Store hesap ayarlarınızdan yönetebilir veya iptal edebilirsiniz.</li>
    <li>İade talepleri, Apple'ın geçerli iade politikalarına göre değerlendirilir.</li>
  </ul>

  <h2>4. Kullanıcı Yükümlülükleri</h2>
  <ul>
    <li>Uygulamayı yalnızca yasalara uygun ve meşru amaçlarla kullanırsınız.</li>
    <li>Hizmetin işleyişini bozacak, güvenliğini tehlikeye atacak veya başkalarının haklarını
    ihlal edecek davranışlardan kaçınırsınız.</li>
    <li>Uygulamaya aktardığınız içeriklere ilişkin gerekli hak ve izinlere sahip olduğunuzu kabul
    edersiniz.</li>
  </ul>

  <h2>5. İçerik ve Fikri Mülkiyet</h2>
  <p>Uygulamadaki yazılım, tasarım ve markalar Feslihan'a veya lisans verenlerine aittir ve fikri
  mülkiyet haklarıyla korunur. Üçüncü kişi platformlarından aktardığınız tarifler ilgili hak
  sahiplerine aittir; bu içeriklerin kullanımından siz sorumlusunuz.</p>

  <h2>6. Yapay Zekâ Özellikleri</h2>
  <p>Tarif ve besin değeri analizleri yapay zekâ ile otomatik olarak üretilir ve yalnızca bilgilendirme
  amaçlıdır. Bu bilgiler tıbbi veya diyet tavsiyesi niteliği taşımaz; sonuçlar hatalı veya eksik
  olabilir. Sağlığınızı ilgilendiren kararlarda bir uzmana danışmanız önerilir.</p>

  <h2>7. Sorumluluğun Sınırlandırılması</h2>
  <p>Uygulama "olduğu gibi" sunulur. Yürürlükteki mevzuatın izin verdiği ölçüde, Uygulamanın
  kesintisiz veya hatasız çalışacağına dair garanti verilmez ve dolaylı zararlardan sorumluluk
  kabul edilmez.</p>

  <h2>8. Hesabın Askıya Alınması veya Kapatılması</h2>
  <p>Bu koşulların ihlali hâlinde hesabınızı askıya alabilir veya kapatabiliriz. Dilediğiniz zaman
  Uygulama içindeki Ayarlar bölümünden hesabınızı silebilirsiniz.</p>

  <h2>9. Değişiklikler</h2>
  <p>Bu koşulları zaman zaman güncelleyebiliriz. Güncel sürüm bu sayfada yayımlanır ve yürürlük
  tarihi sayfanın başında belirtilir. Değişikliklerin ardından Uygulamayı kullanmaya devam etmeniz
  güncel koşulları kabul ettiğiniz anlamına gelir.</p>

  <h2>10. Uygulanacak Hukuk</h2>
  <p>Bu koşullar Türkiye Cumhuriyeti kanunlarına tabidir ve bu kanunlara göre yorumlanır.</p>

  <h2>11. İletişim</h2>
  <p>Kullanım koşullarıyla ilgili sorularınız için:
  <a href="mailto:${SUPPORT_EMAIL}">${SUPPORT_EMAIL}</a></p>
`);
