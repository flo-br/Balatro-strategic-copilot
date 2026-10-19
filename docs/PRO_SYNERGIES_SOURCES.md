<!-- Recherche sourcée (en anglais) utilisée pour les synergies des builds de la version 1.0.8 : model/builds_db.lua, engine/builds.lua, docs/PRO_LESSONS.md §7. -->

# Balatro: run-winning synergies and build archetypes (research for the strategy mod)

Compiled 2026-10-18 for the Balatro strategic copilot mod. Target: vanilla PC Balatro. balatrowiki.org says it is current with **1.0.1o (Friends of Jimbo 4)**, so the joker numbers below are 1.0.1-era values.

## Legend and source quality

- **[wiki]**: read on a balatrowiki.org page I opened. Use these numbers as authoritative.
- **[computed]**: arithmetic I did from wiki rules. The formula is shown so it can be checked.
- **[estimate]**: my judgement or a synthesis. It is not a number from the game or a source.
- **[snippet]**: seen only in a search-engine snippet. I could not open the page.
- **[community]**: an opinion from a player or guide writer (Steam thread, article). Treat it as a strength or popularity signal, not a mechanic.
- **[inference]**: a game-mechanics inference that the fetched pages do not state outright.

**Reddit coverage limitation.** WebFetch refuses reddit.com outright. WebSearch refuses `allowed_domains: reddit.com` (user-agent block). The redlib mirrors I tried returned 503 or a bot wall. So r/balatro reaches this file only three ways:
- one Reddit cross-post mirror on rblind.com, about the Balatro University "pairs are better" video;
- Steam threads where players relay Reddit or Balatro University (BU) advice;
- secondary articles.

Every other community signal here comes from Steam discussions, guide writers and tier lists.

**Source quality ranking, as used below:**
1. balatrowiki.org pages. Mechanics and listed synergies.
2. Steam threads where the poster states experience. Most useful is mangonaise, who got Completionist++ twice, with Gold Stake wins on every deck.
3. Guide writers who state Gold-Stake credentials: the Mancunion Gold Stake guide, Superjump, and the Addison Kindrick tier-list addendum.
4. Generic articles and tier lists: Choost, SteelSeries, Two Average Gamers, Switchblade, comicbook, games.gg, earlyguides. Several contain arithmetic or mechanics errors, noted where relevant.

---

## 0. Mechanics that decide which synergies matter

### 0.1 Score targets you must beat (wiki)
Base chips by Ante, from https://balatrowiki.org/w/Blinds_and_Antes. Small Blind is x1, Big Blind x1.5, Boss x2 (The Wall x4, Violet Vessel x6, The Needle x1). Plasma Deck doubles every value.

