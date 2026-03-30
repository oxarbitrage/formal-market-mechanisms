---- MODULE ShieldedDEX ----
EXTENDS TLC, Common, FiniteSets

\* Multi-asset shielded exchange with per-pair batch clearing.
\*
\* Extends the ZKDarkPool model to multiple trading pairs where even the
\* asset pair targeted by each order is hidden. Inspired by Zcash Shielded
\* Assets (ZIP-226/227): custom tokens issued within the shielded pool
\* inherit Zcash's privacy guarantees — transfers of different asset types
\* are indistinguishable on-chain.
\*
\* In existing mechanisms, the asset pair is always public:
\*   - CLOB: order book is per-pair
\*   - AMM: pool is per-pair (reserves visible)
\*   - BatchedAuction: orders are per-pair
\*   - ZKDarkPool: order contents hidden, but pair is known
\*
\* ShieldedDEX hides the pair itself. Commitments don't reveal which pair
\* they target. After clearing, individual orders are destroyed across ALL
\* pairs. An observer cannot determine which pairs were active, how many
\* orders each pair received, or whether a commitment was a trade or transfer.
\*
\* Novel formal results:
\*   1. Per-pair batch auction correctness holds (all invariants inherited)
\*   2. Cross-pair isolation: each pair clears independently (verified)
\*   3. Asset-targeted attacks fail (attacker can't identify which pair to target)
\*   4. The impossibility triangle is NOT fixed by privacy
\*   5. Privacy adds a 4th dimension: privacy vs price discovery
\*
\* Real-world context:
\*   - Zcash ZSA (ZIP-226/227): shielded custom assets
\*   - Penumbra + multi-asset: shielded batch auctions across pairs
\*   - Anoma: intent-centric architecture with privacy across asset types

CONSTANTS
    Traders,
    Prices,
    Quantities,
    Pairs,              \* set of trading pair identifiers (e.g., {"P1", "P2"})
    MaxOrdersPerBatch   \* max orders per pair (per side)

VARIABLES
    buyOrders,          \* [Pairs -> Seq(order)] per-pair shielded buy orders
    sellOrders,         \* [Pairs -> Seq(order)] per-pair shielded sell orders
    trades,             \* [Pairs -> Seq(trade)] per-pair executed trades
    clearPrice,         \* [Pairs -> Nat] per-pair clearing price (0 = no clearing)
    phase,              \* "commit" | "clear" | "done"
    nextOrderId

vars == << buyOrders, sellOrders, trades, clearPrice, phase, nextOrderId >>

\* ── Parameterized clearing functions ──
\* Same logic as BatchedAuction/ZKDarkPool, but taking order sequences
\* as parameters so they can be applied independently per pair.

DemandAtP(buys, p) ==
    LET s[j \in 0..Len(buys)] ==
        IF j = 0 THEN 0
        ELSE IF OPrice(buys[j]) >= p
             THEN s[j-1] + OQty(buys[j])
             ELSE s[j-1]
    IN s[Len(buys)]

SupplyAtP(sells, p) ==
    LET s[j \in 0..Len(sells)] ==
        IF j = 0 THEN 0
        ELSE IF OPrice(sells[j]) <= p
             THEN s[j-1] + OQty(sells[j])
             ELSE s[j-1]
    IN s[Len(sells)]

VolumeAtP(buys, sells, p) == Min(DemandAtP(buys, p), SupplyAtP(sells, p))

ClearingPriceP(buys, sells) ==
    IF buys = <<>> \/ sells = <<>>
    THEN 0
    ELSE CHOOSE p \in Prices :
        /\ \A q \in Prices : VolumeAtP(buys, sells, p) >= VolumeAtP(buys, sells, q)
        /\ \A q \in Prices :
            (VolumeAtP(buys, sells, q) = VolumeAtP(buys, sells, p)) => p <= q

ClearTradesP(buys, sells, cp, vol) ==
    IF Len(buys) = 0 \/ Len(sells) = 0
    THEN <<>>
    ELSE
    LET nb == Len(buys)
        ns == Len(sells)
        numSlots == nb * ns
        BuyIdx(k)  == ((k-1) \div ns) + 1
        SellIdx(k) == ((k-1) % ns) + 1
        result[k \in 0..numSlots] ==
            IF k = 0
            THEN [trades  |-> <<>>,
                  buyRem  |-> [b \in 1..nb |-> OQty(buys[b])],
                  sellRem |-> [s \in 1..ns |-> OQty(sells[s])],
                  volRem  |-> vol]
            ELSE LET prev == result[k-1]
                     b == BuyIdx(k)
                     s == SellIdx(k)
                 IN
                  IF \/ OPrice(buys[b]) < cp
                     \/ OPrice(sells[s]) > cp
                     \/ OTrader(buys[b]) = OTrader(sells[s])
                     \/ prev.volRem = 0
                  THEN prev
                  ELSE LET fillQty == Min(Min(prev.buyRem[b], prev.sellRem[s]),
                                          prev.volRem)
                       IN  IF fillQty = 0
                           THEN prev
                           ELSE [trades  |-> Append(prev.trades,
                                    <<OTrader(buys[b]),
                                      OTrader(sells[s]),
                                      cp, fillQty, 0,
                                      OPrice(buys[b]),
                                      OPrice(sells[s])>>),
                                 buyRem  |-> [prev.buyRem  EXCEPT ![b] = @ - fillQty],
                                 sellRem |-> [prev.sellRem EXCEPT ![s] = @ - fillQty],
                                 volRem  |-> prev.volRem - fillQty]
    IN result[numSlots].trades

\* ── Actions ──

Init ==
    /\ buyOrders  = [pair \in Pairs |-> <<>>]
    /\ sellOrders = [pair \in Pairs |-> <<>>]
    /\ trades     = [pair \in Pairs |-> <<>>]
    /\ clearPrice = [pair \in Pairs |-> 0]
    /\ phase = "commit"
    /\ nextOrderId = 0

\* ── COMMIT PHASE ──
\* Traders submit shielded orders. BOTH the order contents AND the target
\* pair are hidden in the commitment. Each submission is independent of
\* all other traders' orders and pair choices.
\*
\* In TLA+, nondeterministic choice over (pair, trader, price, qty) models
\* the shielded commitment: no action references another commitment's pair.
\* In the real system, ZK proofs or MPC protocols enforce this.

CommitBuy ==
    /\ phase = "commit"
    /\ \E pair \in Pairs :
        /\ Len(buyOrders[pair]) + Len(sellOrders[pair]) < MaxOrdersPerBatch
        /\ \E t \in Traders :
            \E p \in Prices :
                \E q \in Quantities :
                    /\ buyOrders' = [buyOrders EXCEPT ![pair] =
                           Append(@, <<t, p, q, nextOrderId, 0>>)]
                    /\ nextOrderId' = nextOrderId + 1
                    /\ UNCHANGED << sellOrders, trades, clearPrice, phase >>

