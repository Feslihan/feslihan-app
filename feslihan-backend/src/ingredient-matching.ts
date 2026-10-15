// Ingredient name normalization and fuzzy matching, shared by the server
// (src/index.ts) and one-off maintenance scripts (scripts/).

const turkishWordMap: Record<string, string> = {
  sarimsak: "sarımsak",
  sarmısak: "sarımsak",
  sogan: "soğan",
  sogani: "soğanı",
  kiyma: "kıyma",
  feslegen: "fesleğen",
  cilek: "çilek",
  salca: "salça",
  salcasi: "salçası",
  nisasta: "nişasta",
  kirmizi: "kırmızı",
  yesil: "yeşil",
  kasar: "kaşar",
  yogurt: "yoğurt",
  sut: "süt",
  tereyagi: "tereyağı",
  zeytinyagi: "zeytinyağı",
  seker: "şeker",
  sekeri: "şekeri",
  pirinc: "pirinç",
  havuc: "havuç",
  patlican: "patlıcan",
  fistik: "fıstık",
  fistigi: "fıstığı",
  ispanak: "ıspanak",
  baligi: "balığı",
  yapragi: "yaprağı",
  tatli: "tatlı",
  misir: "mısır",
  pirasa: "pırasa",
  salatalik: "salatalık",
  seftali: "şeftali",
  kayisi: "kayısı",
  visne: "vişne",
  uzum: "üzüm",
  cicek: "çiçek",
  corek: "çörek",
  corekotu: "çörekotu",
  aci: "acı",
  bugday: "buğday",
  cesnisi: "çeşnisi",
  pastirma: "pastırma",
  corba: "çorba",
  borek: "börek",
  guvec: "güveç",
  kofte: "köfte",
  tursu: "turşu",
  recel: "reçel",
  lavash: "lavaş",
  cikolata: "çikolata",
  biskuvi: "bisküvi",
  eriste: "erişte",
  findik: "fındık",
  kori: "köri",
  kornison: "kornişon",
  yagi: "yağı",
  yag: "yağ",
  eksisi: "ekşisi",
  sivi: "sıvı",
  siviyag: "sıvı yağ",
  sıvıyağ: "sıvı yağ",
  tatlandirici: "tatlandırıcı",
  zerdecal: "zerdeçal",
  arpacik: "arpacık",
  ezmesi: "ezmesi",
  cipsi: "cipsi",
  mercimek: "mercimek",
  peyniri: "peyniri",
  pudra: "pudra",
  kabartma: "kabartma",
  fasulye: "fasulye",
  dolma: "dolma",
  sucuk: "sucuk",
  susam: "susam",
  kuskus: "kuskus",
  incir: "incir",
};

function turkishCapitalizeWord(word: string): string {
  if (!word) return word;
  const first = word[0];
  if (first === "i") return "İ" + word.slice(1);
  if (first === "ı") return "I" + word.slice(1);
  return first.toLocaleUpperCase("tr-TR") + word.slice(1);
}

// Words that should stay lowercase (connectors/prepositions)
const LOWERCASE_WORDS = new Set(["veya", "ve", "için", "ile", "ya", "da"]);

export function fixTurkish(name: string): string {
  // NFC-normalize first: iOS clients send decomposed Unicode ("ğ" as
  // "g" + combining breve), which breaks every string comparison and
  // produced invisible duplicate ingredient rows.
  const lower = name.normalize("NFC").toLocaleLowerCase("tr-TR").replace(/\s+/g, " ").trim();
  // Fix each word: apply word map, then capitalize (except connectors)
  const words = lower.split(/\s+/).map((w) => turkishWordMap[w] ?? w);
  return words
    .map((w, i) => (i > 0 && LOWERCASE_WORDS.has(w)) ? w : turkishCapitalizeWord(w))
    .join(" ");
}

// Bigram similarity (Dice coefficient) for fuzzy matching
function bigrams(str: string): Set<string> {
  const s = str.toLocaleLowerCase("tr-TR").trim();
  const set = new Set<string>();
  for (let i = 0; i < s.length - 1; i++) set.add(s.slice(i, i + 2));
  return set;
}

export function diceCoefficient(a: string, b: string): number {
  const biA = bigrams(a);
  const biB = bigrams(b);
  if (biA.size === 0 && biB.size === 0) return a.toLocaleLowerCase("tr-TR") === b.toLocaleLowerCase("tr-TR") ? 1 : 0;
  let intersection = 0;
  for (const bi of biA) if (biB.has(bi)) intersection++;
  return (2 * intersection) / (biA.size + biB.size);
}

// Suffixes that fundamentally change the ingredient (X ≠ X yağı, X unu, etc.)
const PRODUCT_FORM_SUFFIXES = [
  " yağı", " yağ", " unu", " un", " suyu", " sosu", " sos",
  " ezmesi", " püresi", " rendesi", " tozu", " toz",
  " cipsi", " gevreği", " lapası", " sütü", " süt",
  " peyniri", " peynir", " ekmeği", " ekmek",
  " eti", " fileto",
];

// Suffixes that are just alternate names (safe to strip for matching)
const COSMETIC_SUFFIXES = [
  " içi", // ceviz içi = ceviz
];

