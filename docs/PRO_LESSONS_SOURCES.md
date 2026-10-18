# Balatro (vanilla 1.0.1): lessons from top players, written as decision rules

Compiled 2026-10-18 for the Balatro Strategic Copilot advisor mod.

## How to read this

- Each item is a rule, followed by the source URL(s) it comes from. Every URL was opened during this research, except those marked "(search-result snippet)". Those were only seen in search results. For each one, the search engine linked the claim to that page, but I did not open the page to confirm the quote, so treat these as weaker evidence.
- Kinds of source:
  - **[W]**: official Balatro wiki (balatrowiki.org). Treat its numbers as exact.
  - **[G]**: a written guide or article.
  - **[C]**: a community or forum post by experienced players (Steam, PC Gamer forum).
  - **[D]**: my own derivation from wiki numbers. These are labelled; no source states them.
- **DISAGREEMENT** marks places where sources contradict each other.
- The Fandom wiki (balatrogame.fandom.com) returned HTTP 402 and could not be read. Reddit is blocked for the fetch tool. So the community material comes from the Steam forums, the PC Gamer forum, and written guides.

---

## 0. Ground rules: version, baseline, and "every seed is playable"

**0.1 Stakes in 1.0.1, which are cumulative.**
- White: no modifier.
- Red: Small Blind gives no reward money.
- Green: required score scales faster.
- Black: shop can have Eternal jokers.
- Blue: -1 discard.
- Purple: required score scales faster again.
- Orange: shop can have Perishable jokers ("debuffed after 5 rounds").
- Gold: shop can have Rental jokers ("$3 per round").
- [W] https://balatrowiki.org/w/Stakes

**0.2 Ignore pre-1.0.1 stake advice.** Patch 1.0.1f made two changes:
- Gold changed from "-1 hand size" to "30% Rental".
- Orange changed from "Booster Packs cost $1 more per Ante" to "30% Perishable".

Older guides that say Gold means -1 hand size are outdated. The 1.0.1 patch notes also list "Scrapped -1 hand size" for Gold and "Scrapped increasing pack cost" for Orange.
- [W] https://balatrowiki.org/w/Gold_Stake
- [W] https://balatrowiki.org/w/Orange_Stake
- [G] https://insider-gaming.com/balatro-is-getting-its-first-major-update/

**0.3 Baseline numbers for an un-modified deck.**
- $4 starting money, 8 hand size, 4 hands, 3 discards.
- 5 Joker slots, 2 consumable slots.
- $5 base reroll.
- On Blue stake and above (including Gold), discards drop to 2.
- [G] https://balatrocalc.com/blog/balatro-gameplay/
- [W] https://balatrowiki.org/w/Stakes

**0.4 "Every seed is playable" is the community consensus, but it is not proven.**
- "every seed on gold is winnable, as far as anyone has ever tested" (CMDR Shven).
- "I never saw a single seed that was proven impossible to beat. Even at gold stake" (malogoss).
- The developer reportedly believes a perfect player wins White Stake every time.
- **DISAGREEMENT:** some players believe a few Gold seeds are unwinnable, especially with early Rental or Perishable jokers (ccsk723, Mattrex). It remains an open problem.
- Sources:
  - [C] https://steamcommunity.com/app/2379780/discussions/0/595141367272838813/
  - [C] https://steamcommunity.com/app/2379780/discussions/0/4357869219921982825/

**0.5 What separates top players from the rest, according to the community.**
- "being really good at recognizing when to pivot diminishes a ton of rng" (RazzberryMocha).
- Failed runs without xMult usually trace back to "weak economy" (snakeskip).
- "being able to see a lot of cards is crucial" (snakeskip). Money buys rerolls and packs, which means more cards seen.
- [C] https://steamcommunity.com/app/2379780/discussions/0/595141367272838813/

**0.6 Top players audit every loss.**
- Balatro University (DrSpectred) reportedly had a streak of more than 40 wins on the highest difficulty. "the first thing he does after a defeat is to analyze his mistakes."
- Another post credits him with 66 consecutive Gold Stake wins. These streak figures are forum claims and were not verified.
- On losses, malogoss says: "you'll see it for what it is, a bunch of misplays by you."
- Rule for the advisor: never output "bad luck" as a loss cause without first running the post-mortem in section 10.
- Sources:
  - [C] https://steamcommunity.com/app/2379780/discussions/0/604142859631741886/?ctp=2
  - [C] https://steamcommunity.com/app/2379780/discussions/0/604167589085578695/
  - [C] https://steamcommunity.com/app/2379780/discussions/0/4694531145715173333

**0.7 Seeded RNG.**
- Shop contents and draws are set by the seed. "the RNG is set up to offer you the same things in the same order every run of a seed" (Goblin).
- Ronald Brain argues that randomness is fixed once a blind starts.
- Consequence: a loss on a seed can always be replayed to find the decision that went wrong.
- [C] https://steamcommunity.com/app/2379780/discussions/0/4357869219921982825/

---

## 1. Game phases and benchmarks

**1.1 Base chips per ante, confirmed from the wiki.** The White column matches the values you gave (300, 800, 2000, 5000, 11000, 20000, 35000, 50000).

| Ante | White and Red | Green, Black and Blue ("Green+") | Purple, Orange and Gold ("Purple+") |
|---|---|---|---|
| 1 | 300 | 300 | 300 |
| 2 | 800 | 900 | 1,000 |
| 3 | 2,000 | 2,600 | 3,200 |
| 4 | 5,000 | 8,000 | 9,000 |
| 5 | 11,000 | 20,000 | 25,000 |
| 6 | 20,000 | 36,000 | 60,000 |
| 7 | 35,000 | 60,000 | 110,000 |
| 8 | 50,000 | 100,000 | 200,000 |

- The Plasma Deck doubles all of these.
- [W] https://balatrowiki.org/w/Blinds_and_Antes
- [W] https://balatrowiki.org/w/Purple_Stake

**DISAGREEMENT: two different tables.**
- The 1.0.1 patch-note article lists:
  - Green: 900 / 2,400 / 7,000 for Antes 2-4.
  - Purple: 1,000 / 3,000 / 8,000 / 22,000 for Antes 2-5.
- The wiki and the mod's `blinds_db.lua` both use 2,600 / 8,000 (Green) and 3,200 / 9,000 / 25,000 (Purple).
- The patch notes were probably a pre-release change. The in-game `get_blind_amount()` is authoritative, and the mod already calls it when available.
- Sources:
  - [G] https://insider-gaming.com/balatro-is-getting-its-first-major-update/
  - [W] https://balatrowiki.org/w/Blinds_and_Antes

**1.2 Blind multipliers and rewards.**
- Small Blind is 1x base and Big Blind is 1.5x base.
- Boss Blinds are 2x base, with three exceptions: The Wall is 4x, Violet Vessel is 6x, and The Needle is 1x.
- Rewards: Small $3, Big $4, Boss $5, Showdown $8.
- On Red stake and above, the Small Blind pays $0.
- [W] https://balatrowiki.org/w/Blinds_and_Antes

**1.3 [D] Score targets per blind (Small / Big / Boss), computed from 1.1 and 1.2.**

| Ante | White | Green+ | Purple+ (includes Gold) |
|---|---|---|---|
| 1 | 300 / 450 / 600 | 300 / 450 / 600 | 300 / 450 / 600 |
| 2 | 800 / 1.2k / 1.6k | 900 / 1.35k / 1.8k | 1k / 1.5k / 2k |
| 3 | 2k / 3k / 4k | 2.6k / 3.9k / 5.2k | 3.2k / 4.8k / 6.4k |
| 4 | 5k / 7.5k / 10k | 8k / 12k / 16k | 9k / 13.5k / 18k |
| 5 | 11k / 16.5k / 22k | 20k / 30k / 40k | 25k / 37.5k / 50k |
| 6 | 20k / 30k / 40k | 36k / 54k / 72k | 60k / 90k / 120k |
| 7 | 35k / 52.5k / 70k | 60k / 90k / 120k | 110k / 165k / 220k |
| 8 | 50k / 75k / 100k | 100k / 150k / 200k | 200k / 300k / 400k |

- Violet Vessel at Ante 8 needs 300k (White), 600k (Green+) or 1.2M (Purple+). [W] https://balatrowiki.org/w/Violet_Vessel
- A Gold-stake guide gives the same figures: about 400k for the Ante 8 boss and 1.2M for Violet Vessel. [G] https://mancunion.com/2025/09/01/a-guide-to-gold-stake-balatro/
- The Wall at 4x is brutal late. For example, a Gold Ante 6 Wall needs 240k and a Gold Ante 7 Wall needs 440k.

**1.4 [D] The requirement grows faster than any additive build.**
- On Purple+ scaling, the base multiplies by these factors from one ante to the next:
  - Ante 3 to 4: x2.8
  - Ante 4 to 5: x2.8
  - Ante 5 to 6: x2.4
  - Ante 6 to 7: x1.8
  - Ante 7 to 8: x1.8
- Your score per hand must therefore roughly double every ante from Ante 3 on. Only multiplicative or scaling sources keep that pace.
- This matches "chips and flat mult stop mattering around Ante 5." [G] https://www.twoaveragegamers.com/balatro-strategy-guide-the-joker-combos-that-actually-win-runs/

**1.5 The health check: clear blinds in one or two hands.**
- "If you're not winning blinds in two or ideally one hand consistently, it's usually a sign that your build is falling behind." (PC Gamer, search-result snippet) https://pcgamer.com/balatro-tips
- "Buy enough to clear blinds in two hands most of the time, then let money build to $25." [G] https://steamcommunity.com/sharedfiles/filedetails/?id=3653261996
- Before the boss, ask: "does your build enable you to beat the current boss in one or two hands?" [G] https://steamcommunity.com/sharedfiles/filedetails/?id=3166946815
- **[D] Rule of thumb for the advisor:**
  - A 2-hand boss clear needs a typical hand score of at least the ante's base chips, because the boss is 2x base.
  - A 1-hand boss clear needs at least 2x base.
  - If the expected best hand for the next ante is below that ante's base, flag "falling behind" while there are still shops left to fix it.

**1.6 The end-of-Ante-2 checkpoint.**
- "If you have not found a way to increase scoring by the end of Ante 2, your deck likely cannot clear Ante 3 Blinds."
- [W] https://balatrowiki.org/w/Guide:_General_strategy

**1.7 Ante 1 can be won without jokers.** These are the no-joker thresholds for the 300-chip first blind:
- Full House: scored ranks must total at least 36 chips.
- Straight: the highest card must be a Queen or better.
- Flush: scored ranks must total at least 40 chips.
- Any Straight Flush or Four of a Kind wins outright.
- [W] https://balatrowiki.org/w/Guide:_General_strategy

**DISAGREEMENT: the first boss (600 chips).**
- "two 5-card hands without any help" (QuantuuM).
- Versus a one-shot with Jimbo and "almost any 5 card hand" (HattedHead).
- [C] https://steamcommunity.com/app/2379780/discussions/0/840628406751272258/

**1.8 Joker count benchmarks.**
- Buy at least one scoring joker before the first boss. Get a +Mult joker "in the first two shops, preferably the first shop."
- Aim for "4 or sometimes 5 jokers in your lineup at the end of ante 2 or the start of ante 3" (malogoss).
- **DISAGREEMENT:** "1-2 jokers ante 2" is enough (Wheelchair Murdura).
- [C] https://steamcommunity.com/app/2379780/discussions/0/4756452715167149899

**1.9 When xMult becomes mandatory.** Sources disagree on the exact ante, but they converge on a window:

| Source | xMult timing |
|---|---|
| QuantuuM (Steam) | Antes 3-4: seek xMult; non-scaling jokers "start to lose their power here" |
| Switchblade (deck-building mistakes) | One xMult joker by Antes 3-4 |
| Balatro HQ | "2-3 X Mult jokers online by Ante 4-5"; a common mistake is "Delaying your X Mult engine until Ante 7" |
| Steam guide 3653261996 | xMult is "critical for Antes six through eight"; without it "you will probably lose" |
| jeu.video (French) | Look for xMult at Antes 6-7 |
| Mel Gibson (Steam) | "X mults are not good until you have high base mults (via mult jokers and planets)" |

- **[D] Consensus window:** start acquiring xMult at Ante 3-4. Have at least 1 by Ante 5. Have 2-3 by Ante 7-8.
- Sources:
  - [C] https://steamcommunity.com/app/2379780/discussions/0/840628406751272258/
  - [G] https://www.switchbladegaming.com/strategy-games/balatro-deck-building-mistakes/
  - [G] https://balatrohq.com/guides/gold-stake-guide/
  - [G] https://steamcommunity.com/sharedfiles/filedetails/?id=3653261996
  - [G] https://jeu.video/guide/balatro-debutant-jokers
  - [C] https://steamcommunity.com/app/2379780/discussions/0/4694531145715173333

**1.10 Money benchmarks.**
- Hit the $25 interest cap by Ante 3.
  - [G] https://www.twoaveragegamers.com/balatro-strategy-guide-the-joker-combos-that-actually-win-runs/
  - [G] https://www.switchbladegaming.com/strategy-games/balatro-gold-stake-guide/
