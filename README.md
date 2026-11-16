# AgentCard

**One card. Your name in gold.**

AgentCard is a premium agent ID-card NFT collection on BNB Chain. Every card is an issued ID: a gold emblem, a sequential number, and its owner's name engraved on the plate.

## Supply — 2,222

| Pool | Amount | Price | Rules |
| --- | --- | --- | --- |
| Free Mint | 1,888 | 0 BNB | Binance Agent ID holders only, max 2 per wallet, Standard Issue steel card, no rarity draw |
| Paid Mint | 334 | 0.0012 BNB | Open to everyone, max 5 per wallet, Premium Issue gold card with the only rarity draw |

- **No phases.** Free and Paid open at the same moment; Paid Mint never waits for Free and never needs an Agent ID.
- **Paid rarity draw:** Common 50% · Rare 32% · Legendary 18% — the drawn tier upgrades the card's metal (bronze / silver+gold / full gold).
- **Automatic inscription:** every minted card is engraved with its sequential number (F-…/1,888 or P-…/334), the owner's wallet, tier, issue type and mint date.
- **Custom name engraving:** holders can engrave a name of their choice on their card for 0.0005 BNB per engraving.
- **Agent Points:** held cards earn points daily — Common 10/day, Rare 25/day, Legendary 100/day — unlocking whitelist priority, holder-only features and first entry to holder events. Points are not a token and promise no BNB returns.
- Cards are standard ERC-721 once the contract is live, and can be listed, bought and sold on BNB Chain marketplaces.

## Website

`index.html` is the complete site in a single file (all artwork inlined): mint panels for wallet and AI-agent minting with copyable prompts, the collection, Holder Rewards (points, Hall of Legendary, leaderboard), the holder dashboard with card lookup, PNG download and Post to X.

To publish with GitHub Pages: Settings → Pages → deploy from branch `main`, folder `/ (root)`.

## Status

- Website: live in this repo.
- Smart contract: **coming soon** — until it is deployed, the site's mint, points and lookup run in clearly labelled preview mode on the site's own records.
- NFT token files: **ready — no pre-numbering.** Metadata is four type templates in `meta/`: `free.json` (Standard Issue steel), `paid-common.json`, `paid-rare.json`, `paid-legendary.json` (Premium Issue plates). There are no numbered token files and no number ranges per pool: tokens take their ID in mint order from a single counter, and the contract's `tokenURI` returns the template matching the type/tier recorded for that token at mint. Paid rarity (Common 50% · Rare 32% · Legendary 18%) is rolled inside the mint transaction itself. Paid Mint is open to **every** wallet from the first moment mint opens — including Binance Agent ID holders, who may mint both Free and Paid. (The earlier numbered files `meta/1.json`–`meta/2222.json` are superseded by this scheme and are not used by the contract.)
