<!-- Recherche sourcée (en anglais) utilisée pour les règles des mises élevées de la version 1.0.10 : engine/plan.lua, engine/skip.lua, engine/advice.lua, engine/shop.lua ; synthèse en français : docs/PRO_LESSONS.md §9. -->

# Balatro High-Stakes Research (Black → Gold), vanilla 1.0.1

Research date: 2026-10-21. Target: a strategy copilot for Balatro 1.0.1 (LocalThunk, unmodded) at Black, Blue, Purple, Orange and Gold stake.

---

## 0. Method, source quality and legend

**Tags used on each claim**

| Tag | Meaning |
|---|---|
| **[W]** | Game mechanic from the Balatro Wiki (balatrowiki.org) or the 1.0.1 patch notes. Treated as fact. |
| **[C]** | Consensus: 3 or more independent sources agree, with no credible dissent found. |
| **[M]** | Several sources agree, but some dissent exists or the sources are few. |
| **[S]** | One person's opinion. |
| **[D]** | Disputed: the sources disagree, and both sides are shown. |
| **[snippet]** | Seen only in a search-result snippet. The page could not be opened. |
| **[pre-1.0.1]** | Posted before 1.0.1 landed (about April–May 2024). Gold then had -1 hand size, and Orange made packs cost +$1 per ante. Reread such advice with that in mind. |
| **[derived]** | My own arithmetic from cited numbers. Not a community claim. |