- Have Seed Money or To the Moon by Ante 4. [G] https://www.switchbladegaming.com/strategy-games/balatro-gold-stake-guide/
- About "$10 to 15" by the first boss (Kaamos_Llama). [C] https://forums.pcgamer.com/threads/balatro-tips-and-strategies-add-your-own.148962
- Leave shops with "20-25$" when possible (malogoss). [C] https://steamcommunity.com/app/2379780/discussions/0/4756452715167149899
- An older guide targets "$15 to $20" at the end of each shop phase. [G] https://addisonkindrick.substack.com/p/10-balatro-tier-list-addendum

**1.11 Phase plan, combined.**
- Ante 1-2: stabilise one hand type, protect the economy, and take power that solves the next blind.
- Ante 3-5: move from temporary value to scaling engines and prepare for known weaknesses.
- Ante 6+: compounding interactions, spend for reliability, no full pivots unless the run is collapsing.
- Sources:
  - [G] https://balatrocalc.com/blog/balatro-gameplay/
  - [G] https://balatrohq.com/guides/gold-stake-guide/ (Ante 1-3: one economy joker plus start a scaling joker; Ante 7-8: sell economy and bridge jokers for more multipliers)

**1.12 Commit to a hand type early.** Pick one by Ante 2-3 and level it with Planets at every shop.
- [G] https://balatrohq.com/guides/gold-stake-guide/
- [G] https://www.switchbladegaming.com/balatro/advanced-strategy-guide-2/

**1.13 Take scaling jokers early.**
- Non-retroactive growth jokers: "obtaining them earlier in a run will result in more effect." [W] https://balatrowiki.org/w/Guide:_Scaling
- "Don't take scaling +Mult Jokers after ante 4 or 5." [G] https://www.superjumpmagazine.com/all-in-advanced-strategies-for-earning-c-in-balatro/

---

## 2. Economy

**2.1 Interest rules, exactly.**
- $1 per $5 held at round end, capped at $5 per round (that is, $25 held).
- Seed Money raises the cap to $10 per round ($50 held).
- Money Tree raises it to $20 per round ($100 held). Money Tree unlocks by maxing interest for 10 consecutive rounds.
- To the Moon adds +$1 per $5 held:
  - $10 per round at $25 with no vouchers.
  - $20 per round with Seed Money.
  - $40 per round with Seed Money plus Money Tree.
- [W] https://balatrowiki.org/w/Interest

**2.2 Timing: what counts toward interest.**
- Income that arrives after the round ends does not count toward that round's interest. Examples are Golden Joker, Rocket, the blind reward, and the $1 per unused hand.
- Gold cards held in hand, and jokers that trigger before scoring (such as Reserved Parking), do count.
- Rule: the $25 must already be in your wallet when you leave the shop, plus whatever you earn during the round.
- [W] https://balatrowiki.org/w/Interest

**2.3 The $25 floor.**
- "Unless in a make-or-break situation, running a Vagabond build, or playing Green Deck, never drop below $25." [G] https://hardcoregamer.com/ten-tips-for-dominating-gold-stake-in-balatro/
- "I usually only spend down to the next multiple of 5" (Kaamos_Llama). [C] https://forums.pcgamer.com/threads/balatro-tips-and-strategies-add-your-own.148962
- "$25 is your floor, not your spending account." A $10 item bought from $25 costs $2 per round of interest; a $20 item costs $4 per round. [G] https://www.switchbladegaming.com/strategy-games/balatro-economy-strategy/

**2.4 Survival comes before interest. This tempers 2.3.**
- Ante 2: "Survival trumps money but you will need as much money as you can get" (QuantuuM). [C] https://steamcommunity.com/app/2379780/discussions/0/840628406751272258/
- Reaching $25 is the second priority, after "finding a joker/planet that helps you stay alive." [C] https://steamcommunity.com/app/2379780/discussions/0/604167589085578695/
- "Avant l'Ante 3, achetez ce qui vous rend plus fort tout de suite. Après l'Ante 3, commencez à protéger votre économie." (Before Ante 3, buy whatever makes you stronger right now. After Ante 3, start protecting your economy.) [G] https://jeu.video/guide/balatro-debutant-jokers
- Buying a scoring joker at the first shop is right. Skipping it is "a bit too greedy" (malogoss). [C] https://steamcommunity.com/app/2379780/discussions/0/4756452715167149899
- **DISAGREEMENT:**
  - "Econ is king": prioritise the economy and reach the cap as soon as possible. [G] https://mancunion.com/2025/09/01/a-guide-to-gold-stake-balatro/
  - "you don't need any joker to get through ante 1 quite reliably" (a minority view at low stakes). This came from a search-result snippet only, and I could not identify which thread it is from, so treat it as weak evidence.
  - **[D] Resolution for the advisor:** spend whatever is needed to make the next blind a 1-2 hand clear. Bank the rest up to $25.

**2.5 Clear the first antes on as little as possible.**
- "Learning to clear the first two or three antes on as little as possible to get your interest going is vital" (Black Hammer).
- A $10 loss early "can be a serious blow to your cash flow."
- [C] https://steamcommunity.com/app/2379780/discussions/0/4308327413812836587/?ctp=2

**2.6 Money for unused hands.**
- You get $1 per unused hand at cash-out. Discards pay nothing, except on Green Deck, which pays $2 per hand and $1 per discard instead of interest. [W] https://balatrowiki.org/w/Hands
- "Every hand 'costs money'": focus on discards and win each blind with one strong hand (Wheelchair Murdura). [C] https://steamcommunity.com/app/2379780/discussions/0/4756452715167149899
- **DISAGREEMENT:**
  - For per-hand scalers, "with 4 hands, use 3 to scale or farm money, then play one winning hand." [G] https://www.superjumpmagazine.com/all-in-advanced-strategies-for-earning-c-in-balatro/
  - On Blue Deck, "Play more, lower-quality hands to scale hand-based jokers." [G] https://mancunion.com/2025/09/01/a-guide-to-gold-stake-balatro/
  - **[D] Rule:** play an extra hand only if its permanent scaling gain is worth more than $1 (for example Green Joker, Ride the Bus, Supernova, Square Joker, Runner, Spare Trousers, Loyalty Card).

**2.7 Economy jokers pay for themselves fast.**
- "Almost every economy joker is worth taking temporarily, since it pays for itself in 1-2 rounds." [C] https://steamcommunity.com/app/2379780/discussions/0/604167589085578695/
- Exact values (shop cost in brackets):

| Joker | Effect |
|---|---|
| Golden Joker ($6) | $4 per round |
| Rocket ($6) | $1, +$2 per Boss defeated |
| To the Moon ($5) | +$1 interest per $5 |
| Cloud 9 ($7) | $1 per 9 in the deck |
| Egg ($4) | +$3 sell value per round |
| Gift Card ($6) | +$1 sell value to every Joker and consumable per round |
| Business Card ($4) | Played face cards: 1 in 2 for $2 |
| Reserved Parking ($6) | Held face cards: 1 in 2 for $1 |
| Delayed Gratification ($4) | $2 per discard if no discards are used |
| Faceless Joker ($4) | $5 when 3+ face cards are discarded at once |
| Mail-In Rebate ($4) | $5 per discarded card of the named rank |
| Satellite ($6) | $1 per unique Planet used |
| Matador ($7) | $8 when the played hand triggers the boss ability |

- [W] https://balatrowiki.org/w/Jokers

**2.8 Golden Joker versus Rocket.**
- Gold Joker is "undeniably stronger for the first three Antes."
- Rocket pays $9 per round after four Antes.
- Mail-In Rebate is "the cream of the crop" of lump-sum economy jokers.
- [G] https://addisonkindrick.substack.com/p/10-balatro-tier-list-addendum

**2.9 Gold Stake and economy jokers.**
- An early economy joker is "close to mandatory" because the Small Blind pays $0. [G] https://balatrohq.com/guides/gold-stake-guide/
- A Rental Golden Joker nets only $1 per round ($4 - $3). Avoid Rental economy jokers that make less than $4 per round. [G] https://www.switchbladegaming.com/strategy-games/balatro-economy-strategy/
- A Rental Egg is "usually not worth" it. [W] https://balatrowiki.org/w/Egg

**2.10 Sell-value economy.**
- Sell value is half the buy cost, rounded down, with a minimum of $1. [W] https://balatrowiki.org/w/Shop
- Egg grows by $3 per round. Sell it around Ante 5-6 "for maximum return." [G] https://choostgames.com/blog/balatro-jokers/
- Gift Card grows every Joker and consumable by $1 per round and feeds Temperance (capped at $50), Swashbuckler and Ceremonial Dagger. Skipping blinds wastes its rounds. [W] https://balatrowiki.org/w/Gift_Card
- Liquidation lowers the sell value of jokers you already own. [W] https://balatrowiki.org/w/Vouchers

**2.11 Moving from economy to scoring.**
- Antes 5-6: "Sell economy Jokers that aren't contributing and replace them with scaling options." By Ante 8, "every Joker slot should contribute to your score." [G] https://www.twoaveragegamers.com/balatro-strategy-guide-the-joker-combos-that-actually-win-runs/
- **DISAGREEMENT:** Balatro HQ places this sell-off at Antes 7-8. [G] https://balatrohq.com/guides/gold-stake-guide/

**2.12 Seed Money.**
- Buy it once you consistently hold $40 or more. [G] https://www.switchbladegaming.com/strategy-games/balatro-economy-strategy/
- Or once you have "a stable $50 base." [G] https://games.gg/balatro/guides/balatro-economy-guide/
- Never buy To the Moon, Seed Money or Money Tree on Green Deck, which earns no interest. [W] https://balatrowiki.org/w/Deck-Specific_Guides

**2.13 Tarot money: The Hermit and Temperance.**
- The Hermit doubles your money, capped at +$20. Use it when holding at least $20, and spend after using it, never before.
- Temperance pays the total sell value of your jokers, capped at $50.
- Together they give about $50-70.
- Sources:
  - [W] https://balatrowiki.org/w/Tarot_Cards
  - [G] https://games.gg/balatro/guides/balatro-economy-guide/

**2.14 Reroll mechanics.**
- A reroll costs $5, rising by $1 each time, and resets in every new shop.
- Rerolls replace only the card slots. Packs and the voucher are not restocked.
- Reroll Surplus cuts the cost by $2. Reroll Glut brings the starting price down to $1.
- [W] https://balatrowiki.org/w/Shop

**2.15 Reroll discipline.**
- "Don't reroll without a target in mind. Set a reroll budget before clicking. Stop rerolling once the next blind is solved." [G] https://balatrocalc.com/blog/balatro-gameplay/
- Limit yourself to one reroll per shop in Antes 1-3. [G] https://www.switchbladegaming.com/strategy-games/balatro-economy-strategy/
- Avoid expensive rerolls until you have at least one useful joker. [G] https://jeu.video/guide/balatro-debutant-jokers
- Reroll once you hold "generally 30+" (search-result snippet). https://steamcommunity.com/app/2379780/discussions/0/4346606879507212202
- **DISAGREEMENT:** "Don't get rich. Reroll." (Zed Clampet). [C] https://forums.pcgamer.com/threads/balatro-tips-and-strategies-add-your-own.148962
- **[D] Rule:** reroll only with money above $25 plus the reroll price, and only while the shop lacks an item that solves the next boss or completes the build.

**2.16 Chaos the Clown and the D6 Tag.**
- Chaos the Clown ($4) gives 1 free reroll per shop, worth about $5 per shop.
  - On Gold, a Rental Chaos costs $1 and sells for $1, so it is effectively free.
  - It is excellent with Flash Card (+2 Mult per reroll).
  - [W] https://balatrowiki.org/w/Chaos_the_Clown
- The D6 Tag makes rerolls start at $0 (+$1 each) in the next shop only.
  - It is "roughly break-even on its own" and good mainly with Flash Card.
  - Never skip a blind for it: "Free reroll in shop: never" (Draco18s).
  - [W] https://balatrowiki.org/w/D6_Tag
  - [C] https://steamcommunity.com/app/2379780/discussions/0/4294818447590775533

**2.17 Rental cash flow.**
- Rental takes $3 at the end of every round, before the payout. It can push you into debt.
- Rental jokers cost $1 and sell for $1, so selling one before the end of your next round makes it free.
- Debuffed or self-destructing Rental jokers still charge the fee.
- [W] https://balatrowiki.org/w/Rental

**2.18 Money-reset effects.**
- Wraith and The Ox set money to $0. Spend before using Wraith.
- Economy Tag: below $40 it doubles your money; at $40 or more it adds a flat $40. It does nothing while you are in debt.
- Sources:
  - [W] https://balatrowiki.org/w/Money
  - [W] https://balatrowiki.org/w/Wraith
  - [W] https://balatrowiki.org/w/Economy_Tag

---

## 3. Shop decisions

