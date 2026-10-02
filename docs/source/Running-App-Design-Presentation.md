# Running App — Design Presentation (Animal Card Collectible)

Oct 2, 2026 · @amitesh

A presentation-ready walkthrough of the concept and every piece of its logic, built to lift straight into slides.

## The Big Idea

**Every run earns a collectible animal card.** That is the whole product in one line.

You lace up, you run, and the app quietly hands you a beautiful card — an animal that matches how you ran today, stamped with a serial number that is yours alone. No scores to feel bad about. No leaderboard to lose on. Just a growing, shareable collection that makes you want to run again tomorrow.

The emotional promise: running should give you something delightful to keep, not a number that makes you feel slow.

## Why It Is Different

Most running apps are built on comparison: pace, rank, who beat whom. This one deliberately drops all of that.

- **No leaderboards, no rankings.** Nobody is above or below anybody.
- **Fun-first.** The joy is collecting, growing, and showing off animals — not chasing a personal best.
- **The card is the hero.** Standard stats (distance, pace, calendar, heat map) exist, but as quiet supporting furniture. The animal is the star of every screen.
- **The card reflects the run, not the runner.** A gentle jog and a hard sprint earn *different* animals, never a better and a worse one.

## The Three Time Scales

The app tells three different stories about your running, on three clocks:

| Scale | The question it answers | What it measures | Animals you find here |
| --- | --- | --- | --- |
| **Daily** | How did you run *today*? | Speed, pace, distance, effort of one run | Everyday animals — cheetah, horse, rabbit, hamster, cat |
| **Weekly** | What was the *pattern* of your week? | Consistency (3/5/7 days), total volume, variety | Rare animals live here |
| **Monthly** | *Where* are you? | Region and geography you ran in | Regional animals — Kerala species, West Bengal species, camel for Rajasthan |

The daily card is instant gratification. The weekly card rewards showing up. The monthly card celebrates place and travel.

## How an Animal Is Chosen

Three inputs each control a different dimension of the card. This is the core logic of the whole app:

| Input | What it decides | Example |
| --- | --- | --- |
| **Speed** (age-graded) | The animal *family* | Fast effort opens cheetah/falcon/horse; gentle effort opens rabbit/cat/owl/deer |
| **Distance** | The *scale* of the animal | Short run gives a baby; long run gives a full-grown adult |
| **Consistency** | The *special finish* | Streaks add a glow, a seasonal colour, or a rare variant |

So speed says *which* animal, distance says *how big*, and consistency says *how special*. Three dials, endless combinations.

## Slow Is Never Shame

This is the heart of the design, and worth a whole slide.

Speed does not make a *better* animal — it makes a *different* one. Fast and slow are different families, not high and low tiers. An elephant is endurance and majesty. A tortoise is "Unstoppable". A wolf is a "Pack Hunter". None of these is a losing card.

**Age and gender** are used only for age-grading, so a 60-year-old and a 25-year-old can both earn top animals for an equivalent effort. These inputs are optional, private, and never shown on the card.

And a fast runner having a light week simply gets a hamster or a baby animal — because the card reflects *the week*, not the person. Nobody is ever punished.

## Growth & Progression

Animals are alive — they grow with you.

- **Baby to adult.** Keep running consistently and your animal grows up. Growth moments are celebrated events: "Your cheetah is all grown up!"
- **No re-babying on a break.** Miss some days and you are not demoted to a baby — you simply see a *different* animal instead. After about two months of inactivity, animals reset to baby.
- **Skipped weeks give no card at all** — never an insulting one.
- **Unlock the Wild.** Once you have mastered an animal, you graduate to a stage where each run rolls a different rare species. This keeps the late game exciting for dedicated runners.

## The Surprise Layer

There is luck in it, but it is *fair* luck.

**The run decides the pool; luck decides which animal from that pool.** A fast effort opens the fast-animals bag; a gentle run opens the calm bag. So a collector can deliberately run slowly to chase a rabbit — the player always has agency.

