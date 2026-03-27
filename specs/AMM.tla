---- MODULE AMM ----
EXTENDS TLC, Common, FiniteSets

\* Constant-product automated market maker (x * y = k).
\* Two tokens: A and B. The pool holds reserves of both.
\* Traders swap one token for the other at a price determined by the reserve ratio.

CONSTANTS
    Traders,        \* set of traders
    MaxSwap,        \* maximum swap amount per trade
    InitReserveA,   \* initial pool reserve of token A
    InitReserveB,   \* initial pool reserve of token B
    MaxTime,        \* bound for model checking
    FeeNum,         \* fee numerator (e.g. 3 for 0.3%)
    FeeDenom        \* fee denominator (e.g. 1000 for 0.3%)

VARIABLES
    reserveA,       \* pool reserve of token A
    reserveB,       \* pool reserve of token B
    swaps,          \* sequence of executed swaps
    balances,       \* [Traders -> [A: Nat, B: Nat]] trader balances
    time

vars == << reserveA, reserveB, swaps, balances, time >>

\* ── Swap computation ──
\* Swap amtIn of token X for token Y.
\* With fee: effectiveIn = amtIn * (FeeDenom - FeeNum) / FeeDenom
\* Output: amtOut = reserveY * effectiveIn / (reserveX + effectiveIn)
\* Using integer arithmetic to avoid reals.

\* Amount of B received when swapping amtIn of A into the pool.
SwapAForB(amtIn) ==
    LET effectiveIn == (amtIn * (FeeDenom - FeeNum))
        numerator  == reserveB * effectiveIn
        denominator == (reserveA * FeeDenom) + effectiveIn
    IN numerator \div denominator

\* Amount of A received when swapping amtIn of B into the pool.
SwapBForA(amtIn) ==
    LET effectiveIn == (amtIn * (FeeDenom - FeeNum))
        numerator  == reserveA * effectiveIn
        denominator == (reserveB * FeeDenom) + effectiveIn
    IN numerator \div denominator

\* ── Swap record ──
\* <<trader, direction, amtIn, amtOut, time>>
\* direction: "AtoB" or "BtoA"
STrader(s)    == s[1]
SDirection(s) == s[2]
SAmtIn(s)     == s[3]
SAmtOut(s)    == s[4]
STime(s)      == s[5]

\* ── Actions ──
Init ==
    /\ reserveA = InitReserveA
    /\ reserveB = InitReserveB
    /\ swaps = <<>>
    /\ balances = [t \in Traders |-> [A |-> InitReserveA, B |-> InitReserveB]]
    /\ time = 0

\* Trader swaps some amount of A for B.
SwapAtoB ==
    /\ time < MaxTime
    /\ \E t \in Traders :
        \E amt \in 1..MaxSwap :
            /\ balances[t].A >= amt
            /\ LET out == SwapAForB(amt)
               IN
                /\ out > 0
                /\ reserveA' = reserveA + amt
                /\ reserveB' = reserveB - out
                /\ balances' = [balances EXCEPT
                    ![t] = [A |-> balances[t].A - amt,
                            B |-> balances[t].B + out]]
                /\ swaps' = Append(swaps, <<t, "AtoB", amt, out, time>>)
                /\ time' = time + 1

\* Trader swaps some amount of B for A.
SwapBtoA ==
    /\ time < MaxTime
    /\ \E t \in Traders :
        \E amt \in 1..MaxSwap :
            /\ balances[t].B >= amt
            /\ LET out == SwapBForA(amt)
               IN
                /\ out > 0
                /\ reserveB' = reserveB + amt
                /\ reserveA' = reserveA - out
                /\ balances' = [balances EXCEPT
                    ![t] = [A |-> balances[t].A + out,
                            B |-> balances[t].B - amt]]
                /\ swaps' = Append(swaps, <<t, "BtoA", amt, out, time>>)
                /\ time' = time + 1

Terminated ==
    /\ time >= MaxTime
    /\ UNCHANGED vars

Next ==
    \/ SwapAtoB
    \/ SwapBtoA
    \/ Terminated

\* ── Invariants ──

\* Constant product: reserves product never decreases from initial.
\* With fees, k increases over time. With integer division rounding,
\* we allow it to equal the initial product.
ConstantProductInvariant ==
    reserveA * reserveB >= InitReserveA * InitReserveB

\* Reserves are always positive (pool never drained).
PositiveReserves ==
    /\ reserveA > 0
    /\ reserveB > 0

\* Every swap produces output > 0.
PositiveSwapOutput ==
    \A i \in 1..Len(swaps) : SAmtOut(swaps[i]) > 0

\* Conservation: total tokens in system (pool + all traders) is constant.
\* Token A total = reserveA + sum of all trader A balances
\* Token B total = reserveB + sum of all trader B balances
ConservationOfTokens ==
    LET traderSumA == LET f[S \in SUBSET Traders] ==
            IF S = {} THEN 0
            ELSE LET t == CHOOSE x \in S : TRUE
                 IN balances[t].A + f[S \ {t}]
            IN f[Traders]
        traderSumB == LET f[S \in SUBSET Traders] ==
            IF S = {} THEN 0
            ELSE LET t == CHOOSE x \in S : TRUE
                 IN balances[t].B + f[S \ {t}]
            IN f[Traders]
        n == Cardinality(Traders)
    IN /\ reserveA + traderSumA = InitReserveA + (n * InitReserveA)
       /\ reserveB + traderSumB = InitReserveB + (n * InitReserveB)

\* ── Comparison properties (contrast with CLOB and BatchedAuction) ──

\* The AMM does NOT have uniform pricing: different swaps get different
\* effective prices depending on size and reserve state.
\* Add as INVARIANT to find counterexample.
AllSwapsSamePrice ==
    \A i \in 1..Len(swaps) :
        \A j \in 1..Len(swaps) :
            (SAmtOut(swaps[i]) * SAmtIn(swaps[j]))
                = (SAmtOut(swaps[j]) * SAmtIn(swaps[i]))

\* Always-available liquidity: unlike CLOB, a swap never fails due to
\* empty book. As long as reserves are positive and input > 0, output > 0.
\* This is guaranteed by PositiveReserves + the swap formula.

Spec ==
    Init /\ [][Next]_vars

====