**3.1 Shop structure.**
- 2 card slots (3 with Overstock, 4 with Overstock Plus), 2 booster packs and 1 voucher.
- Card-slot weights: Joker 20 (about 71%), Tarot 4, Planet 4.
- Joker rarity: Common 70%, Uncommon 25%, Rare 5%.
- Prices: Common $1-6, Uncommon $4-8, Rare $7-10.
- The first shop of a run always contains a normal Buffoon Pack.
- [W] https://balatrowiki.org/w/Shop

**3.2 Ante 1-2 buy priority.**
1. An unconditional scoring joker, ideally +Mult. "Often the best joker to pick first is a joker that gives +mult, unconditional to what cards/hands you play," for example Abstract Joker (malogoss). [C] https://steamcommunity.com/app/2379780/discussions/0/4756452715167149899
2. An economy joker, which is near-mandatory on Gold. [G] https://balatrohq.com/guides/gold-stake-guide/
3. One or two consistent scaling jokers: Runner, Ride the Bus, Green Joker, Hologram, Spare Trousers, or Rocket for money. [W] https://balatrowiki.org/w/Guide:_General_strategy
- Short-term jokers (Gros Michel, Ice Cream, Popcorn) are good early. Pick up slow long-term ones (Hiker, Vampire) only when already safe (search-result snippet). https://turnbasedlovers.com/guides/10-beginner-tips-to-develop-better-strategies-in-balatro/

**3.3 Never leave a slot empty early.**
- "Early on, any Joker can beat none, since you can sell it later." [G] https://steamcommunity.com/sharedfiles/filedetails/?id=3653261996
- Fill empty slots "with anything that gives value as soon as you can." [C] https://steamcommunity.com/app/2379780/discussions/0/604167589085578695/
- "Not every joker taken has to be a permanent installation in your build" (srn347). [C] https://steamcommunity.com/app/2379780/discussions/0/4361249916210087237
- Exception: Joker Stencil builds, where an empty slot gives X1.

**3.4 The three joker jobs.**
- Every winning board needs a reliable Chips source, a reliable +Mult source, and "at least one xMult source." [G] https://steamcommunity.com/sharedfiles/filedetails/?id=3653261996
- On Gold: "at least one scaling +chips Joker, one scaling +mult Joker, and one x-mult Joker," for example Runner, Red Card and Hologram. [G] https://hardcoregamer.com/ten-tips-for-dominating-gold-stake-in-balatro/
- Slot roles: 1-2 slots for stable base value, 1-2 for scaling growth, 0-1 for utility or boss coverage. [G] https://balatrocalc.com/blog/balatro-gameplay/

**3.5 Joker tiers for Gold Stake clears (one list; tier lists vary by source).**
- **S:** Blueprint, Brainstorm, Triboulet, Cavendish, Throwback, Canio, Perkeo, DNA, Baron, Chicot.
- **A:** Mime, Hologram, Vampire, Constellation, Photograph, Card Sharp, Spare Trousers, Mr. Bones, Stuntman, Four Fingers.
- **B:** Fibonacci, Wee Joker, Hiker, Rocket, Golden Joker, Egg, Lucky Cat, Abstract Joker, Fortune Teller.
- **C:** Misprint, Odd Todd, Even Steven, Raised Fist, Green Joker, Credit Card, Ramen.
- **D:** Marble Joker, Madness, Luchador, Popcorn, Ice Cream, Ceremonial Dagger.
- Source: [G] https://choostgames.com/blog/balatro-jokers/
- Blueprint "appears at the top of nearly every list"; Mobalytics and Dot Esports both put Blueprint and Brainstorm in S tier (search-result snippets).
  - https://mobalytics.gg/blog/tier-lists/best-balatro-jokers/
  - https://dotesports.com/indies/news/balatro-tier-list-best-jokers-ranked
- **DISAGREEMENT:**
  - Choost puts Green Joker in C tier, but HattedHead says newer players undervalue Half Joker, Green Joker and Ride the Bus. [C] https://steamcommunity.com/app/2379780/discussions/0/840628406751272258/
  - Choost puts Luchador in D tier, but the wiki calls it a run-saver against run-ending bosses (see 8.18).

**3.6 Key xMult and scaling jokers, exact numbers.**

| Joker (cost) | Effect |
|---|---|
| Cavendish ($4) | X3 |
| Card Sharp ($6) | X3 if the hand type was already played this round |
| Photograph ($5) | X2 on the first scored face card |
| Baron ($8) | X1.5 per King held |
| The Duo / Trio / Family / Order / Tribe ($8) | X2 / X3 / X4 / X3 / X2 if the hand contains Pair / Trips / Quads / Straight / Flush |
| Hologram ($7) | +X0.25 per card added to the deck |
| Constellation ($6) | +X0.1 per Planet used |
| Vampire ($7) | +X0.1 per enhanced card scored; removes the enhancement |
| Lucky Cat ($6) | +X0.25 per Lucky trigger |
| Glass Joker ($6) | +X0.75 per Glass card destroyed |
| Steel Joker ($7) | X0.2 per Steel card in the deck |
| Throwback ($6) | X0.25 per blind skipped |
| Campfire ($9) | +X0.25 per card sold; resets on boss defeat |
| Obelisk ($8) | +X0.2 per consecutive hand that is not your most-played hand |
| Ramen ($6) | X2, -X0.01 per card discarded |
| Loyalty Card ($5) | X4 every 6 hands |
| Acrobat ($6) | X3 on the final hand |
| Joker Stencil ($8) | X1 per empty slot |
| Driver's License ($7) | X3 with at least 16 enhanced cards |
| Blackboard ($6) | X3 if all held cards are Spades or Clubs |

- [W] https://balatrowiki.org/w/Jokers

**3.7 Photochad.** Photograph plus Hanging Chad reaches at least x8 Mult from two Common jokers. Put the face card leftmost so it scores first, and play small hands.
- [G] https://mancunion.com/2025/09/01/a-guide-to-gold-stake-balatro/
- [G] https://www.twoaveragegamers.com/balatro-strategy-guide-the-joker-combos-that-actually-win-runs/

**3.8 Jokers to pass on.**
- Conditional jokers that need perfect setups. "Prefer a reliable xMult Joker now over a stronger one that requires many hands to come online." [G] https://www.twoaveragegamers.com/balatro-strategy-guide-the-joker-combos-that-actually-win-runs/
- Flat hand-type or suit +Mult jokers (Lusty, Wrathful) "become dead slots" after Ante 4. [G] same source as above.
- Suit-based jokers in general, because bosses debuff suits (Kaamos_Llama). [C] https://forums.pcgamer.com/threads/balatro-tips-and-strategies-add-your-own.148962
- "I never pick up a Joker in the hope I'll be able to use it later" (Kaamos_Llama). [C] same thread.

**3.9 Replacing jokers.**
- First weaken the old joker's importance, then replace it. Example: Red Card beats Abstract Joker, but do not drop Abstract's +15 if the next blind needs it. [G] https://hardcoregamer.com/ten-tips-for-dominating-gold-stake-in-balatro/
- Keep a slot free if a weak joker would block a decisive buy. [G] https://jeu.video/guide/balatro-debutant-jokers
- Before selling a scaling joker, estimate how long it takes to out-earn its sale value. Hold it if that happens within 5-10 rounds. [G] https://www.switchbladegaming.com/strategy-games/balatro-deck-building-mistakes/

**3.10 Final versus intermediate jokers and stickers.**
- Intermediate jokers (flat +Chips or +Mult) are "worth keeping even when Perishable."
- Final (xMult) jokers "are worth taking even when Eternal."
- [W] https://balatrowiki.org/w/Guide:_Scaling

**3.11 Editions on jokers.**
- Effects: Foil +50 Chips, Holographic +10 Mult, Polychrome X1.5 Mult, Negative +1 Joker slot.
- Extra shop cost: Foil +$2, Holographic +$3, Polychrome +$5, Negative +$5.
- Base joker appearance rates: Foil 2%, Holographic 1.4%, Polychrome 0.3%, Negative 0.3%. [W] https://balatrowiki.org/w/Editions
- Pros treat a Polychrome or Negative joker as a strong pickup when it appears (search-result snippet). https://pcgamer.com/balatro-tips
- Edition jokers can stand in for a missing chip or mult source. [W] https://balatrowiki.org/w/Guide:_General_strategy

**3.12 Booster packs: sizes and prices.**

| Size | Cost | Shown / chosen |
|---|---|---|
| Normal | $4 | 3 / 1 (Buffoon and Spectral show 2) |
| Jumbo | $6 | 5 / 1 (Buffoon and Spectral show 4) |
| Mega | $8 | 5 / 2 (Buffoon and Spectral show 4) |

- Type chances: Arcana, Celestial and Standard about 29% each; Buffoon about 8.7%; Spectral about 4.3%.
- Arcana and Spectral packs deal you a hand, so you can apply tarots to it.
- [W] https://balatrowiki.org/w/Booster_Packs

**3.13 Which packs to buy.**
- Buy Buffoon packs early to reach "2-3 jokers." After that, "I'd rather save money and buy jokers when they appear." That is "0, 1, rarely 2 in a whole run."
- Pack ranking: Spectral, then Arcana, then Standard, then Celestial, then Buffoon. This ranking dates from the demo.
- Arcana packs are worth it "if you have some money in the bank and a full joker roster."
- Standard packs: buy when "swimming in money." Hitting a specific suit plus rank target in a 3-card pack has about a 6.1% chance (Goblin).
- [C] https://steamcommunity.com/app/2379780/discussions/0/4201363889242704640

**3.14 Get to $25 before opening packs.**
- Advice seen in a search-result snippet. https://steamcommunity.com/app/2379780/discussions/0/4693406471885516172

**3.15 Squeeze more value out of Celestial packs.**
- Telescope guarantees the Planet for your most-played hand in Celestial packs. [W] https://balatrowiki.org/w/Vouchers
- Use High Priestess before opening a Celestial pack, since planets you already hold will not appear in it (search-result snippet). https://steamcommunity.com/app/2379780/discussions/0/596265364943276073
- Holding unwanted planets blocks them from the pack. "If two unwanted planets are in your consumable slots and one is in the shop, a small celestial pack has a 1/2 chance of any specific planet. A large pack has a 5/6 chance" (RazzberryMocha). [C] https://steamcommunity.com/app/2379780/discussions/0/604167589085578695/

**3.16 Voucher tiers.**
- Balatro HQ:
  - S: Antimatter, Grabber, Nacho Tong, Paint Brush, Palette, Observatory ("Grab on sight").
  - A: Overstock, Overstock Plus, Clearance Sale, Liquidation, Crystal Ball, Telescope, Wasteful, Recyclomancy.
  - B: Hone, Glow Up, Reroll vouchers, Omen Globe, Seed Money, Money Tree, Illusion, Hieroglyph, Petroglyph, Retcon.
  - C: Magic Trick, Director's Cut, Tarot and Planet Merchant/Tycoon.
  - D: Blank.
  - [G] https://balatrohq.com/vouchers/
- games.gg:
  - S: Antimatter, Grabber/Nacho Tong, Paint Brush/Palette, Overstock/Overstock Plus.
  - A: Wasteful/Recyclomancy, Clearance/Liquidation, Reroll Surplus/Glut, Seed Money/Money Tree, Telescope.
  - B: Director's Cut/Retcon, Crystal Ball.
  - Suggested order: Antes 1-3 Grabber, Paint Brush, Overstock. Antes 3-5 Wasteful, Clearance Sale. Antes 5-7 Nacho Tong, Palette, Overstock Plus.
  - [G] https://games.gg/balatro/guides/balatro-vouchers-tier-list/

**3.17 Voucher mechanics.**
- Vouchers cost $10. A new one appears after each boss is defeated. An upgrade can only appear after you buy its base voucher.
- Illusion is bugged in 1.0.1o: no seals appear on shop cards.
- [W] https://balatrowiki.org/w/Voucher
- [W] https://balatrowiki.org/w/Vouchers

**DISAGREEMENT: when to buy vouchers.**
- "Vouchers, at ante 1 and 2 in particular, are often best left there. Spending $10-20 on vouchers that early is a huge commitment" (malogoss). [C] https://steamcommunity.com/app/2379780/discussions/0/4756452715167149899
- Versus the games.gg order, which buys Grabber, Paint Brush and Overstock in Antes 1-3.

**DISAGREEMENT: Director's Cut.**
- Rated C tier by Balatro HQ and B by games.gg.
- Rated A tier in the games.gg economy guide. [G] https://games.gg/balatro/guides/balatro-economy-guide/
- One Steam guide says buy a boss reroll "even if it drops you below $25, to avoid a bad Boss at the end of an otherwise winning run." [G] https://steamcommunity.com/sharedfiles/filedetails/?id=3653261996

---

## 4. Blind skipping

**4.1 What a skip costs.** You lose four things:
1. The blind reward: $3 Small, $4 Big, and $0 Small on Red stake and above.
2. $1 per unused hand.
3. That round's interest, up to $5, because interest is paid at round end.
4. The next shop visit.

Round-based jokers (Egg, Gift Card, Rocket and similar) also lose a round of value.
- "Skipping costs a shop, the blind payout, and interest" (Ronald Brain). [C] https://steamcommunity.com/app/2379780/discussions/0/4756452715167149899
- [W] https://balatrowiki.org/w/Money
- [W] https://balatrowiki.org/w/Egg

