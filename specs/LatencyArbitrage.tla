---- MODULE LatencyArbitrage ----
EXTENDS TLC, Naturals

\* Models latency arbitrage between two CLOBs with stale quotes.
\*
\* Two exchanges list the same asset. When a public signal moves the "true"
\* price, one exchange updates its quotes faster than the other. A fast
\* trader (arbitrageur) snipes the stale quote on the slow exchange before
\* the market maker can update it.
\*
\* This is the core mechanism from Budish, Cramton, and Shim (2015):
\*   "The High-Frequency Trading Arms Race: Frequent Batch Auctions as a
\*    Market Design Response to HFT"
\*
\* Their argument: continuous limit order books create an arms race where
\* speed advantages translate to sniping profits. Frequent batch auctions
\* eliminate this because all orders in a batch get the same price —
\* there is no stale quote to snipe.
\*
\* The model:
\*   - Two CLOBs with market maker quotes at bid/ask
\*   - A price signal moves the true value
\*   - The fast exchange updates quotes immediately
\*   - The slow exchange has stale quotes for one step
\*   - An arbitrageur buys (sells) on the stale exchange and sells (buys)
\*     on the fast exchange
\*
\* Real-world examples:
\*   - NYSE vs BATS/IEX latency differences
\*   - Binance vs Coinbase quote staleness
\*   - Cross-L2 arbitrage (Arbitrum vs Optimism)
\*   - This is the primary argument for IEX's speed bump and for batch auctions
\*
\* Key result:
\*   - NoArbitrageProfit FAILS (fast trader profits from stale quotes)
\*   - MarketMakerNotHarmed FAILS (MM loses on stale fills)
\*   - Contrast: BatchedAuction's OrderingIndependence eliminates staleness

CONSTANTS
    InitBid,        \* initial bid price on both exchanges
    InitAsk,        \* initial ask price on both exchanges
    PriceJump,      \* how much the true price moves (positive = up)
    Qty             \* quantity available at each price level

VARIABLES
    fastBid,        \* fast exchange: current bid
    fastAsk,        \* fast exchange: current ask
    slowBid,        \* slow exchange: current bid (may be stale)
    slowAsk,        \* slow exchange: current ask (may be stale)
    arbProfit,      \* arbitrageur's cumulative profit
    mmLoss,         \* market maker's cumulative loss on stale fills
    slowUpdated,    \* whether the slow exchange has updated
    signalMoved,    \* whether the price signal has occurred
    phase           \* "pre" | "signal" | "arb" | "update" | "done"

vars == << fastBid, fastAsk, slowBid, slowAsk, arbProfit, mmLoss,
           slowUpdated, signalMoved, phase >>

\* ── Actions ──

Init ==
    /\ fastBid = InitBid
    /\ fastAsk = InitAsk
    /\ slowBid = InitBid
    /\ slowAsk = InitAsk
    /\ arbProfit = 0
    /\ mmLoss = 0
    /\ slowUpdated = FALSE
    /\ signalMoved = FALSE
    /\ phase = "signal"

\* Public signal: true price jumps up. Fast exchange updates immediately.
\* Slow exchange still has stale quotes.
SignalUp ==
    /\ phase = "signal"
    /\ PriceJump > 0
    \* Fast exchange updates quotes instantly
    /\ fastBid' = InitBid + PriceJump
    /\ fastAsk' = InitAsk + PriceJump
    \* Slow exchange keeps stale quotes
    /\ UNCHANGED << slowBid, slowAsk >>
    /\ signalMoved' = TRUE
    /\ phase' = "arb"
    /\ UNCHANGED << arbProfit, mmLoss, slowUpdated >>

\* Public signal: true price jumps down.
SignalDown ==
    /\ phase = "signal"
    /\ PriceJump > 0
    /\ InitBid > PriceJump  \* prices stay positive
    \* Fast exchange updates quotes instantly
    /\ fastBid' = InitBid - PriceJump
    /\ fastAsk' = InitAsk - PriceJump
    \* Slow exchange keeps stale quotes
    /\ UNCHANGED << slowBid, slowAsk >>
    /\ signalMoved' = TRUE
    /\ phase' = "arb"
    /\ UNCHANGED << arbProfit, mmLoss, slowUpdated >>