// Prefixes that are qualifiers, not identity changers (safe to ignore for matching)
const IGNORABLE_PREFIXES = [
  "taze ", "kuru ", "organik ", "toz ", "çiğ ",
  "büyük ", "küçük ", "orta ", "orta boy ",
  "az yağlı ", "tam yağlı ", "yağsız ", "ekstra ",
  "kavrulmuş ", "közlenmiş ", "haşlanmış ", "eritilmiş ", "fırınlanmış ",
  "rendelenmiş ", "doğranmış ", "dilimlenmiş ", "süzme ",
  "ince ", "iri ", "sade ", "light ",
  "pul ", "tane ", "çekilmiş ", "öğütülmüş ",
  "soğuk ", "ılık ", "sıcak ",
  "koyu ", "açık ",
  // Dairy brand names ("İçim Labne" = "Labne")
  "içim ", "pınar ", "sütaş ", "torku ", "ülker ",
];

// Measure units that can lead an ingredient line ("2 su bardağı un",
// "yarım demet maydanoz"). Multi-word units first so "çay bardağı" wins
// over "bardak". Matched only as a leading word followed by more text,
// so standalone names ("Çay", "Su") are never consumed.
const MEASURE_UNITS = [
  "su bardağına yakın", "bardağa yakın", "yemek kaşığı", "tatlı kaşığı",
  "çay kaşığı", "su bardağı", "çay bardağı", "kahve fincanı", "orta boy",
  "subardağı", "litre", "paket", "demet", "dilim", "porsiyon", "fincan",
  "bardak", "tutam", "çimdik", "yaprak", "avuç", "adet", "kaşık", "kilo",
  "büyük", "küçük", "orta", "kase", "boy", "dal", "diş", "gram",
  "kg", "gr", "ml", "lt", "g",
];

// Spelled-out amounts ("bir adet limon", "yarım demet maydanoz")
const NUMBER_WORDS = [
  "bir buçuk", "iki buçuk", "yarım", "buçuk", "çeyrek",
  "bir", "iki", "üç", "dört", "beş", "altı", "yedi", "sekiz", "dokuz", "on",
];

// Split a leading amount + unit off an ingredient line:
//   "3-4 kaşık zeytinyağı"    → { amount: "3-4 kaşık", name: "zeytinyağı" }
//   "yarım demet maydanoz"    → { amount: "yarım demet", name: "maydanoz" }
//   "Sarımsaklı yoğurt"       → { amount: "", name: "Sarımsaklı yoğurt" }
// Never consumes the whole string — a bare unit-like name stays intact.
export function splitAmountFromName(raw: string): { amount: string; name: string } {
  const cleaned = raw.normalize("NFC").replace(/\s+/g, " ").trim();
  const lower = cleaned.toLocaleLowerCase("tr-TR");
  let pos = 0;
  while (pos < lower.length) {
    const rest = lower.slice(pos);
    // Numeric amounts incl. fractions and ranges: "1,5", "3-4", "8+1", "½"
    const numMatch = rest.match(/^[+-]?[\d½¼¾⅓⅔]+(?:\s*[.,/+-]\s*[\d½¼¾⅓⅔]+)*\s*/);
    if (numMatch) {
      pos += numMatch[0].length;
      continue;
    }
    const word = [...NUMBER_WORDS, ...MEASURE_UNITS].find((w) => rest.startsWith(w + " "));
    if (!word) break;
    pos += word.length + 1;
  }
  const name = cleaned.slice(pos).trim();
  if (!name) return { amount: "", name: cleaned };
  return { amount: cleaned.slice(0, pos).trim(), name };
}

export function getProductForm(name: string): string | null {
  const lower = name.toLocaleLowerCase("tr-TR").trim();
  for (const suffix of PRODUCT_FORM_SUFFIXES) {
    if (lower.endsWith(suffix)) return suffix.trim();
  }
  return null;
}

function stripPrefixes(name: string): string {
  let s = name.toLocaleLowerCase("tr-TR").trim();
  let changed = true;
  while (changed) {
    changed = false;
    for (const prefix of IGNORABLE_PREFIXES) {
      if (s.startsWith(prefix)) {
        s = s.slice(prefix.length);
        changed = true;
      }
    }
  }
  return s;
}

export function normalizeForMatch(name: string): string {
  // Strip any leading amount/measure words first ("1 çay kaşığı tuz" → "tuz"),
  // then qualifier prefixes and cosmetic suffixes.
  let s = stripPrefixes(splitAmountFromName(name).name);
  for (const suffix of COSMETIC_SUFFIXES) {
    if (s.endsWith(suffix)) { s = s.slice(0, -suffix.length).trim(); break; }
  }
  // Canonicalize spelling variants ("sıvıyağ" → "sıvı yağ") so both sides of
  // a comparison land on the same form.
  return s.split(/\s+/).map((w) => turkishWordMap[w] ?? w).join(" ");
}

export function findBestMatch(
  name: string,
  allIngredients: { id: string; name: string }[]
): { id: string; name: string } | null {
  const normA = normalizeForMatch(name);
  const formA = getProductForm(normA);

  let bestScore = 0;
  let bestMatch: { id: string; name: string } | null = null;

  for (const existing of allIngredients) {
    const normB = normalizeForMatch(existing.name);
    const formB = getProductForm(normB);

    // If product forms differ, never merge (e.g. "Susam" vs "Susam yağı")
    if (formA !== formB) continue;

    // Exact normalized match (after stripping prefixes + cosmetic suffixes)
    if (normA === normB) return existing;

    // Bigram similarity on normalized forms (high threshold)
    const dice = diceCoefficient(normA, normB);
    if (dice > 0.8 && dice > bestScore) {
      bestScore = dice;
      bestMatch = existing;
    }
  }

  return bestMatch;
}