**Coverage limits (please read)**
- **Reddit could not be reached.** reddit.com returns 403 to the fetcher, and the search tool refuses that domain. So there are no r/balatro citations. The main community source is the **Steam Balatro discussion board**. Several regulars there have proven high-stake records and appear across many threads:
  - **malogoss**: multiple Gold completions and C++. Describes progressing to winning "half your gold stake runs".
  - **RazzberryMocha**: says his Gold win rate is about 30–40% ([S19](https://steamcommunity.com/app/2379780/discussions/0/600772276758022609/)).
  - **mangonaise**: did Completionist++ twice.
  - Others: Goblin, srn347, revlayle, QuantuuM.
- **YouTube transcripts** (Balatro University, Roffle, Toby and others) were not available. A search snippet confirms that Balatro University has a "Gold Stake Lessons" playlist of 71 videos [snippet]. Its advice appears here only second-hand, through forum posts.
- **No public win-rate dataset for human players was found.** [balatrostats.com](https://www.balatrostats.com/) and [balatro-analytics.vercel.app](https://balatro-analytics.vercel.app/) show only placeholders or client-side data that could not be read.
- **Low-reliability sites (not used for rules):**
  - findingdulcinea.com tier list: wrong joker texts (Matador, Idol, old Gros Michel odds).
  - switchbladegaming.com: rehashed from other sources, and its sticker table comes from a buggy beta analysis.

---

## 1. Stakes and blind requirements

### 1.1 What each stake adds in 1.0.1 (effects stack) [W]
Sources: [Stakes](https://balatrowiki.org/w/Stakes), [Gold Stake](https://balatrowiki.org/w/Gold_Stake), [Orange Stake](https://balatrowiki.org/w/Orange_Stake), [Black Stake](https://balatrowiki.org/w/Black_Stake), [Discards](https://balatrowiki.org/w/Discards), [Money](https://balatrowiki.org/w/Money)

| Stake | Adds | Notes |
|---|---|---|
| Red | Small Blind pays **$0** | Normally $3. Big Blind still pays $4, Boss $5, Ante-8 boss $8. |
| Green | Scaling tier 2 | See table 1.2. |
| Black | **30%** of shop/pack Jokers are **Eternal** (can't be sold or destroyed) | |
| Blue | **-1 discard** (3 → **2** per round) | |
| Purple | Scaling tier 3 | |
| Orange | **30%** of Jokers are **Perishable** (debuffed after 5 rounds) | Replaced 1.0.0's "+$1 pack cost per ante". |
| Gold | **30%** of Jokers are **Rental** ($1 to buy, **-$3 at end of every round**) | Replaced 1.0.0's "**-1 hand size**". |

**What the patch notes add**
- The 1.0.1 notes confirm the Orange and Gold changes, and that **Eternal now also applies to Jokers in Buffoon packs** ([VGC patch summary](https://www.videogameschronicle.com/news/balatros-first-major-update-tweaks-difficulty-adds-new-joker-types/), [Shacknews 1.0.1c notes](https://shacknews.com/article/139415/balatro-update-101c-patch-notes)).
- The wiki and dood.gg both say stickers apply to Jokers from booster packs as well as the shop ([Perishable](https://balatrowiki.org/w/Perishable), [dood stakes guide](https://dood.gg/en/balatro/guides/stakes-guide/)).

**How common clean Jokers are**
- Eternal and Perishable are mutually exclusive: 30% Eternal, 30% Perishable, 40% neither.
- Rental is rolled separately at 30%.
- So **about 28% of Jokers at Orange+Gold carry no sticker at all** (0.4 × 0.7) ([Stickers](https://balatrowiki.org/w/Stickers)) [W].
- A Steam code reading of the April 2024 beta found about 24% clean because of a `/0.7` bug ([S10](https://steamcommunity.com/app/2379780/discussions/0/4369129313606908896/)).
- **Practical number for the copilot: about 1 Joker in 4 is clean at Gold.**

**Jokers that can never get some stickers**
- **Never Perishable (18 Jokers)** [W] ([Perishable](https://balatrowiki.org/w/Perishable)):
  Ceremonial Dagger, Ride the Bus, Runner, Constellation, Green Joker, Red Card, Madness, Square Joker, Vampire, Hologram, Rocket, Obelisk, Lucky Cat, Flash Card, Spare Trousers, Castle, Glass Joker, Wee Joker. Legendaries are also never Perishable in practice.
  - The wiki explains why: playtesting showed Perishable made these scaling Jokers useless, because they had no time to scale.
  - **So a "perishable scaling joker" mostly cannot happen.**
- **Never Eternal (11 Jokers)** [W] ([Eternal](https://balatrowiki.org/w/Eternal)):
  Gros Michel, Ice Cream, Cavendish, Luchador, Turtle Bean, Diet Cola, Popcorn, Ramen, Seltzer, Mr. Bones, Invisible Joker.

**Version caveats**
- Gold stake **does not reduce hand size in 1.0.1**. Many early-2024 guides still say it does: Steam guides, the "Got my first Gold Stake win" thread, and the 100% achievement guide ([G3](https://steamcommunity.com/sharedfiles/filedetails/?id=3400510379)).
- **Investment Tag pays $25 in 1.0.1f** (it was $15) ([Tags](https://balatrowiki.org/w/Tags)) [W].

### 1.2 Base chip amounts per ante — your table is CONFIRMED [W]
Source: [Blinds and Antes](https://balatrowiki.org/w/Blinds_and_Antes). The dood.gg ante guide matches it.

| Ante | White/Red (tier 1) | Green/Black/Blue (tier 2) | Purple/Orange/Gold (tier 3) |
|---|---|---|---|
| 1 | 300 | 300 | 300 |
| 2 | 800 | 900 | 1,000 |
| 3 | 2,000 | 2,600 | 3,200 |
| 4 | 5,000 | 8,000 | 9,000 |
| 5 | 11,000 | 20,000 | 25,000 |
| 6 | 20,000 | 36,000 | 60,000 |
| 7 | 35,000 | 60,000 | 110,000 |
| 8 | 50,000 | 100,000 | 200,000 |
| 9 (Endless) | 110,000 | 230,000 | 460,000 |
| 10 | 560,000 | 1.1M | 2.2M |
| 11 | 7.2M | 14M | 29M |
| 12 | 300M | 600M | 1.2B |

- The 1.0.1c beta had briefly listed different numbers (for example Purple A3 3,000, A4 8,000, A5 22,000) ([VGC](https://www.videogameschronicle.com/news/balatros-first-major-update-tweaks-difficulty-adds-new-joker-types/)). The final 1.0.1 values are the ones in the table.

**Blind size multipliers** [W]:
- Small ×1, Big ×1.5, Boss ×2.
- Exceptions: **The Wall ×4**, **Violet Vessel ×6**, **The Needle ×1** (but only 1 hand).
- **Plasma Deck doubles every requirement.**

**Blind rewards** [W]: Small $3 ($0 at Red and above), Big $4, Boss $5, Ante-8 Showdown $8. Plus **$1 per unused hand**. Unused discards pay nothing except on Green Deck ([Money](https://balatrowiki.org/w/Money)).

### 1.3 Gold-stake (tier 3) actual targets [derived from 1.2]

| Ante | Small (×1) | Big (×1.5) | Boss (×2) | The Wall (×4) | Needle (×1, one hand) |
|---|---|---|---|---|---|
| 1 | 300 | 450 | 600 | n/a (min ante 2) | n/a |
| 2 | 1,000 | 1,500 | 2,000 | 4,000 | 1,000 |
| 3 | 3,200 | 4,800 | 6,400 | 12,800 | 3,200 |
| 4 | 9,000 | 13,500 | 18,000 | 36,000 | 9,000 |
| 5 | 25,000 | 37,500 | 50,000 | 100,000 | 25,000 |
| 6 | 60,000 | 90,000 | 120,000 | 240,000 | 60,000 |
| 7 | 110,000 | 165,000 | 220,000 | 440,000 | 110,000 |
| 8 | 200,000 | 300,000 | 400,000 (Showdown) | **Violet Vessel 1,200,000** | n/a |

- Wiki rows for The Wall (Purple column: A4 36,000, A5 100,000) and Violet Vessel (Purple 1,200,000) confirm these numbers ([The Wall](https://balatrowiki.org/w/The_Wall), [Violet Vessel](https://balatrowiki.org/w/Violet_Vessel)).
- **Plasma at Gold doubles everything:** Ante-8 boss 800,000, Violet Vessel 2,400,000.
- Purple/Gold is about 3× White at Ante 6 and 4× at Ante 8 ([dood ante guide](https://dood.gg/en/balatro/guides/ante-guide/)).

### 1.4 Score-per-hand targets
Nobody in the sources publishes a per-ante table, so the first rule below is derived. The rest are what players actually say.

- **[derived] "Base-score rule".** If your normal main hand scores at least the ante's **base** (the Small Blind number), you can:
  - one-shot the Small Blind,
  - beat the Big Blind in 2 hands,
  - beat the Boss in 2 hands, leaving 2 hands of margin or $2 of extra income,
  - **pass The Needle**, whose single-hand requirement equals the base.
  - At Gold the targets are **300 / 1,000 / 3,200 / 9,000 / 25,000 / 60,000 / 110,000 / 200,000**.
  - The Wall needs 4× base, which uses all 4 hands with zero margin. Aim for **1.5× base** on antes where The Wall can appear, or keep a reroll or Luchador.
  - Violet Vessel needs about **300k per hand over 4 hands** at Gold.
- **[S] Ante 1–3 one-shots.** "Get anything that can oneshot first few blinds" (HattedHead, [S7](https://steamcommunity.com/app/2379780/discussions/0/840628406751272258/)). The first boss (600) can be beaten by "one Jimbo plus almost any 5-card hand" (same thread).
- **[S] Violet Vessel safety number.** malogoss: VV "is the safest boss to face at ante 8 if you score around **500k per hand**" ([S26](https://steamcommunity.com/app/2379780/discussions/0/4424310458751168875)). This was on Purple, where VV = 1.2M.
- **[S] Treat VV as the real final exam.** "Treat Violet Vessel as the final boss" at **1.2M**: if you can beat it, you likely beat any showdown boss (mangonaise, did C++ twice, [S1](https://steamcommunity.com/app/2379780/discussions/0/604143165271744486)).
- **[S] Early target.** About 450/600 chips is "the target score for early antes" (Ravenous Roxy, [S13](https://steamcommunity.com/app/2379780/discussions/0/4334231676647966765)).

---

## 2. Early game at high stakes (Antes 1–3)

### 2.1 What to buy first
- **[C] Buy a flat scoring Joker (+Mult or +Chips) in the first one or two shops.** Survival comes before economy in Ante 1–2.
  - "Buy a score-boosting joker as soon as possible" (Otakuya, [S15](https://steamcommunity.com/app/2379780/discussions/0/4346606879517114465/)) [pre-1.0.1].
  - "Prioritize +Mult and +Chips Jokers" (QuantuuM, [S8](https://steamcommunity.com/app/2379780/discussions/0/764059330564645976/)).
  - "Ante 1: prioritize +Chips/+Mult" (QuantuuM, [S7](https://steamcommunity.com/app/2379780/discussions/0/840628406751272258/)).
  - "Buy a scoring joker at the first shop when possible" (malogoss, [S18](https://steamcommunity.com/app/2379780/discussions/0/4756452715167149899)).
  - "You'll get killed in ante 2 without at least one scoring joker" (TimTim3000, [S20](https://steamcommunity.com/app/2379780/discussions/0/7252559325161419962)).
  - "Getting to $25 quickly matters, but early survival pieces matter more" (RazzberryMocha, [S2](https://steamcommunity.com/app/2379780/discussions/0/596263931969820235)).
- **[D] Money Joker first instead?**
  - For: phantom says a strong money Joker in Ante 1 beats a scoring Joker, because the first boss can be beaten without one ([S20](https://steamcommunity.com/app/2379780/discussions/0/7252559325161419962)).
  - For: BalatroHQ says to "secure one economy joker right away" ([M6](https://balatrohq.com/guides/gold-stake-guide/)).
  - For, Black deck only: get an early economy Joker even if Eternal (Cloud 9, Golden Joker, Rocket) ([Mancunion](https://mancunion.com/2025/09/01/a-guide-to-gold-stake-balatro/)).
  - **Majority position:** a scoring Joker first, then an economy Joker.
- **[S] A concrete opening plan (Black deck).** malogoss:
  - Beat the Small Blind in one hand, then buy a **+Mult** joker (Raised Fist, Abstract).
  - Beat the Big Blind in one hand, then buy an **economy** joker (Golden Joker, To Do List).
  - Beat the boss in one hand, then buy a **scaling** joker.
  - "Aim for a $20+ bankroll with 5–6 jokers" ([S17](https://steamcommunity.com/app/2379780/discussions/0/604143633269036634)).
- **[M] Slot targets.** Aim for **4–5 Jokers by the end of Ante 2 / start of Ante 3** (malogoss, [S18](https://steamcommunity.com/app/2379780/discussions/0/4756452715167149899)). "One scoring Joker per ante for antes 1–4" (TimTim3000, [S20](https://steamcommunity.com/app/2379780/discussions/0/7252559325161419962); Monoxide, [S31](https://steamcommunity.com/app/2379780/discussions/0/4364626348105356076)). "Fill your Joker slots as early as possible… holding a slot open is throwing away score" ([dood ante guide](https://dood.gg/en/balatro/guides/ante-guide/)).
- **[M] "Good enough" beats perfect.** "Even +4 Mult is valuable"; a basic Joker or Mystic Summit "can buy time" (RazzberryMocha, [S2](https://steamcommunity.com/app/2379780/discussions/0/596263931969820235), [S3](https://steamcommunity.com/app/2379780/discussions/0/596264096371887282)).
  - Accept a bad **Eternal** (for example Greedy Joker) if it keeps the run going (same source).
  - "It's ok to not buy anything in the first shop" if nothing is useful (srn347, [S27](https://steamcommunity.com/app/2379780/discussions/0/4356743780116244183)).
- **[S] Early-only Jokers are fine to take.** Popcorn, Ice Cream, Raised Fist and the pair Jokers are strong early, weak late, and worth taking ([S16](https://steamcommunity.com/app/2379780/discussions/0/4346606879520764406/), [pre-1.0.1]). Ice Cream, Popcorn and Gros Michel early, then scalers (kone, [S20](https://steamcommunity.com/app/2379780/discussions/0/7252559325161419962)).
- **[M] Chips Jokers are under-valued.** "Don't underestimate chip-bonus jokers" (Otakuya, [S15](https://steamcommunity.com/app/2379780/discussions/0/4346606879517114465/)). "When in doubt, take one +chips joker" (malogoss, [S25](https://steamcommunity.com/app/2379780/discussions/0/695376132937158319/)). "+Chips Jokers are rare, so they can justify sacrificing some economy" (malogoss, [S8](https://steamcommunity.com/app/2379780/discussions/0/764059330564645976/)).

### 2.2 Skipping blinds and tags
- **[C] Almost never skip at Gold. The one standard exception is the Investment Tag ($25) in Ante 1.**
  - RazzberryMocha: "skip tags are usually bad. The only one to take consistently is the $25 tag in ante 1" ([S2](https://steamcommunity.com/app/2379780/discussions/0/596263931969820235)).
  - revlayle lists only three skip cases ([S1](https://steamcommunity.com/app/2379780/discussions/0/604143165271744486)):
    - Investment in Ante 1;
    - a "Hail Mary" skip when you can't beat the ante anyway;
    - skipping to dodge a boss that debuffs your Ancient Joker suit.
  - malogoss "often ends runs having skipped 0 or 1 blind" at Gold ([S18](https://steamcommunity.com/app/2379780/discussions/0/4756452715167149899)), and says "Don't skip Blinds" ([S8](https://steamcommunity.com/app/2379780/discussions/0/764059330564645976/), [S25](https://steamcommunity.com/app/2379780/discussions/0/695376132937158319/)).
  - Mancunion: skip tags "mostly useless, except in round 1 for investment or in Anaglyph" ([link](https://mancunion.com/2025/09/01/a-guide-to-gold-stake-balatro/)).
  - Addison Kindrick: only economy tags; Investment especially strong in Ante 1 ([link](https://addisonkindrick.substack.com/p/10-balatro-tier-list-addendum)).
- **Why skipping costs so much.** A skip loses that round's shop, its unused-hand money and its interest ([dood ante guide](https://dood.gg/en/balatro/guides/ante-guide/), camel and Alistair Hutton in [coin-return](https://forums.coin-return.org/threads/balatro-roguelike-poker-just-one-more-hand.782/page-5)). The Red-stake $0 Small Blind only removes $3. "Oneshotting it yields only about $3 extra" (Goblin, [S14](https://steamcommunity.com/app/2379780/discussions/0/4293691486113242157/?ctp=4), [pre-1.0.1]).
- **[D] Other tags**
  - Voucher Tag: worth taking regularly (facetious, [coin-return](https://forums.coin-return.org/threads/balatro-roguelike-poker-just-one-more-hand.782/page-5)).
  - Coupon Tag: "a trap" (abotkin, same thread) vs "amazing" (Black-deck guide, [G1](https://steamcommunity.com/sharedfiles/filedetails/?id=3535175222)).
  - Negative Tag: often useless (abotkin) vs worth taking (WitchPHD, [link](https://witchphd.substack.com/p/balala)).
  - Charm Tag: good for a Mega Arcana pack in Ante 1 ([G1](https://steamcommunity.com/sharedfiles/filedetails/?id=3535175222)).
  - Boss and Juggle Tags: only when the boss hard-counters you (facetious).
- **[M] Joker tags are worth less at Gold.** The free Joker is very likely Perishable, Eternal or Rental (CMDR Shven, [S6](https://steamcommunity.com/app/2379780/discussions/0/4308327178395153352); cct, [S13](https://steamcommunity.com/app/2379780/discussions/0/4334231676647966765); Woody and Aw3som3, [S10](https://steamcommunity.com/app/2379780/discussions/0/4369129313606908896/)).
- **Tag facts** [W] ([Tags](https://balatrowiki.org/w/Tags)):
  - Investment = $25 after the boss.
  - Economy = doubles money, max +$40.
  - Speed = $5 per blind skipped.
  - Orbital = +3 levels to a hand.
  - D6 = rerolls start at $0.
  - 9 tags cannot appear in Ante 1: Negative, Standard, Meteor, Buffoon, Handy, Garbage, Ethereal, Top-up, Orbital.

### 2.3 Rerolls, packs and when to start saving
- **[M] Buy packs before rerolling. Reroll only with money above the interest line.** "Buy packs before rerolling. Reroll only if you have about **$35 left after buying packs**, or save money for packs at the next shop" (malogoss, [S8](https://steamcommunity.com/app/2379780/discussions/0/764059330564645976/)). "Avoid rerolling unless necessary, and don't drop to about $0" (YoruHawk, [S4](https://steamcommunity.com/app/2379780/discussions/0/4356744017103053782), [pre-1.0.1]).
- **Reroll cost** [W] ([Shop](https://balatrowiki.org/w/Shop)):
  - $5, then +$1 for each further reroll in the same shop. Resets every shop.
  - Reroll Surplus makes it start at $3; Reroll Glut at $1.
  - Packs cost $4 / $6 / $8 (normal / jumbo / mega). Vouchers cost $10.
  - Shop Joker rarity: **Common 70%, Uncommon 25%, Rare 5%**.
  - Card weights: Joker 20, Tarot 4, Planet 4 (Jokers are about 71% of shop cards).
- **[M] Bankroll targets after the core is in place:**
  - "Leave each shop with roughly **$20–25**" (malogoss, [S18](https://steamcommunity.com/app/2379780/discussions/0/4756452715167149899)).
  - "Keep **$15 to $20** at the end of each shop phase" (Addison Kindrick, Gold-stake tier list, [link](https://addisonkindrick.substack.com/p/10-balatro-tier-list-addendum)).
  - "Keep about **$20** banked in Antes 1–2" ([dood ante guide](https://dood.gg/en/balatro/guides/ante-guide/)).
  - "Reach $25 early and stay there… econ is king" ([Mancunion](https://mancunion.com/2025/09/01/a-guide-to-gold-stake-balatro/)).
- **[S] Timing of economy.** "Building an economy early is good **only once you're sure you'll survive the next blind**" (malogoss, [S26](https://steamcommunity.com/app/2379780/discussions/0/4424310458751168875)). "Ante 2: reach enough points while starting economy… Antes 3–4: rerolls get expensive, seek xMult… Antes 5–6: don't over-save money at the expense of score" (QuantuuM, [S7](https://steamcommunity.com/app/2379780/discussions/0/840628406751272258/)).
- **[D] Packs**
  - Standard packs are rarely worth it at high difficulty (warmingbird, [S15](https://steamcommunity.com/app/2379780/discussions/0/4346606879517114465/); kone, [S20](https://steamcommunity.com/app/2379780/discussions/0/7252559325161419962)).
  - "Get up to $25 before you start opening packs" (opie, Nebula Gold, [S9](https://steamcommunity.com/app/2379780/discussions/0/4693406471885516172)), against "snap up packs early" (DonDarker, [S4](https://steamcommunity.com/app/2379780/discussions/0/4356744017103053782), [pre-1.0.1]).
  - Buffoon packs help you reach 2–3 Jokers early but are poor once you have 3 [snippet, Steam].
  - **Note:** 1.0.0 Orange stake made packs cost +$1 per ante, so pre-1.0.1 "packs are too expensive at Orange" advice no longer applies.

---

## 3. Reaching enough power by Antes 4–6 (Purple/Gold)

### 3.1 Target Joker composition
- **[C] Have all three: Chips, +Mult and xMult, with 2–3 xMult by Ante 8.**
  - srn347: "about **1 +mult, 1 +chips, 2–3 xmult, 0–1 utility**"; several +Mult or several xMult Jokers alone is inefficient ([S25](https://steamcommunity.com/app/2379780/discussions/0/695376132937158319/)).
  - Amplify: "1–2 chip jokers, 1–2 base-mult jokers, and 2–3 xmult jokers" ([S6](https://steamcommunity.com/app/2379780/discussions/0/4308327178395153352)).
  - HattedHead: "xMult, ~**x3 is usually enough**", plus chips (Square Joker or planets) and a scaling Joker ([S7](https://steamcommunity.com/app/2379780/discussions/0/840628406751272258/)).
  - srn347: a Purple loss at Violet Vessel came from having **no +chips joker** ([S27](https://steamcommunity.com/app/2379780/discussions/0/4356743780116244183)).
  - Dissent [S]: OrangE says Gold can be won with planet levels plus Glass/Steel cards, or chips-only on Plasma ([S7](https://steamcommunity.com/app/2379780/discussions/0/840628406751272258/)). mangonaise won C++ runs with **1–3 Jokers**, scoring from planets, enhancements and seals ([S1](https://steamcommunity.com/app/2379780/discussions/0/604143165271744486)).
- **[C] Put xMult Jokers on the right.** Jokers score left to right, so +Mult should come before xMult (malogoss, [S25](https://steamcommunity.com/app/2379780/discussions/0/695376132937158319/); dmeister and Monoxide, [S31](https://steamcommunity.com/app/2379780/discussions/0/4364626348105356076); WitchPHD, [link](https://witchphd.substack.com/p/balala)).

### 3.2 xMult deadline
- **[C] At least one xMult by Ante 4–5; two by Ante 6.**
  - "A run with zero XMult jokers by the end of Ante 5 almost never catches up at Purple and above." Checklist: by Ante 3, main hand chosen plus a scaler; Ante 4–5, main hand level 3+ and at least 1 xMult; Ante 6–8, 2 xMult, or 1 xMult plus a high-level hand ([dood stakes guide](https://dood.gg/en/balatro/guides/stakes-guide/)).
  - "X Mult should be online by Ante 4-5"; "Ante 4-6: get 2-3 X Mult jokers running, preferring ones with simple conditions" ([BalatroHQ](https://balatrohq.com/guides/gold-stake-guide/)).
  - "Antes 3–4: seek xMult… most jokers lose power here" (QuantuuM, [S7](https://steamcommunity.com/app/2379780/discussions/0/840628406751272258/)).
  - On Plasma, pivot from chips to mult around Ante 3–5 (revlayle and RazzberryMocha, [S11](https://steamcommunity.com/app/2379780/discussions/0/596263244409116960)).
- **xMult sources with simple conditions** [W] ([Jokers](https://balatrowiki.org/w/Jokers)):
  - Cavendish ×3 (Common).
  - The Duo ×2 (Pair), Trio ×3, Family ×4, Order ×3, Tribe ×2 (all Rare).
  - Card Sharp ×3 if the hand was already played this round.
  - Photograph ×2 on the first face card.
  - Baron ×1.5 per King held.
  - Blackboard ×3.
  - Acrobat ×3 on the final hand.
  - Steel Joker ×0.2 per Steel card.
  - Ramen ×2, minus ×0.01 per discarded card.
  - Joker Stencil.
  - Hand-type xMult Jokers work automatically if you play that hand: "Seeing Double gives an easy 2x boost when you go for pairs" (RazzberryMocha, [S3](https://steamcommunity.com/app/2379780/discussions/0/596264096371887282)).
- **Mobalytics "for clearing Gold Stake" tier list** [snippet] ([link](https://mobalytics.gg/blog/tier-lists/best-balatro-jokers/)): S+ Blueprint, Brainstorm, Triboulet. S Vampire, Cavendish, The Duo, The Trio, The Family, Spare Trousers, Canio, Campfire.

### 3.3 Choosing one main hand
- **[M] Antes 1–2: use 5-card hands (Flush or Straight) to one-shot. Then commit to Pair, Two Pair or High Card by about Ante 3–5.**
  - "Flushes are usually best to chase in 5-card hands (4-card flush: 9 outs vs. 8 for straights)… Antes 5–6: **move off 5-card hands** by thinning or changing the deck, because relying on luck for 5-card hands is a common failure point" (QuantuuM, [S7](https://steamcommunity.com/app/2379780/discussions/0/840628406751272258/)).
  - "Move away from Flushes after Ante 1, unless you find Jokers that greatly boost Flush play" (QuantuuM, [S8](https://steamcommunity.com/app/2379780/discussions/0/764059330564645976/)). "Avoid Flushes, except early game, where you should always play some" (malogoss, same thread).
  - "Past blue stake, **5 card hands start to collapse**" (malogoss, [S14](https://steamcommunity.com/app/2379780/discussions/0/4293691486113242157/?ctp=4)) [pre-1.0.1].
  - "Every gold stake run is a pair build, until it isn't" (gold-stake saying quoted by revlayle, [S25](https://steamcommunity.com/app/2379780/discussions/0/695376132937158319/)).
  - "With the blue deck at Blue stake or higher, learn to win with Pair and High Card" (malogoss, [S25](https://steamcommunity.com/app/2379780/discussions/0/695376132937158319/)). "Blue Deck is the best deck for a High Card/Pair strategy" (RazzberryMocha, [S3](https://steamcommunity.com/app/2379780/discussions/0/596264096371887282)). "High card and two pair are the easiest to win with" (YoruHawk, [S4](https://steamcommunity.com/app/2379780/discussions/0/4356744017103053782)).
  - "Only build toward a hand type you can reliably make. If you can't draw a straight every round, you don't have a straight build" (srn347, [S25](https://steamcommunity.com/app/2379780/discussions/0/695376132937158319/)). "Don't commit to flushes or full houses unless you have many suit or rank changers" (srn347, [S27](https://steamcommunity.com/app/2379780/discussions/0/4356743780116244183)).
  - A forum post says a Balatro University video called pairs "more consistent than flushes, especially at higher stakes with fewer discards and less money" [snippet, second-hand].
- **[D] Dissent on hand choice**
  - malogoss (Aug 2024): "Recommends sticking with **Flush the whole game**… wins often but not always". He also says High Card is "nearly impossible to run by Ante 2 on Purple Stake" ([S12](https://steamcommunity.com/app/2379780/discussions/0/6832609818929725471)).
  - mangonaise: "Use **Pairs and Straights over High Card**… Straights scale well with planets, Pairs work with held-in-hand effects (blue seals, steel, gold cards)" ([S1](https://steamcommunity.com/app/2379780/discussions/0/604143165271744486)).
  - WitchPHD favors Flush and Two Pair; pick one hand "often by ante 2" ([link](https://witchphd.substack.com/p/balala)).
  - Checkered deck is the exception, where flushes stay viable ([Mancunion](https://mancunion.com/2025/09/01/a-guide-to-gold-stake-balatro/)).
  - **Synthesis:** the default is Pair-family or High Card. Use Flush when the deck or Jokers support it (Checkered, Smeared, suit-changers, Tribe). Avoid Straights and Full House unless there are enablers (Four Fingers, Shortcut, Runner/Order).
- **[S] Keep options open.** "Good players keep as many viable options open as possible… some winning runs don't settle on a direction until Ante 4–6" (RazzberryMocha, [S19](https://steamcommunity.com/app/2379780/discussions/0/600772276758022609/)).
- **Hand base values** [W] ([Poker Hands](https://balatrowiki.org/w/Poker_Hands)): base chips × mult, then chips/mult added per level.

  | Hand | Base | Per level |
  |---|---|---|
  | High Card | 5×1 | +10 / +1 |
  | Pair | 10×2 | +15 / +1 |
  | Two Pair | 20×2 | +20 / +1 |
  | Three of a Kind | 30×3 | +20 / +2 |
  | Straight | 30×4 | +30 / +3 |
  | Flush | 35×4 | +15 / +2 |
  | Full House | 40×4 | +25 / +2 |
  | Four of a Kind | 60×7 | +30 / +3 |

### 3.4 Hand leveling
- **[M] Feed one hand with planets; Telescope is valued highly.**
  - "Pick your main hand early and funnel its Planet cards into it" ([dood stakes guide](https://dood.gg/en/balatro/guides/stakes-guide/)).
  - WitchPHD takes Telescope "almost every time" ([link](https://witchphd.substack.com/p/balala)).
  - malogoss rates Nebula among the best decks because "the free Telescope matters even more at high stakes" ([S21](https://steamcommunity.com/app/2379780/discussions/0/4357869219920827290)).
  - kone (Nebula Gold): use Telescope fully, plus a scaler and an economy Joker, then Celestial packs, then add xMult over time ([S9](https://steamcommunity.com/app/2379780/discussions/0/4693406471885516172)).
- **[M] Blue Seals are strong.** "Blue seals are very strong" (malogoss, [S25](https://steamcommunity.com/app/2379780/discussions/0/695376132937158319/)). Planet builds are viable with the 1.0.1 Blue Seal buff (cct, [S13](https://steamcommunity.com/app/2379780/discussions/0/4334231676647966765)). In 1.0.1 a Blue Seal held at end of round creates the Planet **for the final hand played** [W] ([Seals](https://balatrowiki.org/w/Seals)).
- **Observatory:** ×1.5 Mult per Planet held for its hand [W]. Rated S tier ([BalatroHQ vouchers](https://balatrohq.com/vouchers/)). WitchPHD: strong because it applies at the end of scoring.
- **Constellation:** "A strong joker like Constellation after the first blind is usually worth committing to" (RazzberryMocha, [S2](https://steamcommunity.com/app/2379780/discussions/0/596263931969820235)).

### 3.5 Scaling Jokers: take them early
- **[C] Start scalers in Antes 1–3. Don't start a new one after about Ante 4.**
  - "Scaling Jokers should be the top early priority, since **at ante 5 it's usually too late** for most of them" (malogoss, [S26](https://steamcommunity.com/app/2379780/discussions/0/4424310458751168875)).
  - "Don't start a growing joker after Ante 4" (Otakuya, [S15](https://steamcommunity.com/app/2379780/discussions/0/4346606879517114465/)) [pre-1.0.1].
  - "Don't skip scaling jokers such as Red Card, Runner, and Campfire" (malogoss, [S25](https://steamcommunity.com/app/2379780/discussions/0/695376132937158319/)).
  - "Jokers that scale with hands played are excellent: **Square Joker, Green Joker, and Ride the Bus**" (RazzberryMocha, [S3](https://steamcommunity.com/app/2379780/discussions/0/596264096371887282)).
  - Green stake and up: Green Joker, Square, Spare Trousers from Ante 1–2 ([dood stakes guide](https://dood.gg/en/balatro/guides/stakes-guide/)).
  - A Gold winner's lineup: Flash Card +72, Supernova +41, Square 176 chips, Pair level 9, **Hologram ×4.5** (HattedHead, [S7](https://steamcommunity.com/app/2379780/discussions/0/840628406751272258/)).
  - Plasma Purple win: Green Joker bought in the first shop was the "early MVP", plus Hologram for xMult (malogoss, [S11](https://steamcommunity.com/app/2379780/discussions/0/596263244409116960)).
- **[D] Dissent on scalers**
  - Black-deck guide: "Avoid scaling Jokers like Ride the Bus… early on, since they are slow to pay off" ([G1](https://steamcommunity.com/sharedfiles/filedetails/?id=3535175222)). The reason is that Black deck has one fewer hand.
  - WitchPHD avoids Obelisk, Green Joker and Ramen, which "punish resource use" ([link](https://witchphd.substack.com/p/balala)).
  - Mancunion: avoid hand-scaling Jokers on Black and Green decks ([link](https://mancunion.com/2025/09/01/a-guide-to-gold-stake-balatro/)).
- **Scaler numbers** [W] ([Jokers](https://balatrowiki.org/w/Jokers)):
  - Green Joker: +1 Mult per hand, -1 per discard.
  - Ride the Bus: +1 Mult per consecutive hand without a scoring face card.
  - Square Joker: +4 Chips per 4-card hand.
  - Runner: +15 Chips per Straight.
  - Spare Trousers: +2 Mult per Two Pair.
  - Hologram: ×0.25 per card added to the deck.
  - Lucky Cat: ×0.25 per Lucky trigger.
  - Constellation: ×0.1 per Planet used.
  - Campfire: ×0.25 per card sold, resets after a boss.
  - Obelisk: ×0.2 per consecutive hand that isn't your most played.
  - Vampire: ×0.1 per enhanced card scored (removes the enhancement).
  - Hit the Road: ×0.5 per Jack discarded this round.
  - Madness: ×0.5 per Small/Big blind, destroys a Joker.
  - Throwback: ×0.25 per skip.
  - Flash Card: +2 Mult per reroll.
  - Red Card: +3 Mult per skipped pack.
- **Madness at Black and above:** Eternal Jokers can't be destroyed by Madness, so Eternals become a positive. malogoss won 3 Gold runs with it (doingwork and malogoss, [S22](https://steamcommunity.com/app/2379780/discussions/0/828204634466163265)).

### 3.6 Retriggers, enhancements and deck manipulation
- **[M] Hanging Chad.** In 1.0.1 it retriggers the first card **twice** [W] ([VGC](https://www.videogameschronicle.com/news/balatros-first-major-update-tweaks-difficulty-adds-new-joker-types/)). "Appeared in most builds… retriggers Lucky cards for cash and Glass cards for safety against Violet Vessel" (mangonaise, [S1](https://steamcommunity.com/app/2379780/discussions/0/604143165271744486)). "Maybe the best joker for Gold Stake ante 8 if Cavendish didn't exist" (RazzberryMocha, same thread). Photograph + Hanging Chad gives at least ×8 ([Mancunion](https://mancunion.com/2025/09/01/a-guide-to-gold-stake-balatro/)).
- **[M] Glass and Steel cards for Ante 8.** "Build enough Glass/Steel cards and keep the deck small enough to draw them" to beat VV (mangonaise, [S1](https://steamcommunity.com/app/2379780/discussions/0/604143165271744486)). Glass with Red Seal plus a retrigger Joker (Clockwise, [S25](https://steamcommunity.com/app/2379780/discussions/0/695376132937158319/)).
  - Glass = ×2, 1 in 4 breaks. Steel = ×1.5 while held [W] ([Enhancements](https://balatrowiki.org/w/Enhancements)).
- **[M] Deck thinning and fixing.** Use Hanged Man or Immolate to thin (kone, [S20](https://steamcommunity.com/app/2379780/discussions/0/7252559325161419962)). Keep Death, Hanged Man or a suit-changer for Cerulean Bell ([S16](https://steamcommunity.com/app/2379780/discussions/0/4346606879520764406/)). Keep tarots for boss fights: "a Glass card can change a fight, a Moon can create a flush" (malogoss, [S3](https://steamcommunity.com/app/2379780/discussions/0/596264096371887282)).
- **[S] Wheel of Fortune is not worth buying.** 75% nothing; 12.5% Foil, 8.75% Holo, 3.75% Polychrome ([Mancunion](https://mancunion.com/2025/09/01/a-guide-to-gold-stake-balatro/)).
- **[S] Baron + Mime** is weaker at Orange than in Endless White (malogoss, [S4](https://steamcommunity.com/app/2379780/discussions/0/4356744017103053782)).

---

## 4. Economy at high stakes

### 4.1 Interest mechanics [W]
Source: [Interest](https://balatrowiki.org/w/Interest)
- $1 per $5 held at end of round, **capped at $5** (so $25 or more).
- Seed Money raises the cap to $10 ($50+). Money Tree raises it to $20 ($100+). To the Moon adds +$1 per $5.
- Golden Joker and Rocket pay **after** interest is counted. Gold cards and Reserved Parking count toward it.
- Green Deck earns no interest. WitchPHD: "Seed Money has no effect [on Green Deck], please stop snap buying them" ([link](https://witchphd.substack.com/p/balala)).
- **[derived] Gold-stake income per ante** (cap interest, win each blind in 1 hand so 3 unused hands): Small 0+3+5 = $8; Big 4+3+5 = $12; Boss 5+3+5 = $13. **About $33 per ante at best.** One rental costs $9 per ante, about 27% of that.

### 4.2 The $25 rule and when to break it
- **[C] Hold $25 between shops once your survival Jokers are bought.** Sources: malogoss ([S18](https://steamcommunity.com/app/2379780/discussions/0/4756452715167149899)), Mancunion, dood, Addison ($15–20 floor), YoruHawk ([S4](https://steamcommunity.com/app/2379780/discussions/0/4356744017103053782)), dmeister and Monoxide ([S31](https://steamcommunity.com/app/2379780/discussions/0/4364626348105356076)), mangonaise ("economy is the most important mechanic", [S1](https://steamcommunity.com/app/2379780/discussions/0/604143165271744486)).
- **[C] Break the cap when a blind is at risk.**
  - "When a blind threatens you, spending below interest is worth it. Losing your economy to find a joker or tarot that saves the run beats losing the run" (RazzberryMocha, [S3](https://steamcommunity.com/app/2379780/discussions/0/596264096371887282)).
  - "Losing a blind narrowly can come from staying above interest instead of rerolling or taking an eternal joker"; against The Needle or The Water, "spend all your money on a good Tarot" (RazzberryMocha, [S2](https://steamcommunity.com/app/2379780/discussions/0/596263931969820235)).
  - "A clean early Joker can be worth giving up some interest" (malogoss, [S8](https://steamcommunity.com/app/2379780/discussions/0/764059330564645976/)).
  - "Don't over-save money at the expense of score" in Antes 5–6 (QuantuuM, [S7](https://steamcommunity.com/app/2379780/discussions/0/840628406751272258/)).
- **[S] Late game.** Sell economy and bridge Jokers for more multipliers in Antes 7–8 ([BalatroHQ](https://balatrohq.com/guides/gold-stake-guide/)). Being greedy in the final shop lost one run by **2%** of the Ante-8 total, by skipping a 2-joker buy to wait for a 3-joker buy (malogoss, [S2](https://steamcommunity.com/app/2379780/discussions/0/596263931969820235)).
- **[M] Money Jokers are especially strong at Gold.** "GREED hard for money early" (Whatsapp Warrior, [S16](https://steamcommunity.com/app/2379780/discussions/0/4346606879520764406/)) [pre-1.0.1]. Prefer guaranteed-money Jokers like Golden Joker and Cloud 9 (YoruHawk, [S4](https://steamcommunity.com/app/2379780/discussions/0/4356744017103053782)). Rocket is a late-game exception to dumping economy Jokers; it reaches about $9 per round after 4 antes (Addison, [link](https://addisonkindrick.substack.com/p/10-balatro-tier-list-addendum)).
  - Dissent: Bootstraps is "often a problem on high stakes" because it needs wealth; Ceremonial Dagger also needs you to be rich (malogoss, [S28](https://steamcommunity.com/app/2379780/discussions/0/4308327413811541697)).

### 4.3 Rentals (Gold)
- **Mechanics** [W] ([Stickers](https://balatrowiki.org/w/Stickers), [Money](https://balatrowiki.org/w/Money)):
  - Buy for $1, sell for $1.
  - -$3 at end of round, charged **before interest**: "One rental means holding **$28** for interest, two means **$31**" (RazzberryMocha, [S2](https://steamcommunity.com/app/2379780/discussions/0/596263931969820235)). The Black-deck guide agrees fees come before interest ([G1](https://steamcommunity.com/sharedfiles/filedetails/?id=3535175222)).
  - Rental can push money below $0.
- **[M] Avoid rentals until the economy is established; take them for top-value Jokers.**
  - "Avoid rental jokers until your economy is established" (RazzberryMocha, [S2](https://steamcommunity.com/app/2379780/discussions/0/596263931969820235)). "Delay rental jokers" ([Mancunion](https://mancunion.com/2025/09/01/a-guide-to-gold-stake-balatro/)).
  - "An **excellent Rental Joker is better than a clean, mediocre one**. Raise your interest threshold from $25 to $28" (malogoss, [S8](https://steamcommunity.com/app/2379780/discussions/0/764059330564645976/)).
  - "Does this joker do more than $3 of work per round? An **XMult pillar is an automatic yes**. A mediocre additive joker should wait for a clean copy" ([dood stakes guide](https://dood.gg/en/balatro/guides/stakes-guide/)).
  - "You **cannot** support more than one rental on base economy" (Draco18s, [S13](https://steamcommunity.com/app/2379780/discussions/0/4334231676647966765)).
  - "Rent only when you're near a win or your income can cover the drain" ([BalatroHQ](https://balatrohq.com/guides/gold-stake-guide/)). "Avoid rental jokers before Ante 6" (Switchblade, low reliability).
- **[M] The $0 rental trick.** Rentals whose effect fires on blind selection, during the blind, or in the shop can be bought and **sold before the round ends for net $0**. Examples: Cartomancer, Mail-In Rebate (cct, [S13](https://steamcommunity.com/app/2379780/discussions/0/4334231676647966765); dood: "selling an unneeded Rental before the round ends saves one more $3 payment"). Certificate of Authenticity can add Blue Seals cheaply and be sold later (Adam Heron, [S8](https://steamcommunity.com/app/2379780/discussions/0/764059330564645976/)).
  - **[derived] Caveat:** the round ends the moment the blind is beaten. So a scoring Joker you need in the winning hand will be charged. The trick only works for Jokers whose value is gone before the final hand.
- **[S] Eternal + Rental is the worst combination.** It "can never be cancelled… charging $3 forever. Always check the sticker line" ([dood stakes guide](https://dood.gg/en/balatro/guides/stakes-guide/)). About 9% of Jokers at Gold (0.3 × 0.3) [derived].

### 4.4 Eternal (Black and above)
- **[M] Eternal is fine for scalers and xMult you'd keep anyway, and a trap for temporary fixes.**
  - "For a scaler or an XMult pillar you'd never sell anyway, the downside is effectively zero… temporary early-game patches… will still be squatting in one of your five slots at Ante 7" ([dood stakes guide](https://dood.gg/en/balatro/guides/stakes-guide/)).
  - Take Eternal only on a Joker you'll keep all run ([BalatroHQ](https://balatrohq.com/guides/gold-stake-guide/)).
  - Dissent [S]: take even a bad Eternal (Greedy Joker) to survive (RazzberryMocha, [S3](https://steamcommunity.com/app/2379780/discussions/0/596264096371887282)).
- **Eternal interactions** [W/M]:
  - Eternal Jokers are immune to Hex, Ankh and Madness destruction, so Ghost-deck Hex can be used safely around them (Adam Heron, [S8](https://steamcommunity.com/app/2379780/discussions/0/764059330564645976/); [Eternal](https://balatrowiki.org/w/Eternal)).
  - Eternal Egg is worthless. Eternal Jokers can't feed Campfire or Swashbuckler ([dood stakes guide](https://dood.gg/en/balatro/guides/stakes-guide/)).
  - On Amber Acorn, Eternal Jokers show greyed price tags, which helps find them ([Amber Acorn](https://balatrowiki.org/w/Amber_Acorn)).

### 4.5 Perishable (Orange and above)
- **[W] 5 rounds, then debuffed.** The Joker stays in its slot and can still be sold. The 18 positive scalers listed in 1.1 can never be Perishable.
- **[M] Perishable is acceptable as a bridge, or when bought within 5 rounds of the Ante-8 boss.**
  - "Acceptable when within five rounds of the ante 8 boss" ([Mancunion](https://mancunion.com/2025/09/01/a-guide-to-gold-stake-balatro/)).
  - "Use it only as a short-term bridge and replace it before round 5 ends" ([BalatroHQ](https://balatrohq.com/guides/gold-stake-guide/)).
  - "Buy instant-value Perishables (Fibonacci, Stuntman, Cavendish)… the most expensive mistake on Orange is forgetting to sell a debuffed Perishable" ([dood stakes guide](https://dood.gg/en/balatro/guides/stakes-guide/)).
  - Perishables are temporary power to sell later (Aw3som3, [S10](https://steamcommunity.com/app/2379780/discussions/0/4369129313606908896/)).
  - **dood also wrongly lists Green Joker and Hologram as "pass if perishable"**: the wiki says both are perishable-incompatible.
- **[derived] Perishable-safe window.** Buying in the shop after the **Ante-7 Small Blind** covers A7 Big, A7 Boss, A8 Small, A8 Big and the A8 Boss: exactly 5 rounds.

### 4.6 Blue stake's "-1 discard"
- **[W]** 3 → 2 discards per round. It applies at every stake above Blue ([S25](https://steamcommunity.com/app/2379780/discussions/0/695376132937158319/), [Discards](https://balatrowiki.org/w/Discards)).
- **[M] Effects and responses:**
  - It "visibly drops the completion rate of assembly hands like Flushes and Four of a Kind".
  - Wasteful jumps up the priority list; Red Deck nearly cancels the stake.
  - Build around Pair, Two Pair or High Card.
  - "With a truly dead hand, flush it by playing a weak hand instead of discarding" — this costs $1 of unused-hand money ([dood stakes guide](https://dood.gg/en/balatro/guides/stakes-guide/)).
  - "Yorick is hard to run under the -1 discard" (malogoss, [S28](https://steamcommunity.com/app/2379780/discussions/0/4308327413811541697)).

---

## 5. Boss Blind preparation (high stakes)

**General rules**
- **[C] Look ahead.** "Check the next boss as soon as you beat one, and use all three shops to prepare for it" (malogoss, [S3](https://steamcommunity.com/app/2379780/discussions/0/596264096371887282), [S25](https://steamcommunity.com/app/2379780/discussions/0/695376132937158319/)). Also HattedHead ([S7](https://steamcommunity.com/app/2379780/discussions/0/840628406751272258/)) and Mancunion.
  - In 1.0.1 the next blinds and tags are visible right after beating the boss [W] ([VGC](https://www.videogameschronicle.com/news/balatros-first-major-update-tweaks-difficulty-adds-new-joker-types/)).
- **[W] Bosses don't repeat** until every eligible boss has appeared ([Blinds and Antes](https://balatrowiki.org/w/Blinds_and_Antes)). "A build that's weak to an already-faced boss is fine" (malogoss, [S3](https://steamcommunity.com/app/2379780/discussions/0/596264096371887282)).
  - Ante 1 can only roll the 8 "any-ante" bosses: Hook, Club, Psychic, Goad, Window, Manacle, Pillar, Head.
  - Minimum antes: Plant 4, Eye 3, Tooth 3, Serpent 5, Ox 6. Most others 2.
- **[M] Bosses to plan for.** "Wall/Vessel, Eye, Mouth (if playing 5oak/straights), Plant, Needle, and Heart" (HattedHead, [S7](https://steamcommunity.com/app/2379780/discussions/0/840628406751272258/)).
- **[M] Universal counters:**
  - Director's Cut ($10, one reroll per ante) or Retcon ($10, unlimited) [W].
  - Boss Tag (free reroll).
  - Luchador (sell to disable). Chicot (disables all bosses).
  - Mr. Bones (survive at ≥25% of the requirement).
  - "Getting the Director's Cut/Retcon is usually the best way to deal with problematic Bosses" (AzrealPlays2, [S4](https://steamcommunity.com/app/2379780/discussions/0/4356744017103053782)). "Mr. Bones or Luchador can save you from a losing position" (malogoss, [S3](https://steamcommunity.com/app/2379780/discussions/0/596264096371887282)).
- **[S] High Card or Pair makes bosses easy.** "If jokers let you win with High Card or Pair, bosses become trivial", except The Needle, which Burglar counters (malogoss, [S3](https://steamcommunity.com/app/2379780/discussions/0/596264096371887282)).

| Boss | Effect / minimum ante [W] | Concrete counters (sources) |
|---|---|---|
| **The Wall** | 4× base, min ante 2. Gold: A4 36k, A5 100k, A6 240k, A7 440k | Reroll if 4 × your average hand is below the requirement [derived]. Luchador or Chicot return it to 2×. Loyalty Card set up earlier in the ante; Campfire; Mr. Bones (≥25%, "effectively X4 for 1 round"); Glass cards; The Star to make a Flush House one-shot early ([The Wall](https://balatrowiki.org/w/The_Wall)). "No effect debuff — a pure output check; reroll it if you can't" ([dood ante](https://dood.gg/en/balatro/guides/ante-guide/)). |
| **Violet Vessel** | 6× base at Ante 8. **Gold 1.2M; Plasma Gold 2.4M** | Plan ≥300k per hand over 4 hands [derived]; about 500k per hand is "safest" (malogoss, [S26](https://steamcommunity.com/app/2379780/discussions/0/4424310458751168875)). Outs: Director's Cut, Luchador, Mr. Bones, Chicot, many xMult, Blueprint/Brainstorm, Burglar (same). Glass/Steel deck plus Hanging Chad (mangonaise, [S1](https://steamcommunity.com/app/2379780/discussions/0/604143165271744486)). Loyalty Card, Campfire, Turtle Bean ([Violet Vessel](https://balatrowiki.org/w/Violet_Vessel)). Hieroglyph at Ante 8 sends you back to a lower showdown requirement (Ronald Brain, [S23](https://steamcommunity.com/app/2379780/discussions/0/4346606879510867624/)). |
| **The Needle** | 1 hand only; 1× base; min ante 2 | Need ≥1× base in a single hand. **Burglar** (+3 hands, strong counter), Luchador, Chicot. Keep **Justice** to make Glass for the one hand. Raise hand size or discards to dig for the best hand. Acrobat and Dusk boost the final hand ([The Needle](https://balatrowiki.org/w/The_Needle)). "Spend all your money on a good Tarot" (RazzberryMocha, [S2](https://steamcommunity.com/app/2379780/discussions/0/596263931969820235)). "A Pair build with a Burglar is nearly invincible" (malogoss, [S3](https://steamcommunity.com/app/2379780/discussions/0/596264096371887282)). |
| **The Psychic** | Must play exactly 5 cards; any ante | Pad Pair or High Card plays with junk cards to reach 5. **Splash** helps. Half Joker is useless here; Square Joker can't scale. Don't let hand size fall to 4 or below (Stuntman, Ectoplasm, Ouija) ([The Psychic](https://balatrowiki.org/w/The_Psychic)). Fatal to the Ghost-deck Ectoplasm high-card plan ([G2](https://steamcommunity.com/sharedfiles/filedetails/?id=3172577970)). |
| **The Plant** | Face cards debuffed; min ante 4 | Face builds (Photograph, Smiley, Baron, Triboulet) have no counter except avoiding it: Director's Cut, Retcon, Boss Tag, Luchador, Chicot. **Pareidolia makes every card debuffed.** Ride the Bus actually benefits ([The Plant](https://balatrowiki.org/w/The_Plant)). |
| **The Eye** | No repeated hand type this round; min ante 3 | Card Sharp does nothing. Single-hand builds should save **Justice or Chariot** to win in one hand. Obelisk benefits. Spread planet levels across 2–3 hand types ([The Eye](https://balatrowiki.org/w/The_Eye); [dood ante](https://dood.gg/en/balatro/guides/ante-guide/)). "Pray for Card Sharp, play pairs, and hope you don't run into The Eye" (Lilium, [S25](https://steamcommunity.com/app/2379780/discussions/0/695376132937158319/)). |
| **The Mouth** | Only the first hand type played can score; min ante 2 | **Open with your main hand.** Never open with High Card unless it clears the blind. Keep Death, Strength or Sun to shape the hand. Burglar can be sold ([The Mouth](https://balatrowiki.org/w/The_Mouth)). |
| **The House** | First hand drawn face down; min ante 2 | Smaller hand size is better. Joker-driven builds do fine. Sort by rank or suit to infer cards. The Empress or Ouija briefly reveals them. You can play face-down cards to see them, at the cost of a hand ([The House](https://balatrowiki.org/w/The_House)). Probe with discards first ([dood ante](https://dood.gg/en/balatro/guides/ante-guide/)). |
| **The Fish** | Cards drawn after each hand are face down; min ante 2 | **Discard face-down cards**: the replacements arrive face up. Sorting helps ([The Fish](https://balatrowiki.org/w/The_Fish)). Ideally win with the visible opening hand ([dood ante](https://dood.gg/en/balatro/guides/ante-guide/)). |
| **The Ox** | Ante 6+. Playing your most-played hand sets money to $0 | Spend your cash first, or win with a different hand ([dood ante](https://dood.gg/en/balatro/guides/ante-guide/)). Obelisk makes it irrelevant; Matador pays $8 ([The Ox](https://balatrowiki.org/w/The_Ox)). Very costly when holding $25+ at Ante 6+ [derived]. |
| **Cerulean Bell** (A8) | Forces 1 card to always be selected | **Hanged Man** destroys the forced card. Pair-type hands handle it better ([Cerulean Bell](https://balatrowiki.org/w/Cerulean_Bell)). Ended two runs at Ante 8 for one player; keep Death or Hanged Man ([S16](https://steamcommunity.com/app/2379780/discussions/0/4346606879520764406/)). |
| **Verdant Leaf** (A8) | All cards debuffed until 1 Joker is sold | Keep a **sacrificial non-scoring Joker** (economy, Negative, or a spent utility like Burglar or Marble) into Ante 8 ([Verdant Leaf](https://balatrowiki.org/w/Verdant_Leaf); [dood ante](https://dood.gg/en/balatro/guides/ante-guide/)). |
| **Crimson Heart** (A8) | One random Joker disabled each hand, never the same twice in a row | Build redundancy; more slots or Negatives help. A throwaway hand moves the debuff. Chicot disables it; Luchador only works if it isn't the disabled one ([Crimson Heart](https://balatrowiki.org/w/Crimson_Heart)). |
| **Amber Acorn** (A8) | Flips and shuffles Jokers | Lower game speed and track triggers. Shapes identify Square, Half, Wee and Photograph. Holding a Joker during the shuffle keeps its position. Chicot only works after the shuffle ([Amber Acorn](https://balatrowiki.org/w/Amber_Acorn)). Order-dependent setups like Blueprint suffer most ([dood ante](https://dood.gg/en/balatro/guides/ante-guide/)). |

---

## 6. Decks at Gold stake

**Hardest: Black — strong consensus [C]**
- "Black deck is the toughest, at all stake levels" (malogoss, [S21](https://steamcommunity.com/app/2379780/discussions/0/4357869219920827290)).
- "Black deck was obviously awful. That -1 hand really hurts" (Ravenous Roxy, 13.5 decks on Gold, same thread). BaconX agrees (same thread).
- Hardest deck for Mancunion's author: "about 30 tries" ([link](https://mancunion.com/2025/09/01/a-guide-to-gold-stake-balatro/)).
- "Harder than he expected" (WitchPHD, [link](https://witchphd.substack.com/p/balala)).
- Hypixel ranking, hardest to easiest: **Black, Painted, Plasma, Nebula, Anaglyph, Abandoned, Erratic, Green, Zodiac, Ghost, Magic, Red, Blue, Checkered, Yellow**. "Everything below Nebula is mostly similar except the easiest 3" ([hypixel](https://hypixel.net/threads/all-decks-gold-stake-balatro.6086776/)) [snippet].

**Easiest [M]: Yellow, Checkered, Green, Blue; also Ghost and Abandoned by some**
- Yellow is "easy" (WitchPHD); easiest for Ronald Brain ([Steam](https://steamcommunity.com/app/2379780/discussions/0/4346606879521298087)); last (easiest) on the hypixel list.
- Checkered is "basically a free pass through Ante 1" (Morthgarrow, [S5](https://steamcommunity.com/app/2379780/discussions/0/4294818016870729305)) [pre-1.0.1]; "one of the easiest" (WitchPHD); a favorite of Roxy ([S21](https://steamcommunity.com/app/2379780/discussions/0/4357869219920827290)).
- Green is "probably the fastest and easiest deck" (WitchPHD); "relatively easy… early burst of money" (malogoss, [S5](https://steamcommunity.com/app/2379780/discussions/0/4294818016870729305)).
- Blue: "Consistency is key", used almost exclusively for C++ (mangonaise, [S1](https://steamcommunity.com/app/2379780/discussions/0/604143165271744486)).

**Contested [D]**
- **Plasma**
  - Easy: the Mancunion author's easiest deck; Hulana needed only 2 attempts ([S13](https://steamcommunity.com/app/2379780/discussions/0/4334231676647966765)).
  - Weak at Purple and above (malogoss, [S13](https://steamcommunity.com/app/2379780/discussions/0/4334231676647966765)). A "slog" (Roxy). "With plasma deck chips will not cut it on purple stake and higher" (RazzberryMocha, [S11](https://steamcommunity.com/app/2379780/discussions/0/596263244409116960)).
- **Nebula:** "among the best" (malogoss) vs "unexpected trouble" (WitchPHD) vs "lackluster with its single consumable slot" (OP, [S21](https://steamcommunity.com/app/2379780/discussions/0/4357869219920827290)).
- **Painted:** "huge stability but with only 4 joker slots it becomes tricky at high stake" (malogoss); "hardest" for Roxy; "top power" for DirtCheap ([S21](https://steamcommunity.com/app/2379780/discussions/0/4357869219920827290)).

**Deck-specific strategies at Gold** (mostly [S]; main sources [Mancunion](https://mancunion.com/2025/09/01/a-guide-to-gold-stake-balatro/) and [S21](https://steamcommunity.com/app/2379780/discussions/0/4357869219920827290))

- **Red** (+1 discard)
  - Nearly cancels Blue stake ([dood](https://dood.gg/en/balatro/guides/stakes-guide/)).
  - Can afford Full House, Straight and Flush; discard for the better hand.
  - Discard Jokers: Faceless, Mail-In Rebate, Trading Card, Burnt Joker, Castle (Mancunion).
  - A Red-deck Gold win: Flush plus Lucky cards for money (False Prophet, [S22](https://steamcommunity.com/app/2379780/discussions/0/828204634466163265)).
- **Blue** (+1 hand)
  - Pairs; hand-count scalers (Green Joker, Ride the Bus, Square, Runner, Supernova, Card Sharp) (Mancunion; RazzberryMocha, [S3](https://steamcommunity.com/app/2379780/discussions/0/596264096371887282)).
  - "Any scaling joker is very strong on the Blue Deck" (RazzberryMocha).
- **Yellow** (+$10): interest from turn 1 (+$2 in round 1) [W]. Early strength. Bull and Bootstraps (Mancunion).
- **Green** (no interest; $2 per unused hand, $1 per unused discard)
  - Beat rounds in **one hand**.
  - Good: Merry Andy, Drunkard, Burglar, Banner, Ramen, Vagabond.
  - **Never buy Seed Money, Money Tree or To the Moon** (Mancunion; WitchPHD). Avoid Green Joker, Castle, Mystic Summit, Dusk, Acrobat (Mancunion).
  - The +1 hand voucher (Grabber) helps a lot (malogoss, [S5](https://steamcommunity.com/app/2379780/discussions/0/4294818016870729305)).
- **Black** (+1 Joker slot, -1 hand)
  - Early economy Joker even if Eternal (Cloud 9, Golden, Rocket). Early flat mult (Half Joker, Popcorn).
  - **Grabber negates the drawback.** Avoid hand-scalers and rentals (Mancunion).
  - Use the 6th slot as a buffer for early economy or utility ([G1](https://steamcommunity.com/sharedfiles/filedetails/?id=3535175222)).
  - Burglar early (CJones, [S17](https://steamcommunity.com/app/2379780/discussions/0/604143633269036634)).
  - Joker Stencil is strongest here ([G2](https://steamcommunity.com/sharedfiles/filedetails/?id=3172577970)).
- **Magic** (Crystal Ball + 2 Fools): tarot generators and Purple Seals (Mancunion). About a $40 boost around Ante 3 if you survive (DirtCheap, [S21](https://steamcommunity.com/app/2379780/discussions/0/4357869219920827290)).
- **Nebula** (Telescope, -1 consumable slot)
  - An easily drawn hand such as Pair; Astronomer, Constellation, Supernova. Red Card and Obelisk are weak. Crystal Ball fixes the drawback (Mancunion).
  - Scaler plus economy Joker, then Celestial packs, then xMult; High Card or Pair; Gold cards and Blue Seals (kone, [S9](https://steamcommunity.com/app/2379780/discussions/0/4693406471885516172)).
  - Depends on affording Blue Seals and Death (DirtCheap).
- **Ghost** (Hex, Spectrals in shop)
  - "Hex the first good joker you find" (malogoss, [S2](https://steamcommunity.com/app/2379780/discussions/0/596263931969820235)).
  - Save Hex to test on different starting Jokers. Selling Hex gives $1. An early Ankh can make 2 Polychrome copies (QuantuuM, [S8](https://steamcommunity.com/app/2379780/discussions/0/764059330564645976/)).
  - Buy an early economy Joker that isn't Perishable or Rental (DirtCheap).
  - Eternal Jokers are immune to the Hex downside (Adam Heron, [S8](https://steamcommunity.com/app/2379780/discussions/0/764059330564645976/)).
  - "Probably the easiest deck to high-roll" (ENJOYMENT ENJOYER, [S27](https://steamcommunity.com/app/2379780/discussions/0/4356743780116244183)).
- **Abandoned** (no face cards)
  - Straights and Four of a Kind; early chips. Hack, Fibonacci, Odd Todd, Even Steven, Ride the Bus (Mancunion).
  - Smaller deck makes Straights easier (DirtCheap).
  - Weak early because no face cards means less score per hand (WitchPHD).
- **Checkered** (26 Spades, 26 Hearts)
  - Flush spam; Hearts Jokers (Lusty, Bloodstone with Oops! All 6s) or Spades Jokers (Wrathful, Arrowhead) (Mancunion).
  - Beat the first two bosses without Jokers, then build economy (DirtCheap).
  - Flush House and Flush Five are easier than Straight Flush (Goblin, [S5](https://steamcommunity.com/app/2379780/discussions/0/4294818016870729305)).
  - Put Steel cards in the suit you use less (Scroubignon, [S15](https://steamcommunity.com/app/2379780/discussions/0/4346606879517114465/)).
- **Zodiac** (Tarot Merchant, Planet Merchant, Overstock): hand-based setups and deck fixing. Fortune Teller, Vampire, Constellation, Driver's License, Astronomer, Campfire (Mancunion).
- **Painted** (+2 hand size, -1 Joker slot): enhancements and planets. Wee Joker, Spare Trousers, held-in-hand Jokers (Mime, Shoot the Moon, Reserved Parking), Stuntman. Ectoplasm is an acceptable trade (Mancunion).
- **Anaglyph** (Double Tag after each boss)
  - Hold tags until about Ante 5–6. Economy-type tags; Throwback (Mancunion).
  - Luck dependent (WitchPHD). Good economy (DirtCheap).
- **Plasma** (balance Chips and Mult; blinds ×2)
  - Chips early: Stuntman, Square, Bull, Bonus cards, Red Seals, Foil (malogoss, [S21](https://steamcommunity.com/app/2379780/discussions/0/4357869219920827290)).
  - **Pivot to Mult/xMult by Ante 3–5**; "the earlier the pivot, the easier" (malogoss, [S11](https://steamcommunity.com/app/2379780/discussions/0/596263244409116960)).
  - "Plasma: xmult is the most powerful thing you can be doing" (WitchPHD).
- **Erratic** (random ranks and suits)
  - Check the distribution and adapt; reset for a good start; economy early; no rentals early (Mancunion).
  - Reset until you see 9+ of one rank (Morthgarrow, [S5](https://steamcommunity.com/app/2379780/discussions/0/4294818016870729305)) [pre-1.0.1].
  - Weak early game (DirtCheap).

---

## 7. Why good players lose at Gold (post-mortems)

1. **No xMult or scaling online in time** [C]. Zero xMult by the end of Ante 5 rarely recovers ([dood](https://dood.gg/en/balatro/guides/stakes-guide/)). Scalers started at Ante 5 are too late (malogoss, [S26](https://steamcommunity.com/app/2379780/discussions/0/4424310458751168875)). A White-strength board stalls by Ante 6 on Gold ([BalatroHQ](https://balatrohq.com/guides/gold-stake-guide/)).
2. **Relying on 5-card hands with 2 discards** [M]. "A common failure point" in Antes 5–6 (QuantuuM, [S7](https://steamcommunity.com/app/2379780/discussions/0/840628406751272258/)). "5 card hands start to collapse" (malogoss, [S14](https://steamcommunity.com/app/2379780/discussions/0/4293691486113242157/?ctp=4)). A Flush build drew no flushes at Ante 6 (zxzc77, [S20](https://steamcommunity.com/app/2379780/discussions/0/7252559325161419962)).
3. **Unprepared for Violet Vessel or another showdown boss** [M].
   - VV is the ultimate check (mangonaise, [S1](https://steamcommunity.com/app/2379780/discussions/0/604143165271744486)).
   - Missing VV by about 2× with no +chips Joker (srn347, [S27](https://steamcommunity.com/app/2379780/discussions/0/4356743780116244183)).
   - Cerulean Bell ended 2 runs ([S16](https://steamcommunity.com/app/2379780/discussions/0/4346606879520764406/)).
   - A purple boss needing 1M on High Card (echoes37, [S15](https://steamcommunity.com/app/2379780/discussions/0/4346606879517114465/)).
4. **Holding interest instead of spending to survive** [S]. Narrow blind losses from "staying above interest instead of rerolling or taking an eternal joker". About 80% of Gold losses were self-inflicted (RazzberryMocha, [S2](https://steamcommunity.com/app/2379780/discussions/0/596263931969820235)).
5. **Greed in the final shop** [S]. Lost by 2% of the Ante-8 requirement (malogoss, [S2](https://steamcommunity.com/app/2379780/discussions/0/596263931969820235)).
6. **Weak early economy** [M]. "You need some kind of early eco or you get fried pretty quickly" (el pepe, [S7](https://steamcommunity.com/app/2379780/discussions/0/840628406751272258/)). "Lack of economy killed me" (discrider, [coin-return p4](https://forums.coin-return.org/threads/balatro-roguelike-poker-just-one-more-hand.782/page-4)).
7. **Sticker mismanagement** [M].
   - An Eternal temporary fix stuck in a slot at Ante 7.
   - A forgotten debuffed Perishable still taking a slot.
   - Two rentals (-$6 per round) cancelling interest.
   - Sources: [dood](https://dood.gg/en/balatro/guides/stakes-guide/), [BalatroHQ](https://balatrohq.com/guides/gold-stake-guide/).
8. **Skipping too often, or greedy skips** [M]. About two-thirds of 40 dead runs were lost at the Ante-1 Big Blind, after greedy skips, or to bosses ([S16](https://steamcommunity.com/app/2379780/discussions/0/4346606879520764406/)) [pre-1.0.1]. "Skipping too many blinds is a bad idea" (malogoss, [S12](https://steamcommunity.com/app/2379780/discussions/0/6832609818929725471)).
9. **Committing to a build a boss can hard-counter** [S]. Face build against The Plant, suit build against a suit boss (malogoss, [S3](https://steamcommunity.com/app/2379780/discussions/0/596264096371887282); zxzc77, [S20](https://steamcommunity.com/app/2379780/discussions/0/7252559325161419962)). Fix: keep "a second win condition against suit-lock bosses" by Ante 6 ([dood ante](https://dood.gg/en/balatro/guides/ante-guide/)).
10. **Pivoting too late, or never** [S]. "Some runs were lost by sticking with a plan too long" (Beakstore, [S31](https://steamcommunity.com/app/2379780/discussions/0/4364626348105356076)). Plasma players who don't pivot from chips to mult (several, [S11](https://steamcommunity.com/app/2379780/discussions/0/596263244409116960)).
11. **Only +Mult, or a missing scoring category** [M]. "Missing a category keeps totals low by Ante 8" (dmeister, [S20](https://steamcommunity.com/app/2379780/discussions/0/7252559325161419962)). "Focusing too heavily on mult jokers" (JmonDmon, [S27](https://steamcommunity.com/app/2379780/discussions/0/4356743780116244183)).

**Context on win rates** (self-reported, [S]):
- RazzberryMocha about 30–40% at Gold ([S19](https://steamcommunity.com/app/2379780/discussions/0/600772276758022609/)).
- malogoss describes a skill progression ending at "half your gold stake runs" won ([S17](https://steamcommunity.com/app/2379780/discussions/0/604143633269036634)). This is a general description, not a measured personal rate.
- 20/30+ Gold win streaks reportedly exist (kaibarnard, [S19](https://steamcommunity.com/app/2379780/discussions/0/600772276758022609/)).
- A 2024 tracker reported about 48% Purple, 33% Orange, 17.5% Gold [snippet, pre-1.0.1].
- Fewer than 10% of players have won a single Gold run (malogoss, [S2](https://steamcommunity.com/app/2379780/discussions/0/596263931969820235)).
- Purple is the biggest jump: "the biggest difficulty spike… a good 50 games" (sab0t, [S5](https://steamcommunity.com/app/2379780/discussions/0/4294818016870729305)); "the hardest stake to adjust to" (False Prophet, [S22](https://steamcommunity.com/app/2379780/discussions/0/828204634466163265)); malogoss ([S12](https://steamcommunity.com/app/2379780/discussions/0/6832609818929725471)).

---

## 8. Voucher priorities at high stakes

All vouchers cost $10. One new voucher appears per ante (after the boss), or via a Voucher Tag. An upgraded voucher appears only after its base voucher was bought in the same run [W] ([Vouchers](https://balatrowiki.org/w/Vouchers)).

| Voucher | Effect [W] | High-stake view |
|---|---|---|
| **Grabber / Nacho Tong** | +1 hand per round each | **[M] Top.** S tier ([BalatroHQ](https://balatrohq.com/vouchers/)). Economy vouchers are "extremely valuable… increase the remaining hand bonus" ([Addison](https://addisonkindrick.substack.com/p/10-balatro-tier-list-addendum)). Negates the Black-deck drawback (Mancunion). The author restarts runs to find it ([G2](https://steamcommunity.com/sharedfiles/filedetails/?id=3172577970)) [pre-1.0.1]. Most people "almost always take +1 Hand and +1 hand size" (sab0t, [S23](https://steamcommunity.com/app/2379780/discussions/0/4346606879510867624/)). |
| **Paint Brush / Palette** | +1 hand size each | **[M] Top.** S tier (BalatroHQ); sab0t above. Helps with The Needle ([wiki](https://balatrowiki.org/w/The_Needle)). |
| **Wasteful / Recyclomancy** | +1 discard each | **[M] High from Blue stake on.** "Cancels the modifier outright" ([dood](https://dood.gg/en/balatro/guides/stakes-guide/)). A tier (BalatroHQ). |
| **Telescope → Observatory** | Celestial packs always contain your main hand's Planet → ×1.5 per Planet held | **[M] High for planet builds.** WitchPHD takes Telescope almost always; malogoss values it highly; Observatory is S (BalatroHQ). Observatory is "hard to use" on Nebula (Mancunion). |
| **Overstock / Plus** | +1 shop slot | [M] A tier; see more Jokers per shop (Addison). |
| **Clearance Sale / Liquidation** | 25% / 50% off | [M] A tier; "value rises with every stake you climb" ([dood](https://dood.gg/en/balatro/guides/stakes-guide/)). |
| **Crystal Ball** | +1 consumable slot | [S] A tier; fixes Nebula (Mancunion). Lets you hold boss-counter tarots. |
| **Director's Cut / Retcon** | Reroll boss ($10) | [D] "Usually the best way to deal with problematic Bosses" (AzrealPlays2, [S4](https://steamcommunity.com/app/2379780/discussions/0/4356744017103053782)); "excellent insurance" ([dood ante](https://dood.gg/en/balatro/guides/ante-guide/)); vs C tier (BalatroHQ). Most valuable for face, suit or single-hand builds. |
| **Reroll Surplus / Glut** | Rerolls -$2 each | [M] B tier; rises with stake (dood); synergy with Flash Card (Addison). |
| **Hieroglyph / Petroglyph** | -1 ante; -1 hand / -1 discard | [D] **Situational.** "Absurdly powerful" (brickey.8, [S23](https://steamcommunity.com/app/2379780/discussions/0/4346606879510867624/)). The only early voucher worth it (Otakuya, [S15](https://steamcommunity.com/app/2379780/discussions/0/4346606879517114465/)) [pre-1.0.1]. Take "only when [you] need more time before a boss… with a strong scaling Joker like Madness or Obelisk" (RazzberryMocha, [S24](https://steamcommunity.com/app/2379780/discussions/0/604149771486109542)). "Robin Hood in reverse": it helps strong builds and does little for weak ones (Twelvefield, same). The scaling gain is a "micro optimisation" (Goblin, [S23](https://steamcommunity.com/app/2379780/discussions/0/4346606879510867624/)). Supernova math: buy it after the Ante-5 boss or later. Petroglyph is risky at Blue+ (MrTherandomguy42, [S24](https://steamcommunity.com/app/2379780/discussions/0/604149771486109542)). |
| **Seed Money / Money Tree** | Interest cap $10 / $20 | [D] B tier. Needed for reroll budget (Whatsapp Warrior, [S16](https://steamcommunity.com/app/2379780/discussions/0/4346606879520764406/), pre-1.0.1). Useless on Green deck. Only worth it if you can actually hold $50+ [derived]. |
| **Antimatter** | +1 Joker slot | S tier when it appears; needs a meta unlock (Blank redeemed 10 times). |
| Magic Trick / Illusion, Hone, Tarot/Planet Merchant | | [M] Low. Illusion is "detrimental to shop value" (Addison); C/B tiers (BalatroHQ). "Many vouchers lose value" at high difficulty (warmingbird, [S15](https://steamcommunity.com/app/2379780/discussions/0/4346606879517114465/)). |

- games.gg puts Antimatter and Grabber in S tier [snippet].
- **[derived] Purchase rule.** At $10, a voucher costs two rounds of interest if it drops you below $25. Hand, hand-size and discard vouchers pay for themselves through unused-hand money and consistency.

---

## 9. Top 25 rules for a copilot at high stakes

These are checkable decision rules. [derived] numbers come from the cited tables. "Base(a)" means the tier-3 base for ante a: 300 / 1,000 / 3,200 / 9,000 / 25,000 / 60,000 / 110,000 / 200,000. Multiply by 2 for Plasma.

1. **Know the target.** Gold boss = 2 × base(a): 600 / 2k / 6.4k / 18k / 50k / 120k / 220k / 400k. Wall = 4 × base. Violet Vessel = 1.2M. Needle = base(a) in ONE hand. (Wiki)
2. **Power check each shop.** If your expected main-hand score is below base(a) for the *next* ante, enter "survival mode": spending below $25 is allowed for scoring Jokers, xMult or planets. (Derived + RazzberryMocha/QuantuuM)
3. **Skip check.** Never skip a blind at Gold unless (a) it is the Ante-1 Investment Tag ($25), (b) you run Throwback or Anaglyph, or (c) it is a Hail Mary because you can't beat the ante anyway. Target ≤1 skip per run. (Consensus)
4. **Ante-1 shops.** If you have 0 scoring Jokers, buy the best affordable flat +Mult or +Chips Joker, even if it is Eternal. Take a Rental only if it is a strong scoring Joker, and sell it as soon as a clean replacement appears ($3 per round is about 60% of max interest). (Consensus)
5. **Slot fill.** Have ≥3 Jokers by the end of Ante 1 and **4–5 by the end of Ante 2**. Never leave a slot empty while waiting for something better. (malogoss, dood)
6. **Interest floor.** After rule 5 is met, finish every shop with ≥ **$25 + $3 × (rentals held)**, with a hard floor of $15–20. Only break it under rule 2 or for a run-defining xMult or scaler. (Consensus; RazzberryMocha's $28/$31)
7. **Reroll budget.** Buy wanted packs or Jokers first. Reroll only with money above the rule-6 floor (about $30–35 or more). Ante 1–2: reroll only if you still lack a scoring Joker. (malogoss)
8. **Packs.** Skip Standard packs. Buy Buffoon packs mainly while holding fewer than 3 Jokers. Buy Celestial packs when they can hit your main hand (always, with Telescope). Arcana packs only when they serve deck-fixing or boss counters. (Multiple)
9. **Main hand.** Antes 1–2: play the best 5-card hand (Flush first; 9 outs vs 8). **Commit to one hand by Ante 3.** At Blue+ (2 discards), default to Pair, Two Pair or High Card unless the deck supports 5-card hands (Checkered, ≥3 suit or rank changers, Four Fingers/Shortcut). (Consensus with dissent)
10. **Planets.** Always buy your main hand's Planet when it costs ≤$3–4 and keeps rule 6. Target main hand **level ≥3 by Ante 4–5**. Spread a few levels to a second hand type if The Eye has not appeared yet. (dood, wiki)
11. **Scalers early.** In Antes 1–3, take hand-count scalers that fit your hand: Green Joker, Ride the Bus, Square (4-card hands), Spare Trousers (Two Pair), Runner (Straights), Supernova, Constellation, Hologram, Lucky Cat. **Do not start a new additive scaler after Ante 4.** (malogoss, Otakuya, RazzberryMocha)
12. **xMult deadline.** At least **1 xMult source by the end of Ante 4** (hard deadline end of Ante 5), and **2 by Ante 6**. Entering Ante 5 with 0 xMult makes xMult the #1 buy, overriding interest. (dood, BalatroHQ, QuantuuM)
13. **Final composition target.** About 1 +Chips, 1 +Mult (or scaler), 2–3 xMult, 0–1 utility or economy. Order: chips and +Mult left, xMult right, copy Jokers next to the best xMult. (srn347, Amplify, malogoss)
14. **Eternal rule.** Buy an Eternal only if you would keep it at Ante 8 (a scaler, an xMult core or Rocket), or if it is the only way to survive Antes 1–2 and you have ≥2 free slots. Never buy Eternal + Rental unless it is an xMult core. (dood, BalatroHQ, RazzberryMocha)
15. **Perishable rule.** Before Ante 7, buy Perishables only as a bridge: non-scaling instant-power Jokers such as Cavendish, Fibonacci, Stuntman, The Duo or Trio. From the shop after the Ante-7 Small Blind onward, any Perishable is fine, because its 5 rounds reach the Ante-8 boss. Track the counter and sell the Joker the round it is debuffed. The 18 scaling Jokers can never be Perishable. (Wiki, Mancunion, dood)
16. **Rental rule.** Buy a Rental if (a) it gives more than $3 per round of value, meaning an xMult core or key scaler, and your income keeps you at $25 + $3 per rental; or (b) its value fires before the final hand (on blind select, discard, or shop), so you can sell it in the same round for net $0. Hold at most 1 rental before Ante 6 unless you have strong income Jokers. (malogoss, Draco18s, cct, dood)
17. **Boss look-ahead.** Right after beating a boss, read the next boss and plan all 3 shops around it. Keep one counter consumable when possible: Hanged Man for Cerulean Bell, Death/Strength/Sun for The Mouth, Justice/Chariot for The Eye or The Needle, Moon/Star for suit fixes. (malogoss, wiki)
18. **Needle check.** If your best single hand is below base(a), reroll (Director's Cut or Boss Tag), use Luchador, or use Burglar; otherwise buy a Tarot or Glass for that one hand. (Wiki, malogoss)
19. **Wall check.** If 4 × your average hand is below 4 × base(a) — that is, your average hand is below base(a) — reroll, use Luchador, or rely on Mr. Bones (survives at ≥25%). Otherwise Glass cards, Campfire or Loyalty Card can bridge. (Wiki)
20. **Violet Vessel check (Ante 7 shops).** Projected 4-hand total must be ≥1.2M at Gold (2.4M on Plasma), meaning ≥300k per hand. Aim for 500k for safety. If below, buy xMult, Glass/Steel or Hanging Chad, or hold Luchador, Chicot or Mr. Bones. (malogoss, mangonaise, wiki)
21. **Showdown prep.** Carry a sacrificial non-scoring Joker into Ante 8 for Verdant Leaf. Avoid single-Joker dependence for Crimson Heart. Keep xMult on the right and lower game speed for Amber Acorn. Hold Hanged Man for Cerulean Bell. (Wiki, dood)
22. **The Ox (Ante 6+).** If your most-played hand is your only win route, spend money down before the blind. Otherwise win with a different hand. (Wiki, dood)
23. **Last shop before the Ante-8 boss.** Interest is worthless after winning, so convert all money into score (Jokers, rerolls, planets). Exception: Bull or Bootstraps scaling on cash. Don't wait for a better buy: malogoss lost by 2% doing that. (malogoss)
24. **Voucher priority at Black+.** Grabber/Nacho Tong ≈ Paint Brush/Palette > Wasteful (Blue+) ≈ Telescope/Observatory (if planet-leveling) > Overstock ≈ Clearance Sale > Crystal Ball ≈ Director's Cut (if boss-vulnerable) > Reroll Surplus > Hieroglyph (only with a strong engine or to buy time before VV or a scaler payoff) > Seed Money (only if you can hold $50+; never on Green deck) > the rest. Buy hand, hand-size and discard vouchers even below $25. Buy others only while keeping rule 6. (BalatroHQ, Addison, dood, Steam)
25. **Deck-aware defaults.**
    - Black: economy Joker plus Grabber first; avoid hand-scalers.
    - Plasma: chips early, pivot to Mult/xMult by Ante 3–5; all targets ×2.
    - Green: win in 1 hand; never buy interest vouchers.
    - Checkered: Flush is allowed all run.
    - Blue: Pair plus hand-count scalers.
    - Ghost: Hex the first strong Joker (or an Eternal).
    - Erratic: check rank and suit counts in Ante 1 and pick the most common rank or suit.
    - Expected difficulty: Black hardest; Yellow, Checkered, Green and Blue easiest.
    - (Consensus/majority, section 6)

---

## 10. Sources actually opened

**Wiki (mechanics):**
- Stakes and stickers: [Stakes](https://balatrowiki.org/w/Stakes), [Gold Stake](https://balatrowiki.org/w/Gold_Stake), [Orange Stake](https://balatrowiki.org/w/Orange_Stake), [Blue Stake](https://balatrowiki.org/w/Blue_Stake), [Black Stake](https://balatrowiki.org/w/Black_Stake), [Stickers](https://balatrowiki.org/w/Stickers), [Perishable](https://balatrowiki.org/w/Perishable), [Eternal](https://balatrowiki.org/w/Eternal)
- Blinds, shop and economy: [Blinds and Antes](https://balatrowiki.org/w/Blinds_and_Antes), [Vouchers](https://balatrowiki.org/w/Vouchers), [Tags](https://balatrowiki.org/w/Tags), [Shop](https://balatrowiki.org/w/Shop), [Interest](https://balatrowiki.org/w/Interest), [Money](https://balatrowiki.org/w/Money)
- Cards and decks: [Poker Hands](https://balatrowiki.org/w/Poker_Hands), [Jokers](https://balatrowiki.org/w/Jokers), [Seals](https://balatrowiki.org/w/Seals), [Enhancements](https://balatrowiki.org/w/Enhancements), [Decks](https://balatrowiki.org/w/Decks), [Hands](https://balatrowiki.org/w/Hands), [Discards](https://balatrowiki.org/w/Discards)
- Boss pages: [The Needle](https://balatrowiki.org/w/The_Needle), [Violet Vessel](https://balatrowiki.org/w/Violet_Vessel), [The Psychic](https://balatrowiki.org/w/The_Psychic), [The Wall](https://balatrowiki.org/w/The_Wall), [The Plant](https://balatrowiki.org/w/The_Plant), [The Eye](https://balatrowiki.org/w/The_Eye), [The Mouth](https://balatrowiki.org/w/The_Mouth), [The House](https://balatrowiki.org/w/The_House), [The Fish](https://balatrowiki.org/w/The_Fish), [Cerulean Bell](https://balatrowiki.org/w/Cerulean_Bell), [Verdant Leaf](https://balatrowiki.org/w/Verdant_Leaf), [Crimson Heart](https://balatrowiki.org/w/Crimson_Heart), [Amber Acorn](https://balatrowiki.org/w/Amber_Acorn), [The Ox](https://balatrowiki.org/w/The_Ox)

**1.0.1 patch-note coverage:** [VGC](https://www.videogameschronicle.com/news/balatros-first-major-update-tweaks-difficulty-adds-new-joker-types/), [Shacknews 1.0.1c](https://shacknews.com/article/139415/balatro-update-101c-patch-notes). These carry beta scaling numbers that differ from the final ones; the wiki numbers are authoritative.

**Steam discussions** (S1–S31, threads are under `https://steamcommunity.com/app/2379780/discussions/0/`):
- S1–S9: [S1 604143165271744486](https://steamcommunity.com/app/2379780/discussions/0/604143165271744486), [S2 596263931969820235](https://steamcommunity.com/app/2379780/discussions/0/596263931969820235), [S3 596264096371887282](https://steamcommunity.com/app/2379780/discussions/0/596264096371887282), [S4 4356744017103053782](https://steamcommunity.com/app/2379780/discussions/0/4356744017103053782), [S5 4294818016870729305](https://steamcommunity.com/app/2379780/discussions/0/4294818016870729305), [S6 4308327178395153352](https://steamcommunity.com/app/2379780/discussions/0/4308327178395153352), [S7 840628406751272258](https://steamcommunity.com/app/2379780/discussions/0/840628406751272258/), [S8 764059330564645976](https://steamcommunity.com/app/2379780/discussions/0/764059330564645976/), [S9 4693406471885516172](https://steamcommunity.com/app/2379780/discussions/0/4693406471885516172)
- S10–S19: [S10 4369129313606908896](https://steamcommunity.com/app/2379780/discussions/0/4369129313606908896/), [S11 596263244409116960](https://steamcommunity.com/app/2379780/discussions/0/596263244409116960), [S12 6832609818929725471](https://steamcommunity.com/app/2379780/discussions/0/6832609818929725471), [S13 4334231676647966765](https://steamcommunity.com/app/2379780/discussions/0/4334231676647966765), [S14 4293691486113242157 p4](https://steamcommunity.com/app/2379780/discussions/0/4293691486113242157/?ctp=4), [S15 4346606879517114465](https://steamcommunity.com/app/2379780/discussions/0/4346606879517114465/), [S16 4346606879520764406](https://steamcommunity.com/app/2379780/discussions/0/4346606879520764406/), [S17 604143633269036634](https://steamcommunity.com/app/2379780/discussions/0/604143633269036634), [S18 4756452715167149899](https://steamcommunity.com/app/2379780/discussions/0/4756452715167149899), [S19 600772276758022609](https://steamcommunity.com/app/2379780/discussions/0/600772276758022609/)
- S20–S31: [S20 7252559325161419962](https://steamcommunity.com/app/2379780/discussions/0/7252559325161419962), [S21 4357869219920827290](https://steamcommunity.com/app/2379780/discussions/0/4357869219920827290), [S22 828204634466163265](https://steamcommunity.com/app/2379780/discussions/0/828204634466163265), [S23 4346606879510867624](https://steamcommunity.com/app/2379780/discussions/0/4346606879510867624/), [S24 604149771486109542](https://steamcommunity.com/app/2379780/discussions/0/604149771486109542), [S25 695376132937158319](https://steamcommunity.com/app/2379780/discussions/0/695376132937158319/), [S26 4424310458751168875](https://steamcommunity.com/app/2379780/discussions/0/4424310458751168875), [S27 4356743780116244183](https://steamcommunity.com/app/2379780/discussions/0/4356743780116244183), [S28 4308327413811541697](https://steamcommunity.com/app/2379780/discussions/0/4308327413811541697), [S29 4356744017100525047](https://steamcommunity.com/app/2379780/discussions/0/4356744017100525047), [S30 7410182856432960551](https://steamcommunity.com/app/2379780/discussions/0/7410182856432960551), [S31 4364626348105356076](https://steamcommunity.com/app/2379780/discussions/0/4364626348105356076)
- Also: [deck-stake thread 4346606879521298087](https://steamcommunity.com/app/2379780/discussions/0/4346606879521298087)

**Steam guides** (all marked "removed / incompatible" by Steam, but readable):
- [G1 Black Deck Gold Stake, Baka Piot, Jul 2025](https://steamcommunity.com/sharedfiles/filedetails/?id=3535175222)
- [G2 How to gold stake (high card), Leupe, Mar 2024, pre-1.0.1](https://steamcommunity.com/sharedfiles/filedetails/?id=3172577970)
- [G3 100% Achievement Guide, prandtl, Jan 2025](https://steamcommunity.com/sharedfiles/filedetails/?id=3400510379)

**Articles and blogs:**
- [Mancunion, Adam Whiteley, Sep 2025](https://mancunion.com/2025/09/01/a-guide-to-gold-stake-balatro/) — completed every deck on Gold.
- [WitchPHD substack](https://witchphd.substack.com/p/balala) — C+ and C++.
- [Addison Kindrick, Gold-stake tier list addendum, Jan 2025](https://addisonkindrick.substack.com/p/10-balatro-tier-list-addendum)
- [dood stakes guide](https://dood.gg/en/balatro/guides/stakes-guide/), [dood ante guide](https://dood.gg/en/balatro/guides/ante-guide/) — 2026 strategy DB; mostly consistent with the wiki, one perishable error noted above.
- [BalatroHQ Gold guide](https://balatrohq.com/guides/gold-stake-guide/), [BalatroHQ vouchers](https://balatrohq.com/vouchers/) — data stated current as of 1.0.1o.
- [coin-return forum p5](https://forums.coin-return.org/threads/balatro-roguelike-poker-just-one-more-hand.782/page-5), [p4](https://forums.coin-return.org/threads/balatro-roguelike-poker-just-one-more-hand.782/page-4)

**Search-snippet only (page not opened):**
- [Mobalytics Gold-stake joker tier list](https://mobalytics.gg/blog/tier-lists/best-balatro-jokers/) (403)
- [Hypixel "All decks gold stake"](https://hypixel.net/threads/all-decks-gold-stake-balatro.6086776/) (503)
- [TrueAchievements High Stakes](https://www.trueachievements.com/a424923/high-stakes-achievement) (403)
- games.gg voucher tier list
- Balatro University "Gold Stake Lessons" playlist listing (71 videos)
- The "48.3% purple / 33.3% orange / 17.5% gold" win-rate tracker comment (pre-1.0.1)

**Opened but judged unreliable:** [Switchblade Gaming](https://www.switchbladegaming.com/strategy-games/balatro-gold-stake-guide/) and findingdulcinea.com tier list. Used for nothing that matters.