**4.2 Default to playing.**
- "Generally do not skip early Small or Big Blinds." [W] https://balatrowiki.org/w/Guide:_General_strategy
- malogoss skips "0 or 1 blind total" in a Gold run. [C] https://steamcommunity.com/app/2379780/discussions/0/4756452715167149899
- "Skipping blinds is bad 95% of the time." [C] https://steamcommunity.com/app/2379780/discussions/0/604167589085578695/
- Skip tags are "usually a poor choice." [G] https://mancunion.com/2025/09/01/a-guide-to-gold-stake-balatro/

**4.3 Tags pros do skip for.**
- Investment Tag in Ante 1: $25 after the boss. Many players consider it one of the best tags when found early.
  - [W] https://balatrowiki.org/w/Investment_Tag
  - [C] https://steamcommunity.com/app/2379780/discussions/0/604143386282188848
  - [G] https://hardcoregamer.com/ten-tips-for-dominating-gold-stake-in-balatro/
- Polychrome or Negative joker tags: "always (unless its ante 1 as I won't be able to afford it)" (Draco18s). [C] https://steamcommunity.com/app/2379780/discussions/0/4294818447590775533
- From the wiki's list: Holographic, Investment, Buffoon (a free Mega Buffoon pack, which lets you choose 2 jokers), Coupon (next shop free), and Orbital "only if it boosts your desired hand type." [W] https://balatrowiki.org/w/Guide:_General_strategy
- Situational:
  - an Orbital tag before The Arm
  - a Boss tag before an otherwise impassable boss
  - an Economy tag when it supplies resources you need
  - [G] https://hardcoregamer.com/ten-tips-for-dominating-gold-stake-in-balatro/
- Coupon Tag on the very first round only (VastGirth). [C] https://steamcommunity.com/app/2379780/discussions/0/4294818447590775533

**4.4 [D] Money threshold for a cash tag.**
- Skip for cash only if the tag is worth "double the blind's reward + interest" or better (Draco18s). [C] https://steamcommunity.com/app/2379780/discussions/0/4294818447590775533
- Example on Gold: a Small Blind skip forgoes about $0 reward + $3-4 unused hands + $5 interest + a shop. The Investment Tag's $25 clears that bar easily in Ante 1.

**4.5 Tags pros do not skip for.**
- "Double tag, voucher tag: honestly almost never." "Free reroll in shop: never" (Draco18s).
- Joker-pack skips only make sense with a free slot. Tarot-pack skips only with several Double Tags stacked.
- [C] https://steamcommunity.com/app/2379780/discussions/0/4294818447590775533

**4.6 Stake changes the skip value.**
- On Red stake and above, the Small Blind pays $0, so skipping it costs less (search-result snippet). https://twinfinite.net/?p=1063061
- brickey.8 skips the first blind on Red+ if the tag is "anything remotely useful." [C] https://steamcommunity.com/app/2379780/discussions/0/4294818447590775533
- But on Purple stake and above, "skipping a Shop to take the tag becomes hard to afford." [W] https://balatrowiki.org/w/Investment_Tag

**4.7 Skipping Ante 1 entirely is risky.**
- "skipping the first two Blinds in the first Ante is almost always a bad idea, as players will have to beat the Boss with no Jokers" (search-result snippet). https://turnbasedlovers.com/guides/10-beginner-tips-to-develop-better-strategies-in-balatro/
- **DISAGREEMENT:** "Skipping both Ante 1 blinds can be worth it for the rewards." [G] https://steamcommunity.com/sharedfiles/filedetails/?id=3653261996

**4.8 Tag timing details.**
- A tag that affects the shop (Coupon, D6, Negative, Polychrome and so on) applies to the next shop you actually visit. After skipping a Small Blind, that is the shop after the Big Blind.
- A Negative tag waits until a base-edition joker appears in the shop.
- Double Tag copies the next tag you obtain, so take it only when the next tag is known and strong:
  - Investment becomes $50.
  - Orbital becomes +6 levels.
- Sources:
  - [W] https://balatrowiki.org/w/Negative_Tag
  - [W] https://balatrowiki.org/w/Double_Tag
  - [C] https://steamcommunity.com/app/2379780/discussions/0/4294818447590775533

**4.9 Tag availability by ante.**
- These tags cannot appear in Ante 1: Negative, Standard, Meteor, Buffoon, Handy, Garbage, Ethereal, Top-up, Orbital.
- Charm (a free Mega Arcana pack: 5 cards, choose 2) is the only pack tag in Ante 1. It gives about a 1.5% chance at The Soul.
- Sources:
  - [W] https://balatrowiki.org/w/Tags
  - [W] https://balatrowiki.org/w/Charm_Tag

**4.10 Decks and jokers that change the rules.**
- Anaglyph Deck (a Double Tag after each boss): stack Double Tags and spend them around Ante 5-6 on Investment, Economy, Handy or Ethereal tags. [G] https://mancunion.com/2025/09/01/a-guide-to-gold-stake-balatro/
- Throwback (X0.25 per skip) makes skips scale. [W] https://balatrowiki.org/w/Jokers

**4.11 The Pillar.** If The Pillar is the boss, skipping both the Small and Big Blind means none of your cards are debuffed.
- [W] https://balatrowiki.org/w/The_Pillar

---

## 5. Hand play

**5.1 Commit to one or two hand types and level only those.**
- "focusing on one or two planet cards is usually better than spreading out" (Mel Gibson).
- A player who lost repeatedly concluded: "quit spacing out the planet cards and focus down on one (maybe two) things."
- [C] https://steamcommunity.com/app/2379780/discussions/0/4694531145715173333

**5.2 Let early pieces choose the hand.** "Flow with the run, don't fight against it."
- A Runner or Shortcut suggests Straights.
- Two Sun tarots suggest Flushes.
- An early Death or Cryptid suggests three or four of a kind.
- [G] https://hardcoregamer.com/ten-tips-for-dominating-gold-stake-in-balatro/
- A build is "usually just defined by whatever you get a strong joker for first" (brickey.8). [C] https://steamcommunity.com/app/2379780/discussions/0/4308327178393752844
- "the power comes from the jokers, not the hand" (Roffle, who beat every deck on Gold, as relayed by Anno the Meerkat). [C] https://steamcommunity.com/app/2379780/discussions/0/4308327413812836587/?ctp=2

**5.3 Base values and per-level gains (Planet in brackets).**

| Hand | Base chips x mult | Per level |
|---|---|---|
| High Card (Pluto) | 5x1 | +10 / +1 |
| Pair (Mercury) | 10x2 | +15 / +1 |
| Two Pair (Uranus) | 20x2 | +20 / +1 |
| Three of a Kind (Venus) | 30x3 | +20 / +2 |
| Straight (Saturn) | 30x4 | +30 / +3 |
| Flush (Jupiter) | 35x4 | +15 / +2 |
| Full House (Earth) | 40x4 | +25 / +2 |
| Four of a Kind (Mars) | 60x7 | +30 / +3 |
| Straight Flush (Neptune) | 100x8 | +40 / +4 |
| Five of a Kind (Planet X) | 120x12 | +35 / +3 |
| Flush House (Ceres) | 140x14 | +40 / +4 |
| Flush Five (Eris) | 160x16 | +50 / +3 |

- [W] https://balatrowiki.org/w/Poker_Hands
- **[D]** Per planet, Straight and Four of a Kind (+30/+3) level best of the common hands. Flush (+15/+2) levels poorly. For example, a level 6 Flush is 110x14.
- A Flush planet "is rarely a win condition alone." [G] https://addisonkindrick.substack.com/p/10-balatro-tier-list-addendum

**5.4 Which hand type suits which stake.**
- Flushes are the easiest and most stable build at low stakes. They fade at higher stakes because they need 5 suited cards with fewer discards (SpaceCat, malogoss, Twelvefield).
- Pair and High Card are "by far the easiest to win at" on high stakes, but they depend on held-card or xMult jokers (SpaceCat).
- Two Pair is good with Spare Trousers. Opinions split between "arguably the most powerful" and "mediocre."
- Losing a discard on Blue stake and above hurts Straights the most.
- Sources:
  - [C] https://steamcommunity.com/app/2379780/discussions/0/4308327178393752844
  - [C] https://steamcommunity.com/app/2379780/discussions/0/596264060842957220
- **DISAGREEMENT:**
  - Do not force Pair or High Card on Gold; follow the run. [G] https://hardcoregamer.com/ten-tips-for-dominating-gold-stake-in-balatro/
  - Gold calls for "hands with a low fail rate to draw," meaning High Card and Pair. [G] https://www.superjumpmagazine.com/all-in-advanced-strategies-for-earning-c-in-balatro/
  - Avoid Flush as the main strategy by default. [G] https://mancunion.com/2025/09/01/a-guide-to-gold-stake-balatro/
  - PC Gamer calls flushes the simplest hand to aim for (search-result snippet). https://pcgamer.com/balatro-tips

**5.5 Without deck fixing, late game means small hands.**
- Deck fixing is "massively important for consistency." Late game, avoid playing anything besides High Card, Pair or Two Pair without it (RazzberryMocha).
- [C] https://steamcommunity.com/app/2379780/discussions/0/604167589085578695/

**5.6 Antes 5-6: the five-card trap.**
- "plenty of runs die" when the deck can no longer produce the 5-card hand it relies on. Consider dropping 5-card hands (QuantuuM).
- [C] https://steamcommunity.com/app/2379780/discussions/0/840628406751272258/

**5.7 How to discard.**
- Discard as many cards as possible each time while keeping the cards needed for a likely winning hand. "Discarding only 1-2 cards greatly lowers your odds."
- Discards matter most for hard 5-card hands.
- [W] https://balatrowiki.org/w/Guide:_General_strategy
- Do not spend every discard if an average hand already clears the blind. [G] https://jeu.video/guide/balatro-debutant-jokers
- Early on, "use those discards until you can win the round with the first hand" (Zed Clampet). [C] https://forums.pcgamer.com/threads/balatro-tips-and-strategies-add-your-own.148962
- Do not "blindly play whatever hand you first notice." [C] https://steamcommunity.com/app/2379780/discussions/0/4694531145715173333

**5.8 Played cards that do not score act as free discards.**
- Only cards that are part of the hand score. Extra played cards leave without changing the score, except in 5-card hands.
- [W] https://balatrowiki.org/w/Poker_Hands
- Against The Psychic, play non-5-card hands on purpose when you need to draw more (RazzberryMocha). [C] https://steamcommunity.com/app/2379780/discussions/0/715609580327930968

**5.9 [D] Do not over-score.**
- Score above the requirement is worth nothing.
- Once the blind is cleared, every unused hand is $1. [W] https://balatrowiki.org/w/Money
- Degrading jokers lose value per hand played, even blocked ones: Ice Cream -5 chips per hand, Seltzer 10 hands. [W] https://balatrowiki.org/w/The_Psychic

**5.10 Card order inside the played hand.**
- With Hanging Chad, put the power card (Lucky, Red Seal or Glass) first. [G] https://www.superjumpmagazine.com/all-in-advanced-strategies-for-earning-c-in-balatro/
- Otherwise move Glass cards rightmost so flat Mult on earlier cards gets doubled. [W] https://balatrowiki.org/w/Glass_Card

**5.11 Held cards.**
- Steel gives X1.5 only while held. Keep Steel cards in hand, and put flat held-Mult cards (for example Queens with Shoot the Moon) to the left of Steel. [W] https://balatrowiki.org/w/Steel_cards
- Gold cards pay $3 if held at round end, and this counts toward interest. [W] https://balatrowiki.org/w/Interest
- The Hook randomly discards held cards, so Steel, Gold, Blue Seal and Baron become unreliable. [W] https://balatrowiki.org/w/The_Hook

**5.12 Seals.**
- Gold Seal: $3 when the card scores.
- Red Seal: retriggers the card once.
- Blue Seal: creates the Planet for your final hand if the card is held at round end.
- Purple Seal: creates a Tarot when the card is discarded.
- Blue and Purple Seals need a free consumable slot. A new seal overwrites the old one.
- [W] https://balatrowiki.org/w/Seals
- **DISAGREEMENT:** keep consumable slots full to block duplicates (see 7.22), versus leave room for seals and generators. [G] https://hardcoregamer.com/ten-tips-for-dominating-gold-stake-in-balatro/

**5.13 Glass cards.**
- X2 Mult, with a 1 in 4 chance to break after scoring. Retriggers do not re-roll the break chance. [W] https://balatrowiki.org/w/Glass_Card
- Keep a few Glass cards "in your back pocket" against The Flint, The Arm and The Wall. If the round is cleared, they did their job. [G] https://hardcoregamer.com/ten-tips-for-dominating-gold-stake-in-balatro/

**5.14 Lucky cards.**
- 1 in 5 chance of +20 Mult (expected value +4) and 1 in 15 chance of $20 (expected value about $1.33).
- Oops! All 6s doubles both chances, which suits Lucky Cat.
- [W] https://balatrowiki.org/w/Lucky_Card