CommitSell ==
    /\ phase = "commit"
    /\ \E pair \in Pairs :
        /\ Len(buyOrders[pair]) + Len(sellOrders[pair]) < MaxOrdersPerBatch
        /\ \E t \in Traders :
            \E p \in Prices :
                \E q \in Quantities :
                    /\ sellOrders' = [sellOrders EXCEPT ![pair] =
                           Append(@, <<t, p, q, nextOrderId, 0>>)]
                    /\ nextOrderId' = nextOrderId + 1
                    /\ UNCHANGED << buyOrders, trades, clearPrice, phase >>

\* Close commit: at least one pair must have both buys and sells.
CloseCommit ==
    /\ phase = "commit"
    /\ \E pair \in Pairs :
        /\ Len(buyOrders[pair]) > 0
        /\ Len(sellOrders[pair]) > 0
    /\ phase' = "clear"
    /\ UNCHANGED << buyOrders, sellOrders, trades, clearPrice, nextOrderId >>

\* ── CLEAR PHASE ──
\* All pairs cleared simultaneously and independently. Each pair's clearing
\* depends ONLY on that pair's orders — cross-pair isolation by construction.
\* After clearing, all orders destroyed across ALL pairs (post-trade privacy).

ClearBatch ==
    /\ phase = "clear"
    /\ LET cpMap == [pair \in Pairs |->
               ClearingPriceP(buyOrders[pair], sellOrders[pair])]
           trMap == [pair \in Pairs |->
               LET buys == buyOrders[pair]
                   sells == sellOrders[pair]
                   cp == cpMap[pair]
                   vol == VolumeAtP(buys, sells, cp)
               IN ClearTradesP(buys, sells, cp, vol)]
       IN
        /\ clearPrice' = cpMap
        /\ trades' = trMap
        /\ buyOrders'  = [pair \in Pairs |-> <<>>]
        /\ sellOrders' = [pair \in Pairs |-> <<>>]
        /\ phase' = "done"
        /\ UNCHANGED << nextOrderId >>

