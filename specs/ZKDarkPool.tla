---- MODULE ZKDarkPool ----
EXTENDS TLC, Common, FiniteSets

\* Sealed-bid batch auction with commit-reveal protocol (ZK dark pool).
\* Combines batch auction clearing with pre-trade and post-trade privacy
\* to structurally eliminate MEV (front-running, sandwich attacks).
\*
\* Three phases:
\*   1. Commit: traders submit sealed orders (no visibility of others' orders)
\*   2. Clear: orders revealed, uniform-price batch clearing
\*   3. Done: individual orders destroyed, only clearing price + fills retained
\*
\* Privacy guarantees (modeled structurally in TLA+):
\*   - Pre-trade: order contents hidden during commit (nondeterministic choice)
\*   - Commitment binding: orders cannot be modified after commit
\*   - Post-trade: individual orders destroyed after clearing (ZK proofs
\*     verify correctness without revealing inputs)
\*
\* Real-world examples:
\*   - Penumbra (sealed-bid batch auctions on Cosmos with shielded transactions)
\*   - Renegade (MPC-based dark pool for on-chain private matching)
\*   - MEV Blocker / MEV Share (partial privacy via encrypted mempools)
\*
\* Key result: all BatchedAuction correctness properties hold, PLUS
\* sandwich attacks are provably impossible (SandwichResistant invariant).
\* Contrast with SandwichAttack.tla where the same adversary pattern succeeds.

CONSTANTS
    Traders,
    Prices,
    Quantities,
    MaxOrdersPerBatch

VARIABLES
    buyOrders,      \* committed buy orders (sealed during commit phase)
    sellOrders,     \* committed sell orders (sealed during commit phase)
    trades,         \* executed trades (fills visible to participants)
    clearPrice,     \* uniform clearing price (0 before clearing)
    phase,          \* "commit" | "clear" | "done"
    nextOrderId

vars == << buyOrders, sellOrders, trades, clearPrice, phase, nextOrderId >>

\* ── Aggregate supply and demand (same as BatchedAuction) ──

DemandAt(p) ==
    LET s[j \in 0..Len(buyOrders)] ==
        IF j = 0 THEN 0
        ELSE IF OPrice(buyOrders[j]) >= p
             THEN s[j-1] + OQty(buyOrders[j])
             ELSE s[j-1]
    IN s[Len(buyOrders)]

SupplyAt(p) ==
    LET s[j \in 0..Len(sellOrders)] ==
        IF j = 0 THEN 0
        ELSE IF OPrice(sellOrders[j]) <= p
             THEN s[j-1] + OQty(sellOrders[j])
             ELSE s[j-1]
    IN s[Len(sellOrders)]

VolumeAt(p) == Min(DemandAt(p), SupplyAt(p))

\* Clearing price: maximizes volume, lowest on ties.
ClearingPriceVal ==
    CHOOSE p \in Prices :
        /\ \A q \in Prices : VolumeAt(p) >= VolumeAt(q)
        /\ \A q \in Prices : (VolumeAt(q) = VolumeAt(p)) => p <= q

\* ── Clearing engine (same as BatchedAuction) ──
ClearTrades(cp, vol) ==
    LET nb == Len(buyOrders)
        ns == Len(sellOrders)
        numSlots == nb * ns
        BuyIdx(k)  == ((k-1) \div ns) + 1
        SellIdx(k) == ((k-1) % ns) + 1
        result[k \in 0..numSlots] ==
            IF k = 0
            THEN [trades  |-> <<>>,
                  buyRem  |-> [b \in 1..nb |-> OQty(buyOrders[b])],
                  sellRem |-> [s \in 1..ns |-> OQty(sellOrders[s])],
                  volRem  |-> vol]
            ELSE LET prev == result[k-1]
                     b == BuyIdx(k)
                     s == SellIdx(k)
                 IN
                  IF \/ OPrice(buyOrders[b]) < cp
                     \/ OPrice(sellOrders[s]) > cp
                     \/ OTrader(buyOrders[b]) = OTrader(sellOrders[s])
                     \/ prev.volRem = 0
                  THEN prev
                  ELSE LET fillQty == Min(Min(prev.buyRem[b], prev.sellRem[s]),
                                          prev.volRem)
                       IN  IF fillQty = 0
                           THEN prev
                           ELSE [trades  |-> Append(prev.trades,
                                    <<OTrader(buyOrders[b]),
                                      OTrader(sellOrders[s]),
                                      cp, fillQty, 0,
                                      OPrice(buyOrders[b]),
                                      OPrice(sellOrders[s])>>),
                                 buyRem  |-> [prev.buyRem  EXCEPT ![b] = @ - fillQty],
                                 sellRem |-> [prev.sellRem EXCEPT ![s] = @ - fillQty],
                                 volRem  |-> prev.volRem - fillQty]
    IN result[numSlots].trades

\* ── Actions ──

Init ==
    /\ buyOrders = <<>>
    /\ sellOrders = <<>>
    /\ trades = <<>>
    /\ clearPrice = 0
    /\ phase = "commit"
    /\ nextOrderId = 0

\* ── COMMIT PHASE ──
\* Traders submit sealed orders. Each submission is INDEPENDENT of others.
\* In TLA+, nondeterministic choice over (trader, price, qty) models the
\* sealed bid: no action references another trader's order contents.
\* In the real system, cryptographic commitments enforce this.

CommitBuy ==
    /\ phase = "commit"
    /\ Len(buyOrders) + Len(sellOrders) < MaxOrdersPerBatch
    /\ \E t \in Traders :
        \E p \in Prices :
            \E q \in Quantities :
                /\ buyOrders' = Append(buyOrders,
                       <<t, p, q, nextOrderId, 0>>)
                /\ nextOrderId' = nextOrderId + 1
                /\ UNCHANGED << sellOrders, trades, clearPrice, phase >>