| Ante | White/Red | Green/Black/Blue | Purple/Orange/**Gold** |
|---|---|---|---|
| 5 | 11,000 | 20,000 | 25,000 |
| 6 | 20,000 | 36,000 | 60,000 |
| 7 | 35,000 | 60,000 | 110,000 |
| 8 | 50,000 | 100,000 | 200,000 |

[computed] At Gold Stake, the Ante 8 targets are:
- Small Blind 200k, Big Blind 300k, a normal boss **400k**.
- The Wall 800k. **Violet Vessel 1.2M**, which mangonaise treats as "the final boss" for planning.
- Ante 6 to Ante 8 multiplies the requirement by about 3.3x.

Stake rules ([wiki] https://balatrowiki.org/w/Stakes, cumulative):
- Red: Small Blind gives no reward money.
- Green: faster scaling.
- Black: Eternal jokers.
- Blue: **-1 discard**.
- Purple: faster scaling again.
- Orange: Perishable jokers, debuffed after 5 rounds.
- Gold: Rental jokers at $3 per round.

Older posts say Gold Stake gives "-1 hand size" (DigitalTrends [snippet]; Steam posts from 2024). The current wiki lists Rentals for Gold instead, so treat the hand-size claim as a pre-1.0.1 rule [inference].

### 0.2 Poker hand base values and per-level growth (wiki https://balatrowiki.org/w/Poker_Hands)

| Hand | Base chips/mult | Gain per level | Planet |
|---|---|---|---|
| High Card | 5 / 1 | +10 / +1 | Pluto |
| Pair | 10 / 2 | +15 / +1 | Mercury |
| Two Pair | 20 / 2 | +20 / +1 | Uranus |
| Three of a Kind | 30 / 3 | +20 / +2 | Venus |
| Straight | 30 / 4 | +30 / +3 | Saturn |
| Flush | 35 / 4 | +15 / +2 | Jupiter |
| Full House | 40 / 4 | +25 / +2 | Earth |
| Four of a Kind | 60 / 7 | +30 / +3 | Mars |
| Straight Flush | 100 / 8 | +40 / +4 | Neptune |
| Five of a Kind | 120 / 12 | +35 / +3 | Planet X |
| Flush House | 140 / 14 | +40 / +4 | Ceres |
| Flush Five | 160 / 16 | +50 / +3 | Eris |

[computed] Flush gains only +15 chips/+2 mult per level, against +30/+3 for Straight and Four of a Kind. This is one mechanical reason sources say flushes "scale slower in the late game" (Superjump).

Pair and High Card scale weakly from levels. Builds on those hands get their score from jokers and held effects instead: "By getting all of your score from jokers, you don't need high scoring hands" (ui.lemm.ee guide [snippet]).

### 0.3 Scoring order (wiki https://balatrowiki.org/w/Scoring)
1. Boss effect, then "on played" jokers (Midas Mask, Space Joker and similar).
2. **Played scoring cards, left to right.** For each card: its chips, then enhancement, seal and edition, then "on scored" jokers left to right (Photograph, Smiley Face, Bloodstone, Triboulet...). Retriggers repeat this whole sequence for the card.
3. **Held-in-hand, left to right.** Steel enhancement, then "on held" jokers (Baron, Shoot the Moon, Raised Fist, Reserved Parking), then retriggers: Red Seal first, then Mime and any Mime copy.
4. **Jokers, left to right.** Foil/Holo edition, then the joker's independent effect, then jokers that depend on other jokers (Baseball Card), then the Polychrome edition.
5. Observatory planets (X1.5 each) come after all jokers.

What this order means for the mod:
- **xMult goes right of +Mult among jokers.** Multiple Steam posts say this, as do Two Average Gamers and Blizzard Watch.
- **Baron and Steel xMult fire before every independent joker** [inference from the order above]. So a flat +Mult joker such as Joker (+4) or Gros Michel is not multiplied by Baron or Steel. In a Baron/Steel build, the +Mult that gets multiplied comes only from:
  - hand level base mult;
  - played-card effects (Mult cards, Smiley Face, Fibonacci);
  - held Queens with Shoot the Moon, or Raised Fist, placed left of the Kings or Steel cards.

  The wiki says this directly: Steel cards "score before Jokers, so a higher base Mult from Planet cards or Jokers that add Mult on scoring helps" (W:Steel_Joker). It also says Shoot the Moon or Raised Fist Queens must sit left of the Kings (W:Baron).
- **Within the played hand**, cards resolve left to right.
  - Hanging Chad wants the power card **leftmost** (W:Hanging_Chad).
  - Photograph alone wants face cards **right** of other scoring cards, so it multiplies their +Mult (W:Photograph).
  - Glass cards go **rightmost**, unless Hanging Chad is running (W:Glass_Card).
- **Red Seal is not itself retriggered** by Hack, Sock and Buskin, Seltzer, Dusk, Hanging Chad or Mime. A Red Seal card gets exactly one extra trigger (W:Red_Seal, W:Mime, W:Hanging_Chad).
- **Blueprint and Brainstorm copies apply at the copier's slot** [inference]. Brainstorm can therefore sit rightmost and still apply the copied xMult last, even though its target must be leftmost.

### 0.4 Card modifiers (wiki https://balatrowiki.org/w/Card_Modifiers)

| Modifier | Effect |
|---|---|
| Bonus | +30 chips |
| Mult | +4 Mult |
| Wild | counts as every suit |
| Glass | X2 Mult, 1 in 4 chance to be destroyed |
| Steel | X1.5 Mult while held |
| Stone | +50 chips, no rank or suit |
| Gold | $3 if held at end of round |
| Lucky | 1/5 chance of +20 Mult, 1/15 chance of $20 |
| Foil / Holo / Poly editions | +50 chips / +10 Mult / X1.5 Mult |
| Negative edition | +1 slot |
| Gold Seal | $3 when played and scored |
| Red Seal | retrigger once |
| Blue Seal | when held at end of round, creates the Planet for the final hand |
| Purple Seal | when discarded, creates a Tarot |

Tarots ([wiki] https://balatrowiki.org/w/Tarot_Cards):

| Tarot | Effect |
|---|---|
| Magician | Lucky, 2 cards |
| Empress | Mult, 2 cards |
| Hierophant | Bonus, 2 cards |
| Lovers | Wild, 1 card |
| Chariot | Steel, 1 card |
| Justice | Glass, 1 card |
| Devil | Gold, 1 card |
| Tower | Stone, 1 card |
| Strength | +1 rank, up to 2 cards |
| Hanged Man | destroys up to 2 cards |
| Death | converts the left card into a copy of the right card |
| Star / Moon / Sun / World | up to 3 cards to Diamonds / Clubs / Hearts / Spades |
| High Priestess | 2 Planets |
| Emperor | 2 Tarots |
| Fool | copies the last Tarot or Planet used |
| Hermit | doubles money, max $20 |
| Temperance | joker sell value, max $50 |
| Wheel of Fortune | 1/4 chance of Foil/Holo/Poly on a random joker |
| Judgement | random joker |

Spectrals ([wiki] https://balatrowiki.org/w/Spectral_Cards):

| Spectral | Effect |
|---|---|
| Familiar | destroy 1 random card, add 3 enhanced face cards |
| Grim | destroy 1, add 2 enhanced Aces |
| Incantation | destroy 1, add 4 enhanced number cards |
| Talisman | Gold Seal |
| Aura | Foil, Holo or Poly on a card |
| Wraith | random Rare joker, money set to $0 |
| Sigil | whole hand to one random suit |
| Ouija | whole hand to one random rank, -1 hand size |
| Ectoplasm | Negative on a random joker, hand size -(1 + previous uses) |
| Immolate | destroy 5 random cards, +$20 |
| Ankh | copy a random joker, destroy the others |
| Deja Vu | Red Seal |
| Hex | Poly on a random joker, destroy the others |
| Trance | Blue Seal |
| Medium | Purple Seal |
| Cryptid | 2 copies of 1 selected card |
| The Soul | Legendary joker |
| Black Hole | +1 level to every hand |

- The Soul has a 0.3% chance to replace each card in Arcana or Spectral packs (W:Triboulet).
- Shop rarity odds: Common 70%, Uncommon 25%, Rare 5% (Choost). These match my game knowledge but were not re-checked on the wiki.

---

## 1. General rules top players give (with sources)

1. **Build a chips + Mult base first, then stack xMult for Antes 7-8.**
   - Wiki General strategy (Antes 1-2 early, 3-6 mid, 7-8 late): "Be on the look out for XMult Joker, these are important to boost your score in Ante 7 and 8." Also: "Always have at least one +Chip Joker, one +Mult Joker."
   - Superjump: "Do not worry about X-Mult until you have the chips and +Mult."
   - The ui.lemm.ee guide, by a player who says they beat every deck on every stake, recommends "one joker focused on lots of chips, one or two jokers focused on +mult, and then jokers giving xmult" [snippet]. DigitalTrends gives the same split for Gold Stake [snippet].
   - Two Average Gamers: chips and flat mult stop mattering around Ante 5.
   - Steam (Zaga): "X-mult jokers ... scale much better than +mult jokers later." Another poster: xMult "does need something to multiply" [snippet].
   - [computed illustration] A level-8 Pair (115 chips, 9 mult) plus about 20 chips from cards and +20 Mult from jokers gives about 3.9k. One X3 makes 11.7k. A 400k Gold Stake boss needs roughly X100 on top, which is why every winning archetype below has an **exponential** source:
     - several xMult jokers that multiply each other;
     - retriggered per-card xMult (Photograph, Triboulet, Glass, Baron/Steel);
     - stacking planets with Observatory.
2. **Order matters.**
   - Jokers trigger left to right, so put xMult at the far right (Steam "How to win?" thread; Two Average Gamers; Superjump; Blizzard Watch).
   - Blueprint goes directly left of its target. Brainstorm copies the leftmost joker (W:Blueprint, W:Brainstorm).
   - Put Lusty Joker left of Bloodstone, and Riff-Raff left of Madness (Blizzard Watch).
   - With held cards, put Queens (Shoot the Moon) and the lowest card (Raised Fist) left of Steel cards and Kings (W:Shoot_the_Moon, W:Raised_Fist, W:Steel_Card).
3. **Pick one or two hands and commit, and level them.**
   - Wiki: in the mid game (Antes 3-6) "it's time to pivot your build into one or two specific hands type."
   - PC Gamer tips [snippet]: "zeroing in on one is usually the path of least resistance."
   - Supernova, Card Sharp, Spare Trousers, Telescope and Constellation all reward commitment. Obelisk is the exception: it rewards rotating hands.
4. **Do not force a build. Let the shop decide early.**
   - Steam (RazzberryMocha, 300+ hours mostly at the top stake): "hard committing to the first 'good' option you are given" is "the largest noob trap in the entire genre."
   - Steam "How to win?" (Beakstore, Hyper Realistic Blood): pivot when a build isn't coming together. A polychrome joker off-build "will stop being valuable."
   - mangonaise: "There are no instant-click cards in Balatro"; "avoid making quick decisions based on heuristics."
   - A forum reply on high-stake win rates: "forcing a specific strategy is the easiest way to lower your win rate" [snippet].
   - earlyguides calls Baron/Mime worth committing to only once the pieces show up.
   - [estimate] Combining the wiki's "mid game = Antes 3-6" with Superjump's "don't take scaling +Mult past ante 4 or 5": commit to a hand around Ante 3 and to an xMult plan by Ante 4-5.
5. **Scaling jokers must be bought early.** Superjump wouldn't take scaling +Mult jokers "past ante 4 or 5". The wiki calls Spare Trousers a "bell curve" that reaches about +40 Mult by Ante 8. Scaling xMult is "the best choice, but ... risky" (wiki General strategy).
6. **Held-in-hand effects need hand size and small played hands.**
   - Baron, Mime, Steel, Shoot the Moon, Reserved Parking, Gold cards and Blue Seals want High Card or Pair, plus Juggler, Troubadour, Turtle Bean, Paint Brush, Palette or Painted Deck.
   - They hate Stuntman, Merry Andy, Ectoplasm, Ouija, The Hook, The Manacle and The Psychic (W:Baron, W:Mime, W:Steel_Card).
7. **Thin and shape the deck.**
   - Wiki: "Remove or modify the non-primary portion of your deck" with Hanged Man, Immolate, Trading Card, Death, Strength and the suit tarots.
   - Blizzard Watch: thinning raises the odds of drawing what you need.
   - Caveats: thinning hurts Straights (earlyguides) and conflicts with Hologram and card-adding builds (W:Hologram, W:Erosion).
8. **Economy funds the build.**
   - Keep $25 or more for maximum interest (wiki).
   - "Econ is king" (Mancunion). "Economy is the most important mechanic ... Cash is what wins games consistently" (mangonaise).
   - Two Average Gamers: reach the $25 cap by Ante 3, sell weak economy jokers around Ante 5-6, and have every slot scoring by Ante 8.
   - Addison Kindrick: about $15-20 at the end of each shop is the threshold.
   - Orange/Gold: "packs ... so expensive", so buy packs early and don't reroll recklessly (Steam, YoruHawk, who says he beat Gold Stake on about 5 decks).
9. **Score from planets, enhancements and seals, not only jokers.** "Jokers aren't everything... A blue seal is more powerful than many of the jokers" (mangonaise).
10. **Plan for bosses.**
    - Face builds die to The Plant.
    - Suit builds die to The Head, Window, Club and Goad.
    - Card Sharp dies to The Eye and The Needle.
    - Answers: Director's Cut or Retcon ($10 rerolls), Luchador, Chicot, Mr. Bones (wiki General strategy; Steam).
    - Glass and Steel cards and a small deck are the tools for Violet Vessel (mangonaise).
11. **Stake stickers.** Perishable and Rental jokers are fine when you are within about 5 rounds of the Ante 8 boss (Mancunion). Don't take Eternals that won't help by Ante 7-8 (Steam, TrueAchievements [snippet]).
12. **Flat suit +Mult jokers are dead slots late** (Two Average Gamers: Lusty, Wrathful and similar). Hand-type flat jokers (Jolly, Zany and similar) are early-only.

---

## 2. Archetypes

Each section covers: core pieces, support, anti-synergies, hand, why it scales, how to assemble, when it is a trap, and community strength. The strength tier is my synthesis [estimate] for **finishing Ante 8 at high stakes**:
- S: wins on its own when assembled.
- A: major win condition.
- B: good, but needs a second engine.
- C: niche or a transition piece.

### A1. Baron + Mime ("Steel Kings", held-in-hand)
- **Core.**
  - Baron (Rare, $8): "Each King held in hand gives X1.5 Mult."
  - Mime (Uncommon, $5): "Retrigger all card held in hand abilities."
  - Kings, ideally **Steel** Kings. Steel gives X1.5 while held.
  - [wiki] W:Baron, W:Mime, W:Steel_Card.
- **Support.**
  - Red Seal (Deja Vu) on Steel Kings. W:Red_Seal: a Steel Red Seal King under Baron "effectively counts as two Steel Kings." Steel + Red Seal held = X2.25.
  - Blueprint or Brainstorm copying Baron or Mime.
  - DNA to copy Steel Kings.
  - Steel Joker.
  - Shoot the Moon (Queens +13 each, placed **left**) and Raised Fist (placed left).
  - Reserved Parking: $ per held face card, retriggered by Mime.
  - Midas Mask: Gold Kings, then $6 each with Mime.
  - Hand size: Juggler, Troubadour, Turtle Bean, Paint Brush, Palette, Painted Deck.
  - Others: Vagabond, Trading Card, Certificate.
  - Variant: Perkeo + Observatory + Pluto on top of Steel Kings (Steam endless thread).
- **Consumables.**
  - The Chariot on Kings to make them Steel.
  - **Death** with a non-King on the left and your best Steel or Red Seal King on the right copies it, including enhancement and seal.
  - Strength turns Queens into Kings.
  - The Hanged Man thins non-Kings.
  - The Devil makes Gold Kings.
  - Deja Vu adds Red Seals.
  - **Cryptid** makes 2 copies of a Steel Red Seal King.
  - Trance adds Blue Seals, so held Kings also make Planets.
  - Familiar adds enhanced face cards.
  - [wiki] W:Baron synergies; Steam 100M thread (Zelakon, Edranael).
- **Anti-synergies.**
  - Hand-size loss: Stuntman, Merry Andy, Ectoplasm, Ouija.
  - Bosses: The Plant (debuffs Kings), The Psychic, The Hook, The Mark, Cerulean Bell, The Ox.
  - Decks: Abandoned, Medusa, Mad World, Five-Card Draw.
  - Vampire eats Steel.
  - Jokers that want Kings *played*: Triboulet, Sock and Buskin, Photograph.
  - Blackboard is not retriggered by Mime.
  - Independent flat +Mult jokers are not multiplied by Baron [inference, see 0.3].
  - [wiki] W:Baron, W:Mime, W:Triboulet.
- **Hand.** High Card is best, then Pair. Leveling High Card or Pair keeps more Kings in hand (W:Baron, W:Mime). Play an Ace or a junk card, and hold the Kings.
- **Why it scales.** Every held King multiplies, every retrigger multiplies again, and every copy of Baron or Mime raises the exponent. [computed from wiki rules]
  - Per held King, the factor is 1.5^(t*f), where t = triggers = 1 + Red Seal + Mime copies, and f = Baron copies + 1 if Steel.
  - 5 plain Kings with Baron: 1.5^5 = 7.6. Add Mime: 1.5^10 = **57.7**. Two Average Gamers says "x11", which is an arithmetic slip.
  - 4 Steel Kings with Baron + Mime: 2.25^8 = **657**. With Red Seals: 2.25^12, about **16,800**.
  - Example: High Card at level 6 with an Ace played is about 66 chips x 6 mult = 396. Times 657 is about 260k, which is borderline for a 400k Gold boss. With Red Seals it is about 6.7M.
  - **Copy decision rule** [computed]. Copying Baron adds t to the exponent. Copying Mime adds f. So copy Baron when t > f and Mime when f > t.
    - Steel + Red Seal + Mime (t=3, f=2): Baron copy gives exponent 9, Mime copy 8. Copy Baron.
    - Plain Kings + Mime (t=2, f=1): copy Baron.
    - Steel Kings, no seals (t=2, f=2): tie. Mime also helps Shoot the Moon, Gold cards and Blue Seals.
  - Reported results: one player reached Ante 18 and another Ante 15 (Steam [community]). The wiki notes Naneinf scores with Plasma Deck.
- **Assembly.**
  - Shop: buy Baron when seen (Rare). Then Mime, "even if it means selling a weaker Joker" (games.gg).
  - Packs: Arcana for Chariot, Death, Strength and Hanged Man; Spectral for Deja Vu and Cryptid; Standard for Steel or Red Seal Kings.
  - Vouchers: Paint Brush, Palette, Illusion.
  - Sell: flat independent +Mult jokers, hand-size reducers, and economy jokers by the late antes.
  - Discipline: never play a King. A played King stops counting for Baron.
- **Trap when.**
  - Two specific Rare/Uncommon pieces plus several converted Kings. Slow and fragile; The Plant ends it unless you reroll the boss or have Chicot.
  - "Not that great" at Orange (malogoss [community]). "Glass ... with retrigger jokers are more consistent than Baron, which needs two specific rares" (cct [community]).
  - Note that games.gg's math is partly wrong: Wheel of Fortune doesn't give Red Seals, and Jupiter doesn't give hand size.
- **Community strength.**
  - The wiki's showcase example build (General strategy).
  - "One of the three or so builds that can actually make it to Ante 12" (Steam, HeraldOfOpera).
  - Choost: Baron S, Mime A. SteelSeries: Baron A, Mime B. earlyguides: A.
  - **Tier: A** (S in endless; at Gold Stake, only if Baron arrives by about Ante 4-5 [estimate]).
- **Sources:** https://balatrowiki.org/w/Baron · https://balatrowiki.org/w/Mime · https://balatrowiki.org/w/Steel_Card · https://balatrowiki.org/w/Red_Seal · https://balatrowiki.org/w/Guide:_General_strategy · https://steamcommunity.com/app/2379780/discussions/0/7410182856435245149 · https://steamcommunity.com/app/2379780/discussions/0/600772276758004947 · https://steamcommunity.com/app/2379780/discussions/0/4356744017103053782 · https://steamcommunity.com/app/2379780/discussions/0/4634862878162233313 · https://games.gg/balatro/guides/baron-mime-balatro-build/ · https://www.twoaveragegamers.com/balatro-strategy-guide-the-joker-combos-that-actually-win-runs/

### A2. Blueprint / Brainstorm on the best xMult joker
- **Core.** Blueprint (Rare, $10) copies the joker to its right. Brainstorm (Rare, $10) copies the leftmost joker. [wiki]
- **Placement rules.** [wiki]
  - `[Target][Blueprint]` does nothing for the target. You need `[Blueprint][Target]`.
  - Brainstorm: put the target leftmost.
  - The chain `[Blueprint][Target] ... [Brainstorm]` gives 3 instances, because Brainstorm copies whatever the leftmost Blueprint copies.
  - Brainstorm in the leftmost slot does nothing.
  - Moving Blueprint mid-scoring doesn't change what it copied. After the round ends, it copies whatever is to its right then (useful for Mime with Gold cards).
- **Cannot copy.** End-of-round effects (Golden Joker, Rocket, Cloud 9, Satellite), passives (Four Fingers, Smeared, Shortcut, Pareidolia, Splash, Oops! All 6s, Showman, Chicot, Midas Mask, Credit Card, Chaos, Astronomer, Mr. Bones, Invisible), scaling (only the current value), and hand-size or discard changes. Stuntman's chips are copied without the -2 hand size. [wiki]
- **Best targets.** The wiki says copying xMult or retriggers beats copying +Chips or +Mult.
  - Baron or Mime (see the A1 rule).
  - Triboulet. A Steam poster: copied Triboulet is about X2^7, against X2^4 to X2^6 for copied Hanging Chad, unless you run Glass, Lucky or Gold Seal cards.
  - Photograph, Cavendish, Card Sharp, The Duo/Trio/Family/Order, Canio, Yorick, Campfire, Hologram, Constellation, Lucky Cat, Glass Joker, Vampire (copies the xMult, not the eating), Steel Joker, Driver's License, Ancient Joker.
  - Bloodstone: each copy rolls independently, which smooths variance.
  - Utility: DNA, Certificate, Marble ("card factory"); Cartomancer (more Tarots); Mail-In Rebate or Business Card (money; Superjump: "$15 instead of $5"); Burglar; Space Joker.
- **Support.** Showman (duplicates), Invisible Joker, Ankh. Polychrome on the copy.
- **Anti-synergies.** Amber Acorn shuffles jokers. Madness destroys them. On a Knife's Edge pins the Dagger. A missing target leaves Blueprint as a dead $10 slot.
- **Assembly.** Buy Blueprint or Brainstorm almost always. Before you have a target, it can copy an economy or utility joker. Re-slot it as the build changes.
- **Trap when.** No strong xMult or retrigger target, or the slot is better spent on a second independent xMult. Both are Rare, so don't reroll heavily for them [estimate].
- **Community strength.** Mobalytics (Gold Stake clear): S+ Blueprint, Brainstorm, Triboulet [snippet; the page returned 403]. Choost S. SteelSeries S. **Tier: S, conditional on a target.**
- **Sources:** https://balatrowiki.org/w/Blueprint · https://balatrowiki.org/w/Brainstorm · https://steamcommunity.com/app/2379780/discussions/0/604152945255155798 · https://www.superjumpmagazine.com/all-in-advanced-strategies-for-earning-c-in-balatro/ · https://choostgames.com/blog/balatro-jokers/ · https://steelseries.com/blog/balatro-joker-tier-list · https://mobalytics.gg/blog/tier-lists/best-balatro-jokers/ [snippet]

### A3. Face cards: "Photochad" (Photograph + Hanging Chad) plus the face package
- **Core.**
  - Photograph (Common, $5): first scored face card X2.
  - Hanging Chad (Common, $4): retriggers the first scored card 2 additional times.
  - A face card **leftmost** in the played hand gives 3 triggers, so X8 (W:Photograph: "Photochad").
- **Support.**
  - Sock and Buskin (Uncommon, $6): retriggers every played face card.
  - Red Seal on the lead face card. Hanging Chad doesn't retrigger the seal, so the card triggers 4 times total.
  - Glass on the lead card (W:Glass_Card: Chad gives X8 from Glass alone). Polychrome via Aura.
  - Smiley Face (+5 Mult per scored face), Scary Face (+30 chips per face), Business Card (1/2 chance of $2 per face), Reserved Parking (held faces 1/2 chance of $1), Midas Mask (scored faces become Gold).
  - Pareidolia: all cards count as face cards, so any lead card works.
  - Hiker; Dusk; Seltzer; Blueprint on Photograph; Splash.
- **Consumables.** Death or Strength to make or copy face cards. Deja Vu (Red Seal) and Justice (Glass) on one lead King. Aura (Poly). Familiar (3 enhanced faces). Cryptid. Hanged Man to thin. [wiki W:Sock_and_Buskin, W:Photograph]
- **Anti-synergies.**
  - **The Plant** (debuffs faces). The Mark.
  - Ride the Bus, Canio, Faceless Joker.
  - Abandoned and Medusa decks.
  - Straights hold at most 3 face cards.
  - Photograph's "face cards right" advice conflicts with Hanging Chad's "power card left". With Chad, lead with the face card.
- **Hand.** High Card and Pair for Photochad, because you control the first card (Two Average Gamers, Switchblade). With Sock and Buskin and many faces: Full House, Flush, Four or Five of a Kind (W:Sock_and_Buskin).
- **Why it scales.** [computed] The lead face card's triggers multiply Photograph's X2:
  - Chad: X8.
  - Chad + Sock and Buskin: 4 triggers, X16.
  - Chad + Sock and Buskin + Red Seal: 5 triggers, X32.
  - A Glass Red Seal lead card with Chad + Sock and Buskin: (2x2)^5 = X1,024.
  - The effect is flat (it doesn't grow), so by Ante 8 it still needs hand levels or another xMult. Mancunion calls Photochad "extremely powerful" with common jokers.
- **Assembly.**
  - Both pieces are Common and cheap, so buy them early (Ante 1-3).
  - Then put Red Seal and Glass on one King.
  - Add Sock and Buskin, or Blueprint left of Photograph.
  - Sell Ride the Bus and Faceless Joker.
  - Keep Director's Cut or Luchador for The Plant.
- **Trap when.** Many faces in the deck but no lead-card control (5-card hands without Chad). Pareidolia costs a slot, and "deck manipulation and discards can replace its effect" (Addison Kindrick).
- **Community strength.**
  - Hanging Chad is "the clear winner" because it fits most builds (mangonaise).
  - Photochad is "the other major Endless build" (Steam).
  - Choost: Photograph A. SteelSeries: Photograph, Hanging Chad, Smiley Face and Sock and Buskin A; Business Card B; Scary Face, Pareidolia and Midas Mask C.
  - **Tier: A** (Photochad + Sock and Buskin + Red Seal); B for the face +Mult/econ package alone.
- **Sources:** https://balatrowiki.org/w/Photograph · https://balatrowiki.org/w/Hanging_Chad · https://balatrowiki.org/w/Sock_and_Buskin · https://balatrowiki.org/w/Pareidolia · https://balatrowiki.org/w/Midas_Mask · https://balatrowiki.org/w/Reserved_Parking · https://mancunion.com/2025/09/01/a-guide-to-gold-stake-balatro/ · https://steamcommunity.com/app/2379780/discussions/0/604143165271744486 · https://steamcommunity.com/app/2379780/discussions/0/600772276758004947 · https://addisonkindrick.substack.com/p/10-balatro-tier-list-addendum

### A4. Triboulet + Sock and Buskin (legendary face build)
- **Core.** Triboulet (Legendary, from The Soul): "Played Kings and Queens each give X2 Mult when scored." Plus Sock and Buskin. [wiki]
- **Support.**
  - Hanging Chad, Dusk, Seltzer, Red Seals, Splash.
  - Blueprint or Brainstorm copying Triboulet.
  - Photograph.
  - Consumables: Strength (Jack to Queen, Queen to King), Death on K/Q, Cryptid, Deja Vu, Empress, Justice, Familiar, Hanged Man.
- **Anti-synergies.**
  - The Plant.
  - Baron, Shoot the Moon and Reserved Parking want K/Q *held*, not played.
  - Canio. Ride the Bus.
  - Abandoned and Medusa decks.
- **Hand.** Full House, Flush House, Five of a Kind, Flush Five, Flush. High Card and Pair give few triggers.
- **Why it scales.** [computed] 5 scored K/Q give 2^5 = 32. With Sock and Buskin: 2^10 = **1,024**. With Blueprint on Triboulet as well: 4^10, about 1.05M.
- **Assembly.** Take The Soul if it shows up. Then convert the deck toward K/Q with Strength and Death, thin with Hanged Man, and add Sock and Buskin. Sell held-K/Q jokers.
- **Trap when.** You can't plan for it (0.3% Soul chance per pack card). The Plant is the only real threat.
- **Community strength.** Mobalytics S+ [snippet]. Choost S. SteelSeries S. Steam: "very strong, winning runs without The Plant." **Tier: S.**
- **Sources:** https://balatrowiki.org/w/Triboulet · https://steamcommunity.com/app/2379780/discussions/0/4408543518583235699 · https://www.twoaveragegamers.com/balatro-strategy-guide-the-joker-combos-that-actually-win-runs/

### A5. Canio (destroy face cards)
- **Core.** Canio (Legendary): X1, plus X1 per face card destroyed. [wiki]
- **Enablers.**
  - The Hanged Man (2 selected cards).
  - Justice on face cards: Glass faces break.
  - Trading Card.
  - Immolate, Familiar, Grim, Incantation (random destruction).
  - **Pareidolia**: every destroyed card counts.
  - Glass Joker: both scale off Glass faces breaking.
  - Erosion.
  - DNA or Cryptid to make more faces.
  - Death, Strength and The Tower do **not** count as destruction.
- **Anti-synergies.** Baron, Sock and Buskin, Triboulet. The Plant (debuffed faces don't scale it). Abandoned and Medusa decks.
- **Hand.** Any. Prefer high-base hands and keep a chips joker (wiki).
- **Why it scales.** It is permanent and linear: 5 faces destroyed gives X6 [computed].
- **Trap when.** Your other jokers depend on faces.
- **Community strength.** Choost S. Mobalytics S [snippet]. SteelSeries A. Steam: "Canio + Glass Joker scales very quickly." **Tier: S.**
- **Sources:** https://balatrowiki.org/w/Canio · https://steamcommunity.com/app/2379780/discussions/0/4408543518583235699

### A6. Low cards / number cards (Hack, Wee Joker, Walkie Talkie, Fibonacci, Even Steven, Odd Todd, Scholar, Ride the Bus)
- **Core.** [wiki numbers]

  | Joker | Effect |
  |---|---|
  | Hack (Uncommon, $6) | retriggers played 2, 3, 4, 5 |
  | Wee Joker (Rare, $8) | gains +8 chips per scored 2, retriggers count |
  | Walkie Talkie | 10s and 4s: +10 chips, +4 Mult |
  | Fibonacci (Uncommon, $8) | A, 2, 3, 5, 8: +8 Mult each |
  | Even Steven | even ranks +4 Mult |
  | Odd Todd | odd ranks +31 chips |
  | Scholar | Aces +20 chips, +4 Mult |
  | Ride the Bus | +1 Mult per consecutive hand with no scoring face card |

- **Support.**
  - Hanging Chad, Dusk, Seltzer, Red Seals, Hiker, Splash, Shortcut.
  - xMult carriers: **The Idol** (best target ranks are 2-5 with Hack, per the wiki), Bloodstone, Ancient Joker, The Family/Trio, Photograph via Pareidolia (but that kills Ride the Bus).
  - Abandoned Deck, Mad World.
  - Consumables: Hanged Man (remove faces), Death (copy 2s and 5s), Cryptid, Incantation (4 enhanced number cards), Grim (Aces), Strength (King to Ace).
- **Anti-synergies.** 15 Minute City. Pareidolia and Splash for Ride the Bus. Purple Seal and Certificate dilute the deck. Face-scoring jokers. The Plant is harmless here.
- **Hand.** Four or Five of a Kind, Full House or Flush Five of low cards. A-5 Straight. Three of a Kind early (W:Wee_Joker, W:Fibonacci, W:Hack).
- **Why it scales.**
  - Mostly additive, with Hack doubling per-card values. [computed] Five scored 2/3/5 with Fibonacci + Hack gives 10 triggers x8 = +80 Mult.
  - Wee Joker scales permanently, +16 per Hack-retriggered 2.
  - There is **no exponential source on its own**. You need The Idol (Flush Five of the target card: X32, wiki) or other xMult.
- **Assembly.** Hack early, then Fibonacci or Wee Joker. Hanged Man the faces. Death to copy a Red Seal 2 or 5. Then find an xMult.
- **Trap when.** No xMult by Ante 5-6 [estimate]. Ride the Bus wants many hands per round (bad on Black Deck).
- **Community strength.**
  - Mancunion recommends Hack, Fibonacci, Odd Todd, Even Steven and Ride the Bus for Abandoned Deck.
  - Choost: Fibonacci and Wee Joker B; Odd Todd and Even Steven C. SteelSeries: Fibonacci and Walkie Talkie B; Hack C; Ride the Bus and Odd Todd D.
  - Superjump: Ride the Bus pairs with deck thinning and removing faces.
  - **Tier: B** (A with The Idol or Wee Joker + Hack locked in early).
- **Sources:** https://balatrowiki.org/w/Hack · https://balatrowiki.org/w/Wee_Joker · https://balatrowiki.org/w/Fibonacci · https://balatrowiki.org/w/Scholar · https://balatrowiki.org/w/Ride_the_Bus · https://balatrowiki.org/w/The_Idol · https://mancunion.com/2025/09/01/a-guide-to-gold-stake-balatro/

### A7. Flush builds
- **Core.**
  - Hand: Flush (35/4, +15/+2 per level).
  - Smeared Joker (Uncommon, $7, passive): Hearts = Diamonds, Spades = Clubs, for all suit effects and Blinds.
  - Four Fingers (Uncommon, $7, passive): 4-card Flushes and Straights.
  - Suit tarots The Star, Moon, Sun and World (up to 3 cards each). The Lovers (Wild). Hanged Man.
- **Payoff jokers.** [wiki]

  | Joker | Effect |
  |---|---|
  | The Tribe (Rare) | X2 on any hand containing a Flush. No scaling; the wiki calls it the weakest hand xMult, tied with The Duo |
  | Droll | +10 Mult |
  | Crafty | +80 chips |
  | Greedy / Lusty / Wrathful / Gluttonous | +3 Mult per Diamond / Heart / Spade / Club |
  | Onyx Agate | Clubs +7 Mult |
  | Arrowhead | Spades +50 chips |
  | Rough Gem | Diamonds +$1 |
  | **Bloodstone** | Hearts: 1/2 chance of X1.5 |
  | **Ancient Joker** (Rare) | X1.5 per scored card of a suit that changes each round; Wild cards always count |
  | Castle | +3 chips per discarded card of the round's suit |
  | Seance | Straight Flush creates a Spectral |

  Off-type pieces:
  - Flower Pot (X3, needs all 4 suits) and Seeing Double (X2 for a Club plus another suit) are rainbow pieces. They clash with mono-suit flushes unless you have Wilds, Smeared Joker or Splash.
  - Blackboard (X3 if all held cards are Spades or Clubs) suits High Card/Pair. For flushes it needs an all-black deck.
- **Support.**
  - Checkered Deck.
  - Painted Deck, Troubadour, Paint Brush (hand size for flushes).
  - Blueprint on Ancient Joker or Bloodstone.
  - Oops! All 6s with Bloodstone.
  - Sock and Buskin with face flushes; Triboulet.
  - Card Sharp (two flushes per round).
  - Burnt Joker (free Flush levels). Constellation.
- **Anti-synergies.**
  - Suit-debuff bosses: The Head, Window, Club, Goad. Smeared Joker *doubles* the exposure. The Pillar.
  - **Four Fingers vs per-card suit payoffs** (Bloodstone, Ancient, Rough Gem): fewer suited cards score (W:Bloodstone, W:Ancient_Joker).
  - Certificate.
  - Jokers for an off-suit.
  - Blue Stake's lost discard (earlyguides).
- **Why it scales.**
  - Flush levels grow slowly, so the exponential has to come from per-card xMult. [computed] A full suited flush gives Ancient 1.5^5 = 7.6, Bloodstone about 1.25^5 = 3.05 expected (7.6 guaranteed with Oops), Tribe X2.
  - Smeared + Ancient: "nearly won the run alone" (Steam [community]). Smeared + Bloodstone (Switchblade).
- **Assembly.**
  - Choose the suit with the best payoff joker you own: Hearts for Bloodstone and Lusty; Spades for Arrowhead and Wrathful; Clubs for Onyx Agate and Gluttonous; Diamonds for Rough Gem and Greedy.
  - Use the matching suit tarot on 3 off-suit cards per use.
  - Hanged Man on off-suit cards.
  - The Lovers for Wilds if running Ancient Joker or Flower Pot.
  - Smeared Joker halves the conversion work.
  - Then sell flat +3 suit jokers once xMult arrives.
- **Trap when.**
  - "Flushes scale slower in the late game"; avoid straights and flushes "after the first few antes" (Superjump, Gold Stake).
  - "Flush builds doesnt skale into the higher stakes" (Steam [snippet]).
  - mangonaise relied on flushes in his first Completionist++ and moved to Straights/Pairs in the second, which was faster.
  - The BU video, via the rblind Reddit mirror: pairs "more consistent (especially in higher stakes where you have less discards/money)."
  - Flushes are the easiest early hand. PC Gamer [snippet]: "flush the easiest to build around." Superjump: Plasma's Ante 1 is "very easy to win" with flushes.
- **Community strength.**
  - SteelSeries: Smeared, Bloodstone and Ancient A; Four Fingers B; Tribe C; Lusty, Greedy, Wrathful, Gluttonous, Crafty, Blackboard and Flower Pot D. Choost: Four Fingers A. earlyguides: S (low-quality site).
  - **Tier: B** at high stakes (A with Ancient + Smeared + Blueprint, or with Bloodstone + Oops).
- **Sources:** https://balatrowiki.org/w/Smeared_Joker · https://balatrowiki.org/w/Four_Fingers · https://balatrowiki.org/w/Bloodstone · https://balatrowiki.org/w/Ancient_Joker · https://balatrowiki.org/w/The_Tribe · https://balatrowiki.org/w/Blackboard · https://balatrowiki.org/w/Flower_Pot · https://balatrowiki.org/w/Seeing_Double · https://balatrowiki.org/w/Castle · https://balatrowiki.org/w/Rough_Gem · https://www.superjumpmagazine.com/all-in-advanced-strategies-for-earning-c-in-balatro/ · https://www.rblind.com/post/20191354 · https://steamcommunity.com/app/2379780/discussions/0/4408543518583235699 · https://earlyguides.com/balatro/builds

### A8. Lucky build (Lucky Cat + Lucky cards + Oops! All 6s)
- **Core.**
  - Lucky cards via **The Magician** (2 cards per use). Each scored Lucky card has a 1/5 chance of +20 Mult and a 1/15 chance of $20.
  - **Lucky Cat** (Uncommon, $6): gains X0.25 per successful trigger, and a double hit counts once. It only spawns after you own a Lucky card.
  - **Oops! All 6s** (Uncommon, $4, not copyable): doubles listed probabilities.
  - [wiki] W:Lucky_Card, W:Lucky_Cat, W:Oops!_All_6s.
- **Support.**
  - Retriggers: Hanging Chad on a lead Lucky card (3 rolls), Seltzer, Dusk, Hack or Sock and Buskin on matching ranks, Red Seal via Deja Vu.
  - Splash (more Lucky cards score).
  - Bloodstone, Business Card and Reserved Parking (all boosted by Oops).
  - Gold Seal. Driver's License.
  - Consumables: Death to duplicate Lucky cards, Hanged Man to thin, Magic Deck (2 Fools give more Magicians).
- **Anti-synergies.** Vampire (eats Lucky). Midas Mask (overwrites to Gold). The Pillar. Vagabond (a $20 hit turns it off).
- **Hand.** 5-card hands (Straight, Flush, Full House) to score more Lucky cards. Or High Card/Pair with Hanging Chad or Splash.
- **Why it scales.** [computed]
  - P(at least one effect) per scored Lucky card = 1 - (4/5)(14/15), about 25.3%. That is about +X0.063 per scored card. With Oops it is about 48%, so about +X0.12.
  - Five Lucky cards scored per hand gives about X0.32 per hand (about X0.6 with Oops). That compounds to double-digit X over about 30-40 hands [estimate].
  - With Oops a Lucky card averages +8 Mult and $3 (wiki).
- **Assembly.**
  - Magician on the cards you play most (or the Chad lead card).
  - Buy Lucky Cat as soon as it appears.
  - Oops is the multiplier for the whole build. Addison Kindrick calls it "the best utility Joker in its class... makes Lucky cards a reliable source of mult and money."
- **Trap when.** Lucky Cat bought after about Ante 5 [estimate]. Too few Lucky cards (Magician is 1 of 22 Tarots).
- **Community strength.**
  - mangonaise keeps conditional jokers like Lucky Cat "near the top" priority. Hanging Chad retriggering Lucky cards for cash.
  - Steam: "Hanging Chad + Lucky Cat."
  - Choost: Lucky Cat B. SteelSeries: Lucky Cat C, Oops B.
  - **Tier: B** (A with Oops + retriggers early).
- **Sources:** https://balatrowiki.org/w/Lucky_Card · https://balatrowiki.org/w/Lucky_Cat · https://balatrowiki.org/w/Oops!_All_6s · https://addisonkindrick.substack.com/p/10-balatro-tier-list-addendum · https://steamcommunity.com/app/2379780/discussions/0/604143165271744486

### A9. Glass build (Glass cards + Glass Joker + retriggers)
- **Core.**
  - Glass cards via **Justice** (1 card): X2 when scored, 1/4 break chance. A retrigger does not reroll the break chance.
  - **Glass Joker** (Uncommon, $6): X0.75 per Glass card destroyed (raised from X0.5 in 1.0.1f). It counts breaks, Hanged Man, Trading Card and Sixth Sense, but **not** Immolate, Familiar, Grim or Incantation (a bug). It only spawns after you own a Glass card.
  - [wiki] W:Glass_Card, W:Glass_Joker.
- **Support.**
  - Hanging Chad on a lead Glass card: X8.
  - Red Seal on Glass: X4, with no extra break chance.
  - Polychrome Glass: X3.
  - Sock and Buskin on Glass faces. Hack on Glass 2-5. Dusk. Seltzer.
  - Canio (Glass faces) and Erosion: both scale off breaks.
  - Oops! (faster breaks; only good with Glass Joker, Canio or Erosion).
  - DNA, Cryptid, Certificate, Standard packs to replenish.
  - Throwback: fewer hands played means fewer breaks.
- **Anti-synergies.** Vampire. Driver's License (cards disappear). Oops without a break payoff. Spectral destruction (doesn't scale Glass Joker).
- **Hand.** Any. Place Glass rightmost, or leftmost with Hanging Chad. Flush Five of Glass Kings with Red Seals is an endless plan (Steam).
- **Why it scales.** [computed] Each scored Glass card is X2 (and each retrigger X2 again), so 5 Glass cards give X32. Glass Joker grows +X0.75 per break: 4 breaks gives X4.
- **Assembly.**
  - Justice on your most-played rank, or on the Hanging Chad lead card.
  - Hold Glass cards until needed against The Needle, The Wall or Violet Vessel (Steam).
  - Hanged Man on spare Glass cards scales Glass Joker.
- **Trap when.** Small deck plus Oops with no replenishment. Glass Joker alone without Justice supply.
- **Community strength.**
  - Glass is "absurdly broken"; Steel and Glass are "easily the best enhancements by far" (Steam [community]).
  - "Glass cards with retrigger jokers are more consistent than Baron" (cct, Steam).
  - mangonaise uses Glass and Steel plus a small deck against Violet Vessel.
  - **Tier: A** (as a finisher on top of any build).
- **Sources:** https://balatrowiki.org/w/Glass_Card · https://balatrowiki.org/w/Glass_Joker · https://steamcommunity.com/app/2379780/discussions/0/600772276758004947 · https://steamcommunity.com/app/2379780/discussions/0/7410182856435245149 · https://steamcommunity.com/app/2379780/discussions/0/4634862878162233313

### A10. Steel build (Steel Joker + held Steel cards)
- **Core.** Steel cards via **The Chariot** (1 card): X1.5 while held. **Steel Joker** (Uncommon, $7): X0.2 per Steel card in the full deck (cut from X0.25 in 1.0.1f). It only spawns after you own a Steel card. [wiki]
- **Support.**
  - Mime (each held Steel card's X1.5 applies twice). Baron (Steel Kings). Red Seals.
  - DNA and Cryptid to copy Steel cards.
  - Fortune Teller: Chariot use also grows it (comicbook combo).
  - Cartomancer, Vagabond, Hallucination for Tarots.
  - Raised Fist and Shoot the Moon placed left.
  - Blackboard with black Steel cards held.
  - Illusion voucher. Standard packs. Plasma Deck (W:Steel_Joker).
- **Anti-synergies.** Vampire. Hand-size reducers. The Hook. The Manacle.
- **Hand.** High Card or Pair.
- **Why it scales.** [computed] 10 Steel cards in the deck give Steel Joker X3. Holding 5 Steel cards gives 1.5^5 = 7.6, or 1.5^10 = 57.7 with Mime. Both stack multiplicatively.
- **Assembly.** Chariot on cards you will hold (Kings if Baron is possible). Death to copy a Steel Red Seal card. Hand-size vouchers.
- **Trap when.** Few Chariots. Played-hand builds that need 5 cards.
- **Community strength.** Steel is "the best enhancement" (Twelvefield, Steam). SteelSeries: Steel Joker B. Steel Card Economy is A (earlyguides). **Tier: A** with Mime, B without.
- **Sources:** https://balatrowiki.org/w/Steel_Joker · https://balatrowiki.org/w/Steel_Card · https://comicbook.com/gaming/news/best-joker-combos-balatro/ · https://steamcommunity.com/app/2379780/discussions/0/600772276758004947

### A11. Card-adding and enhancement engines (Hologram, DNA, Certificate, Marble, Cryptid, Vampire, Midas Mask, Driver's License)
- **Core.** [wiki]
  - **Hologram** (Uncommon, $7): X0.25 per playing card added. Cards don't need to stay in the deck.
  - **DNA** (Rare, $8): if the first hand is a single card, adds a permanent copy (modifiers included) to the deck and hand.
  - **Certificate**: each round adds a random card with a random seal to your hand. Seals are hard to get otherwise. Addison Kindrick: it should rank "much higher."
  - **Marble Joker**: adds a Stone card each Blind.
  - **Cryptid**: 2 copies, so +X0.5 on Hologram.
  - Familiar, Grim and Incantation: destroy 1, add 3, 2 or 4 enhanced cards.
  - **Vampire** (Uncommon, $7): X0.1 per scored enhanced card, and strips the enhancement before it triggers. Only the leftmost Vampire scales.
  - **Midas Mask**: scored faces become Gold, so they feed Vampire.
  - **Driver's License** (Rare, $7): X3 with 16 or more enhanced cards in the full deck.
- **Support.**
  - Blueprint or Brainstorm on DNA, Certificate, Marble or Hologram.
  - Pareidolia + Midas Mask + Vampire: every scored card becomes Gold and is then eaten. Place Midas Mask left of Vampire for immediate feeding (W:Vampire ordering notes). Golden Ticket only works when Vampire is left of the Mask.
  - Two-card enhancers (Magician, Empress, Hierophant) for Vampire and Driver's License.
  - Tarot Merchant. Illusion. Magic Trick (buy cards for Hologram). Ghost or Zodiac Deck.
  - DNA left of Vampire, so the copy keeps its enhancement.
- **Anti-synergies.**
  - Hologram and Erosion are opposites.
  - Vampire breaks every enhancement-payoff joker: Lucky Cat, Glass Joker, Steel Joker, Stone Joker, Golden Ticket, Driver's License.
  - DNA hates The Needle, The Psychic and Black Deck.
  - Marble Joker dilutes Straights and Four of a Kind.
- **Hand.**
  - DNA wants High Card on the first hand, then the main hand.
  - Hologram: any (High Card/Pair tolerate bloat best).
  - Vampire: 5-card hands full of enhanced cards (W:Vampire).
- **Why it scales.** [computed] All linear, permanent xMult:
  - Hologram: X3 after 8 cards added (DNA adds about 1 per round).
  - Vampire: X3 after 20 enhanced cards eaten.
  - Driver's License: a flat X3 once the threshold is reached.
- **Assembly.**
  - Buy DNA and use it on your best enhanced or sealed card.
  - Hologram plus any card source. Sell Hologram if you turn to Erosion.
  - Vampire wants a steady Tarot flow (Cartomancer, Tarot Merchant) or Midas + Pareidolia.
- **Trap when.**
  - Vampire next to Lucky, Glass or Steel payoffs.
  - Driver's License bought early (dead until 16 enhanced cards).
  - Certificate's Eternal version bloats the deck.
- **Community strength.**
  - Choost: DNA S; Hologram and Vampire A. Mobalytics: Vampire S [snippet]. SteelSeries: DNA S, Hologram A, Driver's License B, Vampire and Midas Mask C.
  - Mancunion: "Good xMult options include Hologram, Constellation, and Vampire."
  - Steam: Midas + Vampire "can snowball out of control if assembled early."
  - **Tier: A** (Hologram + DNA, or Vampire + Midas/Pareidolia); Driver's License B.
- **Sources:** https://balatrowiki.org/w/Hologram · https://balatrowiki.org/w/DNA · https://balatrowiki.org/w/Vampire · https://balatrowiki.org/w/Certificate · https://balatrowiki.org/w/Marble_Joker · https://balatrowiki.org/w/Driver%27s_License · https://balatrowiki.org/w/Midas_Mask · https://addisonkindrick.substack.com/p/10-balatro-tier-list-addendum

### A12. Planet engine (Constellation + Space Joker / Satellite / Astronomer / Blue Seals / Supernova)
- **Core.** **Constellation** (Uncommon, $6): X0.1 per Planet card *used*. Black Hole, Orbital Tag, Burnt Joker and Space Joker level hands but don't count. Not retroactive. [wiki]
- **Support.** [wiki]
  - Astronomer (Planets and Celestial Packs free).
  - Satellite ($1 per unique Planet used).
  - **Blue Seal** (Trance, Certificate) on held cards gives a Planet for the final hand each round. Mime retriggers Blue Seals.
  - Telescope, then Observatory. Planet Merchant or Tycoon. High Priestess (2 Planets). The Fool. Perkeo.
  - Space Joker: 1/4 chance to level the played hand; Oops doubles it; copies roll separately.
  - Supernova: + times the hand was played. Burnt Joker: levels the first discarded hand each round.
  - Economy jokers to fund Celestial packs. Nebula and Zodiac decks.
- **Anti-synergies.** Campfire, Red Card, Throwback, Diet Cola (reward skipping or selling). Tarot Merchant. Showman with Telescope (W:Showman). Satellite with Showman (duplicates don't count).
- **Hand.** Any. Pair suits Telescope consistency (Mancunion, Nebula Deck).
- **Why it scales.** [computed] 20 Planets used gives Constellation X3. Each Planet also levels the hand.
- **Assembly.** Buy early. Take every relevant Planet. Trance on a held card. Blue Seals with Mime.
- **Trap when.** Bought late. Tarot-heavy shop.
- **Community strength.**
  - Choost A. SteelSeries A. Mancunion lists Astronomer, Constellation and Supernova for Nebula.
  - mangonaise: "A blue seal is more powerful than many of the jokers."
  - **Tier: A** (Constellation); Space Joker and Satellite C as support.
- **Sources:** https://balatrowiki.org/w/Constellation · https://balatrowiki.org/w/Space_Joker · https://balatrowiki.org/w/Satellite · https://balatrowiki.org/w/Supernova · https://steamcommunity.com/app/2379780/discussions/0/604143165271744486

### A13. Perkeo + Observatory ("particle accelerator")
- **Core.**
  - **Observatory** voucher (upgrade of Telescope; Telescope must be bought in the same run; unlock by using 25 Planets from Celestial Packs). Each Planet held gives X1.5 when its hand is played, applied **after** jokers.
  - **Perkeo** (Legendary): a Negative copy of 1 random held consumable at the end of each shop.
  - [wiki] W:Observatory, W:Perkeo.
- **Support.**
  - Hold only the target Planet, so Perkeo always copies it.
  - Blue Seals + Mime. Showman. Crystal Ball.
  - Blueprint or Brainstorm copying Perkeo (Superjump).
  - Fool. Constellation (more Planets). Ghost or Zodiac deck.
  - Endless variant on Steel Kings + Pluto (Steam).
- **Anti-synergies.** Other consumables in slots, which dilute Perkeo's random pick. Nebula Deck (-1 slot). Madness.
- **Hand.** High Card, Five of a Kind and Flush Five are the most reliable targets (W:Perkeo). Any committed hand works.
- **Why it scales.** [computed] n matching Planets give 1.5^n: 10 Planets is X57.7, 15 Planets X438. Two Average Gamers: 15 Negative Saturns, every Straight about 40M [community].
- **Trap when.** Perkeo is a Soul-only legendary, and Observatory has unlock and prerequisite gates.
- **Community strength.** Choost S (Perkeo). SteelSeries S. **Tier: S if Perkeo is found.**
- **Sources:** https://balatrowiki.org/w/Perkeo · https://balatrowiki.org/w/Observatory · https://www.twoaveragegamers.com/balatro-strategy-guide-the-joker-combos-that-actually-win-runs/ · https://steamcommunity.com/app/2379780/discussions/0/4634862878162233313

### A14. Pair / High Card / Two Pair "joker-carried" builds (high-stake default)
- **Core.**
  - **Card Sharp** (Uncommon): X3 if the hand was already played this round. It checks the scoring hand type only.
  - **The Duo** X2 on any hand containing a Pair; **The Trio** X3 on Three of a Kind; **The Family** X4 on Four of a Kind.
  - **Spare Trousers**: +2 Mult per Two Pair; Full House counts; about +40 by Ante 8.
  - **Square Joker**: +4 chips per exactly-4-card hand.
  - **Supernova**: + times the hand was played.
  - **Green Joker**: +1 per hand, -1 per discard.
  - **Ride the Bus**.
  - **Burglar**: +3 hands, lose all discards.
  - [wiki]
- **Support.**
  - Mercury, Pluto and Uranus levels. Telescope.
  - Blue Seals. Steel and Gold cards held (pairs keep more cards in hand; mangonaise).
  - Splash (scores the extra enhanced cards with High Card or Pair).
  - Space Joker. Photochad. Baron/Mime. Hanging Chad.
  - Blue Deck: Card Sharp, Green Joker, Ride the Bus, Supernova, Space Joker, Runner, Square Joker (Mancunion).
- **Anti-synergies.**
  - Obelisk punishes the most-played hand.
  - Fewer hands: Black Deck, Troubadour, Hieroglyph.
  - The Eye and The Needle hard-counter Card Sharp. Burglar helps against The Needle.
  - To Do List.
- **Hand.** Pair (most consistent), High Card, Two Pair.
- **Why it scales.**
  - Pair base values are tiny. The score comes from multiplying fixed xMult jokers (Card Sharp X3 from the 2nd hand of each round; Duo X2) and from Photochad or held effects.
  - Superjump: use early hands to scale or earn and play one big hand last ("3 of 4 hands to build, 1 to score").
- **Assembly.** Commit by Ante 2-3. Take Mercury or Pluto. Buy Card Sharp or Duo on sight. Then add one exponential source (Photochad, Steel, Glass, Baron).
- **Trap when.** No xMult beyond flat Card Sharp + Duo by Ante 6 [estimate]. Steam posters say even two pair is less consistent with smaller hand size [snippet]; this refers to the old Gold Stake -1 hand size rule.
- **Community strength.**
  - BU video (via the rblind Reddit mirror): "Pairs are the go-to Hand for winning long streaks of Gold Stake runs."
  - Superjump: High Card and Pair "are the main hands for Gold Stake."
  - Mancunion: pairs are "the most consistently drawable and reliably scalable" (Blue Deck).
  - mangonaise: Pairs' "scaling and scoring potential... superior for non-endless runs."
  - Steam (YoruHawk, about 5 Gold decks): "High card and two pair are the easiest to win with."
  - Choost: Card Sharp and Spare Trousers A. Mobalytics: S for The Duo, Trio, Family and Spare Trousers [snippet]. SteelSeries rates them lower (Duo and Trio C, Family D), an outlier.
  - **Tier: A** (most consistent frame at high stakes).
- **Sources:** https://balatrowiki.org/w/Card_Sharp · https://balatrowiki.org/w/Spare_Trousers · https://balatrowiki.org/w/Supernova · https://www.rblind.com/post/20191354 · https://www.superjumpmagazine.com/all-in-advanced-strategies-for-earning-c-in-balatro/ · https://mancunion.com/2025/09/01/a-guide-to-gold-stake-balatro/ · https://steamcommunity.com/app/2379780/discussions/0/604143165271744486 · https://steamcommunity.com/app/2379780/discussions/0/4356744017103053782

### A15. Scaling xMult jokers (each one is its own mini-archetype) [wiki numbers]

| Joker | Scaling | Enablers | Breakers / trap | Community |
|---|---|---|---|---|
| **Campfire** (Rare, $9) | +X0.25 per card sold; **resets after the Boss**. [computed] X3 needs 8 sales in one ante | Economy; card generators (Cartomancer, Riff-Raff, Perkeo); Emperor and High Priestess (2 cards each); Flash Card; Astronomer; Chaos; Credit Card (free to buy and sell); Gold Stake Rentals; Diet Cola, Luchador, Egg | Painted Deck, Nebula; Constellation and Fortune Teller (want cards *used*); Throwback | Mobalytics S [snippet]; SteelSeries C. Tier B |
| **Hit the Road** (Rare) | +X0.5 per Jack discarded this round; resets each round | DNA or Cryptid on Jacks; Hanged Man non-Jacks; Strength (10 to Jack); **Mail-In Rebate**; Drunkard, Merry Andy, Wasteful; Yorick as the long-term replacement | Burglar; Blue Stake (-1 discard); The Water; small hands only | Tier B (A with a Jack-dense deck) |
| **Madness** (Uncommon) | +X0.5 when a Small or Big Blind is selected (about +X1 per ante), destroys a random other joker | Riff-Raff to its left; Eternal jokers (Black Stake and up); Ankh duplicate | Every non-Eternal joker; Anaglyph skipping | Choost D; SteelSeries D. Tier C |
| **Ceremonial Dagger** (Uncommon) | Destroys the joker to its right on Blind select, +2x its sell value as **+Mult** (not xMult) | Egg, Gift Card, Riff-Raff, Swashbuckler, Rentals; move it rightmost to pause | Clearance Sale or Liquidation; Abstract Joker | Choost D. Tier C |
| **Throwback** (Uncommon) | +X0.25 per Blind skipped, retroactive. [computed] Skipping both the Small and Big Blind in all 8 antes (16 skips) gives X5. Two Average Gamers says "x4 by the final boss" | Anaglyph Deck; Diet Cola; Speed Tag; Hieroglyph; Glass (fewer hands, fewer breaks) | Rocket, Cartomancer, Supernova, Hologram, Vampire, Madness, Campfire (all want blinds played) | Choost S; SteelSeries A. Tier B (A on Anaglyph) |
| **Yorick** (Legendary) | +X1 per 23 cards discarded, never resets. [computed] At Blue+ stake with 2 discards of 5 cards, about +X1 per 2.3 rounds | Drunkard, Merry Andy, Wasteful/Recyclomancy, Red Deck; Mail-In Rebate, Castle, Hit the Road, Burnt Joker, Faceless Joker; Purple Seals (Medium) | Burglar; Green Joker, Ramen, Banner, Delayed Gratification; The Water | Mancunion: "getting a Yorick ... almost always wins the run"; SteelSeries S. Tier S |
| **Obelisk** (Rare) | +X0.2 per consecutive hand that isn't your most-played; resets on it | Build a buffer: play Pair or Two Pair about 15 times, then rotate. Blizzard Watch: "15-20 hands of one kind" | Telescope, Nebula, Burglar, Supernova; High Card main | Addison Kindrick: "skill-based minigame," the most-played hand needs about 10 more plays than any other. Tier B |
| **Lucky Cat**, **Glass Joker**, **Vampire**, **Hologram**, **Constellation**, **Canio**, **Steel Joker** | See A5 and A8-A12 | | | |

Sources: https://balatrowiki.org/w/Campfire · https://balatrowiki.org/w/Hit_the_Road · https://balatrowiki.org/w/Madness · https://balatrowiki.org/w/Ceremonial_Dagger · https://balatrowiki.org/w/Throwback · https://balatrowiki.org/w/Yorick · https://balatrowiki.org/w/Obelisk · https://mancunion.com/2025/09/01/a-guide-to-gold-stake-balatro/ · https://blizzardwatch.com/2025/01/23/balatro-beginner-intermediate-tips/

### A16. Legendary jokers (all from The Soul, 0.3% per Arcana/Spectral pack card) [wiki]

| Legendary | Effect | Best with | Breakers | Tier |
|---|---|---|---|---|
| Triboulet | Scored K/Q X2 each | Sock and Buskin (X1,024 with 5 K/Q), Blueprint, Strength, Death | The Plant; held-K/Q jokers | S |
| Yorick | +X1 per 23 discarded | Discard boosters | Burglar, The Water | S |
| Chicot | Disables every Boss Blind (not copyable) | Face and suit builds, Card Sharp, Baron, Oops | Redundant with Luchador and Director's Cut | S (Choost and SteelSeries); for the mod, it "removes boss risk" |
| Perkeo | Negative copy of a random consumable each shop | Observatory planets, Cryptid, Temperance, Ectoplasm | Madness; cluttered consumable slots | S |
| Canio | +X1 per face card destroyed | Hanged Man, Glass faces, Pareidolia, Trading Card | Face-payoff jokers | S |

Sources: https://balatrowiki.org/w/Triboulet · https://balatrowiki.org/w/Yorick · https://balatrowiki.org/w/Chicot · https://balatrowiki.org/w/Perkeo · https://balatrowiki.org/w/Canio · https://choostgames.com/blog/balatro-jokers/ · https://steelseries.com/blog/balatro-joker-tier-list

### A17. Tarot/Spectral generators (they supply deck fixing and assembly)
- **Cartomancer**: a Tarot on Blind select. Blueprint gives 2. "Most reliable early, falls off later." Strongest with Fortune Teller (+1 Mult per Tarot used). Also good with Lucky Cat, Steel, Glass, Vampire and Driver's License. Anti: Throwback, Anaglyph, Nebula. Superjump: Cartomancer with Blueprint gives "two" Tarots per blind.
- **Vagabond**: a Tarot if a hand is played with $4 or less. Anti: Bull, Bootstraps, Lucky cards.
- **Superposition**: a Tarot on a Straight with a scoring Ace. Shortcut, Four Fingers, Abandoned Deck.
- **Seance**: a Spectral on a Straight Flush. Four Fingers, Shortcut, Smeared, Checkered Deck. Feeds Hologram, Vampire, DNA and Driver's License.
- **Sixth Sense**: a lone 6 is destroyed for a Spectral. Pairs with DNA, Erosion and Canio (via Pareidolia).
- **Fortune Teller**: +1 Mult per Tarot used this run. Comicbook: "Fortune Teller + Steel Joker" via Chariot.
- Community: Choost B (Fortune Teller); SteelSeries C (Cartomancer), D (Superposition, Seance). Tier C as build pieces, B as enablers early.
- Sources: https://balatrowiki.org/w/Cartomancer · https://balatrowiki.org/w/S%C3%A9ance · https://balatrowiki.org/w/Superposition · https://comicbook.com/gaming/news/best-joker-combos-balatro/

### A18. Economy engines that fund the build [wiki numbers]
- **To the Moon**: +$1 interest per $5 held, still bounded by the interest cap.
  - [wiki] Maximum interest per round: $10 with the default cap, $20 with Seed Money, $40 with Seed Money + Money Tree.
  - Copies stack.
  - Anti: Green Deck, Credit Card, Vagabond.
- **Rocket**: $1 per round, +$2 per Boss beaten (applied before that round's payout). [computed] After 4 Bosses it pays $9 per round.
  - Addison Kindrick: the exception to "dump money jokers"; after about 4 antes it funds rerolls.
  - mangonaise used Rocket and Mail-In Rebate more in his faster Completionist++ run.
- **Golden Joker**: $4 per round. Not copyable.
- **Cloud 9**: $1 per 9 in the full deck. That is $4 in a standard deck, and more with Death, Strength or Cryptid on 9s. No cap.
- **Bull**: +2 chips per $1. **Bootstraps**: +2 Mult per $5. Both turn savings into score. Pair them with Rocket, Golden Ticket and Gold cards. Anti: Credit Card, Wraith, The Ox, Rentals.
- **Gold cards** (The Devil) held with **Mime**: $6 each. With a Red Seal and Mime: $9 (W:Mime). **Golden Ticket**: $4 per scored Gold card ($8 with a Red Seal).
- **Mail-In Rebate** ($5 per discarded card of the round's rank). Blueprint/Brainstorm copies multiply it (Superjump).
- **Business Card** or **Reserved Parking** with Oops: guaranteed money.
- **Rough Gem**: $1 per scored Diamond.
- **Trading Card**: $3 plus a deck thin.
- **Timing.** Economy first. Reach the $25 cap by Ante 3 (Two Average Gamers). Sell economy jokers for scorers around Ante 5-6 (Two Average Gamers). Keep Rocket (Addison Kindrick).
- **Community.** Choost: Rocket, Golden Joker and Egg B. SteelSeries: To the Moon and Bootstraps B; Cloud 9, Golden Joker and Bull C.
- Sources: https://balatrowiki.org/w/To_the_Moon · https://balatrowiki.org/w/Rocket · https://balatrowiki.org/w/Cloud_9 · https://balatrowiki.org/w/Bull · https://balatrowiki.org/w/Bootstraps · https://balatrowiki.org/w/Golden_Ticket · https://addisonkindrick.substack.com/p/10-balatro-tier-list-addendum

### A19. Retrigger synergies (Dusk, Sock and Buskin, Hanging Chad, Seltzer, Hack, Red Seals, Mime) and The Idol
- **Sources of retriggers.** [wiki]

  | Source | What it retriggers |
  |---|---|
  | Hanging Chad | first scored card, +2 |
  | Sock and Buskin | played faces, +1 |
  | Hack | played 2-5, +1 |
  | Dusk | every played card in the final hand, +1 |
  | Seltzer | every played card for 10 hands, +1; not Eternal-compatible |
  | Red Seal | its card, +1 (played and held) |
  | Mime | held-in-hand abilities, +1 |

  No retrigger repeats a Red Seal's own retrigger.
- **What to retrigger** (value roughly in this order) [estimate from wiki synergy lists]:
  1. Per-card xMult: Photograph, Triboulet, Glass, Polychrome cards, Bloodstone, Ancient, The Idol, Steel and Baron (held via Mime).
  2. Per-card scaling: Lucky Cat (rolls), Glass Joker (break chances are *not* rerolled), Hiker (+5 chips per trigger), Wee Joker (+8 per 2).
  3. Money: Gold Seal, Golden Ticket, Business Card, Rough Gem.
  4. +Mult or chips per card: Fibonacci, Smiley, Scholar and similar.
- **The Idol**: X2 per scored card of a rank+suit that changes each round. The pick is random from your deck, so a deck concentrated on one card is more likely to be picked. Best targets: 2-5 (Hack) or faces (Sock and Buskin). Flush Five of the target gives X32 before retriggers. "One of the harder Jokers to use well." Anti: Hologram, Certificate.
- **Acrobat**: X3 on the final hand. Pairs with Dusk. Situational at Gold (TrueAchievements [snippet]).
- Sources: https://balatrowiki.org/w/Dusk · https://balatrowiki.org/w/Seltzer · https://balatrowiki.org/w/Hack · https://balatrowiki.org/w/Red_Seal · https://balatrowiki.org/w/The_Idol

### A20. Chips anchors and hand-size trade-offs (Stuntman, Bull, Arrowhead, Wee Joker, Hiker, Stone)
- **Stuntman** (Rare, $7): +250 chips, -2 hand size. Best on High Card or Pair. Blueprint copies the chips *without* the penalty.
  - Support: Juggler, Troubadour, Turtle Bean, Paint Brush, Palette, Painted Deck, Plasma Deck. It helps Blackboard and Raised Fist.
  - Anti: Baron, Shoot the Moon, Reserved Parking, Steel, Gold, Blue Seals, The Psychic, Merry Andy.
  - Choost A. Mancunion: strong on Painted and Plasma decks.
- **Hiker**: +5 chips permanently per scored card, retriggers included. Sock and Buskin, Hack, Splash. DNA copies boosted cards. Hiker + Hanging Chad (Steam).
- **Stone**: Marble Joker + Stone Joker (+25 chips per Stone card in deck) suit High Card/Pair (W:Marble_Joker). Stone cards block Blackboard and Raised Fist.
- Sources: https://balatrowiki.org/w/Stuntman · https://balatrowiki.org/w/Hiker · https://balatrowiki.org/w/Marble_Joker

### A21. Driver's License and Erosion (deck-size payoffs)
- **Driver's License**: X3 with 16 or more enhanced cards. Use the 2-card enhancers, Midas + Pareidolia, Marble, DNA, Cryptid, Illusion. Anti: Vampire, Planet Merchant. (A11)
- **Erosion** (Uncommon): +4 Mult per card below the starting deck size (52, or 40 for Abandoned, 32 for Mad World). [computed] 10 cards removed gives +40.
  - Tools: Hanged Man, Immolate, Trading Card, Sixth Sense, Glass breaks.
  - Synergy: Glass Joker, Canio.
  - Anti: Hologram, DNA, Certificate, Marble, Cryptid.
  - SteelSeries C.
- Sources: https://balatrowiki.org/w/Driver%27s_License · https://balatrowiki.org/w/Erosion

### A22. Other run-shaping pieces players cite
- **Splash** (Common, $3): every played card scores. Best with High Card/Pair. It enables Flower Pot (4 suits from a small hand), Seeing Double, Lucky/Glass extra cards, Scholar and Hiker. Anti: Ride the Bus, 5-card hands. SteelSeries C.
- **Burnt Joker** (Rare): levels the first discarded hand each round. Pairs and High Cards are easy to discard and level. Red Deck, Drunkard. Anti: Burglar, Green Joker, Blue Stake. Mancunion recommends it for Red Deck.
- **Showman**: duplicates possible. Strong with Black Deck and with Commons (Cavendish, Photograph, Hanging Chad), Blueprint, Observatory planets. Anti: Telescope, Satellite.
- **Joker Stencil**: X1 per empty slot, including itself; Negative jokers add to it. Ankh or Ectoplasm with an Eternal Stencil. Anti: Abstract, Riff-Raff. Steam: "Joker Stencil + Ankh." SteelSeries D.
- **Baseball Card** (Rare): X1.5 per Uncommon joker; put Uncommons left. Addison Kindrick: raises the floor of utility Uncommons. Good with Black Deck. Pairs with Blackboard, Hologram, Glass Joker, Spare Trousers, To the Moon, Rocket, Oops.
- **Cavendish** (Common): X3 unconditional, 1/1000 chance to go extinct. It appears only after Gros Michel goes extinct in the same run, so buy Gros Michel early and let it die naturally (Blizzard Watch). Choost S; SteelSeries S.
- **Mr. Bones**: survive at 25% or more of the requirement. Choost A, SteelSeries A. Insurance, not a build.
- **Chicot / Luchador / Director's Cut / Retcon**: boss answers. Director's Cut is recommended by the wiki General strategy.
- Sources: https://balatrowiki.org/w/Splash · https://balatrowiki.org/w/Burnt_Joker · https://balatrowiki.org/w/Showman · https://balatrowiki.org/w/Joker_Stencil · https://balatrowiki.org/w/Baseball_Card · https://balatrowiki.org/w/Cavendish · https://blizzardwatch.com/2025/01/23/balatro-beginner-intermediate-tips/

---

## 3. Compact table

Tier is my synthesis for finishing Ante 8 at Purple-Gold stakes [estimate]. Sources use the short keys defined in section 5.

| Archetype | Core | Key support | Hand | Assemble with | Tier | Sources |
|---|---|---|---|---|---|---|
| Baron + Mime (Steel Kings) | Baron, Mime, Kings | Steel (Chariot), Red Seal (Deja Vu), Blueprint/Brainstorm, DNA, Steel Joker, Shoot the Moon (left), hand size | High Card, Pair | Chariot on K; Death (copy best K); Strength Q to K; Hanged Man; Cryptid; Deja Vu | A (S endless) | W:Baron, W:Mime, W:Red_Seal, ST-100M, ST-ENH |
| Blueprint/Brainstorm | Blueprint, Brainstorm | Any xMult or retrigger target; Showman | any | Place left of target / target leftmost | S (if target) | W:Blueprint, W:Brainstorm, MOBA[s], CHOOST |
| Photochad + face retrigger | Photograph, Hanging Chad | Sock and Buskin, Red Seal + Glass lead King, Smiley, Blueprint on Photo, Pareidolia | High Card, Pair (5-card with S&B) | Deja Vu + Justice on 1 King; Death/Strength faces | A | W:Photograph, W:Hanging_Chad, MAN, MANGO |
| Triboulet + Sock and Buskin | Triboulet, Sock and Buskin | Chad, Dusk, Seltzer, Red Seals, Blueprint | Full House, Flush House, Five of a Kind | Strength, Death, Cryptid, Hanged Man | S | W:Triboulet, ST-2J |
| Canio | Canio | Hanged Man, Justice faces, Pareidolia, Glass Joker, Trading Card, Erosion | any | Hanged Man on faces; Justice on faces | S | W:Canio |
| Low cards | Hack, Fibonacci/Wee Joker/Walkie/Even/Odd/Scholar | Chad, Dusk, Hiker, The Idol, Ride the Bus | Four/Five of a Kind, Full House of 2-5 | Hanged Man faces; Death copies of 2/5; Incantation | B | W:Hack, W:Wee_Joker, W:Fibonacci, MAN |
| Flush | Smeared, Four Fingers, The Tribe | Ancient + Wilds, Bloodstone (+Oops), suit jokers, Droll, Crafty, Card Sharp | Flush (Flush House/Five) | Star/Moon/Sun/World x3, Lovers, Hanged Man | B (A w/ Ancient + Smeared) | W:Smeared_Joker, W:Ancient_Joker, W:Bloodstone, SJ, RB |
| Lucky | Lucky Cat, Lucky cards, Oops | Chad, Red Seals, Splash, Seltzer, Bloodstone, Business Card | 5-card, or High Card + Chad | Magician; Death copies; Deja Vu | B (A w/ Oops) | W:Lucky_Cat, W:Lucky_Card, AK |
| Glass | Glass cards, Glass Joker | Chad (X8 lead), Red Seal (X4), Poly (X3), Canio, Erosion, DNA/Cryptid | any | Justice; Hanged Man on spare Glass | A (finisher) | W:Glass_Card, W:Glass_Joker, ST-ENH |
| Steel | Steel cards, Steel Joker | Mime, Baron, DNA, Red Seals, Fortune Teller | High Card, Pair | Chariot; Death; Cryptid | A w/ Mime | W:Steel_Joker, W:Steel_Card |
| Card adders / enhancement eaters | Hologram, DNA, Certificate, Marble / Vampire + Midas (+Pareidolia), Driver's License | Blueprint on DNA, Cryptid, Familiar/Grim/Incantation, Illusion | High Card for DNA; 5-card for Vampire | DNA on best card; 2-card enhancer tarots | A | W:Hologram, W:DNA, W:Vampire, W:Driver's_License |
| Planet engine | Constellation | Astronomer, Satellite, Blue Seals + Mime, Telescope, High Priestess, Space Joker, Supernova | committed hand | Trance; buy Planets | A | W:Constellation, MANGO |
| Perkeo + Observatory | Perkeo, Telescope then Observatory | Blue Seals, Showman, Crystal Ball, Blueprint on Perkeo | any committed | hold only the target Planet | S (if Perkeo) | W:Perkeo, W:Observatory |
| Pair/High Card joker-carried | Card Sharp, The Duo/Trio/Family, Spare Trousers + Square | Supernova, Green Joker, Burglar, Splash, held Steel/Gold, Blue Seals | Pair, High Card, Two Pair | Mercury/Pluto/Uranus; Telescope | A | RB, SJ, MAN, MANGO |
| Campfire | Campfire | Economy, Cartomancer, Riff-Raff, Emperor, Rentals | any | sell 8+ per ante | B | W:Campfire |
| Hit the Road | Hit the Road | DNA or Cryptid Jacks, Mail-In Rebate, Drunkard | small hands | Strength 10 to J; Hanged Man | B | W:Hit_the_Road |
| Throwback | Throwback | Anaglyph, Diet Cola, Glass | any | skip blinds | B | W:Throwback |
| Yorick | Yorick | discard boosters, Mail-In Rebate, Castle | any | Wasteful/Recyclomancy | S | W:Yorick, MAN |
| Obelisk | Obelisk | buffer of 15+ Pairs, then rotate | rotate | n/a | B | W:Obelisk, AK, BW |
| Economy | To the Moon, Rocket, Golden Joker, Cloud 9, Bull, Bootstraps | Seed Money/Money Tree, Gold cards + Mime, Mail-In Rebate | n/a | Devil (Gold), Talisman | support | W:To_the_Moon, W:Rocket, MANGO, AK |
| Stuntman chips | Stuntman | Blueprint (copy w/o penalty), hand size | High Card, Pair | Paint Brush/Palette | A (Choost) | W:Stuntman, CHOOST |
| Cavendish | Cavendish (via Gros Michel extinction) | Blueprint, Showman | any | buy Gros Michel early | S (Choost/SS) | W:Cavendish, BW |

---

## 4. Pairwise synergies (A + B: why, strength)
Strength codes [estimate]:
- S = run-winning;
- A = strong;
- B = good;
- C = minor;
- ✗ = anti-synergy (negative weight for the mod).

1. **Baron + Mime**: each held King triggers twice; 5 Kings X57.7 [computed]. S
2. **Baron + Steel cards (Chariot on Kings)**: X2.25 per held Steel King. S
3. **Baron + Red Seal (Deja Vu on Steel Kings)**: a Steel Red Seal King "counts as two Steel Kings" (wiki). A
4. **Baron + Blueprint/Brainstorm**: an extra X1.5 per held King per copy; better than copying Mime when triggers > factors [computed]. S
5. **Mime + Blueprint/Brainstorm**: an extra retrigger of all held effects (Steel, Baron, Gold $, Blue Seals). A
6. **Baron + DNA**: adds Kings (copies keep Steel and seals). A
7. **Baron + Shoot the Moon**: +13 per held Queen, multiplied by Kings to its right if the Queens sit left. B
8. **Baron + Raised Fist**: lowest held card's rank x2 to Mult, placed left of the Kings. C
9. **Steel Joker + Chariot/DNA/Cryptid**: X0.2 per Steel card in the deck. A
10. **Mime + Gold cards (Devil)**: $6 per held Gold card, $9 with a Red Seal. B (economy)
11. **Mime + Blue Seal (Trance)**: 2 Planets per round for the final hand; feeds Constellation and Observatory. A
12. **Photograph + Hanging Chad**: face card leftmost gives X8. A
13. **Photograph + Sock and Buskin**: extra triggers on the first face card (X16 with Chad). A
14. **Hanging Chad + Red Seal on the lead card**: 4 triggers total. A
15. **Hanging Chad + Glass lead card**: X8 from Glass alone (wiki). A
16. **Hanging Chad + Lucky lead card / Lucky Cat**: 3 rolls per hand. B
17. **Hanging Chad + Hiker**: +15 permanent chips per hand on the lead card. B
18. **Triboulet + Sock and Buskin**: 5 K/Q give X1,024 [computed]. S
19. **Triboulet + Blueprint/Brainstorm**: X4 per K/Q trigger. S
20. **Sock and Buskin + Pareidolia**: every card retriggers, which feeds Smiley, Scary, Business Card and Scholar. B
21. **Pareidolia + Midas Mask (+Vampire)**: every scored card becomes Gold, then Vampire eats it (X0.1 each). A
22. **Midas Mask + Vampire**: steady Vampire scaling; Mask left of Vampire. B (A early)
23. **Midas Mask + Golden Ticket**: needs Vampire left of the Mask if both are present; otherwise $4 per scored Gold card. C
24. **Canio + Glass Joker (+Justice on faces)**: both scale per Glass face break. A
25. **Canio + Pareidolia**: any destroyed card counts. A
26. **Canio + Hanged Man / Trading Card**: controlled face destruction. A
27. **Glass cards + Red Seal**: X4, with no extra break chance. A
28. **Glass Joker + Hanged Man**: destroying Glass with Hanged Man scales it (Immolate etc. do not; bug). B
29. **Glass Joker + Oops! All 6s**: 1/2 break chance, fast scaling, fast deck drain. B
30. **Lucky Cat + Oops! All 6s**: about 2x trigger rate. A
31. **Lucky Cat + Magician/Death**: supply of Lucky cards. B
32. **Bloodstone + Oops! All 6s**: guaranteed X1.5 per Heart; 5 Hearts X7.6. A
33. **Bloodstone + Smeared Joker**: Diamonds also roll. B
34. **Bloodstone + Lusty Joker (left of it)**: +3 per Heart before the xMult. C
35. **Ancient Joker + Smeared Joker**: the chosen suit covers half the deck; "nearly won the run alone." A
36. **Ancient Joker + Wild cards (Lovers)**: Wilds always match the current suit. A
37. **Ancient Joker + Photograph**: wiki calls this the strongest xMult pairing for Ancient. B
38. **Ancient Joker / Bloodstone / Rough Gem + Four Fingers**: fewer scoring suited cards. ✗ (mild)
39. **Smeared Joker + suit tarots**: half as many conversions needed. B
40. **Four Fingers + Shortcut**: easy Straights and Straight Flushes; Seance and Superposition trigger. B
41. **Flower Pot + Splash**: score 4 suits from small hands. B
42. **Flower Pot + Seeing Double**: X6 on a mixed-suit hand. B
43. **Seeing Double + Smeared Joker**: any Spade or Club counts as a Club (wiki calls this a bug). B
44. **Blackboard + Stuntman/small hand (or Ectoplasm, Merry Andy)**: easier to hold only black cards. B
45. **Blackboard + Mime**: Mime does not retrigger it. ✗ (no synergy)
46. **Hack + Wee Joker**: each 2 gives +16 chips permanently. B
47. **Hack + Fibonacci**: retriggered 2, 3, 5 give +8 each, doubled. B
48. **Hack + The Idol (target rank 2-5)**: X2 twice per target card. A
49. **The Idol + Sock and Buskin (face target)**: same idea for faces. A
50. **Ride the Bus + Pareidolia/Splash/face jokers**: resets. ✗
51. **Card Sharp + Pair/High Card commitment (+Burglar for Needle)**: X3 from the 2nd hand of each round. A
52. **Card Sharp + The Eye / The Needle**: hard counter. ✗
53. **Spare Trousers + Square Joker**: both scale on 4-card Two Pair. B
54. **Spare Trousers / Supernova / Green Joker + Burglar / Grabber**: more hands, faster scaling. B
55. **Supernova + Space Joker / Telescope**: one committed hand. B
56. **Obelisk + Supernova / Telescope / Burglar**: conflict. ✗
57. **Constellation + Astronomer**: free Planets, more Constellation stacks. A
58. **Constellation + Satellite**: unique Planets pay $1 per round each. B
59. **Constellation + Campfire / Red Card / Throwback**: conflict (use vs sell or skip). ✗
60. **Perkeo + Observatory (+single held Planet)**: X1.5 per copy. S
61. **Perkeo + Cryptid / Temperance / Ectoplasm**: high-value copy targets. A
62. **Hologram + DNA / Certificate / Marble / Cryptid**: X0.25 per added card. A
63. **Hologram + Erosion**: opposite goals. ✗
64. **DNA + Blueprint/Brainstorm**: multiple copies per round. A
65. **DNA + Steel/Glass/Lucky/Gold or Red Seal cards**: copies keep modifiers. A
66. **DNA + Sixth Sense**: duplicate the 6 for free Spectrals. B
67. **Vampire + Lucky Cat / Glass Joker / Steel Joker / Driver's License / Golden Ticket**: eats their enhancements. ✗
68. **Driver's License + 2-card enhancers (Magician/Empress/Hierophant) / Midas + Pareidolia**: reach 16 enhanced cards. B
69. **Campfire + Cartomancer / Riff-Raff / Emperor / Rentals / Credit Card**: cards to sell. B
70. **Campfire + Throwback / Diet Cola**: skipping triggers the boss reset sooner. ✗
71. **Hit the Road + Mail-In Rebate (rank Jack) / DNA on Jacks**: X0.5 and money per Jack. A
72. **Yorick + Drunkard / Merry Andy / Wasteful**: more cards discarded. A
73. **Yorick / Hit the Road / Castle / Burnt Joker + Burglar**: no discards. ✗
74. **Throwback + Anaglyph Deck / Diet Cola**: more skips. B
75. **Throwback + Rocket / Cartomancer / Hologram / Vampire / Supernova**: conflict. ✗
76. **Madness + Riff-Raff (left)**: fodder. C
77. **Madness / Ceremonial Dagger + other jokers**: destruction. ✗ (unless Eternal)
78. **Ceremonial Dagger + Egg / Gift Card**: more sell value eaten. C
79. **Stuntman + Blueprint**: +250 chips copied without -2 hand size. B
80. **Stuntman + Baron / Mime / Steel / Shoot the Moon**: hand size loss. ✗
81. **Cavendish + Blueprint/Brainstorm**: X3 copies with no extra extinction risk. A
82. **Gros Michel + Oops! All 6s**: faster extinction, so faster access to Cavendish [inference]. C
83. **Baseball Card + several Uncommons (left)**: X1.5 each. A
84. **Joker Stencil + Ankh / Ectoplasm / Negative jokers**: more empty-slot stacks. B
85. **Bull + Bootstraps + Rocket / Golden Ticket / To the Moon**: savings converted to score. B
86. **Bull / Bootstraps + Credit Card / Wraith / Rentals**: conflict. ✗
87. **To the Moon + Seed Money / Money Tree**: up to $40 interest per round. B
88. **Mail-In Rebate + Blueprint/Brainstorm**: $5 becomes $15 per discard. B
89. **Business Card / Reserved Parking + Oops! All 6s**: guaranteed money. C
90. **Cartomancer + Fortune Teller**: Tarot supply feeds +Mult. B
91. **Cartomancer + Blueprint**: 2 Tarots per Blind. B
92. **Seance + Four Fingers / Shortcut / Smeared / Checkered Deck**: repeatable Spectrals. B
93. **Superposition + Shortcut / Four Fingers / Abandoned Deck**: Ace Straights give Tarots. C
94. **Splash + High Card/Pair with enhanced kickers (Glass/Lucky/Stone)**: extra cards score. B
95. **Burnt Joker + Red Deck / Drunkard (Pair/High Card discards)**: free levels each round. B
96. **Showman + Commons (Cavendish, Photograph, Hanging Chad) / Blueprint**: duplicates. B
97. **Showman + Telescope / Satellite**: conflict. ✗
98. **Erosion + Glass Joker / Canio / Immolate**: deck shrinkage scales all of them. B
99. **Chicot + face/suit/Card Sharp/Baron builds**: boss counters removed. A
100. **Dusk + Acrobat**: final hand retriggered plus X3. B
101. **Dusk + Seltzer / Ice Cream**: hand-count timing conflict. ✗ (mild)
102. **Seltzer + Blueprint**: copies the retrigger. B
103. **Any face build + The Plant**: hard counter. Answer with Director's Cut, Retcon, Luchador or Chicot. ✗

---

## 5. Source list (key → URL, quality)
- **W:\<Page\>** → `https://balatrowiki.org/w/<Page>`. Opened pages: Jokers, Guide:_General_strategy, Scoring, Blinds_and_Antes, Stakes, Poker_Hands, Card_Modifiers, Tarot_Cards, Spectral_Cards, Vouchers, Baron, Mime, Blueprint, Brainstorm, Sock_and_Buskin, Photograph, Hanging_Chad, Pareidolia, Triboulet, Hack, Wee_Joker, Fibonacci, Midas_Mask, Scholar, Smeared_Joker, Four_Fingers, Bloodstone, Ancient_Joker, The_Tribe, Steel_Card, Red_Seal, Glass_Card, Lucky_Card, Hologram, DNA, Vampire, Constellation, Card_Sharp, Lucky_Cat, Glass_Joker, Steel_Joker, Campfire, Hit_the_Road, Perkeo, Observatory, Yorick, Canio, Chicot, Throwback, Obelisk, Ride_the_Bus, Madness, Ceremonial_Dagger, Supernova, Space_Joker, Cartomancer, Driver's_License, The_Idol, Dusk, Seltzer, Stuntman, Erosion, Splash, Burnt_Joker, Showman, Séance, Superposition, Shoot_the_Moon, To_the_Moon, Bull, Bootstraps, Rocket, Cloud_9, Blackboard, Flower_Pot, Seeing_Double, Castle, Oops!_All_6s, Certificate, Marble_Joker, Spare_Trousers, Raised_Fist, Baseball_Card, Rough_Gem, Reserved_Parking, Satellite, Cavendish, Ectoplasm, Hiker, Joker_Stencil, Golden_Ticket. **Highest quality.**
- **MANGO**: mangonaise, "I did Completionist++ twice! Stats & tips". Gold Stake on all decks, twice. https://steamcommunity.com/app/2379780/discussions/0/604143165271744486 **High.**
- **MAN**: Mancunion, "a guide to gold stake balatro" (2025). Deck-by-deck advice from a 200+ hour player. https://mancunion.com/2025/09/01/a-guide-to-gold-stake-balatro/ **Medium-high.**
- **SJ**: Superjump, "All In: Advanced Strategies…" (Gold Stake focus). https://www.superjumpmagazine.com/all-in-advanced-strategies-for-earning-c-in-balatro/ **Medium-high.**
- **AK**: Addison Kindrick, 1.0 Gold Stake tier list addendum. The tier image was not readable; I used the reasoning text. https://addisonkindrick.substack.com/p/10-balatro-tier-list-addendum **Medium-high.**
- **RB**: rblind mirror of an r/balatro post on BU's "pairs are better" video. https://www.rblind.com/post/20191354 **Medium.** It is the only Reddit content I could open.
- **ST-100M**: https://steamcommunity.com/app/2379780/discussions/0/7410182856435245149. Baron vs Glass consistency. Medium (anecdotal).
- **ST-ENH**: https://steamcommunity.com/app/2379780/discussions/0/600772276758004947. Enhancement value, "builds to Ante 12." Medium.
- **ST-ORANGE**: https://steamcommunity.com/app/2379780/discussions/0/4356744017103053782. YoruHawk on hands and economy at high stakes. Medium.
- **ST-HOW**: https://steamcommunity.com/app/2379780/discussions/0/4364626348105356076. Ordering, joker mix, pivoting. Medium.
- **ST-LOCK**: https://steamcommunity.com/app/2379780/discussions/0/614286180499921460. "Hard committing is the largest noob trap." Medium.
- **ST-2J**: https://steamcommunity.com/app/2379780/discussions/0/4408543518583235699. Two-joker combos. Medium.
- **ST-BP**: https://steamcommunity.com/app/2379780/discussions/0/604152945255155798. Blueprint target choice. Medium.
- **ST-ENDLESS**: https://steamcommunity.com/app/2379780/discussions/0/4634862878162233313. Endless builds (Flush Five Glass Kings; Steel King High Card; Perkeo Pluto). Medium.
- **ST-FLUSH**: https://steamcommunity.com/app/2379780/discussions/0/3874841262734556821. Low.
- **BW**: Blizzard Watch, intermediate tips. https://blizzardwatch.com/2025/01/23/balatro-beginner-intermediate-tips/ **Medium.**
- **TAG**: Two Average Gamers, joker combos. https://www.twoaveragegamers.com/balatro-strategy-guide-the-joker-combos-that-actually-win-runs/ **Medium-low.** Its Baron math is wrong: x11 with Mime should be x57.7.
- **CHOOST**: Choost Games Gold Stake tier list (April 2026). https://choostgames.com/blog/balatro-jokers/ **Medium-low.** It lists only about 42 jokers.
- **SS**: SteelSeries tier list. https://steelseries.com/blog/balatro-joker-tier-list **Low-medium.** Some effect text is wrong (Yorick, Baron).
- **MOBA**: Mobalytics Gold Stake tier list. https://mobalytics.gg/blog/tier-lists/best-balatro-jokers/ **[snippet only]**; it returned HTTP 403.
- **GGG**: games.gg, Baron/Mime guide. https://games.gg/balatro/guides/baron-mime-balatro-build/ **Low.** It has mechanics errors.
- **CB**: comicbook, best joker combos. https://comicbook.com/gaming/news/best-joker-combos-balatro/ **Low-medium.**
- **SB**: Switchblade, 15 combos. https://www.switchbladegaming.com/strategy-games/balatro-best-joker-combos/ **Low.** It has arithmetic errors (Photochad "x6"; Midas + Vampire given as "+Mult").
- **EG**: earlyguides builds. https://earlyguides.com/balatro/builds **Low.**
- **Snippet-only**: DigitalTrends Gold Stake jokers (https://digitaltrends.com/?p=3796142); ui.lemm.ee guide (https://ui.lemm.ee/post/35308428, DNS dead); PC Gamer tips (https://pcgamer.com/balatro-tips; the body didn't load); TrueAchievements (403).