**5.15 Stone and Wild cards.**
- Stone: +50 Chips, no rank or suit. It keeps its +50 even when debuffed. [W] https://balatrowiki.org/w/Enhancements
- Stone suits hands of fewer than 5 cards. [G] https://steamcommunity.com/sharedfiles/filedetails/?id=3166946815
- Wild counts as every suit. A debuffed Wild card keeps its original suit. [W] https://balatrowiki.org/w/Enhancements

**5.16 Deck thinning.**
- The Hanged Man destroys up to 2 selected cards. The wiki recommends thinning "as early as possible." [W] https://balatrowiki.org/w/The_Hanged_Man
- Target size:
  - "roughly 30-35" cards by Ante 5-6; thinning below that risks a suit-debuff boss. [G] https://www.switchbladegaming.com/balatro/advanced-strategy-guide-2/
  - 30-40 cards. [G] https://www.switchbladegaming.com/strategy-games/balatro-deck-building-mistakes/
- **DISAGREEMENT:** "I wouldn't waste tarot cards adjusting my deck to hit pairs... far better to boost the cards than to delete them" (Zed Clampet). [C] https://forums.pcgamer.com/threads/balatro-tips-and-strategies-add-your-own.148962

**5.17 Deck fixing by hand type.**
- Multiples (Pair, Trips, Full House, Quads): create copies of one rank with Death or Cryptid, and remove or convert the other ranks.
- Straights: a larger deck is worse. Remove low or high ranks, usually keeping the high ones.
- Flushes: create more cards of one suit.
- Suit tarots convert up to 3 cards each: The Star to Diamonds, The Moon to Clubs, The Sun to Hearts, The World to Spades. [W] https://balatrowiki.org/w/Tarot_Cards
- Strength raises the rank of up to 2 cards by 1.
- Death turns the left card into a copy of the right card.
- [W] https://balatrowiki.org/w/Guide:_Deck_Manipulation

**5.18 Deck shape versus boss risk.**
- Suit-heavy decks are vulnerable to The Club, The Goad, The Window and The Head.
- Face-heavy decks are vulnerable to The Plant and The Mark.
- Small decks are vulnerable to The Hook and The Pillar.
- Builds that rely on one hand type are vulnerable to The Eye, The Arm and The Ox.
- [W] https://balatrowiki.org/w/Guide:_Deck_Manipulation

**5.19 Using tarots mid-round.**
- Use tarots during a round when they clear the blind. For example, The World turns a Straight into a Straight Flush, and Death makes pairs.
- [W] https://balatrowiki.org/w/Guide:_General_strategy

**5.20 Standard packs.**
- Buy them early to learn which cards you want. Later they "are more of a gamble" (Goblin).
- They are very good with Hone, otherwise "very luck-dependant" (ima).
- [C] https://steamcommunity.com/app/2379780/discussions/0/4201363889242704640

---

## 6. Card modifier reference (exact, from the wiki)

**6.1 Enhancements.** A card can hold only one enhancement; a new one replaces the old.

| Enhancement | Effect |
|---|---|
| Bonus | +30 Chips |
| Mult | +4 Mult |
| Wild | Counts as any suit |
| Glass | X2 Mult; 1 in 4 chance to be destroyed |
| Steel | X1.5 Mult while held in hand |
| Stone | +50 Chips; no rank or suit |
| Gold | $3 if held in hand at end of round |
| Lucky | 1 in 5 for +20 Mult; 1 in 15 for $20 |

- Debuffed cards lose their modifiers, except Stone and Negative.
- [W] https://balatrowiki.org/w/Enhancements
- Where enhancements come from (tarots, so 2 cards or 1 card per use):

| Tarot | Result |
|---|---|
| The Magician | 2 Lucky |
| The Empress | 2 Mult |
| The Hierophant | 2 Bonus |
| The Lovers | 1 Wild |
| The Chariot | 1 Steel |
| Justice | 1 Glass |
| The Devil | 1 Gold |
| The Tower | 1 Stone |

- [W] https://balatrowiki.org/w/Tarot_Cards

**6.2 Editions (same effect on jokers and on playing cards).**
- Foil +50 Chips, Holographic +10 Mult, Polychrome X1.5 Mult, Negative +1 Joker slot (or +1 consumable slot on a consumable).
- Extra cost: +$2 / +$3 / +$5 / +$5.
- Hone doubles Foil, Holographic and Polychrome rates; Glow Up quadruples them. For Polychrome jokers specifically it is 3x with Hone and 7x with Glow Up.
- Sources of editions:
  - Wheel of Fortune: 1 in 4 for Foil, Holographic or Polychrome on a random joker.
  - Aura: playing cards only, never Negative.
  - Hex: Polychrome.
  - Ectoplasm: Negative.
  - Foil, Holographic, Polychrome and Negative tags.
- Sources:
  - [W] https://balatrowiki.org/w/Editions
  - [W] https://balatrowiki.org/w/Vouchers

**6.3 Seals and where they come from.**
- Gold: $3 when played and scoring (Talisman).
- Red: retrigger once (Deja Vu).
- Blue: Planet for the final played hand if held, needs room (Trance).
- Purple: Tarot when discarded, needs room (Medium).
- Mime and Hack do not re-trigger a Red Seal a second time.
- [W] https://balatrowiki.org/w/Seals

**6.4 Eternal sticker.**
- Appears from Black stake.
- 30% chance on shop or pack jokers.
- "Can't be sold or destroyed": Hex, Ankh and Madness do not destroy it.
- Never on Legendaries.
- Never on these 11 jokers: Gros Michel, Cavendish, Ice Cream, Luchador, Turtle Bean, Diet Cola, Popcorn, Ramen, Seltzer, Mr. Bones, Invisible Joker.
- Eternal and Perishable are mutually exclusive.
- Sources:
  - [W] https://balatrowiki.org/w/Eternal
  - [W] https://balatrowiki.org/w/Hex
  - [W] https://balatrowiki.org/w/Ankh

**6.5 Perishable sticker.**
- Appears from Orange stake.
- 30% chance.
- Debuffed after 5 rounds. The debuff lands after the 5th blind is won but before cash-out, so cash-out economy jokers such as Golden Joker and Cloud 9 effectively last 4 rounds.
- A debuffed joker loses its effect and its edition.
- These 18 scaling jokers can never be Perishable: Ceremonial Dagger, Ride the Bus, Runner, Constellation, Green Joker, Red Card, Madness, Square Joker, Vampire, Hologram, Rocket, Obelisk, Lucky Cat, Flash Card, Spare Trousers, Castle, Glass Joker, Wee Joker.
- Legendaries are never Perishable.
- [W] https://balatrowiki.org/w/Perishable

**6.6 Rental sticker.**
- Appears on Gold stake.
- 30% chance on non-Legendary jokers, in the shop and in packs.
- Buy price becomes $1, sell value $1.
- -$3 at the end of every round, before the payout. It can push you into debt.
- Still charged when the joker is debuffed or self-destructs.
- Stacks with Eternal or Perishable.
- Added in 1.0.1f.
- [W] https://balatrowiki.org/w/Rental

**6.7 [D] Sticker odds on Gold.**
- Eternal 30% and Perishable 30% (exclusive of each other), with neither 40%.
- Rental is an independent 30%.
- So 28% of jokers carry no in-run sticker. The wiki gives the same 28% figure. [W] https://balatrowiki.org/w/Stickers
- **DISAGREEMENT:** Switchblade's breakdown (24.01% clean) does not match the wiki. [G] https://www.switchbladegaming.com/strategy-games/balatro-gold-stake-guide/

**6.8 How to handle each sticker.**
- Eternal: take it only on a joker you would keep all run. An Eternal economy joker you cannot sell late is a classic trap. [G] https://balatrohq.com/guides/gold-stake-guide/
- Eternal plus Rental: skip it before Ante 6. Take it in Antes 7-8 only if it directly closes out the run. [G] https://www.switchbladegaming.com/strategy-games/balatro-gold-stake-guide/
- Perishable: use it as a bridge and do not build the engine on it. Within the last 5 rounds before the Ante 8 boss, the sticker has "no real downside."
  - [G] https://balatrohq.com/guides/gold-stake-guide/
  - [G] https://mancunion.com/2025/09/01/a-guide-to-gold-stake-balatro/
- Rental: rent when your income absorbs it or you are close to winning. A Rental Blueprint gives temporary access. Rentals also make free fodder for Campfire or Ceremonial Dagger. [G] https://hardcoregamer.com/ten-tips-for-dominating-gold-stake-in-balatro/
- Eternal jokers make Hex, Ankh and Madness safe to use. [G] https://hardcoregamer.com/ten-tips-for-dominating-gold-stake-in-balatro/

---

## 7. Consumables

**7.1 Slot rules.**
- Judgement, The Soul, Wraith and Ankh all need an empty Joker slot. Their Use button is greyed out when the slots are full.
- Emperor, High Priestess, Blue and Purple Seals need consumable room.
- Rule: if the card is worth more than your weakest joker, sell that joker first. For The Soul, always do this.
- Sources:
  - [W] https://balatrowiki.org/w/Judgement
  - [W] https://balatrowiki.org/w/The_Soul
  - [W] https://balatrowiki.org/w/Wraith
  - [W] https://balatrowiki.org/w/Ankh
  - [W] https://balatrowiki.org/w/Tarot_Cards

**7.2 The Soul.**
- Creates one of 5 Legendary jokers. It is the only source of Legendaries.
- 0.3% chance per card in Arcana and Spectral packs.
- Legendaries never carry stickers.
- "If you see it, use it."
- Some Legendaries (Triboulet, Canio) need a deck built around them.
- Sources:
  - [W] https://balatrowiki.org/w/The_Soul
  - [G] https://games.gg/balatro/guides/balatro-spectral-cards-guide/

**7.3 Judgement.**
- Random joker: 70% Common, 25% Uncommon, 5% Rare, never Legendary.
- Best early. "In early antes, spending the $3 cost on Judgement can be better than rerolling the shop."
- The new joker can carry stickers.
- [W] https://balatrowiki.org/w/Judgement

**7.4 Wraith.**
- Random Rare joker; sets money to $0 (and also wipes debt).
- Spend money first. Use Hermit, Temperance or Immolate after Wraith, not before.
- Avoid it with Bull or Bootstraps.
- Strong early, "a hard sell late in a run."
- Sources:
  - [W] https://balatrowiki.org/w/Wraith
  - [G] https://games.gg/balatro/guides/balatro-spectral-cards-guide/

**7.5 Hex.**
- Polychrome on one random joker; destroys the others.
- It skips jokers that already have an edition, including Negative. Eternal jokers survive.
- Sell unwanted non-Eternal jokers first to steer the target.
- Use it when one scaling joker carries the run. It is much stronger from Black stake, where Eternal jokers survive it.
- Sources:
  - [W] https://balatrowiki.org/w/Hex
  - [G] https://games.gg/balatro/guides/balatro-spectral-cards-guide/

**7.6 Ankh.**
- Copies one random joker and destroys the others. The copy loses Negative but keeps its stickers, including Rental and Perishable.
- It cannot be used with full slots.
- Sell the jokers you do not want copied first.
- Use it "only... when you have a single Joker that carries your entire run," or very early.
- "Hex + Ankh are the absolute best thing to get in an early Mega pack" (cct).
- Sources:
  - [W] https://balatrowiki.org/w/Ankh
  - [G] https://games.gg/balatro/guides/balatro-spectral-cards-guide/
  - [C] https://steamcommunity.com/app/2379780/discussions/0/7434949789835831475

**7.7 Ectoplasm.**
- Negative on a random base-edition joker.
- The hand-size penalty escalates: -1, then -2, and so on (three uses cost 6 hand size in total).
- Good early. Avoid it if hand size matters, and remember it risks The Psychic.
- Sources:
  - [W] https://balatrowiki.org/w/Ectoplasm
  - [G] https://games.gg/balatro/guides/balatro-spectral-cards-guide/

**7.8 Immolate.**
- Destroys 5 random cards in hand and gives $20.
- Discard the cards you want to keep first. Avoid it against The Serpent.
- "super good for early deck thinning" (cct).
- Sources:
  - [W] https://balatrowiki.org/w/Immolate
  - [C] https://steamcommunity.com/app/2379780/discussions/0/7434949789835831475

**7.9 Cryptid.**
- 2 copies of a selected card. Use it on your best enhanced card (Steel, Glass, Lucky, Red Seal).
- "pure upside with no drawback."
- Sources:
  - [G] https://games.gg/balatro/guides/balatro-spectral-cards-guide/
  - [C] https://steamcommunity.com/app/2379780/discussions/0/7434949789835831475

**7.10 Familiar, Grim and Incantation.**
- Each destroys 1 random card in hand and adds enhanced cards: Familiar 3 face cards, Grim 2 Aces, Incantation 4 numbered cards.
- They "turn Hologram into a nuke" (cct).
- Sources:
  - [W] https://balatrowiki.org/w/Spectral_Cards
  - [C] https://steamcommunity.com/app/2379780/discussions/0/7434949789835831475