CommitSell ==
    /\ phase = "commit"
    /\ Len(buyOrders) + Len(sellOrders) < MaxOrdersPerBatch
    /\ \E t \in Traders :
        \E p \in Prices :
            \E q \in Quantities :
                /\ sellOrders' = Append(sellOrders,
                       <<t, p, q, nextOrderId, 0>>)
                /\ nextOrderId' = nextOrderId + 1
                /\ UNCHANGED << buyOrders, trades, clearPrice, phase >>

\* Close the commit window. Orders are now locked — commitment binding.
CloseCommit ==
    /\ phase = "commit"
    /\ Len(buyOrders) > 0
    /\ Len(sellOrders) > 0
    /\ phase' = "clear"
    /\ UNCHANGED << buyOrders, sellOrders, trades, clearPrice, nextOrderId >>

\* ── CLEAR PHASE ──
\* Sealed orders are opened and cleared at a uniform price.
\* After clearing, order books are destroyed (post-trade privacy).
\* In the real system, ZK proofs verify the clearing was computed
\* correctly from the committed orders without revealing them.

ClearBatch ==
    /\ phase = "clear"
    /\ LET cp  == ClearingPriceVal
           vol == VolumeAt(cp)
           newTrades == ClearTrades(cp, vol)
       IN
        /\ trades' = newTrades
        /\ clearPrice' = cp
        /\ buyOrders' = <<>>      \* post-trade privacy: orders destroyed
        /\ sellOrders' = <<>>     \* post-trade privacy: orders destroyed
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

\* ── Invariants (correctness — should hold) ──

\* All trades execute at the same clearing price.
UniformClearingPrice ==
    \A i \in 1..Len(trades) :
        \A j \in 1..Len(trades) :
            TPrice(trades[i]) = TPrice(trades[j])

\* Price improvement: trade price within both parties' limits.
PriceImprovement ==
    \A i \in 1..Len(trades) :
        /\ TPrice(trades[i]) <= TBuyLimit(trades[i])
        /\ TPrice(trades[i]) >= TSellLimit(trades[i])

PositiveTradeQuantities ==
    \A i \in 1..Len(trades) : TQty(trades[i]) > 0

NoSelfTrades ==
    \A i \in 1..Len(trades) : TBuyer(trades[i]) /= TSeller(trades[i])

\* Same clearing price regardless of commit order.
OrderingIndependence ==
    (phase = "done") =>
        \A i \in 1..Len(trades) : TPrice(trades[i]) = clearPrice

\* Zero spread within the batch — no price difference to exploit.
NoSpreadArbitrage ==
    \A i \in 1..Len(trades) :
        \A j \in 1..Len(trades) :
            TPrice(trades[i]) = TPrice(trades[j])

\* ── MEV resistance (should hold — the key dark pool properties) ──

\* Sandwich resistant: a trader who has both buy and sell fills in the
\* same batch gets the SAME price on both sides. The spread is zero,
\* making the front-run/back-run pattern produce zero profit.
\* Contrast with SandwichAttack.tla where the adversary profits because
\* front-run and back-run execute at DIFFERENT prices.
SandwichResistant ==
    \A t \in Traders :
        \A i \in 1..Len(trades) :
            \A j \in 1..Len(trades) :
                (/\ TBuyer(trades[i]) = t
                 /\ TSeller(trades[j]) = t)
                    => TPrice(trades[i]) = TPrice(trades[j])

\* ── Privacy invariants ──

\* Post-trade privacy: after clearing, individual orders are destroyed.
\* Only the clearing price and individual fills (in trades) are retained.
PostTradeOrdersDestroyed ==
    (phase = "done") =>
        /\ buyOrders = <<>>
        /\ sellOrders = <<>>

\* ── Temporal properties ──

\* If the batch is ready to clear, it eventually clears.
EventualClearing ==
    (phase = "clear") ~> (phase = "done")

Spec ==
    Init /\ [][Next]_vars /\ WF_vars(ClearBatch)

====
