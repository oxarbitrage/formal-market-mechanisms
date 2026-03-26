---- MODULE ContinuousOrderBook ----
EXTENDS TLC, Naturals, Sequences

CONSTANTS Traders, Prices, Quantities, MaxTime

VARIABLES
    nextOrderId,
    buyBook,
    sellBook,
    trades,
    time

vars == << nextOrderId, buyBook, sellBook, trades, time >>

Init ==
    /\ nextOrderId = 0
    /\ buyBook = <<>>
    /\ sellBook = <<>>
    /\ trades = <<>>
    /\ time = 0

SubmitBuyOrder ==
    \E t \in Traders:
        \E p \in Prices:
            \E q \in Quantities:
                /\ buyBook' = Append(buyBook, <<t, p, q, nextOrderId, time>>)
                /\ nextOrderId' = nextOrderId + 1
                /\ time' = time + 1
                /\ UNCHANGED << sellBook, trades >>

SubmitSellOrder ==
    \E t \in Traders:
        \E p \in Prices:
            \E q \in Quantities:
                /\ sellBook' = Append(sellBook, <<t, p, q, nextOrderId, time>>)
                /\ nextOrderId' = nextOrderId + 1
                /\ time' = time + 1
                /\ UNCHANGED << buyBook, trades >>

JustTick ==
    /\ time < MaxTime
    /\ time' = time + 1
    /\ UNCHANGED << nextOrderId, buyBook, sellBook, trades >>

Next ==
    \/ JustTick
    \/ SubmitBuyOrder
    \/ SubmitSellOrder
Spec ==
    Init
    /\ [][Next]_vars


====