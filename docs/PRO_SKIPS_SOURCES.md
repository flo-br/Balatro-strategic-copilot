<!-- Recherche sourcée (en anglais) utilisée pour le calcul des blindes passées de la version 1.0.8 : engine/skip.lua, docs/PRO_LESSONS.md §4. -->

# Balatro: when to skip a blind for its tag (sourced research, pass 2)

Scope: vanilla Balatro, current PC version **1.0.1o** (24 Feb 2025). The wiki's Updates page still lists "Update 1.1" as "No confirmed date" (checked Oct 2026).

Legend:
- **[wiki]** means balatrowiki.org; raw wikitext was read via `?action=raw`, so the quotes are exact.
- **[src]** means a reading of the game's own Lua code (version 1.0.1o) during the research, used only to confirm mechanics the wiki leaves vague. No game code is copied into this project.
- **[community]** means a forum, guide or article opinion. The date is given because the 1.0.1f patch (May 2024) changed tag values.
- **[estimate]** means my own number or synthesis, not taken from a source.
- **[snippet only]** means I saw the text in a search result but could not open the page.

Access limits:
- **Reddit** could not be reached: the search tool refuses reddit.com and direct fetches return 403. No r/balatro content is cited.
- **YouTube transcripts** could not be retrieved (bot wall). For the Balatro University videos (channel @drspectred) I could only confirm the titles through YouTube oEmbed: "Updated Skip Tag Tier List (Balatro 101 Patch)" (Lx2bAMdKwIs), "Balatro Basics: Skip Tag Tier List (You're doing it wrong)" (q4YAHDuRUcQ), "Let's talk about Skip Tags (Gold Stake Lessons)" (NXttotDW4LY), "Which skips are even worth it? (Gold Stake Lessons)" (RvhjDvaZnHM) and "Coupon Tag is SO bad (Gold Stake Lessons)" (iNoj0zqaRZo). Their content is **not verified**, and only the titles are used below.
- **GameFAQs, TierMaker and Twinfinite** returned 403 (Cloudflare), so they are cited as snippets only.

---

## 0. Patch history relevant to skipping (answers "did anything change after 1.0.1?")

Only one live patch changed tags: **1.0.1f** (1 May 2024; identical to experimental 1.0.1c/e). Sources: https://balatrowiki.org/w/Update_1.0.1f and https://balatrowiki.org/w/Tags (update history). Its relevant changes:
- Uncommon, Rare, Negative, Polychrome, Holographic and Foil tags: "Now makes the … joker free". **Before this patch, edition tags made the joker cost more.**
- Investment Tag: "Gives $15 -> gives $25".
- "Upcoming blinds/tags can now be seen in the shop immediately after defeating a boss blind/cashing out". You can plan the next ante's skips while still in the shop.
- "Changed the first Shop in every run to always include a normal Buffoon pack". [wiki The Shop] words it as "the first visit to any Shop in a run", and [src] uses a run-level flag (`G.GAME.first_shop_buffoon`). **Skipping the Ante-1 Small Blind therefore does not lose the guaranteed Buffoon pack**; it moves to the shop after the Big Blind. This contradicts a Steam claim (Goblin) that skipping "forfeits … a guaranteed Buffoon Pack".
- Stake rework: Orange adds Perishable stickers (30%) and Gold adds Rental stickers (30%, $3 per round). Both change the value of free-joker tags at high stakes (see §2).