\* No signal: prices don't move.
NoSignal ==
    /\ phase = "signal"
    /\ signalMoved' = FALSE
    /\ phase' = "done"
    /\ UNCHANGED << fastBid, fastAsk, slowBid, slowAsk,
                    arbProfit, mmLoss, slowUpdated >>

\* Arbitrageur snipes stale quotes after upward signal.
\* Buy on slow exchange at stale ask, sell on fast exchange at new bid.
\* Profit = fastBid - slowAsk (positive when signal moved price up).
ArbSniperUp ==
    /\ phase = "arb"
    /\ fastBid > slowAsk  \* profitable: fast bid > slow stale ask
    /\ arbProfit' = arbProfit + (fastBid - slowAsk) * Qty
    /\ mmLoss' = mmLoss + (fastBid - slowAsk) * Qty
    /\ phase' = "update"
    /\ UNCHANGED << fastBid, fastAsk, slowBid, slowAsk, slowUpdated, signalMoved >>

\* Arbitrageur snipes after downward signal.
\* Sell on slow exchange at stale bid, buy on fast exchange at new ask.
\* Profit = slowBid - fastAsk (positive when signal moved price down).
ArbSniperDown ==
    /\ phase = "arb"
    /\ slowBid > fastAsk  \* profitable: slow stale bid > fast ask
    /\ arbProfit' = arbProfit + (slowBid - fastAsk) * Qty
    /\ mmLoss' = mmLoss + (slowBid - fastAsk) * Qty
    /\ phase' = "update"
    /\ UNCHANGED << fastBid, fastAsk, slowBid, slowAsk, slowUpdated, signalMoved >>

\* No arbitrage opportunity (spread doesn't cross).
SkipArb ==
    /\ phase = "arb"
    /\ fastBid <= slowAsk
    /\ slowBid <= fastAsk
    /\ phase' = "update"
    /\ UNCHANGED << fastBid, fastAsk, slowBid, slowAsk,
                    arbProfit, mmLoss, slowUpdated, signalMoved >>

\* Slow exchange finally updates quotes.
SlowUpdate ==
    /\ phase = "update"
    /\ slowBid' = fastBid
    /\ slowAsk' = fastAsk
    /\ slowUpdated' = TRUE
    /\ phase' = "done"
    /\ UNCHANGED << fastBid, fastAsk, arbProfit, mmLoss, signalMoved >>

Terminated ==
    /\ phase = "done"
    /\ UNCHANGED vars

Next ==
    \/ SignalUp
    \/ SignalDown
    \/ NoSignal
    \/ ArbSniperUp
    \/ ArbSniperDown
    \/ SkipArb
    \/ SlowUpdate
    \/ Terminated

\* ── Invariants (should hold) ──

\* After update, both exchanges have the same quotes.
QuotesConverge ==
    (phase = "done" /\ signalMoved) =>
        /\ slowBid = fastBid
        /\ slowAsk = fastAsk

\* Arbitrage profit equals market maker loss (zero-sum).
ZeroSum ==
    arbProfit = mmLoss

\* ── Latency arbitrage properties (EXPECTED TO FAIL) ──

\* "No one profits from being faster."
\* FAILS: arbitrageur profits by sniping stale quotes.
NoArbitrageProfit ==
    arbProfit = 0

\* "Market makers are not harmed by latency differences."
\* FAILS: market maker on slow exchange gets adversely selected.
MarketMakerNotHarmed ==
    mmLoss = 0

\* ── Batch auction comparison (structural argument) ──

\* In a batch auction, there are no stale quotes to snipe because:
\*   1. Orders are collected over a time window (no continuous matching)
\*   2. All orders clear at the same price (OrderingIndependence)
\*   3. A price signal during the batch window is reflected in the clearing
\*      price — there is no "fast" vs "slow" execution
\*
\* This is Budish et al.'s core argument: batch auctions eliminate the
\* value of speed by removing the concept of "stale" quotes entirely.
\* Our BatchedAuction spec verifies OrderingIndependence, confirming
\* that submission timing cannot affect the clearing price.

Spec ==
    Init /\ [][Next]_vars

====