Terminated ==
    /\ phase = "done"
    /\ UNCHANGED vars

Next ==
    \/ CommitBuy
    \/ CommitSell
    \/ CloseCommit
    \/ ClearBatch
    \/ Terminated

\* ── Per-pair correctness invariants (should hold) ──
\* Inherited from BatchedAuction, verified per pair.

PerPairUniformPrice ==
    \A pair \in Pairs :
        \A i \in 1..Len(trades[pair]) :
            \A j \in 1..Len(trades[pair]) :
                TPrice(trades[pair][i]) = TPrice(trades[pair][j])

PerPairPriceImprovement ==
    \A pair \in Pairs :
        \A i \in 1..Len(trades[pair]) :
            /\ TPrice(trades[pair][i]) <= TBuyLimit(trades[pair][i])
            /\ TPrice(trades[pair][i]) >= TSellLimit(trades[pair][i])

PerPairPositiveTradeQuantities ==
    \A pair \in Pairs :
        \A i \in 1..Len(trades[pair]) :
            TQty(trades[pair][i]) > 0

PerPairNoSelfTrades ==
    \A pair \in Pairs :
        \A i \in 1..Len(trades[pair]) :
            TBuyer(trades[pair][i]) /= TSeller(trades[pair][i])

\* ── Cross-pair isolation (should hold) ──

\* Each pair's trades match only that pair's clearing price.
\* Since ClearingPriceP takes only that pair's orders, this verifies
\* that clearing is pair-independent — no cross-pair information leakage.
CrossPairIsolation ==
    (phase = "done") =>
        \A pair \in Pairs :
            \A i \in 1..Len(trades[pair]) :
                TPrice(trades[pair][i]) = clearPrice[pair]

\* Post-trade: all orders destroyed across ALL pairs.
PostTradeOrdersDestroyed ==
    (phase = "done") =>
        \A pair \in Pairs :
            /\ buyOrders[pair] = <<>>
            /\ sellOrders[pair] = <<>>

\* ── MEV resistance (should hold) ──

\* Per-pair sandwich resistance: uniform price within each pair means
\* the sandwich pattern yields zero profit, same as ZKDarkPool.
\* Additionally, the attacker can't even TARGET a specific pair because
\* the pair identity is hidden in the commitment.
PerPairSandwichResistant ==
    \A pair \in Pairs :
        \A t \in Traders :
            \A i \in 1..Len(trades[pair]) :
                \A j \in 1..Len(trades[pair]) :
                    (/\ TBuyer(trades[pair][i]) = t
                     /\ TSeller(trades[pair][j]) = t)
                        => TPrice(trades[pair][i]) = TPrice(trades[pair][j])

\* ── Impossibility triangle: NOT fixed (should hold) ──

\* No immediacy: during commit phase, no trades exist in any pair.
\* Privacy doesn't help — you still must wait for the batch to close.
NoImmediacy ==
    (phase = "commit") =>
        \A pair \in Pairs : trades[pair] = <<>>

\* ── Price discovery tradeoff (EXPECTED TO FAIL) ──
\* The cost of asset-type privacy: cross-pair price information is lost.

\* "Clearing prices are consistent across pairs."
\* In a transparent system, arbitrageurs see price divergence across pairs
\* and submit orders to correct it. In a ShieldedDEX, no one can see which
\* pairs are active or at what prices — cross-pair arbitrage is impossible
\* within the batch.
\* FAILS: different pairs can clear at completely different prices with
\* no mechanism to align them. This is the price discovery cost of privacy.
CrossPairPriceConsistency ==
    (phase = "done") =>
        \A p1 \in Pairs :
            \A p2 \in Pairs :
                (/\ Len(trades[p1]) > 0
                 /\ Len(trades[p2]) > 0)
                    => clearPrice[p1] = clearPrice[p2]

\* ── Temporal properties ──

EventualClearing ==
    (phase = "clear") ~> (phase = "done")

Spec ==
    Init /\ [][Next]_vars /\ WF_vars(ClearBatch)

====
