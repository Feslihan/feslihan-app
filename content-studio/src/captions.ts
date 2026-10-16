import Anthropic from "@anthropic-ai/sdk";
import type { SeedRecipe } from "../../feslihan-backend/src/platform-recipes-data.js";

const client = new Anthropic({ timeout: 120_000, maxRetries: 2 });
const MODEL = "claude-sonnet-4-6";

const VOICE = `Sen Feslihan'ın sosyal medya sesisin. Feslihan, "Annenin yemek defteri,
her zaman cebinde" sloganlı bir tarif ve yemek planlama uygulaması. Ses tonu: sıcak,
samimi, anne mutfağı nostaljisi; asla satışçı ya da abartılı değil. Kısa cümleler,
doğal Türkçe. Emoji az ve yerinde (en fazla 2).`;

function parseJson<T>(text: string): T {
  const cleaned = text.replace(/```json\s*/g, "").replace(/```\s*/g, "").trim();
  return JSON.parse(cleaned) as T;
}

async function ask<T>(prompt: string): Promise<T> {
  const response = await client.messages.create({
    model: MODEL,
    max_tokens: 1024,
    messages: [{ role: "user", content: prompt }],
  });
  const text = response.content[0].type === "text" ? response.content[0].text : "";
  return parseJson<T>(text);
}

export interface CaptionResult {
  caption: string;
  hashtags: string[];
  alt_text: string;
}

export async function recipeCaption(recipe: SeedRecipe): Promise<CaptionResult> {
  return ask<CaptionResult>(`${VOICE}

Aşağıdaki tarif için bir Instagram gönderi metni yaz. Görselde tarifin malzeme
kartı var; caption görseli tekrarlamasın, tarifin hikâyesine/duygusuna dokunsun
ve yapılışın uygulamada olduğunu doğal bir cümleyle söylesin.

Tarif: ${recipe.title}
Mutfak: ${recipe.cuisine} · Süre: ${recipe.cookingTimeMinutes} dk · ${recipe.servings} kişilik
Öne çıkan malzemeler: ${recipe.ingredientsWithMeasures.slice(0, 5).map((i) => i.name).join(", ")}

Örnek ses (farklı tarifler için):
- "Kokusu mutfağa yayıldığında herkes sofraya kendiliğinden gelir. Mercimek çorbası işte böyle bir şey. 🍲 Tam ölçülü tarifi Feslihan'da."
- "Annemin karnıyarığı hep bir tık daha lezzetliydi; sırrı sabırla kavrulan soğanmış. Tarifin tamamı uygulamada."

SADECE şu JSON'u döndür:
{"caption": "2-3 cümle", "hashtags": ["#...", 8-12 adet, Türkçe, yemek/tarif odaklı, #feslihan dahil"], "alt_text": "görme engelli kullanıcılar için tek cümlelik görsel açıklaması"}`);
}

export async function suggestionCaption(recipe: SeedRecipe): Promise<CaptionResult & { hook: string }> {
  return ask<CaptionResult & { hook: string }>(`${VOICE}

"Yarın ne pişirsem?" serisinin yeni gönderisi. Görselde, uygulamanın her akşam
20:00'de gönderdiği öneri bildirimi var; bugünün önerisi: ${recipe.title}.
Seri fikri: "bu soruyu her gün senin yerine cevaplıyoruz".

SADECE şu JSON'u döndür:
{"hook": "görselin altına gelecek tek cümlelik, serif-italik tonda duygusal/espirili bir cümle (soru yorgunluğuna dokunan)", "caption": "2-3 cümle; seriyi ve uygulamanın bildirim özelliğini doğal anlatan", "hashtags": ["#...", 8-12 adet, #feslihan ve #nepisirsem dahil"], "alt_text": "tek cümlelik görsel açıklaması"}`);
}

export interface TipResult extends CaptionResult {
  tip_title: string;
  tip_body: string;
  anne_notu: string;
}

export async function tipContent(topic: string): Promise<TipResult> {
  return ask<TipResult>(`${VOICE}

Mutfak ipucu kartı üretiyoruz. Konu: ${topic}.

SADECE şu JSON'u döndür:
{"tip_title": "kart başlığı, 4-7 kelime, pratik ve merak uyandıran",
 "tip_body": "ipucunun kendisi, 2-4 kısa cümle, net ve uygulanabilir; gerekiyorsa satır arası için \\n kullan",
 "anne_notu": "tek cümlelik, anneanne bilgeliği tonunda sıcak bir ek not",
 "caption": "2-3 cümlelik gönderi metni; ipucunu tekrarlamadan tamamlayan",
 "hashtags": ["#...", 8-12 adet, #feslihan ve #mutfakipucu dahil"],
 "alt_text": "tek cümlelik görsel açıklaması"}`);
}
