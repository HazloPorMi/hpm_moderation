/// Term lists for [ContentFilterService].
///
/// Every entry is already normalized: lowercase, no accents, ASCII letters
/// only. Matching is per whole word (token), so a term never matches inside
/// a longer word ("puta" does not match "computadora" or "reputación").
/// Because of that, the inflected forms that should also be blocked (plural,
/// feminine, -ing, ...) are listed explicitly.
library;

/// Insults and profanity, matched as single whole words.
const Set<String> offensiveWords = {
  // English
  'fuck', 'fucks', 'fucked', 'fucker', 'fuckers', 'fucking', 'fuckin',
  'fuckyou', 'motherfucker', 'motherfuckers',
  'shit', 'shits', 'shitty', 'bullshit', 'shithead',
  'bitch', 'bitches',
  'asshole', 'assholes',
  'bastard', 'bastards',
  'damn', 'damned', 'goddamn',
  'nigger', 'niggers',
  'faggot', 'faggots',
  'retard', 'retards', 'retarded',
  'kys', 'killyourself',
  // Spanish
  'puta', 'putas', 'puto', 'putos',
  'hijueputa', 'hijueputas', 'hijoputa', 'hijoputas', 'hijodeputa',
  'hijosdeputa',
  'mierda', 'mierdas',
  'cabron', 'cabrona', 'cabrones', 'cabronas',
  'pendejo', 'pendeja', 'pendejos', 'pendejas', 'pendejada', 'pendejadas',
  'verga', 'vergas',
  'marica', 'maricas', 'maricon', 'maricones',
  'joto', 'jotos',
  'zorra', 'zorras',
  'culero', 'culera', 'culeros', 'culeras',
  'chingar', 'chingada', 'chingado', 'chingadas', 'chingados',
  'chingarte', 'chingarlo', 'chingarla', 'chingaron',
  'malparido', 'malparida', 'malparidos', 'malparidas',
  'bastardo', 'bastarda', 'bastardos', 'bastardas',
  // "retardo" (delay) is ordinary Spanish and stays allowed.
  'retardado', 'retardada', 'retardados', 'retardadas',
};

/// Insults that are only offensive as a word sequence.
const List<String> offensivePhrases = [
  'kill yourself',
];

/// Off-platform payment / scam indicators, matched as single whole words.
///
/// "transferencia" is a POLICY term, not an insult: it is blocked to keep
/// payments on the platform (PixelPay) instead of a direct bank transfer
/// arranged in chat. Whether to keep it is an owner decision. Only the exact
/// word is matched ("transferencias" or "retransferencia" are not).
const Set<String> offPlatformPaymentWords = {
  'transferencia',
};

/// Off-platform payment / scam indicators matched as word sequences.
const List<String> offPlatformPaymentPhrases = [
  'send money',
  'wire transfer',
  'western union',
  'envia dinero',
];