**7.11 Spectrals with no downside.**
- Black Hole (+1 level to every hand), Aura, Talisman, Deja Vu, Trance and Medium.
- Black Hole is "one of the strongest cards in the pool."
- Sources:
  - [W] https://balatrowiki.org/w/Spectral_Cards
  - [G] https://games.gg/balatro/guides/balatro-spectral-cards-guide/

**7.12 Sigil and Ouija.**
- Sigil converts the whole hand to one random suit. Ouija converts it to one random rank, at -1 hand size.
- Both are "better the earlier you get them" (cct).
- [C] https://steamcommunity.com/app/2379780/discussions/0/7434949789835831475

**7.13 Wheel of Fortune.**
- "Never worth spending money on."
- Outcomes: 75% nothing, 12.5% Foil, 8.75% Holographic, 3.75% Polychrome.
- [G] https://mancunion.com/2025/09/01/a-guide-to-gold-stake-balatro/

**7.14 The Hanged Man and Death.**
- These are the core deck-fixing tarots (see 5.16-5.17).
- With the Magic Deck, use The Fool to repeat Hanged Man.
- [W] https://balatrowiki.org/w/The_Hanged_Man

**7.15 The Fool.**
- Creates the last Tarot or Planet used, but never another Fool.
- Use it right after a high-value card such as Hanged Man, Death or Judgement.
- [W] https://balatrowiki.org/w/Tarot_Cards

**7.16 Hermit and Temperance.** See 2.13.

**7.17 Save Chariot and Justice for bosses.**
- Keep Justice (Glass) and The Chariot (Steel) for The Eye and The Needle, to reach the score in one hand.
- [W] https://balatrowiki.org/w/The_Eye
- [W] https://balatrowiki.org/w/The_Needle

**7.18 Hold suit changers as insurance.**
- Save suit-changing tarots for when the draw goes bad (search-result snippet). https://steamcommunity.com/app/2379780/discussions/0/7410182856437605680
- Keep Death, Strength or The Sun for The Mouth, in case your first hand locks you into the wrong type. [W] https://balatrowiki.org/w/The_Mouth

**7.19 The Hanged Man against Cerulean Bell.** Destroying the forced card frees your selection for that hand.
- [W] https://balatrowiki.org/w/Cerulean_Bell

**7.20 Verdant Leaf insurance.** A Judgement or Wraith in a consumable slot lets you re-create a joker after selling one to lift Verdant Leaf.
- [W] https://balatrowiki.org/w/Verdant_Leaf

**7.21 Pros' top early picks.**
- Red Deck picks: The Fool, High Priestess, Emperor, Judgement, Wraith, Soul.
- Blue Deck picks: The Fool, Magician, High Priestess, Empress, Emperor, Justice, Hanged Man, Death.
- [W] https://balatrowiki.org/w/Deck-Specific_Guides

**7.22 Block the cards you do not want.**
- Without Showman, only one copy of a card can be on screen. Holding Lovers or Judgement therefore makes the tarots you want more likely.
- A tarot already seen in the shop will not show up in an Arcana pack.
- [C] https://steamcommunity.com/app/2379780/discussions/0/604167589085578695/
- [G] https://hardcoregamer.com/ten-tips-for-dominating-gold-stake-in-balatro/

---

## 8. Boss blinds

**8.1 Boss Blinds are the top run-killer.**
- Chicot's value rests on disabling Boss Blinds, which Choost calls "the single most common cause of losing runs."
- [G] https://choostgames.com/blog/balatro-jokers/

**8.2 The pros' must-prepare list.**
- "most important are wall/vessel, eye, mouth." Also prepare for The Plant, The Needle and Crimson Heart (HattedHead).
- [C] https://steamcommunity.com/app/2379780/discussions/0/840628406751272258/

**8.3 Other run-killers players name.**
- The Arm: permanent level loss.
- The Manacle: "a secret run assassin if you get him at higher antes."
- The Water, The Hook ("the worst on 1st ante"), The Needle, The Serpent, The Fish, The Mouth.
- The Flint at Ante 2 on high stakes.
- The Wall on large blinds.
- The Psychic when hand size is 4.
- Suit bosses "will just snipe a run."
- [C] https://steamcommunity.com/app/2379780/discussions/0/4346606879521850576

**8.4 Preparation loop.**
- Check the boss at the start of each ante, then plan the shops in between.
- **DISAGREEMENT:** "You have three shops to prepare" versus "two rounds to look for a solution in the Shop." Three shops is possible if you check Run Info in the shop right after the previous boss.
  - [G] https://www.twoaveragegamers.com/balatro-strategy-guide-the-joker-combos-that-actually-win-runs/
  - [G] https://steamcommunity.com/sharedfiles/filedetails/?id=3166946815
- "Identify your failure condition for the round." "You only need to remove the one constraint that would break your line, not counter every boss." [G] https://balatrocalc.com/blog/balatro-gameplay/

**8.5 Diversify to survive bosses.**
- Carry something outside the main plan: a secondary hand, a Negative or non-vital joker to sell, or a few Glass cards.
- [G] https://hardcoregamer.com/ten-tips-for-dominating-gold-stake-in-balatro/

**8.6 Bosses do not repeat until all have appeared.**
- So if the first boss debuffs Hearts, building for Hearts afterwards is safe.
- [W] https://balatrowiki.org/w/Boss_Blinds
- [C] https://steamcommunity.com/app/2379780/discussions/0/604167589085578695/

**8.7 Boss minimum antes.**
- Any ante: Hook, Club, Psychic, Goad, Window, Manacle, Pillar, Head.
- Ante 2: House, Wall, Wheel, Arm, Fish, Water, Mouth, Needle, Flint, Mark.
- Ante 3: Eye, Tooth.
- Ante 4: Plant.
- Ante 5: Serpent.
- Ante 6: Ox.
- Showdown (Ante 8): Amber Acorn, Verdant Leaf, Violet Vessel, Crimson Heart, Cerulean Bell.
- [W] https://balatrowiki.org/w/Boss_Blinds

**8.8 Counters for specific bosses.**

The Wall (4x) and Violet Vessel (6x)
- Pure damage checks.
- Selling Luchador, or owning Chicot, returns them to 2x.
- Answers on Vessel: Loyalty Card timed for the boss, Campfire, Turtle Bean, Mr. Bones, Glass cards.
- Sources:
  - [W] https://balatrowiki.org/w/Boss_Blinds
  - [W] https://balatrowiki.org/w/Violet_Vessel
  - [W] https://balatrowiki.org/w/Luchador

The Needle (1 hand, 1x)
- Burglar is the best counter (+3 hands, no discards).
- Justice for Glass; Dusk.
- More hand size and discards help.
- Avoid relying on Card Sharp, DNA or Sixth Sense.
- "It's always recommended to build your deck to win with one hand" (Ronald Brain).
- Sources:
  - [W] https://balatrowiki.org/w/The_Needle
  - [C] https://steamcommunity.com/app/2379780/discussions/0/4694531145715173333

The Eye (no repeated hand type)
- Card Sharp is nullified.
- Builds with one hand type should save Justice or Chariot to win in one hand.
- Supernova is mixed; Obelisk benefits.
- [W] https://balatrowiki.org/w/The_Eye

