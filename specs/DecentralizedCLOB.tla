---- MODULE DecentralizedCLOB ----
EXTENDS TLC, Common, FiniteSets

\* Decentralized continuous limit order book.
\* Multiple nodes each maintain independent order books.
\* Orders are submitted to a global pool and delivered to nodes
\* in nondeterministic order. Each node runs the same price-time
\* priority matching engine, but different delivery orders can
\* produce different trade results — motivating consensus.
\*
\* Real-world examples:
\*   - Serum / OpenBook (Solana on-chain order book)
\*   - dYdX v4 (Cosmos app-chain, validators run matching)
\*   - Hyperliquid (L1 with on-chain order book)
\*   - Injective Protocol (Cosmos chain with FBA)

CONSTANTS
    Traders,
    Prices,
    Quantities,
    Nodes,          \* set of nodes (e.g. {"N1", "N2"})
    MaxTime,
    MaxOrders

VARIABLES
    orderPool,      \* sequence of submitted orders: <<side, trader, price, qty, id, time>>
    buyBooks,       \* [Nodes -> Seq(order)] per-node buy books
    sellBooks,      \* [Nodes -> Seq(order)] per-node sell books
    tradeLogs,      \* [Nodes -> Seq(trade)] per-node trade logs
    processed,      \* [Nodes -> SUBSET Nat] order pool indices delivered to each node
    nextOrderId,
    time

vars == <<orderPool, buyBooks, sellBooks, tradeLogs, processed, nextOrderId, time>>

\* ── Pool order accessors ──
\* Pool orders carry a side tag: <<"buy"/"sell", trader, price, qty, id, time>>
PSide(o)   == o[1]
PTrader(o) == o[2]
PPrice(o)  == o[3]
PQty(o)    == o[4]
PId(o)     == o[5]
PTime(o)   == o[6]

\* ── Per-node price-time priority ──
\* Same logic as CentralizedCLOB but parameterized over a book.

BestBidIdxOf(book) ==
    CHOOSE i \in 1..Len(book) :
        \A j \in 1..Len(book) :
            \/ OPrice(book[i]) > OPrice(book[j])
            \/ (OPrice(book[i]) = OPrice(book[j])
               /\ OTime(book[i]) <= OTime(book[j]))

BestAskIdxOf(book) ==
    CHOOSE i \in 1..Len(book) :
        \A j \in 1..Len(book) :
            \/ OPrice(book[i]) < OPrice(book[j])
            \/ (OPrice(book[i]) = OPrice(book[j])
               /\ OTime(book[i]) <= OTime(book[j]))

\* ── Actions ──

Init ==
    /\ orderPool = <<>>
    /\ buyBooks = [n \in Nodes |-> <<>>]
    /\ sellBooks = [n \in Nodes |-> <<>>]
    /\ tradeLogs = [n \in Nodes |-> <<>>]
    /\ processed = [n \in Nodes |-> {}]
    /\ nextOrderId = 0
    /\ time = 0

\* Submit a buy order to the global pool.
SubmitBuy ==
    /\ time < MaxTime
    /\ Len(orderPool) < MaxOrders
    /\ \E t \in Traders :
        \E p \in Prices :
            \E q \in Quantities :
                /\ orderPool' = Append(orderPool,
                       <<"buy", t, p, q, nextOrderId, time>>)
                /\ nextOrderId' = nextOrderId + 1
                /\ time' = time + 1
                /\ UNCHANGED <<buyBooks, sellBooks, tradeLogs, processed>>

\* Submit a sell order to the global pool.
SubmitSell ==
    /\ time < MaxTime
    /\ Len(orderPool) < MaxOrders
    /\ \E t \in Traders :
        \E p \in Prices :
            \E q \in Quantities :
                /\ orderPool' = Append(orderPool,
                       <<"sell", t, p, q, nextOrderId, time>>)
                /\ nextOrderId' = nextOrderId + 1
                /\ time' = time + 1
                /\ UNCHANGED <<buyBooks, sellBooks, tradeLogs, processed>>

\* A node receives an order from the pool.
\* Nondeterministic: any node can receive any unprocessed order next.
\* This models network propagation where nodes see orders in different sequences.
DeliverOrder ==
    \E n \in Nodes :
        \E i \in 1..Len(orderPool) :
            /\ i \notin processed[n]
            /\ LET po    == orderPool[i]
                   entry == <<PTrader(po), PPrice(po), PQty(po),
                              PId(po), PTime(po)>>
               IN
                /\ IF PSide(po) = "buy"
                   THEN /\ buyBooks' = [buyBooks EXCEPT
                              ![n] = Append(buyBooks[n], entry)]
                        /\ UNCHANGED sellBooks
                   ELSE /\ sellBooks' = [sellBooks EXCEPT
                              ![n] = Append(sellBooks[n], entry)]
                        /\ UNCHANGED buyBooks
                /\ processed' = [processed EXCEPT
                       ![n] = processed[n] \union {i}]
                /\ UNCHANGED <<orderPool, tradeLogs, nextOrderId, time>>