A **pity timer** quietly raises the odds of a rare the longer you go without one, so nobody gets stuck feeling unlucky forever. The surprise keeps every run feeling like opening a pack, without ever feeling random or unearned.

## Exploration & Geography

The app rewards *where* and *how* you explore, not just how fast you go. Each trigger unlocks a different kind of animal:

| Trigger | What you do | What you earn |
| --- | --- | --- |
| **New route** | Run a zigzag or untraced path in a familiar area | An explorer animal (e.g. fox) |
| **New location** | Run even once in a place you have not run before | That location's animal — a travel souvenir |
| **Home region** | Set once | An always-available regional pride animal |
| **Migratory bird** | Run across different geographies (likely state-level) over about 3 weeks | The prestige prize |
| **Time of day** | Run at night, or at dawn | An owl at night; a rooster or songbird at dawn |

A minimum distance or duration floor (about 1 km or 10 minutes at running pace) keeps people from farming location animals from a train or a car.

## The Card Itself

Every card carries the same ingredients, so two runners can compare at a glance:

- **Original animal art** — illustrated per animal, per tier.
- **A unique serial number** — the scarcity and proof mechanic. Tiger #0009 beats Tiger #4120, and everyone can see it.
- **Run stats** — the numbers behind this card.
- **A short flavour line** — e.g. "Elephant, the tireless traveller".
- **A set name** — e.g. "Monsoon 2026", grouping cards into collectible seasons.

**Same animal plus same tier means an identical template for everyone** — only the serial number differs. The rarest cards carry foil or holographic shimmer and rarity borders. The *feel* is a rare collectible card, but all art, layout, fonts, and naming are fully original.

## Trust & Sharing

The serial number is what makes a card real — and that powers both trust and growth.

- **One search field: serial-number lookup.** No searching people by name. You type a number (e.g. Tiger #0427) and see that single card — animal, number, who earned it, when.
- **The trust mechanism.** Anyone can fake a card image or AI-generate one, but they cannot fake a serial number that lives in the database. If it is in there, it is real.
- **Shareable posters** for Instagram and WhatsApp stories, showing the animal and serial number, with a QR code or short link to a simple public verify page — no app download needed. This is the growth loop: friends verify, then want their own.
- **Safety:** posters and verify pages never show the route map or start point, so nobody leaks a home address.

## Discovery-First Philosophy

The magic depends on *not* explaining the magic.

- **Never reveal the recipe.** The app hints that rewards exist, but never spells out how parameters map to animals. Users discover it by playing — "I got something different when I ran faster!"
- **Easter eggs.** Some secret animals are undocumented, waiting to be stumbled upon.
- **The encyclopedia.** A searchable in-app database of every animal and its majestic real-world qualities (elephants walk up to 50 miles a day). This is what turns a "slow" animal into a point of pride, and adds a layer of genuine charm and learning.
- **Gentle nudges.** The app may notice you are somewhere new and softly suggest a run — warm and well-timed, never spammy, never surveillance.

## Parameter Reference (appendix)

Every parameter the app reads, and what it controls on the card:

| Parameter | What it maps to |
| --- | --- |
| Speed / pace (age-graded) | The animal family (fast vs calm) |
| Distance | The scale of the animal (baby to adult) |
| Consistency / streak | The special finish (glow, seasonal colour, variant) |
| Days run per week | Weekly card tier (3/5/7 days) |
| Total weekly volume | Weekly card richness |
| New route / zigzag | Explorer animal |
| New location | Location's souvenir animal |
| Home region | Regional pride animal |
| Different geographies over ~3 weeks | Migratory bird |
| Time of day | Night owl, dawn songbird |
| Age / gender (optional, private) | Age-grading only; never shown |
| Heart rate (optional, watch) | Effort refinement and anti-cheat |

Together these dials give enormous variety from a tiny amount of input — the player just runs.