Later patches (1.0.1g, j, m, n, o) did not change tags or skipping. The only tag-related note is a bug fix in 1.0.1m: "Fixed bug where starting tags are always the same" (https://balatrowiki.org/w/Update_1.0.1m).

**Consequence for evaluating sources.** Many of the loudest anti-skip posts date from Feb–Apr 2024, before 1.0.1f. Example (Steam, Goblin, 16 Mar 2024): "Poly/Holo/Rare/etc.: actually just costs you money by increasing the cost of jokers in the next store". That is obsolete: those jokers are now free. The earlier pass's "skipping is bad 95% of the time" comes from RazzberryMocha (18 Mar 2025, post-patch) and is still a valid opinion, but it is the strict end of the spectrum (see §3).

---

## 1. Mechanics that the decision rule depends on (verified)

### 1.1 Tag pool and visibility
- Tags are uniformly random: "The chance for each Tag to appear is the same" [wiki Tags]. [src] `get_next_tag_key` uses `pseudorandom_element` over the pool.
- Ante 1 can roll 15 tags. It excludes Negative, Standard, Meteor, Buffoon, Handy, Garbage, Ethereal, Top-up and Orbital [wiki Tags]; in [src] these have `min_ante = 2`. Ante 2 onward can roll all 24.
  - So an ante-1 tag slot has a 1/15 chance per specific tag, and later slots 1/24, if everything is discovered.
  - Hidden requirements: Rare needs Blueprint discovered; Negative, Foil, Holographic and Polychrome need their edition discovered [wiki Tags].
- Both the Small and Big tags for the ante are shown on the blind-select screen. Since 1.0.1f they are also visible in the shop after the boss.
- Orbital: the hand is chosen per ante and per blind when the tag is generated, and it is named on the tag ("Upgrade [poker hand] by 3 levels" [wiki Tags table]). [src] `G.GAME.orbital_choices[ante][blind_type]` draws from the currently visible hands. **The player knows the hand before skipping.**
- Handy, Garbage and Speed show their exact payout on the tag ("Will give $X") [wiki Tags table; src loc_vars], so the mod can read the exact value.

### 1.2 When each tag pays off (timing classes)
| Class | Tags | When the effect lands | Source |
|---|---|---|---|
| Immediate, on skip | Economy, Speed, Handy, Garbage, Orbital, Top-up | Instantly on the blind-select screen | [src] `type='immediate'` |
| Immediate pack | Charm, Meteor, Buffoon, Standard, Ethereal | Opens right after the skip, one pack at a time | [wiki each page: "acquire and then immediately open"]; [src] `new_blind_choice` |
| Immediate reroll | Boss | "immediately re-rolls the next Boss Blind" | [wiki Boss Tag] |
| Next shop visited | Uncommon, Rare, Foil, Holo, Poly, Negative, Coupon, D6, Voucher | Next shop, i.e. **after the next blind you play** | [wiki]; [src] `store_joker_create`, `store_joker_modify`, `shop_start`, `shop_final_pass`, `voucher_add` |
| Next round | Juggle | Start of the next blind played; all Juggle copies apply together | [wiki Juggle]; [src] `round_start_bonus` |
| After the boss | Investment | Cash-out of the boss; stacks; pays even if saved by Mr. Bones | [wiki Investment] |
| Next tag gained | Double | Copies the next tag (not another Double) | [wiki Double] |

**Implication** [synthesis]: if you skip the Small Blind for a shop tag, its value arrives only after you beat the Big Blind with your current build. If you skip the Big Blind for one, it arrives only after you beat the Boss. Immediate tags (Buffoon, Top-up, Charm, Orbital, Meteor, Ethereal, money tags) can strengthen the build *before* the next blind.

### 1.3 How the free-joker tags work in the shop (asked explicitly)

**Uncommon and Rare tags.** The tag joker **takes one of the shop's normal card slots; it is not an extra slot**, and it costs $0.
- [wiki Rare Tag]: "Multiple Rare Tags or Uncommon Tag will take effect in order, until there are no more open slots available in the current shop. Rerolling the shop will let any remaining Rare/Uncommon Tags take effect."
- [src] `create_card_for_shop`: when the shop fills each card slot, it first asks the tags for a `store_joker_create`. If one fires, that joker *is* the slot's card. The cost is set to $0 (`couponed`).
- With the default 2 card slots, one tag gives the tag joker plus 1 normal card.
- The joker is forcibly generated, ignoring rarity weights and vouchers that lower joker odds [wiki]. It can roll an edition and, on Black stake and above, stickers [wiki].
- The Rare Tag says "NOPE" if you already hold all Rare jokers [wiki].

**Edition tags (Foil, Holographic, Polychrome, Negative).** They make "the next base edition Joker found in the Shop cost $0 and come with a … edition" [wiki Negative/Foil/Poly/Holo Tag].
- The tag applies automatically to the **first base-edition joker created for a shop**. That includes a joker created by an Uncommon or Rare tag ("Works with the Uncommon Tag and Rare Tag if the generated Joker does not have an edition naturally"), and jokers created by rerolls.
- It ignores Tarot, Planet and playing cards, and jokers that already have an edition.
- "If there are no base edition Jokers in the next shop, this Tag will instead be stored."
- [src]: `store_joker_modify` is checked for every shop card created, including on reroll. Only jokers with `set=='Joker'` and no edition qualify. One edition tag is consumed per joker.
- **The player cannot choose the target joker.** The tag is consumed on that joker whether or not you buy it (also stated on Steam by malogoss, 20 Dec 2024).
- On Black stake and above, the target joker "can have any in-run Sticker" [wiki]. That means Eternal at Black+, Perishable at Orange+, and Rental at Gold, each 30% [wiki Eternal/Perishable/Rental].

**Sell value of free tag jokers** [src `Card:set_cost`]. The sell value is computed from the *full* price before the price is set to $0, so a free tag joker sells for floor(full price/2).
- This gives a guaranteed cash floor when the joker is useless, unless it is Eternal (cannot be sold) or Rental (costs $1, sells for $1).
- Base prices [wiki The Shop]: Common $1–6, Uncommon $4–8, Rare $7–10. Editions add Foil +$2, Holo +$3, Poly +$5, Negative +$5.
- Example: a Rare from the Rare tag sells for about $3–5; a Polychrome uncommon sells for about $4–6.

**Coupon.** It makes "all of the Jokers, Consumables, and Booster Packs that appear upon first entering The Shop cost nothing. This tag does not apply to Vouchers, nor any Jokers or Consumables that appear after a reroll." [wiki Coupon Tag]

**D6.** "makes rerolls start at $0 (then, increase by $1 for each reroll) the next time the player visits The Shop." Several D6 tags are used one per shop [wiki D6 Tag].

### 1.4 Cash-out details that set the cost of skipping
- Blind reward:
  - Small Blind: $3, but on Red stake and above "it provides no reward money" [wiki Small Blind; Red Stake].
  - Big Blind: $4 [wiki Big Blind].
  - Boss: $5 (Showdown $8) [wiki Money].
- Unused hands pay $1 each [wiki Money].
- Green Deck pays $2 per remaining hand and $1 per remaining discard, but earns no interest. Omelette and Mad World earn no hand money [wiki Money; Interest].
- Interest: "$1 of interest is earned for every $5 the player has at the end of the round, with a cap of $5". Seed Money raises the cap to $10 and Money Tree to $20; To the Moon adds more [wiki Interest].
  - [src] Interest is computed on the money held *before* that cash-out's payouts are added. The Investment $25 therefore earns no interest in the round it is paid.
- Rental: "deduct $3 at the end of every round. This price is deducted before the round payout." [wiki Rental] A skipped blind has no end of round, so **each Rental joker saves you $3 per skip**.
- Perishable: "debuffs the joker after 5 rounds" [wiki Perishable]. Skipped blinds are not rounds.
- Blind sizes [wiki Blinds and Antes]:
  - Small = 1x base, Big = 1.5x, most bosses 2x. The Wall is 4x, Violet Vessel 6x, The Needle 1x with one hand.
  - Base score by ante:

| Ante | White/Red | Green/Black/Blue | Purple/Orange/Gold |
|---|---|---|---|
| 1 | 300 | 300 | 300 |
| 2 | 800 | 900 | 1,000 |
| 3 | 2,000 | 2,600 | 3,200 |
| 4 | 5,000 | 8,000 | 9,000 |
| 5 | 11,000 | 20,000 | 25,000 |
| 6 | 20,000 | 36,000 | 60,000 |
| 7 | 35,000 | 60,000 | 110,000 |
| 8 | 50,000 | 100,000 | 200,000 |

  - Plasma Deck doubles every requirement.

---

## 2. Every tag: effect, minimum ante, value, when to skip

Format: effect [wiki] / minimum ante / face value in $ / what players say / when it is worth a skip. Tiers are given in the final table and are **my synthesis** of the cited opinions.

### Investment Tag
- **Effect:** "After defeating the Boss Blind, gain $25". Stacks. Pays even if Mr. Bones saved you.
- **Minimum ante:** any.
- **Face value:** $25 at the end of the current ante (no interest that round).
- **Wiki:**
  - "considered by many players to be one of the best, if not the best tag in the game, especially if found early on … $25 is usually enough money to buy plenty of things … as well as instantly hitting the interest cap".
  - It loses value later ("becomes less worth it unless the player is really in a pinch").
  - Caveat: "During Purple Stake and higher, the scores necessary to progress further in the Antes becomes too high to afford skipping at least one Shop over." https://balatrowiki.org/w/Investment_Tag
- **Community:** the most universally endorsed tag, even by strict no-skip players.
  - RazzberryMocha (Steam, Dec 2024): skip "only for the $25 tag or a necessary boss reroll".
  - Mancunion Gold Stake guide (1 Sep 2025): the "round 1 investment" skip is the main exception.
  - Hardcore Gamer Gold Stake tips (15 Apr 2025): "The Investment tag is probably the most valuable".
  - Addison Kindrick (4 Jan 2025): "economy-based skip tags are often the only skips one should take in an entire run … Investment Tag providing an especially strong benefit if found in Ante 1".
  - WitchPHD (all-Gold, Completionist++ player, 19 Dec 2025): "$25 is $25, bro."
- **Disagreement:** the wiki's Purple+ caveat versus Gold-stake guides that still take it at Ante 1.
  - Reconciliation [synthesis]: the caveat is about mid and late antes. At Ante 1–2 nearly everyone takes it.
- **Skip when:** Ante 1–3, any stake, especially the Small Blind on Red+. Later, only if money is below about $25, so the $25 also restores interest [estimate].

### Coupon Tag
- **Effect:** initial shop cards and packs free (not vouchers, not rerolls).
- **Minimum ante:** any.
- **Face value:** 2 cards plus 2 packs. Roughly $15–30 if you would buy them all [estimate from wiki prices].
- **Wiki:**
  - "The best time to take this tag is Ante 1, as the player will not have very much money saved at the time."
  - "can be seen as a slightly worse version of the Investment Tag". https://balatrowiki.org/w/Coupon_Tag
- **Community:**
  - Wiki early-skip list includes it [wiki Guide: General strategy].
  - RazzberryMocha (S6; date not captured, but the thread-ID range matches Dec 2024–Jan 2025 threads, so post-1.0.1f): "the only skip reward that is ever viable in 99% of scenarios is free shop on ante 1".
  - Goblin (Mar 2024): "Free shop tag is probably the best one … you should probably always take this one on the first round".
  - S♥ShiMe: "free shop is ssss tier in gold stake".
  - Baka Piot (Gold-stake guide, 2025): "Coupon Tag is amazing".
  - Hardcore Gamer best tags (Oct 2024): #2.
  - Twinfinite [snippet only]: "The best Tag in the game".
- **Disagreement:** a Balatro University video is titled "Coupon Tag is SO bad (Gold Stake Lessons)". Its argument could not be verified. Note also that it is "100% a gamble" on the two jokers (Goblin).
- **Skip when:** the Ante-1 Small Blind, almost always. Later, when money is low and the next shop matters. Weaker late, when interest is capped and a free shop of random items saves less than the lost round earns [synthesis].

### Polychrome Tag
- **Effect:** next base-edition shop joker becomes free and Polychrome (X1.5 Mult).
- **Minimum ante:** any.
- **Face value:** joker plus $5 edition; sells for half the full price.
- **Community:**
  - Draco18s (Steam, Mar 2024): "Negative or Polychrome Joker tags: always (unless its ante 1...)".
  - Moray Eel (Dec 2024): "Good skip tags like polychrome/1.5X multipliers … can enable a lot of runs if taken early".
  - WitchPHD: "Occasionally I'll pick up an early Polychrome tag, but not late in the run."
  - Amplify's Ante-1 tier list (Mar 2024): A tier.
  - brickey.8 (Mar 2024, pre-patch) said "Poly … B tier … since you may not afford it". That reasoning is obsolete; it is free now.
- **Caveat:** the joker is random, and on Black+ it can carry a sticker (Piot: "the main issue of a free special edition/rarity Joker is that the Joker may be perishable/rental").
- **Skip when:** Ante 1–4, Small Blind, with the next blind beatable. Strongest with an empty joker slot or a weak lineup. With a later Polychrome the joker is less likely to fit [synthesis].

### Holographic Tag
- **Effect:** free Holographic (+10 Mult) joker.
- **Minimum ante:** any.
- **Face value:** joker plus $3.
- **Wiki early-skip list:** "Provides you a source of reliable and constant early game Mult that is helpful regardless of the joker it is attached to" [wiki Guide: General strategy].
- **Community:** Amplify: S tier for the first skip. Mel Gibson (Dec 2024): skip for holo or $25. Twelvefield: yes.
- **Skip when:** Ante 1–2, Small Blind. Falls off later because +10 Mult is minor by Ante 5+ (GameRant also says "strong early but fades").

### Negative Tag
- **Effect:** free Negative joker (+1 joker slot).
- **Minimum ante:** 2 (the only edition tag absent from Ante 1).
- **Face value:** joker plus $5.
- **Wiki:**
  - "There's no guarantee the Joker will be useful or even usable at all … skipping a blind costs skipping the benefits and opportunities from playing a blind and visiting the subsequent shop."
  - "If the player wishes to take the Negative Tag at any point, it's imperative that the current Joker build can accommodate for missing a Shop and the bigger Blind requirements, especially on higher stakes."
  - A useless Negative joker still blocks that joker from reappearing (unless Showman), raises Temperance, and can be sold to disable Verdant Leaf, unless it is Eternal.
  - Source: https://balatrowiki.org/w/Negative_Tag
- **Community:**
  - A bear (Mar 2024): the only non-Anaglyph tag he takes. Draco18s: always. Thundergod and Lil brekky: mid-late "negative/xMult" skips. WitchPHD: "negative jokers are so solid". Hardcore Gamer: #1.
  - Against: Ronald Brain (Sep 2024): "Negative is easily the biggest beginner's trap, you're screwed if you end up with a food joker". Mancunion: on Anaglyph at Gold, perishable and rental stickers make "most of the negative jokers useless".
- **Skip when:** Ante 2–6, Small Blind preferred, with a build that beats the next blind without a shop. Most valuable when joker slots are full or limited (Painted, Blast Off and Cruelty decks; [wiki Skip]). Top value when doubled by Double tags (Anaglyph).

### Foil Tag
- **Effect:** free Foil (+50 Chips) joker.
- **Minimum ante:** any.
- **Face value:** joker plus $2.
- **Wiki:**
  - "having a single Foil Edition Joker can supplement or remove the need to obtain a Chips dedicated Joker".
  - "significantly more beneficial on the Plasma Deck … a potentially worthwhile skip in an early Ante". https://balatrowiki.org/w/Foil_Tag
- **Community:** Amplify: A tier for the first skip. GameRant: ranks it low (21/24).
- **Skip when:** the Ante-1 Small Blind on Red+, or on Plasma or chip-starved builds. Otherwise marginal.

### Uncommon Tag
- **Effect:** free Uncommon joker (one shop slot).
- **Minimum ante:** any.
- **Face value:** $4–8, sells for $2–4.
- **Community:** Amplify: A tier for the first skip. Twelvefield: skip if it "guarantees you an uncommon/foil/holographic joker". RazzberryMocha: joker skips are "practically never worth it under any circumstance" (as a Double target).
- **Skip when:** the Ante-1 Small Blind on Red+ when there is no better tag. Rarely later [synthesis].

### Rare Tag
- **Effect:** free Rare joker (one shop slot). Can NOPE.
- **Minimum ante:** any (needs Blueprint discovered).
- **Face value:** $7–10, sells for $3–5.
- **Community, split:**
  - For: Amplify B tier; Hardcore Gamer #4 and listed among "most consistent" Gold starts; Falcon: "rare joker can give free blueprint".
  - Against: Mel Gibson "not … rare tags"; Shven: "A free blueprint on ante 2 with nothing to copy is the same as having no jokers"; RazzberryMocha: "A rare joker tag has a 1/10 chance of a blueprint/brainstorm".
- **Skip when:** Ante 1–3 Small Blind, when the lineup has room and the build can wait one shop. High variance [synthesis].

### Economy Tag
- **Effect:** "doubles the player's money if it is below $40; otherwise, it adds $40". In debt it gives $0 [wiki].
- **Minimum ante:** any.
- **Face value:** min(max(money, 0), 40), paid immediately.
- **Community:**
  - srn347 (Mar 2024): skip if "offered something big enough like $40".
  - Draco18s: cash-now tags depend on "double the blind's reward + interest" or better.
  - Hardcore Gamer: "sometimes the Economy tag can provide just enough resources to seize victory".
  - [wiki Yellow Deck]: "Skipping for an Economy Tag in ante 1 should usually allow the player to reach the initial Interest cap" ($14 becomes $28).
- **Skip when:** money is at least about $20 (gain of $20–40). At Ante 1 on standard decks ($4–7) it is not worth it, except on Yellow Deck. Never in debt.

### Speed Tag
- **Effect:** "$5 for each blind that is skipped, including the Speed Tag itself", uncapped.
- **Minimum ante:** any.
- **Face value:** $5 × total skips so far (shown on the tag).
- **Wiki:** beats Investment after 5+ skips and Economy after 8+.
- **Community:** Goblin (Mar 2024): on Red+ the first-blind Speed tag "is thus just +$1 … at the cost of 1 store", and in another post "$2 more at the cost of a store".
- **Skip when:** the shown value is at least about $20 (3 or more prior skips), or with Throwback. Not as the first skip.

### Handy Tag
- **Effect:** $1 per hand played this run.
- **Minimum ante:** 2.
- **Face value:** shown on the tag; it grows over the run.
- **Community:** Mancunion (Anaglyph): Investment, Economy and Handy "can provide a lot of money". RazzberryMocha lists "$1 per hand played" among good Double targets.
- **Skip when:** the shown value beats the skip cost by a margin, roughly $15 or more mid-run [estimate]. Better with Burglar and hand-scaling builds [wiki Handy].

### Garbage Tag
- **Effect:** $1 per unused discard this run.
- **Minimum ante:** 2.
- **Face value:** shown on the tag; smaller on Blue+ ("will get $1 less per round").
- **Skip when:** same rule as Handy, applied to the shown value. Usually small unless your build rarely discards [GameRant].

### Orbital Tag
- **Effect:** "+3 levels" to the hand shown on the tag. Does not trigger Satellite or Constellation.
- **Minimum ante:** 2.
- **Face value:** about 3 Planet cards (3 × $3) [estimate].
- **Wiki early list:** "(If on a desired hand type)".
- **Community:**
  - srn347: "upgrading my main hand 3 times (if I need the chips)".
  - Lil brekky: "+3 to a hand level can be better than an actual blind at certain points on certain runs".
  - Hardcore Gamer: "A good Orbital tag ahead of the Arm can be very valuable".
  - Goblin: "not worth" (pre-patch, Ante-1 context, where it cannot even appear).
- **Skip when:** the shown hand is your main or planned scoring hand. Strongest Ante 2–5 and before The Arm or The Flint [synthesis]. Otherwise never.

### Buffoon Tag
- **Effect:** free Mega Buffoon Pack (choose 2 of 4 jokers), opened immediately. Jokers can have stickers.
- **Minimum ante:** 2.
- **Face value:** $8.
- **Wiki early list:** "Makes up for lost money and shop offerings by providing access to 2 free jokers".
- **Community:** Goblin: "pretty much a worse Coupon … Probably worth it". DrunkBunny94: "large Buffoon packs early".
- **Skip when:** Ante 2–3 with open joker slots or a weak lineup. It works before the next blind.

### Top-up Tag
- **Effect:** up to 2 Common jokers without stickers. Needs empty slots. Immediate.
- **Minimum ante:** 2.
- **Face value:** 2 × $1–6.
- **Wiki:**
  - "best taken when the player has no scoring Jokers".
  - "more powerful on higher stakes, especially Gold Stake, as it guarantees the Jokers will have no in-run Stickers … can use this Tag even when in debt".
  - Black Deck synergy; wastes Double tags unless 3–4 slots are open.
- **Community:** Goblin: "strictly worse Buffoon".
- **Skip when:** at least 2 empty slots and a weak board. Gold or Black Deck adds to the case. Never with full slots.

### Charm Tag
- **Effect:** free Mega Arcana Pack (choose 2 of 5), immediate. "the only pack-related Tags that can appear in Ante 1". The Soul chance is about 1.5%.
- **Minimum ante:** any.
- **Face value:** $8.
- **Community:**
  - For: Piot: consider skipping the Ante-1 Small Blind for it ("a Mega Arcana Pack can have some good stuff"). Moray Eel lists it. The Anaglyph wiki calls Charm with stacked Doubles an "extremely potent" immediate payoff. The Completionist++ guide fishes for The Soul with an Ante 1–2 Charm.
  - Against: malogoss (Sep 2024): "that tag is not good. The pack is worth $8, at most. By skipping, that's likely 10$+ you won't make … and a shop you won't visit". Goblin: "not worth".
- **Skip when:** the Ante-1 Small Blind on Red+ as a weak-to-medium option, or with Double tags. Otherwise play.

### Ethereal Tag
- **Effect:** free normal Spectral Pack (choose 1 of 2), immediate.
- **Minimum ante:** 2.
- **Face value:** $4.
- **Community:** Mancunion: useful on Anaglyph. Hardcore Gamer: #9. DrunkBunny: "Spectral packs can be good early".
- **Skip when:** rarely. With Doubles, or when you specifically need a Spectral effect. Weak on Ghost Deck [wiki].

### Meteor Tag
- **Effect:** free Mega Celestial Pack (choose 2 of 5), immediate.
- **Minimum ante:** 2.
- **Face value:** $8.
- **Community:** Goblin: "rarely worth anything". GameRant: 22/24. The wiki notes that, unlike Orbital, it does scale Constellation and Satellite.
- **Skip when:** rarely. With Constellation, or Telescope plus a main hand [synthesis].

### Standard Tag
- **Effect:** free Mega Standard Pack (choose 2 of 5 playing cards), immediate.
- **Minimum ante:** 2.
- **Face value:** $8.
- **Community:** Goblin: "AHAHAHAHA please tell me you're kidding". GameRant: 23/24. The wiki notes Hologram synergy.
- **Skip when:** effectively never, except with Hologram or a specific deck-fixing need.

### Voucher Tag
- **Effect:** one extra voucher, for sale (not free), in the next shop only.
- **Minimum ante:** any.
- **Face value:** the option to buy a $10 voucher.
- **Wiki:** several Voucher tags stack. Buying a base voucher while tags are pending can make them roll its upgrade.
- **Community:** Draco18s: "honestly almost never". Mel Gibson: no. malogoss: "Buying an early voucher is a good way to ruin a run, at high stakes."
- **Skip when:** almost never. Exception: rich and hunting a specific voucher (Director's Cut, Telescope and similar) [synthesis].

### Boss Tag
- **Effect:** "immediately re-rolls the next Boss Blind".
  - On Ante 8 the reroll stays a Showdown boss [src `get_new_boss`; wiki Director's Cut].
  - It uses up the Director's Cut reroll for that ante [wiki Boss Tag / Director's Cut].
  - The new boss is random among the least-used eligible bosses [wiki Blinds].
- **Minimum ante:** any.
- **Face value:** about one Director's Cut reroll ($10, plus owning the $10 voucher).
- **Wiki list of hard-counter bosses** (transcluded from Mr. Bones):
  - Mono-suit deck or Smeared Joker: Club, Goad, Window, Head.
  - Face-card deck or Pareidolia: Plant, Mark.
  - High-level hand: Flint.
  - One hand type or Card Sharp: Eye, Arm.
  - Discard-reliant: Wheel, Water, Cerulean Bell.
  - Joker combinations: Verdant Leaf, Crimson Heart.
  - Economy: Ox, Tooth.
  - Hard hands or Burglar: Mouth, Fish.
  - "relatively weak and relying on multiple hands": Needle, Wall, Violet Vessel.
  - Big hand size: House.
  - The Mr. Bones text adds The Psychic when hand size is below 5.
- **Community:** RazzberryMocha, CMDR Shven, Lil brekky and Mr. Tact take it against a bad boss. Hardcore Gamer: "A Boss tag can save a run". Xaelon: would not skip for "temporary" effects.
- **Skip when:** the ante's boss (visible on the blind screen) is a hard counter to your build, and you can beat the remaining Big Blind or the new boss. Never otherwise.
- **Anaglyph caveat:** a Boss tag duplicated by Doubles "has a chance to reroll into the same Boss Blind … particularly on Ante 8" [wiki Anaglyph].

### Juggle Tag
- **Effect:** +3 hand size for the next round only. Copies stack in the same round.
- **Minimum ante:** any.
- **Face value:** none in $.
- **Wiki:** counters The Manacle (net +2).
- **Community:** Goblin: "Worthless IMO on the first blind". Xaelon: not for temporary hand size. GameRant: "borderline useless". Wiki trivia: stacked with Anaglyph Doubles it can reach naneinf.
- **Skip when:** essentially never. Exception: skipping the Big Blind right before a boss where +3 hand size flips the outcome (Manacle, Psychic, or a find-5-cards hand), or stacked with Doubles.

### D6 Tag
- **Effect:** rerolls in the next shop start at $0 and rise by $1.
- **Minimum ante:** any.
- **Face value:** saves $5 per reroll with no voucher ($3 with Reroll Surplus, $1 with Reroll Glut).
- **Wiki:** "it takes 17 rerolls in 1 shop with the D6 Tag for the cost per card seen to be equal to spreading out rerolls between that shop and the one skipped". Flash Card synergy.
- **Community:** Draco18s: free reroll "never". Goblin: "net negative" at Ante 1. brickey.8: about C tier.
- **Skip when:** only if you will reroll heavily in that shop anyway (rich, hunting a key joker, Flash Card) [synthesis].

### Double Tag
- **Effect:** "Gives a copy of the next selected Tag", excluding Double. All held Doubles convert at once (malogoss, Steam, Dec 2024).
- **Minimum ante:** any.
- **Face value:** the value of the next tag.
- **Community:**
  - Draco18s: "Double tag, voucher tag: honestly almost never". DAKKA: always takes it.
  - RazzberryMocha (Mar 2025): "Would not recommend skipping for a double tag". Best targets are a skip worth about $50 or more (the Investment pair, Handy late, Economy at $40 or more), then a +3-level hand, then a Tarot pack only with several Doubles. "Joker skips: practically never worth it under any circumstance."
  - Wiki: Doubles plus Negative is the Completionist++ classic, but a "high risk strategy".
- **Skip when:** the next visible tag (often the same ante's Big tag, or next ante's tags shown in the shop since 1.0.1f) is S or A tier, and you would skip for it anyway. Never on spec. Top-up wastes Doubles.

---

## 3. The real cost of a skip

### 3.1 Formula (components all sourced; weights are mine)
Cost of skipping blind B = R + H + I + J − Rent + Shop + Scaling − Decay − ThrowbackOrSpeed, where:
- **R:** blind reward. Small = $3 on White, $0 on Red and above. Big = $4. (§1.4)
- **H:** unused hands × $1, or × $2 plus $1 per discard on Green Deck. In practice it is 0–3; Black Deck makes it at most 2 (Piot).
- **I:** interest this round = min(floor(money / 5), cap / 5). The cap is 5, 10 with Seed Money, 20 with Money Tree. Lost entirely on a skip. To the Moon adds $1 per $5 [wiki Interest].
- **J:** end-of-round and in-round money: Golden Joker, Cloud 9, Rocket, Delayed Gratification, Satellite [src `calculate_dollar_bonus`], gold cards held, Gift Card and Egg growth, To Do List, Mail-In Rebate, and similar. Lost on a skip.
- **Rent:** $3 × number of Rental jokers. **Saved** by skipping [wiki Rental]. Piot builds his whole Black-Deck Gold approach on this ("Small Blind loses you money").
- **Shop:** 2 cards, 2 packs, the reroll opportunity, a chance at the voucher (the voucher only restocks after the boss [wiki The Shop]), and planet or tarot purchases.
  - No source gives a $ figure for a shop.
  - malogoss (Sep 2024) puts R + I + H + J at "likely $10+", plus "a shop you won't visit, that could very well have offered you an arcana pack. Or actually two. Plus at least a joker, on average."
- **Scaling:** lost increments for round, hand or blind-select scalers: Ride the Bus, Green Joker, Runner, Square, Wee, Hiker, Supernova, Spare Trousers, Obelisk, Lucky Cat, Hologram, Vampire, Fortune Teller and Constellation (via shop purchases), Flash Card (rerolls), Campfire, Red Card (packs). Also the blind-select effects of Madness, Cartomancer, Riff-raff, Burglar, Marble Joker and Ceremonial Dagger [src `setting_blind` list; wiki Madness and Cartomancer note the anti-synergy with skipping].
  - Thundergod (S2, Mar 2024): "Once you get some scaling jokers, you want to play as much as you can." malogoss (S2): "Scaling jokers (square, green, bus, wee, etc...) and earning interest is crucial."
- **Decay:** skipping preserves Popcorn, Ice Cream, Turtle Bean, Ramen and Seltzer, delays Perishable debuffs [wiki Tags, Skip], and keeps Loyalty Card timing [wiki Skip].
  - Ronald Brain (Sep 2024) also skips to keep a good Ancient Joker suit before an "all [suit] debuffed" boss. Ancient Joker's suit resets at end of round [src `reset_ancient_card` at round end].
- **ThrowbackOrSpeed:** +X0.25 Throwback per skip (retroactive) and +$5 on future Speed tags.

### 3.2 Concrete numbers by situation (from the formula plus wiki values)

**Ante-1 Small Blind, Red+ stake, standard deck with $4:**
- R = 0, I = 0 (because floor(4/5) = 0), H ≤ 3 if one-shot (wiki and malogoss: "the first small blind should always be defeated in one hand only").
- Total: **about $0–3 plus one shop**, where the shop is only worth what about $7 can buy.
- Goblin: "Playing the first blind in the game, in almost all cases gives you $3 past red stake, versus $6 on white stake … you'll be at $7 in the first store instead of $10".
- Piot: "playing the Ante 1 Small Blind is rarely worth it because you only get 2$ at most" (Black Deck).
- The guaranteed Buffoon pack is not lost; it moves to the next shop (§0).
- This is the **cheapest skip in the game**. Even the strict camp (RazzberryMocha, Goblin) accepts skipping it for Coupon or Investment.

**Ante-1 Small Blind, White stake:** add $3, so about $3–6 plus a shop. Yellow Deck ($14) also loses $2 interest.

**Green Deck:** a one-shot Small Blind pays $6 from hands plus $3 from discards ($2 on Blue+), with no interest. Skips cost more than on other decks [computed from wiki Money].

**Ante-1 Big Blind:**
- $4 + H + interest (usually $0–1) plus **the shop before the first boss**.
- You face the boss (600 chips) with whatever you have. If both ante-1 blinds are skipped, you face it with no shop at all.
- Goblin: "God forbid you're one of those double skippers, banking entirely on beating the boss jokerless".
- Headywon (Mar 2024) called double-skipping Ante 1 "reasonable" but warned of "two free Eternal jokers" at Black+.

**Mid game (Ante 3–6), Red+, interest capped:**
- Small: about $5 interest + $0–3 hands + J − rent, so **roughly $6–12 plus a shop** [estimate].
- Big: add $4.
- The shop is worth more now: more money to spend, and xMult or scaling pieces are needed (Guide: General strategy, mid-game section).

**Late game (Ante 7–8):** the money matters less, but every shop is a chance at the final xMult. Scaling jokers lose increments. Skip mainly to change the boss (Boss tag), for Negative, or for an Orbital on the main hand [synthesis].

### 3.3 Small vs Big, and the "same deck" risk
- Skipping Small means facing the Big Blind (1.5× base) with no new shop. Shop tags pay after the Big Blind.
- Skipping Big means facing the boss (2× base, or 4× The Wall, 6× Violet Vessel, plus its effect) with no shop. Shop tags pay only after the boss.
- Hence the near-consensus: **Small skips are much cheaper than Big skips** [synthesis of Piot, Goblin, wiki Negative Tag].

**Explicit confidence guidance (the rule the user asked about):**
- Baka Piot, "A guide to Black Deck Gold Stake" (2025):
  - "From my experience, if you can beat Small Blind, you can probably beat Big Blind more often than not."
  - "Consider NOT skipping Ante 2+ Small Blind if: You're unsure whether you can beat Big Blind (since it's no longer a two-shot beyond Ante 1) / The skip reward kinda stinks and rentals won't drag you down too much / You want to visit shops (mainly because you need new Jokers)".
  - "Consider skipping Ante 2+ Small Blind if: You're low on money and have no econ in your build … or a rental Joker in your build / The skip reward kinda rocks and there's no particular reason to play the blind".
  - Source: https://steamcommunity.com/sharedfiles/filedetails/?id=3535175222
- Wiki Negative Tag: "imperative that the current Joker build can accommodate for missing a Shop and the bigger Blind requirements, especially on higher stakes."
- Wiki Anaglyph: "keep in mind that you need to survive until the next shop (or longer) to see any real benefit while the blinds continue scaling exponentially."

### 3.4 Stakes
- **Red+:** the Small Blind pays $0. That is the main reason Small skips become cheaper (Paradigm, Mar 2024: "Red Stake makes early small blinds not worth dealing with at all"; Amplify; Lemmy user hexabs: "On higher stake difficulties the small blind doesn't provide a reward so skipping the first small blind makes sense if the reward is good").
  - Counterpoint (Goblin): you still get hand money, joker money, gold cards and the shop.
- **Green / Purple+:** faster scaling. The wiki's Investment caveat says skipping a shop becomes unaffordable at Purple+. Purple is "the biggest difficulty bump" (malogoss).
- **Blue+:** −1 discard, which reduces Garbage tag value.
- **Black+:** tag jokers can be Eternal (30%). Black+ joker tags lose value because a bad Eternal joker blocks a slot (Headywon; wiki).
- **Orange+:** Perishable (30%). Skipping preserves Perishable jokers [wiki Tags].
- **Gold:** Rental (30%).
  - A tag joker that is Rental costs $3 per round and sells for $1.
  - Skipping saves the rent [wiki Rental; Piot].
  - Top-up becomes relatively better because its jokers have no stickers [wiki Top-up].
  - The wiki Skip page says skipping is "especially detrimental on Gold Stake, where economy, interest, and shop visits are vital to success".
- **Disagreement:** Piot (Gold, Completionist++ grinder) argues the opposite for early Small Blinds: "More often than not, skipping early Small Blinds is optimal. It could give you money, a free Joker, a free booster pack, or even a free shop."

---

## 4. How often strong players skip, and tier lists

**No dataset of skip rates or win rates exists in anything I could open.** The available evidence is self-reports:
- malogoss (prolific Steam helper, Gold winner), Mar 2024: "The higher the stake, the less I skip. At gold, 3-5 skips per run, rarely more."
- malogoss, Sep 2024: "At gold stake I'll often end runs skipping 0 or 1 blind total."
- A bear: "I think I play about 98% of the time". FeloniousMont: "99% playing blinds". PusherPlayer: "Never Skip (unless anaglyph)". All Mar 2024.
- WitchPHD (all-deck Gold, Completionist++, Dec 2025): rarely skips; only Negative, Investment, and an occasional early Polychrome.
- Baka Piot (Gold, Completionist++ grinder, 2025): skips most early Small Blinds, especially on Black Deck.
- Restart culture: several Gold players restart until the Ante-1 tag is good.
  - Dollop of Mayo (Mar 2024): "I restart if I don't get a good benefit from the first small blind and skip".
  - Mancunion: restarting for a round-1 Investment is "one of the more reliable ways" to win Black Deck.
  - Hardcore Gamer: "re-roll for good tags in Ante 1".
  - Caution for the mod [synthesis]: this inflates how often Ante-1 skips appear in winning runs.
- Speedrunner achievement: requires skipping at least 12 blinds in an 8-ante run [wiki Speedrunner]. That is a different objective.

**Tier lists found:**
- Amplify (Steam, 9 Mar 2024, pre-1.0.1f, first skip only): S = Free Shop (Coupon), Holographic. A = Foil, Poly, Uncommon. B = Rare, Mega Tarot (Charm). F = every other Ante-1 tag. https://steamcommunity.com/app/2379780/discussions/0/4293690852344075764/
  - brickey.8 in the same thread: Investment and Double around A/B, D6 around C.
- JudgeTy (Steam, Mar 2024, pre-1.0.1f) put $ values on Small-Blind skips: "Speed ($5), Coupon ($10-$20), Ethereal ($6), Buffoon ($8?), Meteor ($7-8?), Charm ($7-8?), Standard ($7-8?), Investment ($15), Polychrome(~$6+), Holographic(~$5+), Foil (~$5+), Negative (~$5+), Orbital (~$6+) Rare (~$5+), Uncommon (~$5+), D6 ($5), Top-up (~$5-8)".
  - Goblin rebutted it point by point ("What an equivalent would cost does not mean that's what it gives you in value"). https://steamcommunity.com/app/2379780/discussions/0/4293691486113242157/?ctp=4
- Wiki Guide: General strategy, "Early Game Skipping": Holographic, Investment, Buffoon, Coupon, Orbital ("If on a desired hand type").
- Hardcore Gamer (8 Oct 2024; article, not a pro): Negative > Coupon > Polychrome > Rare > Uncommon > Holographic > Foil > Buffoon > Ethereal > Orbital.
  - It describes the Mega Buffoon pack as "choose 2 of 5", but the wiki says 4.
- GameRant (5 May 2025): ranks the bottom 10 as Juggle (24), Standard, Meteor, Foil, Top-up, Holographic, Orbital, Speed, Garbage, Handy (15). The top 14 were not in the fetched content.
- Balatro University: two skip-tag tier-list videos exist, including one updated for the 1.0.1 patch. Their content could not be retrieved; Steam users recommend them (YoruHawk, Apr 2024).

---

## 5. Special cases
- **Speed tag:** $5 × skips including itself, uncapped. It beats Investment after 5 skips and Economy after 8 [wiki]. Value it from the number shown on the tag. It is weak as the first skip (+$1–2 net on a Red+ Ante-1 Small Blind, per Goblin).
- **Juggle:**
  - It applies to the next round played. To use it on a boss, it must come from the Big Blind skip, or from a Small skip followed by a Big skip.
  - All copies stack in one round. One Juggle against The Manacle nets +2 hand size [wiki].
- **D6 with planned rerolls:** worth it only if you will reroll many times in that shop. The wiki's break-even is 17 rerolls in one D6 shop versus spreading them across two shops (no Reroll Surplus). Flash Card synergy.
- **Boss tag:** use it only when you see the hard-counter boss on the blind screen (§2 list).
  - The Wall: 4× and Violet Vessel: 6× punish weak multi-hand builds. The Needle allows 1 hand. The Psychic is a problem with hand size below 5. The Pillar debuffs cards played earlier this ante [wiki].
  - Director's Cut interaction and Ante-8 showdown reroll as in §2.
- **Orbital before The Arm:** The Arm lowers the played hand by one level. +3 levels on the main hand offsets it (Hardcore Gamer tip). Orbital's hand is visible before you skip.
- **The Pillar:** "Skipping both the Small Blind and the Big Blind would result in no debuffed cards." [wiki The Pillar] The Pillar can appear from Ante 1.
- **Double stacking:**
  - Doubles copy the next tag; all held Doubles convert at once.
  - Anaglyph Deck (unlocked by a Black-stake win) gives a Double after each boss. Wiki: stack them and dump on Negative, or on immediate-payoff tags like Charm or Ethereal. Its example is Ante 5 with 4 Doubles, giving 25 tarots seen and 10 used.
  - Wiki warning: the deck's "primary downside … is the rarity of tags worth skipping for". Top-up wastes Doubles.
  - Mancunion: wait until about Ante 5–6, then use them on Investment, Economy, Handy or Ethereal; avoid Negative at Gold because of stickers.
  - WitchPHD: "you don't know if you'll get a good skip tag later in the run".
  - Diet Cola: selling it gives a Double; "in effect, a $3 Double Tag". A Rental Diet Cola on Gold is a free Double [wiki Diet Cola].
- **Throwback:** +X0.25 per skipped blind, retroactive (counts skips made before you owned it) [wiki Throwback]. It pairs with flat +Mult and early-power jokers, and conflicts with Hologram, Vampire, Supernova and Madness. Hieroglyph and Petroglyph add extra skippable blinds.
- **Red Card:** this is about skipping *booster packs*, not blinds. It gives +3 Mult per skipped pack, once per Mega pack. The wiki advises not skipping packs just to scale it. Tag-opened packs (Charm, Meteor, Buffoon, Standard, Ethereal) still count [wiki Red Card].
- **Cartomancer, Madness, Riff-raff, Burglar, Marble Joker, Ceremonial Dagger:** these trigger "when Blind is selected", so a skip gives them nothing [src]. The wiki notes the anti-synergy for Cartomancer and Madness.
- **Food and Perishable jokers:** skipping extends their life [wiki Tags, Skip, Throwback].
- **Rental jokers (Gold):** each skip saves $3 per Rental joker [wiki Rental].
- **Loyalty Card:** skip timing can align its trigger [wiki Skip].
- **Ancient Joker:** a skip keeps the current suit (Ronald Brain).

---

## 6. Cerulean Bell (verification requested)

Exact wiki text (https://balatrowiki.org/w/Cerulean_Bell, raw):
- "**Cerulean Bell** is a Showdown Blind that forces a random playing card to always be selected. If there's no force-selected card in the player's hand after playing or discarding, a new random playing card will be chosen."
- "The player can still discard the forcefully selected playing card, though it would result into another playing card to be forcefully selected instead."
- "The Hanged Man is a great way to deselect the card by destroying it, letting the player freely select other cards for the given hand."
- "Smaller poker hands like Pair may have an easier time with this blind, since non-scoring cards that are selected will have no effect on your played hands."

Answers:
1. **Is the forced card discarded along with the others? Yes.**
   - The wiki does not say this in one sentence. It follows from "always be selected" plus "can still discard the forcefully selected playing card": a discard sends every selected card, and the forced card cannot be deselected.
   - [src 1.0.1o] confirms it:
     - `CardArea:remove_from_highlighted` refuses to unselect a `forced_selection` card in hand.
     - `G.FUNCS.discard_cards_from_highlighted` (and `play_cards_from_highlighted`) first clear `forced_selection` on all playing cards, then discard (or play) everything highlighted, including the forced card.
     - The same applies to playing a hand: the forced card is always part of the played hand.
2. **Is a new card forced after the draw? Yes.**
   - After drawing back up, `Blind:drawn_to_hand()` runs. If no card is forced, it unhighlights everything, picks a random card from the *current* hand (which may be a newly drawn card), and force-selects it.
   - Because play and discard always clear the flag, a new forced card is chosen after every play or discard. That matches the wiki's "after playing or discarding" wording.
3. **At most 4 other cards? Yes, but this is not stated on the Cerulean Bell page.**
   - The hand selection limit is 5: [wiki Discards] "the player selects up to 5 cards"; [src] `CardArea` `highlighted_limit = 5`.
   - The forced card occupies one of the 5, so at most 4 others can be selected for a play or discard.
   - Consumables that act on selected cards also see the forced card; The Hanged Man can destroy it [wiki The Hanged Man].

---

## 7. Proposed decision rules for the mod (synthesis; numbers marked [estimate])

1. **Compute the skip cost** with §3.1. Use the live values for R, H, I, J and rent.
   - Add a shop value: about $4–8 at Ante 1–2, $8–15 at Ante 3–6, $10–20 at Ante 7–8 [estimate].
   - Raise the shop value when joker slots are empty, there is no xMult yet, or a key piece is missing. Lower it when money is below about $5 (cannot buy) or the build is complete.
   - Add a scaling-loss term per owned round, hand or blind-select scaler [estimate: $2–5 each mid game].
2. **Compute the tag value.**
   - Use the shown $ for Economy, Speed, Handy and Garbage, and $25 for Investment.
   - Free jokers: face value counts only partly. Use about 60–100% of the full price if it is likely to be kept, and the sell value (floor of full price / 2) as the floor [estimate].
   - Pack tags: $8 for Mega packs, $4 for Ethereal, scaled by fit.
   - Orbital: about $9 if it is the main hand, else 0.
   - Boss: high only when the current boss is a hard counter.
   - Double: equal to the next visible tag's value.
   - Black+: multiply joker-tag value by about 0.7 for sticker risk; Gold: subtract rent for a possible Rental [estimate].
3. **Survival gate.** Before a skip, check that the current build beats the next blind with margin: about 1.3× the Big Blind requirement if skipping Small, about 1.5× the Boss requirement and no hard-counter effect if skipping Big [estimate].
   - Immediate tags (Buffoon, Top-up, Charm, Orbital, Meteor, Ethereal, money) may count toward the check. Shop tags may not.
4. **Default skips** (the user is right that the current rule is too strict):
   - Ante-1 Small Blind (any stake, especially Red+): skip for Investment, Coupon, Polychrome, Holographic. Also Uncommon, Rare and Foil when no joker is held yet. Charm is optional.
   - Ante 2–4 Small Blind: skip for Investment, Negative, Polychrome, Coupon, Buffoon (if slots are open), Orbital on the main hand, Economy when money is at least $20, Boss against a hard counter, Top-up with at least 2 empty slots on a weak board, and Speed or Handy when the shown value is at least about $15–20.
   - Big Blind: skip only for a Boss tag against a hard counter, against The Pillar (skip both), with Throwback or Anaglyph plans, or for S-tier tags when the survival gate passes comfortably.
   - Ante 5+: skip mostly for Boss (counter), Negative (if slot-limited), Orbital on the main hand, or Double-stack payoffs. Money tags only if the build is short on cash.
   - Never: Juggle, D6, Voucher or Double without a specific plan; Standard; Top-up with full slots; Economy while in debt; Orbital on an unused hand.
5. **Modifiers:**
   - Each Rental joker adds $3 in favour of skipping.
   - Decaying or Perishable key jokers and Throwback favour skipping.
   - Owned scalers, blind-select jokers (Cartomancer, Madness, Riff-raff, Burglar), econ jokers, gold cards and Green Deck favour playing.

---

## 8. Compact table
Tiers are **my synthesis**: S = skip almost whenever offered in its window; A = usually skip if the conditions hold; B = situational; C = rarely; never = do not skip for it alone.

| Tag | Effect (wiki) | Min ante | Tier | Skip when | Sources |
|---|---|---|---|---|---|
| Investment | +$25 after beating the boss; stacks | 1 | S (Ante 1–3), B later | Early, especially Small Blind on Red+; later only if money is below about $25 | wiki Investment_Tag; RazzberryMocha (S5); Mancunion; HardcoreGamer Gold; WitchPHD; Addison |
| Coupon | First shop's cards and packs free (not vouchers or rerolls) | 1 | S (Ante-1 Small), A early, C late | Ante 1–2, little money | wiki Coupon_Tag, Guide; S5, S6, S3, S4; Piot; title-only dissent: Balatro University "Coupon Tag is SO bad" |
| Polychrome | Next base shop joker free + Poly (X1.5) | 1 | A | Ante 1–4 Small Blind, next blind beatable | wiki Polychrome_Tag; S1 Draco18s; S8 Moray Eel; WitchPHD; S4 |
| Holographic | Next base shop joker free + Holo (+10 Mult) | 1 | A early, C late | Ante 1–2 Small Blind | wiki Guide early list; S4 Amplify; S5 |
| Negative | Next base shop joker free + Negative (+1 slot) | 2 | A (S with Doubles) | Ante 2–6, build survives a missed shop; full slots | wiki Negative_Tag; S1, S2; WitchPHD; dissent Ronald Brain (S9), Mancunion (Gold Anaglyph) |
| Foil | Next base shop joker free + Foil (+50 Chips) | 1 | B (A on Plasma early) | Ante-1 Small Blind with no joker; Plasma | wiki Foil_Tag; S4 |
| Uncommon | Free Uncommon joker in one shop slot | 1 | B | Ante-1 Small Blind on Red+ with no better tag | wiki Uncommon_Tag; S4; S8 |
| Rare | Free Rare joker in one shop slot (can NOPE) | 1 (needs Blueprint discovered) | B | Ante 1–3 Small Blind with slot room; high variance | wiki Rare_Tag; S4; S5/S6 dissent |
| Economy | Double money, max +$40; $0 in debt | 1 | A if money ≥ $20, C if poor | Money ≥ about $20–40; Yellow Deck at Ante 1 | wiki Economy_Tag, Yellow_Deck; S2 srn347; HardcoreGamer Gold |
| Speed | $5 × skips this run (includes itself) | 1 | C first skip; A with ≥5 skips | Shown value ≥ about $20, or with Throwback | wiki Speed_Tag; S3/S10 Goblin |
| Handy | $1 × hands played this run | 2 | B (by shown value) | Shown value ≥ about $15–20 [estimate] | wiki Handy_Tag; Mancunion; S7 |
| Garbage | $1 × unused discards this run (less on Blue+) | 2 | C (by shown value) | Same rule as Handy | wiki Garbage_Tag |
| Orbital | +3 levels to the hand shown on the tag | 2 | A on main hand, never otherwise | Main hand; before The Arm or Flint | wiki Orbital_Tag, Guide; S2; HardcoreGamer Gold |
| Buffoon | Free Mega Buffoon (2 of 4), immediate | 2 | B (A if slots open early) | Ante 2–3, weak lineup | wiki Buffoon_Tag, Guide; S3 Goblin |
| Top-up | Up to 2 sticker-free Commons, needs slots | 2 | B (Gold, Black Deck, empty board), never with full slots | At least 2 empty slots, no scoring jokers | wiki Top-up_Tag, Black_Deck |
| Charm | Free Mega Arcana (2 of 5); only pack tag in Ante 1 | 1 | C/B | Ante-1 Small Blind on Red+, or with Doubles | wiki Charm_Tag, Anaglyph, Completionist++; Piot; dissent malogoss (S9) |
| Ethereal | Free Spectral Pack (1 of 2) | 2 | C | With Doubles, or a specific Spectral need | wiki Ethereal_Tag; Mancunion |
| Meteor | Free Mega Celestial (2 of 5) | 2 | C | Constellation, or main hand with Telescope | wiki Meteor_Tag; S3 |
| Standard | Free Mega Standard (2 of 5 playing cards) | 2 | never/C | Hologram only | wiki Standard_Tag; S3 |
| Voucher | +1 purchasable voucher next shop | 1 | C/never | Rich and hunting a specific voucher | wiki Voucher_Tag; S1; S5 |
| Boss | Reroll this ante's boss (Ante 8 stays a showdown) | 1 | S vs hard counter, never otherwise | Visible boss counters the build | wiki Boss_Tag, Mr._Bones list, Director's_Cut; S5, S7; HardcoreGamer Gold |
| Juggle | +3 hand size next round | 1 | never (rare exceptions) | Big Blind skip before Manacle or Psychic; Double stacks | wiki Juggle_Tag, The_Manacle; S3 |
| D6 | Next shop rerolls start at $0 | 1 | C/never | Heavy reroll plan, Flash Card, rich | wiki D6_Tag; S1; S3 |
| Double | Copy of the next tag (not Double) | 1 | = next tag's tier | Next visible tag is S/A; Anaglyph or Diet Cola plans | wiki Double_Tag, Anaglyph_Deck, Diet_Cola; S7 RazzberryMocha; S1 |

### Source key
- **Wiki** (balatrowiki.org/w/...): Tags, Skip, Guide:_General_strategy, each `<Name>_Tag` page, The_Shop, Money, Interest, Small_Blind, Big_Blind, Red_Stake, Blinds_and_Antes, Rental, Perishable, Eternal, Throwback, Anaglyph_Deck, Diet_Cola, The_Pillar, Red_Card, Cartomancer, Madness, Mr._Bones, Director's_Cut, The_Manacle, Yellow_Deck, Black_Deck, Speedrunner, Guide:_Completionist++, Updates, Update_1.0.1f, Update_1.0.1m, Cerulean_Bell, Discards, The_Hanged_Man.
- **src:** the game's Lua code, version 1.0.1o (tag.lua, blind.lua, cardarea.lua, card.lua, game.lua, functions/state_events.lua, functions/UI_definitions.lua, functions/common_events.lua), read during the research; not included here.
- **Steam discussions:**
  - S1 "When to skip?" (25 Mar 2024): https://steamcommunity.com/app/2379780/discussions/0/4294818447590775533
  - S2 "How often do you like to skip versus play the blinds?" (31 Mar 2024): https://steamcommunity.com/app/2379780/discussions/0/4357869401130629356
  - S3 "Gold Stake is such a horrific slot machine grindfest" (Mar 2024): https://steamcommunity.com/app/2379780/discussions/0/4293691486113242157 (pages ?ctp=2 to 4)
  - S4 "Best starting tags?" (9 Mar 2024): https://steamcommunity.com/app/2379780/discussions/0/4293690852344075764/
  - S5 "The higher difficulties are insufferable." (13 Dec 2024): https://steamcommunity.com/app/2379780/discussions/0/575994948960141267
  - S6 "there is no RNG…" (page 2; date not captured, post-patch content): https://steamcommunity.com/app/2379780/discussions/0/596265345117862261/?ctp=2
  - S7 "Double Tag" (18 Mar 2025): https://steamcommunity.com/app/2379780/discussions/0/828205063835017417
  - S8 "How to get a good run?" (23 Dec 2024): https://steamcommunity.com/app/2379780/discussions/0/604143386282188848
  - S9 "I'm bad at this game help." (9–11 Sep 2024): https://steamcommunity.com/app/2379780/discussions/0/4756452715167149899/
  - S10 "Well it was a game" (11 Mar 2024): https://steamcommunity.com/app/2379780/discussions/0/4308327178393725233/?ctp=7
  - S11 "I'm never gonna get past orange stake" (7 Apr 2024): https://steamcommunity.com/app/2379780/discussions/0/4356744017103053782
  - S12 "What is Double Tag?" (malogoss reply, 20 Dec 2024): https://steamcommunity.com/app/2379780/discussions/0/4201364982091817785
- **Steam guide:** Baka Piot, "A guide to Black Deck Gold Stake" (posted 26 Jul 2025): https://steamcommunity.com/sharedfiles/filedetails/?id=3535175222
- **Articles:**
  - WitchPHD (19 Dec 2025): https://witchphd.substack.com/p/balala
  - Mancunion (1 Sep 2025): https://mancunion.com/2025/09/01/a-guide-to-gold-stake-balatro/
  - Addison Kindrick (4 Jan 2025): https://addisonkindrick.substack.com/p/10-balatro-tier-list-addendum
  - Hardcore Gamer, Gold tips (15 Apr 2025): https://hardcoregamer.com/ten-tips-for-dominating-gold-stake-in-balatro/
  - Hardcore Gamer, best tags (8 Oct 2024): https://hardcoregamer.com/balatro-best-tags/
  - GameRant (5 May 2025): https://gamerant.com/balatro-best-worst-every-tag/
  - Lemmy, hexabs: https://lemmy.world/comment/24572109
- **Snippet only:**
  - GameFAQs "Tip: Skip tags are traps in most cases": https://gamefaqs.gamespot.com/boards/407420-balatro/81184260. The snippet says the only non-traps are "an early (Ante 1) Investment Tag and on some specific runs, Double, Juggle, and Voucher tags", and mentions a Balatro University valuation of one tag at $40.
  - Twinfinite: https://twinfinite.net/guides/should-you-skip-blinds-in-balatro/
  - TierMaker community lists.
- **YouTube (titles only):** Balatro University videos Lx2bAMdKwIs, q4YAHDuRUcQ, NXttotDW4LY, RvhjDvaZnHM, iNoj0zqaRZo.
