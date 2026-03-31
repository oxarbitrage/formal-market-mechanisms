# Why the way you trade matters — and how privacy makes it fair

When you place a trade on most exchanges, you're walking into a game that's rigged by design. Not because anyone is cheating — because the rules themselves create winners and losers.

On a traditional order book (the kind NYSE, Binance, and Coinbase use), the first order in gets the best price. That sounds fair until you realize that "first" means whoever has the fastest connection, the closest server, the most expensive infrastructure. Speed becomes a tax on everyone else. Billions are spent each year on shaving microseconds off trade execution — not to build better products, but to see your order before you do and trade ahead of it. That's front-running, and it's structural, not a bug.

On an AMM like Uniswap, there's no order book — a mathematical formula sets the price. Anyone can trade, anytime. That sounds fair too, until someone sees your pending transaction, buys before you to push the price up, lets your trade execute at the worse price, then sells. You lost money. They gained it. That's a sandwich attack, and it happens thousands of times a day on Ethereum. It's estimated that MEV extraction — profits taken from ordinary users through transaction ordering — totals hundreds of millions of dollars per year.

## What if order didn't matter?

There's a different design: batch auctions. Instead of matching orders one by one as they arrive, orders are collected over a window and then cleared all at once at a single price. Everyone in the batch gets the same price. It doesn't matter if your order arrived first or last, from a fast server or a slow one.

We formally verified this — using the same mathematical proof techniques used in aerospace and chip design. Not simulated, not argued, *proved*: in a batch auction, the clearing price is the same regardless of the order in which trades are submitted. There is no spread to capture, no timing advantage to exploit, no sandwich to construct. The game is fair because the rules make exploitation structurally impossible.

## Privacy is not about having something to hide

Now consider: even in a fair batch auction, everyone can see what you're trading. They can see which asset pair you're interested in, how active that market is, and adjust their strategy accordingly. If a fund is rebalancing its portfolio, the market sees it. If a DAO votes to diversify its treasury, front-runners position themselves before the diversification even begins. If an individual in a difficult jurisdiction is moving assets, the pair itself reveals their intent.

Privacy in this context is not about concealing wrongdoing. It's about removing the information asymmetry that allows the powerful to exploit the ordinary. When your order contents are sealed and even the asset pair is hidden, no one can target you — because no one knows what you're doing. Your trade is indistinguishable from everyone else's. You are just another opaque commitment in a batch.

We proved that adding this privacy layer doesn't break any of the fairness guarantees. The same uniform pricing, the same ordering independence, the same resistance to manipulation — all carry over. Privacy is not a tradeoff against fairness. It's an addition to it.

## The cost of freedom

There is a real cost. When nobody can see what anyone is trading, price information doesn't flow between markets. Two pairs can clear at completely different prices and nobody can arbitrage the difference — because nobody can see it. We proved this too: full privacy eliminates cross-pair price discovery. That's a structural tradeoff, not a bug to fix.

There's also no instant execution — you wait for the batch. And no guaranteed liquidity — if nobody else is trading, you wait.

But these are honest tradeoffs. You know what you're giving up and what you're getting. No hidden extraction, no invisible tax, no advantage for the fastest. Just a fair clearing at a fair price, with nobody watching.

## The work

We built formal specifications for seven market mechanisms and six attack models, verified with TLC (a model checker for TLA+). Every claim above is backed by a mathematical proof or a concrete counterexample — not an opinion. The full specifications, proofs, and a readable book are open source.

[Read the book](https://oxarbitrage.github.io/formal-market-mechanisms/) · [Browse the specs](https://github.com/oxarbitrage/formal-market-mechanisms/tree/main/specs)