\* A node matches its best bid against best ask.
\* Same matching logic as CentralizedCLOB: executes at the ask (resting sell) price.
MatchAt ==
    \E n \in Nodes :
        /\ Len(buyBooks[n]) > 0
        /\ Len(sellBooks[n]) > 0
        /\ LET bb   == buyBooks[n]
               sb   == sellBooks[n]
               bi   == BestBidIdxOf(bb)
               ai   == BestAskIdxOf(sb)
               buy  == bb[bi]
               sell == sb[ai]
           IN
            \* Crossed book: bid >= ask
            /\ OPrice(buy) >= OPrice(sell)
            \* Self-trade prevention
            /\ OTrader(buy) /= OTrader(sell)
            /\ LET fillQty    == Min(OQty(buy), OQty(sell))
                   tradePrice == OPrice(sell)
                   trade      == <<OTrader(buy), OTrader(sell),
                                  tradePrice, fillQty, time,
                                  OPrice(buy), OPrice(sell)>>
               IN
                /\ tradeLogs' = [tradeLogs EXCEPT
                       ![n] = Append(tradeLogs[n], trade)]
                /\ buyBooks' = [buyBooks EXCEPT ![n] =
                    IF OQty(buy) = fillQty
                    THEN RemoveAt(bb, bi)
                    ELSE ReplaceAt(bb, bi,
                         <<OTrader(buy), OPrice(buy),
                           OQty(buy) - fillQty,
                           OId(buy), OTime(buy)>>)]
                /\ sellBooks' = [sellBooks EXCEPT ![n] =
                    IF OQty(sell) = fillQty
                    THEN RemoveAt(sb, ai)
                    ELSE ReplaceAt(sb, ai,
                         <<OTrader(sell), OPrice(sell),
                           OQty(sell) - fillQty,
                           OId(sell), OTime(sell)>>)]
                /\ UNCHANGED <<orderPool, processed, nextOrderId, time>>

\* ── Helpers ──

NodeBookCrossed(n) ==
    /\ Len(buyBooks[n]) > 0
    /\ Len(sellBooks[n]) > 0
    /\ OPrice(buyBooks[n][BestBidIdxOf(buyBooks[n])])
       >= OPrice(sellBooks[n][BestAskIdxOf(sellBooks[n])])

NodeBookCrossedDifferentTraders(n) ==
    /\ NodeBookCrossed(n)
    /\ OTrader(buyBooks[n][BestBidIdxOf(buyBooks[n])])
       /= OTrader(sellBooks[n][BestAskIdxOf(sellBooks[n])])

AllDelivered ==
    \A n \in Nodes : processed[n] = 1..Len(orderPool)

AllSettled ==
    /\ time >= MaxTime
    /\ AllDelivered
    /\ \A n \in Nodes : ~NodeBookCrossedDifferentTraders(n)

Terminated ==
    /\ AllSettled
    /\ UNCHANGED vars

Next ==
    \/ SubmitBuy
    \/ SubmitSell
    \/ DeliverOrder
    \/ MatchAt
    \/ Terminated

\* ── Invariants (per-node correctness — should hold) ──

\* Every resting order on every node has quantity > 0.
PositiveBookQuantities ==
    \A n \in Nodes :
        /\ \A i \in 1..Len(buyBooks[n])  : OQty(buyBooks[n][i]) > 0
        /\ \A i \in 1..Len(sellBooks[n]) : OQty(sellBooks[n][i]) > 0

\* Every trade at every node has quantity > 0.
PositiveTradeQuantities ==
    \A n \in Nodes :
        \A i \in 1..Len(tradeLogs[n]) : TQty(tradeLogs[n][i]) > 0

\* Price improvement holds at every node.
PriceImprovement ==
    \A n \in Nodes :
        \A i \in 1..Len(tradeLogs[n]) :
            /\ TPrice(tradeLogs[n][i]) <= TBuyLimit(tradeLogs[n][i])
            /\ TPrice(tradeLogs[n][i]) >= TSellLimit(tradeLogs[n][i])

\* No self-trades at any node.
NoSelfTrades ==
    \A n \in Nodes :
        \A i \in 1..Len(tradeLogs[n]) :
            TBuyer(tradeLogs[n][i]) /= TSeller(tradeLogs[n][i])

\* ── Cross-node consensus properties ──
\* These are EXPECTED TO FAIL. Add as INVARIANT to find counterexamples
\* showing that different delivery orders produce different results.

\* Do all nodes agree on the exact trade sequence?
ConsensusOnTrades ==
    AllSettled =>
        \A n1, n2 \in Nodes : tradeLogs[n1] = tradeLogs[n2]

\* Do nodes at least agree on the set of trade prices used?
ConsensusOnPrices ==
    AllSettled =>
        \A n1, n2 \in Nodes :
            {TPrice(tradeLogs[n1][i]) : i \in 1..Len(tradeLogs[n1])}
            = {TPrice(tradeLogs[n2][i]) : i \in 1..Len(tradeLogs[n2])}

\* Do nodes agree on how many trades occurred?
ConsensusOnVolume ==
    AllSettled =>
        \A n1, n2 \in Nodes :
            Len(tradeLogs[n1]) = Len(tradeLogs[n2])

Spec ==
    Init /\ [][Next]_vars

====