The Mouth (only the first hand's type scores)
- Do not open with High Card unless it clears the blind.
- Keep Death, Strength or The Sun to repair the hand. Drunkard helps.
- [W] https://balatrowiki.org/w/The_Mouth

The Psychic (must play 5 cards)
- Splash helps.
- Never let hand size fall to 4 or below (Stuntman, Merry Andy, Ouija, Ectoplasm).
- Half Joker, Square Joker, DNA and Sixth Sense are dead here.
- [W] https://balatrowiki.org/w/The_Psychic

The Plant (face cards debuffed, Ante 4+)
- Pareidolia turns this into "debuff everything."
- Photograph, Smiley Face and Baron are dead.
- For face builds "the only real way to beat The Plant is to avoid it": Luchador, Chicot, Director's Cut, Retcon or a Boss Tag.
- [W] https://balatrowiki.org/w/The_Plant

The Flint (base chips and mult halved, rounded up)
- Without jokers it removes about 75% of the score.
- Hits leveled hands and xMult builds hardest.
- Counter with big additive Mult (Supernova, Bootstraps) or Glass cards.
- Sources:
  - [W] https://balatrowiki.org/w/The_Flint
  - [G] https://hardcoregamer.com/ten-tips-for-dominating-gold-stake-in-balatro/

The Water (0 discards)
- Burglar, Mystic Summit, hand size, a Juggle Tag, Luchador.
- Discard-based jokers are dead here.
- [W] https://balatrowiki.org/w/The_Water

The Hook (discards 2 random held cards per hand)
- Draw-dependent hands (Straight, Full House) and held effects (Steel, Gold, Blue Seal, Baron) suffer.
- Discard-trigger jokers benefit.
- [W] https://balatrowiki.org/w/The_Hook

The Arm (played hand -1 level, never below 1)
- Play a non-main hand, ideally an un-leveled one.
- Blue Seal, Space Joker and Burnt Joker help recover.
- An Orbital tag taken before The Arm is a known skip reason.
- Sources:
  - [W] https://balatrowiki.org/w/The_Arm
  - [G] https://hardcoregamer.com/ten-tips-for-dominating-gold-stake-in-balatro/

The Ox (most-played hand sets money to $0, Ante 6+)
- The target is locked in at the start of the ante.
- Avoid that hand type. Spend down before the blind if you must play it.
- [W] https://balatrowiki.org/w/The_Ox

The Serpent (always draw exactly 3 after play or discard, Ante 5+)
- Playing 5 cards shrinks your hand.
- Small discards temporarily grow it.
- Good with Baron and Steel.
- [W] https://balatrowiki.org/w/The_Serpent

The Pillar (cards played earlier this ante are debuffed)
- Skip both blinds, or play few cards in them.
- Changing a card's enhancement clears its debuff.
- [W] https://balatrowiki.org/w/The_Pillar

Face-down bosses (House, Fish, Mark, Wheel)
- "burn a couple of hands as Discard" to see face-up cards (Ronald Brain).
- [C] https://steamcommunity.com/app/2379780/discussions/0/4694531145715173333

The Tooth (-$1 per card played)
- Play fewer cards. [D] Follows directly from the effect.
- [W] https://balatrowiki.org/w/Boss_Blinds

Verdant Leaf (all cards debuffed until you sell 1 joker)
- Keep a sellable non-scoring joker: an economy joker, a spare Negative, or Invisible Joker after 2 rounds.
- On Black+ stakes, Eternal jokers cannot be sold, so make sure at least one joker is sellable.
- Sources:
  - [W] https://balatrowiki.org/w/Verdant_Leaf
  - [W] https://balatrowiki.org/w/Negative_Tag

Crimson Heart (one random joker disabled each hand)
- Play a throwaway hand to move the debuff off a key joker.
- More joker slots dilute the odds.
- End-of-round payouts can fail on the winning hand.
- [W] https://balatrowiki.org/w/Crimson_Heart

Amber Acorn (jokers flipped and shuffled once at the start of the round)
- Track which joker triggers and move the xMult one to the right.
- Grab and hold one joker right after selecting the blind.
- Chicot still lets the shuffle happen.
- [W] https://balatrowiki.org/w/Amber_Acorn

Cerulean Bell (one card is always selected)
- The Hanged Man on the forced card.
- Small hands (Pair), where the forced card can just ride along without scoring.
- [W] https://balatrowiki.org/w/Cerulean_Bell

**8.9 Tools against bosses.**
- **Luchador:** sell it during the boss. It works only if it is not debuffed; Perishable and Crimson Heart both block it.
  - It is "more useful early than late."
  - Carrying it to Ante 8 is unreliable if it is Perishable.
  - The wiki puts the chance of facing both a dangerous boss and a dangerous Showdown in one run at about 6%.
  - [W] https://balatrowiki.org/w/Luchador
- **Chicot:** disables every boss. Holding Luchador alongside it is redundant. [W] https://balatrowiki.org/w/Luchador
- **Director's Cut:** one boss reroll per ante at $10.
- **Retcon:** unlimited rerolls at $10.
- **Boss Tag:** one free reroll.
- [W] https://balatrowiki.org/w/Boss_Blinds
- [W] https://balatrowiki.org/w/The_Plant
- **Mr. Bones:** survive with at least 25% of the requirement.
  - It self-destructs and you get no blind reward, but you still earn interest and the Investment Tag still pays.
  - At Ante 8 it effectively divides the final requirement by 4.
  - It cannot save you against The Psychic with hand size below 5.
  - [W] https://balatrowiki.org/w/Mr._Bones
- **Matador:** $8 when your hand triggers the boss ability (compatible bosses only). [W] https://balatrowiki.org/w/Boss_Blinds

---

## 9. Joker ordering

**9.1 Scoring order, as activated by the game.**
1. Boss effects.
2. "On played" jokers.
3. Each scored card, left to right: its chips; then enhancement, seal and edition; then "on scored" jokers left to right; then retriggers.
4. Held-in-hand effects, left to right: Steel, then "on held" jokers, then retriggers such as Mime.
5. Jokers, left to right. For each joker: Foil or Holographic, then the joker's own effect, then Polychrome.
6. Observatory planets.
7. The Plasma Deck balance step.

- [W] https://balatrowiki.org/w/Scoring

**9.2 +Chips and +Mult to the left of xMult.**
- The wiki's example: 40 chips x 4 mult with a +4 joker and an X2 Ramen scores 640 with the +4 on the left and 480 with it on the right.
  - [W] https://balatrowiki.org/w/Scoring
- Order: chips and setup, then +Mult, then xMult.
  - [G] https://steamcommunity.com/sharedfiles/filedetails/?id=3653261996
  - [G] https://www.switchbladegaming.com/strategy-games/balatro-deck-building-mistakes/
- Exception: place +Mult to the right of xMult only when you deliberately want a lower score. [W] https://balatrowiki.org/w/Scoring

**9.3 Polychrome position.**
- Polychrome's X1.5 applies at that joker's position, so an editioned joker placed too far left loses value. A Polychrome Fortune Teller placed far left is the cited example (Goblin).
- [C] https://steamcommunity.com/app/2379780/discussions/0/4308327413812836587/?ctp=2

**9.4 Blueprint.**
- Copies the joker to its right. Place it directly left of your best xMult or retrigger joker, because copying xMult is "usually better" than copying +Chips or +Mult.
- It cannot copy:
  - end-of-round money (Golden Joker)
  - debuffed jokers
  - editions and stickers
  - destruction effects
  - passive effects (Chicot, Pareidolia, Four Fingers, Credit Card, Egg, Splash, Shortcut, Mr. Bones, Invisible Joker, and others)
- The joker it copies is locked in when you press Play. For end-of-round value (Gold cards, Blue Seals), move the copy onto Mime for the final hand.
- [W] https://balatrowiki.org/w/Blueprint

**9.5 Brainstorm.**
- Copies the leftmost joker.
- Stacking Blueprint with Brainstorm adds one more copy of the effect.
- [W] https://balatrowiki.org/w/Blueprint
- **[D] Trade-off:** putting an xMult joker leftmost for Brainstorm makes the original fire before your +Mult. Usually make the leftmost joker a non-positional effect (economy, retrigger, card generation), or accept the loss only if two copies outweigh it.
- Good copy targets: money, card-making and hand-leveling jokers (DNA, Mail-In Rebate, Perkeo), and Burglar placed far left before the blind. [G] https://www.superjumpmagazine.com/all-in-advanced-strategies-for-earning-c-in-balatro/

**9.6 Retriggers.**
- Hanging Chad: first scored card, 2 more times.
- Sock and Buskin: face cards.
- Hack: 2, 3, 4 and 5.
- Dusk: every card in the final hand.
- Seltzer: every card for 10 hands.
- Mime: held-card effects, so it pairs with Steel, Baron and Gold or Blue Seals.
- Retriggers repeat the card's whole activation.
- Sources:
  - [W] https://balatrowiki.org/w/Jokers
  - [W] https://balatrowiki.org/w/Scoring
- Steel Kings with Baron, Mime and Blueprint/Brainstorm is the canonical held-card engine. Raise hand size whenever you can. [W] https://balatrowiki.org/w/Steel_cards

**9.7 Ceremonial Dagger and Madness.**
- Dagger destroys the joker to its right when a blind is selected. Put Egg there to cash its value into Mult.
- Madness destroys a random joker on Small and Big Blinds. It anti-synergises with Blueprint unless your jokers are Eternal.
- Sources:
  - [W] https://balatrowiki.org/w/Egg
  - [W] https://balatrowiki.org/w/Blueprint
  - [W] https://balatrowiki.org/w/Eternal

**9.8 Re-sort after Amber Acorn.** See 8.8.

---

## 10. Common mistakes and the post-mortem checklist

### 10.1 Mistakes, with sources

1. **No xMult by Ante 5-6.**
   - "Delaying your X Mult engine until Ante 7." [G] https://balatrohq.com/guides/gold-stake-guide/
   - "without one in later Antes, you will probably lose." [G] https://steamcommunity.com/sharedfiles/filedetails/?id=3653261996
   - A run that "missed stack some xmult" died to a boss at Ante 4 (denyEQ). [C] https://steamcommunity.com/app/2379780/discussions/0/4308327413812836587/?ctp=2
2. **Weak economy, the usual root cause of missing xMult.** Failed runs without xMult trace back to "weak economy" (snakeskip). [C] https://steamcommunity.com/app/2379780/discussions/0/595141367272838813/
3. **Overspending.** Clearing every shop and still not having enough money. [C] https://steamcommunity.com/app/2379780/discussions/0/4694531145715173333
   - "Over-rerolling early and entering mid-game broke." [G] https://balatrocalc.com/blog/balatro-gameplay/
4. **Over-saving.** One player lost "because I oversaved" (search-result snippet). https://steamcommunity.com/app/2379780/discussions/0/4329727037117813191
   - Survival comes first (see 2.4).
5. **Spreading Planets across hand types** instead of focusing on one or two. [C] https://steamcommunity.com/app/2379780/discussions/0/4694531145715173333
6. **Treating Planets as optional.** This creates a ceiling around Ante 5 and a wall by Ante 6. [G] https://www.switchbladegaming.com/strategy-games/balatro-deck-building-mistakes/
7. **Ignoring the boss until the blind starts.** [G] https://balatrocalc.com/blog/balatro-gameplay/
   - "Not reading the Boss Blind." [G] https://www.switchbladegaming.com/strategy-games/balatro-deck-building-mistakes/
8. **Undiversified build** that a single boss hard-counters. [G] https://hardcoregamer.com/ten-tips-for-dominating-gold-stake-in-balatro/
9. **Skipping too much.** "You surely can kill a run by skipping" (malogoss). [C] https://steamcommunity.com/app/2379780/discussions/0/604143386282188848
10. **Wrong joker order**, with xMult left of +Mult. [W] https://balatrowiki.org/w/Scoring
11. **Careless discards.**
    - Running out of discards before the hand appears ("Then you have 0 discards left and are boned"). [C] https://steamcommunity.com/app/2379780/discussions/0/4694531145715173333
    - Discarding only 1-2 cards at a time. [W] https://balatrowiki.org/w/Guide:_General_strategy
12. **Neglecting deck stacking.** [C] https://steamcommunity.com/app/2379780/discussions/0/4694531145715173333
13. **Buying for novelty instead of fit, and keeping weak pieces too long.** [G] https://balatrocalc.com/blog/balatro-gameplay/
14. **Chasing perfect hands** instead of reliable clears. [G] https://balatrocalc.com/blog/balatro-gameplay/
15. **Sticker traps.**
    - Not checking the sticker before buying.
    - An Eternal economy joker you cannot sell later.
    - A Perishable xMult joker that dies around Ante 7.
    - Harsh-condition jokers combined with -1 discard.
    - [G] https://balatrohq.com/guides/gold-stake-guide/
    - An early Eternal plus Rental joker; a Perishable Ride the Bus in Ante 2. [G] https://www.switchbladegaming.com/strategy-games/balatro-gold-stake-guide/
16. **Neglecting the early game while assembling a late-game engine** (search-result snippet). https://steamcommunity.com/app/2379780/discussions/0/604149771486111524
17. **Boxing yourself in.** Evaluate every shop card for "any way this card can help you survive" (OrangE). [C] https://steamcommunity.com/app/2379780/discussions/0/840628406751272258/
18. **Pivoting late without reason.** "Avoid full pivots unless the run is collapsing." [G] https://balatrocalc.com/blog/balatro-gameplay/
    - Ante 8: "stop changing plans without a reason." [G] https://jeu.video/guide/balatro-debutant-jokers

### 10.2 Post-mortem checklist for the advisor

Run this on every loss. These are [D] thresholds assembled from the sources above.

- [ ] **Scoring curve.** At each ante, did the typical hand score at least the ante's base chips (a 2-hand boss clear)? Find the first ante where it fell below. That ante's shops are where the run was lost (see 1.5).
- [ ] **End of Ante 2.** Was there any scoring upgrade (a joker, levels or enhancements)? If not, the run was in trouble from Ante 3 on. [W] https://balatrowiki.org/w/Guide:_General_strategy
- [ ] **Jokers.** Was there a scoring joker before the first boss, and 4-5 jokers by the start of Ante 3? (see 1.8)
- [ ] **Three jobs.** By Ante 5, were Chips, +Mult and xMult each covered? Did at least one xMult exist by Ante 5, and 2-3 by Ante 7-8? (see 3.4, 1.9)
- [ ] **Economy.**
  - Did the player sit at $25 or more at round end from about Ante 3?
  - Count the rounds below $25 and the interest lost (each $5 below the cap is $1 per round).
  - Count dollars spent on rerolls that bought nothing. Count dollars spent on items that were sold within 2 rounds.
- [ ] **Over-saving.** Was there a round with $25 or more in the bank where a scoring joker or a planet for the main hand was skipped, followed by a failed blind within the next 1-2 rounds?
- [ ] **Hand focus.** What share of Planets went to the main hand? Flag it if below about 70%. Was the main hand chosen by Ante 3?
- [ ] **Skips.** For each skip, compare the tag's value with the blind reward plus $1 per hand plus interest plus the lost shop (see 4.1 and 4.4).
- [ ] **Boss.** Was the losing boss visible beforehand? Did a counter exist in the intervening shops (Luchador, Director's Cut, Burglar, Glass or Chariot, Mr. Bones, a secondary hand)?
- [ ] **Joker order.** Was any +Mult or +Chips joker to the right of an xMult joker? Was Blueprint not directly left of the best target?
- [ ] **Discards and hand selection.** In the losing round, were discards used to dig for the main hand? Was a hand played while a stronger one was available?
- [ ] **Stickers.** Did an Eternal, Perishable or Rental joker cost a slot, money or effect at the critical ante?
- [ ] **Slot waste.** Was a non-scoring economy joker still held in Ante 7-8? Was a slot empty?
- [ ] **Only after every box above passes** may the advisor label the loss "variance." Even then, note that the community has never found a provably unwinnable Gold seed (see 0.4).

---

## 11. Late game (Antes 6-8)

**11.1 Score requirements.** On Gold (Purple+ scaling):

| Ante | Small | Big | Boss | The Wall | Violet Vessel |
|---|---|---|---|---|---|
| 6 | 60k | 90k | 120k | 240k | n/a |
| 7 | 110k | 165k | 220k | 440k | n/a |
| 8 | 200k | 300k | 400k | n/a | 1.2M |

- On White, Ante 8 is 50k / 75k / 100k, and Violet Vessel is 300k.
- [W] https://balatrowiki.org/w/Blinds_and_Antes
- [W] https://balatrowiki.org/w/Violet_Vessel
- [G] https://mancunion.com/2025/09/01/a-guide-to-gold-stake-balatro/
- **DISAGREEMENT:** one guide claims the Ante 8 boss needs "roughly 300 million chips." That figure is actually Ante 12. [G] https://www.twoaveragegamers.com/balatro-strategy-guide-the-joker-combos-that-actually-win-runs/

**11.2 [D] What the per-hand score has to be.**
- Gold Ante 8 boss: about 200k per hand for a 2-hand clear, or 100k per hand using all 4 hands.
- Since score = chips x mult, 200k needs roughly 450 x 450, or 300 x 670.
- Example board: 300 chips from the leveled hand, cards and chip jokers; 40 Mult from the hand and +Mult jokers; then X3, X2 and X1.5 (a total of X9). That gives 300 x 360 = 108k per hand.
  - It clears the Gold Ante 7 boss (220k) in 3 hands.
  - It clears the Ante 8 boss (400k) in 4 hands, with no margin.
- Conclusion: a Gold winning board needs about X10 or more of total xMult, or a retrigger or held-card engine.

**11.3 What a winning board looks like.**
- Early chip and +Mult jokers, then a transition to scaling xMult (Roffle, via Anno the Meerkat). [C] https://steamcommunity.com/app/2379780/discussions/0/4308327413812836587/?ctp=2
- "a scaling joker, xMult (about x3), and chips." Gold also involves some luck: "usually you don't see something like baron mime" (HattedHead). [C] https://steamcommunity.com/app/2379780/discussions/0/840628406751272258/
- 2-3 condition-light xMult jokers. In Antes 7-8, sell economy and bridge jokers for more multipliers. [G] https://balatrohq.com/guides/gold-stake-guide/
- To beat Ante 8 you usually need chip, +Mult and xMult scaling jokers, for example Runner, Red Card, Hologram, Constellation and Vampire. [G] https://mancunion.com/2025/09/01/a-guide-to-gold-stake-balatro/

**11.4 Every slot scores by Ante 8.**
- "every Joker slot should contribute to your score." [G] https://www.twoaveragegamers.com/balatro-strategy-guide-the-joker-combos-that-actually-win-runs/
- At Ante 7-8, prefer multiplicative pairings over new additions. Past Ante 4, joker type matters more than joker count. [G] https://www.switchbladegaming.com/balatro/advanced-strategy-guide-2/

**11.5 Stickers late in the run.**
- Perishable jokers are acceptable from Ante 6. Within 5 rounds of the end they carry no real downside.
- A Perishable Ride the Bus or Card Sharp is worth taking in Antes 5-6, because it can close the run.
- Rentals become short-term contracts.
- Sources:
  - [G] https://www.switchbladegaming.com/strategy-games/balatro-gold-stake-guide/
  - [G] https://mancunion.com/2025/09/01/a-guide-to-gold-stake-balatro/

**11.6 Plan the Showdown in Ante 7-8.**
- Know the Ante 8 boss as early as possible.
- Keep one sellable joker for Verdant Leaf.
- Keep extra joker slots or Negatives against Crimson Heart.
- Have a re-sort plan for Amber Acorn and The Hanged Man for Cerulean Bell.
- Violet Vessel is a pure damage check unless you have Luchador.
- Mr. Bones divides the final requirement by 4.
- Sources:
  - [W] https://balatrowiki.org/w/Verdant_Leaf
  - [W] https://balatrowiki.org/w/Crimson_Heart
  - [W] https://balatrowiki.org/w/Amber_Acorn
  - [W] https://balatrowiki.org/w/Cerulean_Bell
  - [W] https://balatrowiki.org/w/Violet_Vessel
  - [W] https://balatrowiki.org/w/Mr._Bones

**11.7 Late-game spending.**
- Late game, "spend for reliability." [G] https://balatrocalc.com/blog/balatro-gameplay/
- Buy a boss reroll even if it drops you below $25. [G] https://steamcommunity.com/sharedfiles/filedetails/?id=3653261996
- [D] Interest stops mattering in the last rounds: at Ante 8 the remaining interest is at most about $10-15, so convert money into score.
- Campfire scales with buy-and-sell during the final ante. [W] https://balatrowiki.org/w/Violet_Vessel

**11.8 Late-game hand choice.**
- Without heavy deck fixing, lean on High Card, Pair or Two Pair (RazzberryMocha), or on a heavily leveled main hand.
- [C] https://steamcommunity.com/app/2379780/discussions/0/604167589085578695/

---

## Appendix A: compact decision rules for implementation ([D], drawn from the rules above)

1. **next_blind_ok:** expected best hand x hands available is at least the requirement, with a margin of at least 1.3x (bosses can disrupt). For the boss, also apply the boss-specific modifier from 8.8.
2. **falling_behind:** typical hand < ante base chips (that is, worse than a 2-hand boss clear). Then shift shop priority to scoring over interest, and allow spending below $25.
3. **Shop priority, Antes 1-2:**
   1. an unconditional +Mult or +Chips joker if 0-1 scoring jokers are owned
   2. an economy joker if none is owned
   3. a scaling joker for the likely hand
   4. a Planet for the main hand
   5. save to $25

   Skip vouchers in Antes 1-2 unless the voucher is Grabber, Paint Brush or Overstock and the money stays at $25 or more.
4. **Shop priority, Antes 3-5:**
   1. a Planet for the main hand
   2. an xMult joker
   3. replace the weakest flat joker
   4. keep $25
   5. Seed Money once $40 or more is held
   6. boss counters 2-3 shops ahead
5. **Shop priority, Antes 6-8:**
   1. xMult or retrigger
   2. convert economy jokers into scoring jokers
   3. boss counters (Director's Cut is allowed below $25)
   4. a Perishable or Rental joker is acceptable when the run ends within 5 rounds
6. **Reroll:** only if money - reroll price is at least $25 (Antes 1-5) and no item in the shop raises next_blind_ok or fills a missing job (chips, +Mult or xMult). Cap at 1 reroll per shop in Antes 1-3, unless Chaos the Clown or Flash Card is owned.
7. **Skip:** only if tag value is at least 2 x (blind reward + unused-hand money + interest), plus a shop penalty, and next_blind_ok holds without the lost shop. Whitelist: Investment (Ante 1-2), Polychrome or Negative joker, Holographic, Coupon (first round), Orbital for the main hand, Boss Tag before a hard-counter boss, Charm for The Soul. Never skip for D6, Double or Voucher alone.
8. **Hand selection:** play the hand that clears the requirement with the fewest hands. Use discards aggressively, keeping only the cards for the target hand. Stop scoring once the blind is cleared; each saved hand is $1.
9. **Joker order:** chips, then +Mult, then xMult (Polychrome jokers right of +Mult). Blueprint directly left of the best xMult or retrigger joker. Re-check after Amber Acorn.
10. **Loss attribution:** run the 10.2 checklist before ever reporting variance.

---

## Source list (all opened unless marked as a snippet)

### Official wiki (balatrowiki.org)

- Blinds and stakes:
  - https://balatrowiki.org/w/Blinds_and_Antes
  - https://balatrowiki.org/w/Stakes
  - https://balatrowiki.org/w/Gold_Stake
  - https://balatrowiki.org/w/Orange_Stake
  - https://balatrowiki.org/w/Green_Stake
  - https://balatrowiki.org/w/Purple_Stake
- Stickers:
  - https://balatrowiki.org/w/Stickers
  - https://balatrowiki.org/w/Rental
  - https://balatrowiki.org/w/Perishable
  - https://balatrowiki.org/w/Eternal
- Economy:
  - https://balatrowiki.org/w/Interest
  - https://balatrowiki.org/w/Money
  - https://balatrowiki.org/w/Hands
- Shop and vouchers:
  - https://balatrowiki.org/w/Shop
  - https://balatrowiki.org/w/Booster_Packs
  - https://balatrowiki.org/w/Vouchers
  - https://balatrowiki.org/w/Voucher
- Tags:
  - https://balatrowiki.org/w/Tags
  - https://balatrowiki.org/w/Investment_Tag
  - https://balatrowiki.org/w/Double_Tag
  - https://balatrowiki.org/w/Negative_Tag
  - https://balatrowiki.org/w/D6_Tag
  - https://balatrowiki.org/w/Economy_Tag
  - https://balatrowiki.org/w/Charm_Tag
- Card modifiers:
  - https://balatrowiki.org/w/Enhancements
  - https://balatrowiki.org/w/Seals
  - https://balatrowiki.org/w/Editions
  - https://balatrowiki.org/w/Steel_cards
  - https://balatrowiki.org/w/Glass_Card
  - https://balatrowiki.org/w/Lucky_Card
- Hands and scoring:
  - https://balatrowiki.org/w/Poker_Hands
  - https://balatrowiki.org/w/Planet_Cards
  - https://balatrowiki.org/w/Scoring
- Consumables:
  - https://balatrowiki.org/w/Tarot_Cards
  - https://balatrowiki.org/w/Spectral_Cards
  - https://balatrowiki.org/w/The_Hanged_Man
  - https://balatrowiki.org/w/Hex
  - https://balatrowiki.org/w/Ectoplasm
  - https://balatrowiki.org/w/Ankh
  - https://balatrowiki.org/w/The_Soul
  - https://balatrowiki.org/w/Wraith
  - https://balatrowiki.org/w/Judgement
  - https://balatrowiki.org/w/Immolate
- Jokers:
  - https://balatrowiki.org/w/Jokers
  - https://balatrowiki.org/w/Blueprint
  - https://balatrowiki.org/w/Chaos_the_Clown
  - https://balatrowiki.org/w/Mr._Bones
  - https://balatrowiki.org/w/Egg
  - https://balatrowiki.org/w/Gift_Card
  - https://balatrowiki.org/w/Luchador
- Boss Blinds:
  - https://balatrowiki.org/w/Boss_Blinds
  - https://balatrowiki.org/w/The_Psychic
  - https://balatrowiki.org/w/The_Eye
  - https://balatrowiki.org/w/The_Mouth
  - https://balatrowiki.org/w/The_Plant
  - https://balatrowiki.org/w/The_Needle
  - https://balatrowiki.org/w/The_Flint
  - https://balatrowiki.org/w/The_Hook
  - https://balatrowiki.org/w/The_Water
  - https://balatrowiki.org/w/The_Ox
  - https://balatrowiki.org/w/The_Arm
  - https://balatrowiki.org/w/The_Serpent
  - https://balatrowiki.org/w/The_Pillar
  - https://balatrowiki.org/w/Verdant_Leaf
  - https://balatrowiki.org/w/Crimson_Heart
  - https://balatrowiki.org/w/Amber_Acorn
  - https://balatrowiki.org/w/Cerulean_Bell
  - https://balatrowiki.org/w/Violet_Vessel
- Wiki guides:
  - https://balatrowiki.org/w/Guide:_General_strategy
  - https://balatrowiki.org/w/Guide:_Scaling
  - https://balatrowiki.org/w/Guide:_Deck_Manipulation
  - https://balatrowiki.org/w/Guide:_Completionist%2B%2B
  - https://balatrowiki.org/w/Deck-Specific_Guides

### Guides and articles

- https://mancunion.com/2025/09/01/a-guide-to-gold-stake-balatro/
- https://hardcoregamer.com/ten-tips-for-dominating-gold-stake-in-balatro/
- https://balatrohq.com/guides/gold-stake-guide/
- https://balatrohq.com/vouchers/
- https://www.superjumpmagazine.com/all-in-advanced-strategies-for-earning-c-in-balatro/
- https://choostgames.com/blog/balatro-jokers/
- https://games.gg/balatro/guides/balatro-vouchers-tier-list/
- https://games.gg/balatro/guides/balatro-spectral-cards-guide/
- https://games.gg/balatro/guides/balatro-economy-guide/
- https://games.gg/balatro/guides/balatro-beginners-guide/
- https://balatrocalc.com/blog/balatro-gameplay/
- https://www.twoaveragegamers.com/balatro-strategy-guide-the-joker-combos-that-actually-win-runs/
- https://addisonkindrick.substack.com/p/10-balatro-tier-list-addendum
- https://setsideb.com/beginners-guide-to-scoring-high-in-balatro/
- https://jeu.video/guide/balatro-debutant-jokers
- https://insider-gaming.com/balatro-is-getting-its-first-major-update/
- Switchblade Gaming (lower reliability; contains some factual errors, so it is used only where other sources agree):
  - https://www.switchbladegaming.com/strategy-games/balatro-economy-strategy/
  - https://www.switchbladegaming.com/strategy-games/balatro-gold-stake-guide/
  - https://www.switchbladegaming.com/balatro/advanced-strategy-guide-2/
  - https://www.switchbladegaming.com/strategy-games/balatro-deck-building-mistakes/
- Steam guides (the pages now show them as removed from the Community, but the text was readable):
  - https://steamcommunity.com/sharedfiles/filedetails/?id=3653261996
  - https://steamcommunity.com/sharedfiles/filedetails/?id=3166946815

### Community (Steam, app 2379780; PC Gamer forum)

- https://steamcommunity.com/app/2379780/discussions/0/604167589085578695/
- https://steamcommunity.com/app/2379780/discussions/0/604143386282188848
- https://steamcommunity.com/app/2379780/discussions/0/840628406751272258/
- https://steamcommunity.com/app/2379780/discussions/0/4361249916210087237
- https://steamcommunity.com/app/2379780/discussions/0/4756452715167149899
- https://steamcommunity.com/app/2379780/discussions/0/604142859631741886/?ctp=2
- https://steamcommunity.com/app/2379780/discussions/0/7434949789835831475
- https://steamcommunity.com/app/2379780/discussions/0/4308326918575062372
- https://steamcommunity.com/app/2379780/discussions/0/4308327413812836587/?ctp=2
- https://steamcommunity.com/app/2379780/discussions/0/4346606879521850576
- https://steamcommunity.com/app/2379780/discussions/0/715609580327930968
- https://steamcommunity.com/app/2379780/discussions/0/4294818447590775533
- https://steamcommunity.com/app/2379780/discussions/0/4201363889242704640
- https://steamcommunity.com/app/2379780/discussions/0/595141367272838813/
- https://steamcommunity.com/app/2379780/discussions/0/4357869219921982825/
- https://steamcommunity.com/app/2379780/discussions/0/4694531145715173333
- https://steamcommunity.com/app/2379780/discussions/0/4308327178393752844
- https://steamcommunity.com/app/2379780/discussions/0/596264060842957220
- https://forums.pcgamer.com/threads/balatro-tips-and-strategies-add-your-own.148962

### Seen only as search-result snippets (not opened)

- https://pcgamer.com/balatro-tips
- https://turnbasedlovers.com/guides/10-beginner-tips-to-develop-better-strategies-in-balatro/
- https://twinfinite.net/?p=1063061
- https://mobalytics.gg/blog/tier-lists/best-balatro-jokers/ (fetching it returned 403)
- https://dotesports.com/indies/news/balatro-tier-list-best-jokers-ranked
- https://steamcommunity.com/app/2379780/discussions/0/4346606879507212202
- https://steamcommunity.com/app/2379780/discussions/0/4693406471885516172
- https://steamcommunity.com/app/2379780/discussions/0/596265364943276073
- https://steamcommunity.com/app/2379780/discussions/0/7410182856437605680
- https://steamcommunity.com/app/2379780/discussions/0/4329727037117813191
- https://steamcommunity.com/app/2379780/discussions/0/604149771486111524
