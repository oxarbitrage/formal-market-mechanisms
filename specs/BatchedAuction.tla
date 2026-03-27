---- MODULE BatchedAuction ----
EXTENDS TLC, Common, FiniteSets

CONSTANTS Traders, Prices, Quantities, MaxBatches, MaxOrdersPerBatch

VARIABLES
    nextOrderId,
    buyOrders,      \* orders collected in current batch
    sellOrders,     \* orders collected in current batch
    trades,         \* all executed trades across all batches
    batch,          \* current batch number
    phase           \* "collecting" or "clearing"

vars == << nextOrderId, buyOrders, sellOrders, trades, batch, phase >>

\* ── Aggregate supply and demand ──

\* Demand at price p: total buy quantity from orders with limit >= p
DemandAt(p) ==
    LET s[j \in 0..Len(buyOrders)] ==
        IF j = 0 THEN 0
        ELSE IF OPrice(buyOrders[j]) >= p
             THEN s[j-1] + OQty(buyOrders[j])
             ELSE s[j-1]
    IN s[Len(buyOrders)]

\* Supply at price p: total sell quantity from orders with limit <= p
SupplyAt(p) ==
    LET s[j \in 0..Len(sellOrders)] ==
        IF j = 0 THEN 0
        ELSE IF OPrice(sellOrders[j]) <= p
             THEN s[j-1] + OQty(sellOrders[j])
             ELSE s[j-1]
    IN s[Len(sellOrders)]

\* Volume that clears at price p
VolumeAt(p) == Min(DemandAt(p), SupplyAt(p))

\* The clearing price maximizes traded volume.
\* Among ties, pick the lowest price (convention).
ClearingPrice ==
    CHOOSE p \in Prices :
        /\ \A q \in Prices : VolumeAt(p) >= VolumeAt(q)
        /\ \A q \in Prices :
            (VolumeAt(q) = VolumeAt(p)) => p <= q

\* ── Clearing engine ──
\* Match eligible buyers and sellers at the clearing price.
\* Iterates buy index 1..Len(buyOrders), for each iterates sell index
\* 1..Len(sellOrders). Deterministic — no CHOOSE over permutations.
\* Returns a sequence of trades.
ClearTrades(cp, vol) ==
    LET nb == Len(buyOrders)
        ns == Len(sellOrders)
        \* Flatten buyer-seller pairs into a deterministic sequence:
        \* pair k (0-indexed) = <<buy index, sell index>>
        \* where k = (b-1)*ns + (s-1), b in 1..nb, s in 1..ns
        numSlots == nb * ns
        BuyIdx(k)  == ((k-1) \div ns) + 1
        SellIdx(k) == ((k-1) % ns) + 1
        \* Sequential fill over all slots
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
                  \* Skip if not eligible or self-trade
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
                                      cp, fillQty, batch,
                                      OPrice(buyOrders[b]),
                                      OPrice(sellOrders[s])>>),
                                 buyRem  |-> [prev.buyRem  EXCEPT ![b] = @ - fillQty],
                                 sellRem |-> [prev.sellRem EXCEPT ![s] = @ - fillQty],
                                 volRem  |-> prev.volRem - fillQty]
    IN result[numSlots].trades

\* ── Actions ──
Init ==
    /\ nextOrderId = 0
    /\ buyOrders = <<>>
    /\ sellOrders = <<>>
    /\ trades = <<>>
    /\ batch = 0
    /\ phase = "collecting"

SubmitBuyOrder ==
    /\ phase = "collecting"
    /\ batch < MaxBatches
    /\ Len(buyOrders) + Len(sellOrders) < MaxOrdersPerBatch
    /\ \E t \in Traders:
        \E p \in Prices:
            \E q \in Quantities:
                /\ buyOrders' = Append(buyOrders, <<t, p, q, nextOrderId, batch>>)
                /\ nextOrderId' = nextOrderId + 1
                /\ UNCHANGED << sellOrders, trades, batch, phase >>

SubmitSellOrder ==
    /\ phase = "collecting"
    /\ batch < MaxBatches
    /\ Len(buyOrders) + Len(sellOrders) < MaxOrdersPerBatch
    /\ \E t \in Traders:
        \E p \in Prices:
            \E q \in Quantities:
                /\ sellOrders' = Append(sellOrders, <<t, p, q, nextOrderId, batch>>)
                /\ nextOrderId' = nextOrderId + 1
                /\ UNCHANGED << buyOrders, trades, batch, phase >>

\* Close the collection window and move to clearing.
CloseBatch ==
    /\ phase = "collecting"
    /\ batch < MaxBatches
    /\ Len(buyOrders) + Len(sellOrders) > 0
    /\ phase' = "clearing"
    /\ UNCHANGED << nextOrderId, buyOrders, sellOrders, trades, batch >>

\* Execute the batch: compute clearing price, generate trades, reset for next batch.
ClearBatch ==
    /\ phase = "clearing"
    /\ LET cp  == ClearingPrice
           vol == VolumeAt(cp)
           newTrades == ClearTrades(cp, vol)
       IN
        /\ trades' = trades \o newTrades
        /\ buyOrders' = <<>>
        /\ sellOrders' = <<>>
        /\ batch' = batch + 1
        /\ phase' = "collecting"
        /\ UNCHANGED << nextOrderId >>

Terminated ==
    /\ batch >= MaxBatches
    /\ phase = "collecting"
    /\ UNCHANGED vars

Next ==
    \/ SubmitBuyOrder
    \/ SubmitSellOrder
    \/ CloseBatch
    \/ ClearBatch
    \/ Terminated

\* ── Invariants ──

\* All trades within the same batch execute at the same price.
UniformClearingPrice ==
    \A i \in 1..Len(trades) :
        \A j \in 1..Len(trades) :
            (TTime(trades[i]) = TTime(trades[j]))
                => TPrice(trades[i]) = TPrice(trades[j])

\* Price improvement: trade price <= buyer's limit, >= seller's limit.
PriceImprovement ==
    \A i \in 1..Len(trades) :
        /\ TPrice(trades[i]) <= TBuyLimit(trades[i])
        /\ TPrice(trades[i]) >= TSellLimit(trades[i])

\* Every trade has quantity > 0.
PositiveTradeQuantities ==
    \A i \in 1..Len(trades) : TQty(trades[i]) > 0

\* No self-trades.
NoSelfTrades ==
    \A i \in 1..Len(trades) : TBuyer(trades[i]) /= TSeller(trades[i])

\* ── Temporal properties ──

\* If the batch is in clearing phase, it eventually returns to collecting.
EventualClearing ==
    (phase = "clearing") ~> (phase = "collecting")

Spec ==
    Init /\ [][Next]_vars /\ WF_vars(ClearBatch)

====
