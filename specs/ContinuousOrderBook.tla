---- MODULE ContinuousOrderBook ----
EXTENDS TLC, Common

CONSTANTS Traders, Prices, Quantities, MaxTime, MaxOrders

VARIABLES
    nextOrderId,
    buyBook,
    sellBook,
    trades,
    time

vars == << nextOrderId, buyBook, sellBook, trades, time >>

\* ── Price-time priority ──
\* Best bid: highest price, then earliest time
BestBidIdx ==
    CHOOSE i \in 1..Len(buyBook) :
        \A j \in 1..Len(buyBook) :
            \/ OPrice(buyBook[i]) > OPrice(buyBook[j])
            \/ OPrice(buyBook[i]) = OPrice(buyBook[j])
               /\ OTime(buyBook[i]) <= OTime(buyBook[j])

\* Best ask: lowest price, then earliest time
BestAskIdx ==
    CHOOSE i \in 1..Len(sellBook) :
        \A j \in 1..Len(sellBook) :
            \/ OPrice(sellBook[i]) < OPrice(sellBook[j])
            \/ OPrice(sellBook[i]) = OPrice(sellBook[j])
               /\ OTime(sellBook[i]) <= OTime(sellBook[j])

\* ── Actions ──
Init ==
    /\ nextOrderId = 0
    /\ buyBook = <<>>
    /\ sellBook = <<>>
    /\ trades = <<>>
    /\ time = 0

SubmitBuyOrder ==
    /\ time < MaxTime
    /\ Len(buyBook) + Len(sellBook) < MaxOrders
    /\ \E t \in Traders:
        \E p \in Prices:
            \E q \in Quantities:
                /\ buyBook' = Append(buyBook, <<t, p, q, nextOrderId, time>>)
                /\ nextOrderId' = nextOrderId + 1
                /\ time' = time + 1
                /\ UNCHANGED << sellBook, trades >>

SubmitSellOrder ==
    /\ time < MaxTime
    /\ Len(buyBook) + Len(sellBook) < MaxOrders
    /\ \E t \in Traders:
        \E p \in Prices:
            \E q \in Quantities:
                /\ sellBook' = Append(sellBook, <<t, p, q, nextOrderId, time>>)
                /\ nextOrderId' = nextOrderId + 1
                /\ time' = time + 1
                /\ UNCHANGED << buyBook, trades >>

\* ── Matching engine ──
\* Executes at the ask (resting sell) price.
\* Handles partial fills: the smaller side is fully filled,
\* the larger side's quantity is reduced in place.
MatchOrders ==
    /\ time < MaxTime
    /\ Len(buyBook) > 0
    /\ Len(sellBook) > 0
    /\ LET bi   == BestBidIdx
           ai   == BestAskIdx
           buy  == buyBook[bi]
           sell == sellBook[ai]
       IN
        \* Crossed book: bid >= ask
        /\ OPrice(buy) >= OPrice(sell)
        \* Self-trade prevention
        /\ OTrader(buy) /= OTrader(sell)
        /\ LET fillQty    == Min(OQty(buy), OQty(sell))
               tradePrice == OPrice(sell)
               trade      == <<OTrader(buy), OTrader(sell),
                              tradePrice, fillQty, time>>
           IN
            /\ trades' = Append(trades, trade)
            /\ buyBook' =
                IF OQty(buy) = fillQty
                THEN RemoveAt(buyBook, bi)
                ELSE ReplaceAt(buyBook, bi,
                     <<OTrader(buy), OPrice(buy),
                       OQty(buy) - fillQty,
                       OId(buy), OTime(buy)>>)
            /\ sellBook' =
                IF OQty(sell) = fillQty
                THEN RemoveAt(sellBook, ai)
                ELSE ReplaceAt(sellBook, ai,
                     <<OTrader(sell), OPrice(sell),
                       OQty(sell) - fillQty,
                       OId(sell), OTime(sell)>>)
            /\ time' = time + 1
            /\ UNCHANGED << nextOrderId >>

Terminated ==
    /\ time >= MaxTime
    /\ UNCHANGED vars

Next ==
    \/ SubmitBuyOrder
    \/ SubmitSellOrder
    \/ MatchOrders
    \/ Terminated

Spec ==
    Init /\ [][Next]_vars

====
