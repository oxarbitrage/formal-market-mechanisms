---- MODULE ImpermanentLoss ----
EXTENDS TLC, Naturals

\* Models impermanent loss (IL) for a liquidity provider in a constant-product AMM.
\*
\* Setup: LP deposits (InitReserveA, InitReserveB) into the pool.
\* External traders swap against it, moving the price.
\* At any point, the LP could withdraw (reserveA, reserveB).
\*
\* IL occurs when the LP's withdrawal is worth LESS than simply holding
\* the original tokens. This happens whenever the price ratio changes,
\* even though fees grow the pool's total value (k increases).
\*
\* The "impermanent" part: if the price returns to the original ratio,
\* the LP keeps the fee income with no loss. IL is only realized when
\* withdrawing at a different price ratio than deposit.
\*
\* Real-world context:
\*   - Uniswap v2 LPs face IL on every price movement
\*   - Uniswap v3 concentrated liquidity amplifies both fees AND IL
\*   - This is why protocols offer "liquidity mining" rewards to compensate LPs

CONSTANTS
    InitReserveA,   \* LP's initial deposit of token A
    InitReserveB,   \* LP's initial deposit of token B
    FeeNum,         \* fee numerator (e.g. 3 for 0.3%)
    FeeDenom,       \* fee denominator (e.g. 1000)
    MaxSwap,        \* max swap amount per trade
    MaxTime         \* bound for model checking

VARIABLES
    reserveA,       \* current pool reserve A
    reserveB,       \* current pool reserve B
    time

vars == << reserveA, reserveB, time >>

\* ── Swap computation (same formula as AMM.tla) ──
SwapOutput(amtIn, resIn, resOut) ==
    LET effectiveIn == amtIn * (FeeDenom - FeeNum)
        numerator   == resOut * effectiveIn
        denominator == (resIn * FeeDenom) + effectiveIn
    IN numerator \div denominator

\* ── Actions ──

Init ==
    /\ reserveA = InitReserveA
    /\ reserveB = InitReserveB
    /\ time = 0

\* External trader swaps A for B (pushes price of A down, B up).
SwapAtoB ==
    /\ time < MaxTime
    /\ \E amt \in 1..MaxSwap :
        LET out == SwapOutput(amt, reserveA, reserveB)
        IN /\ out > 0
           /\ reserveA' = reserveA + amt
           /\ reserveB' = reserveB - out
           /\ time' = time + 1

\* External trader swaps B for A (pushes price of B down, A up).
SwapBtoA ==
    /\ time < MaxTime
    /\ \E amt \in 1..MaxSwap :
        LET out == SwapOutput(amt, reserveB, reserveA)
        IN /\ out > 0
           /\ reserveB' = reserveB + amt
           /\ reserveA' = reserveA - out
           /\ time' = time + 1

Terminated ==
    /\ time >= MaxTime
    /\ UNCHANGED vars

Next ==
    \/ SwapAtoB
    \/ SwapBtoA
    \/ Terminated

\* ── Invariants (should hold) ──

PositiveReserves ==
    /\ reserveA > 0
    /\ reserveB > 0

\* Constant product never decreases (fees always grow k).
ConstantProductInvariant ==
    reserveA * reserveB >= InitReserveA * InitReserveB

\* ── Impermanent loss property (EXPECTED TO FAIL) ──
\*
\* To compare LP value vs hold value, we use the current AMM price
\* as reference: price_A = reserveB / reserveA.
\*
\* LP withdrew (reserveA, reserveB), valued in B:
\*   V_lp = reserveA * (reserveB / reserveA) + reserveB = 2 * reserveB
\*
\* If LP had just held (InitReserveA, InitReserveB), valued in B:
\*   V_hold = InitReserveA * (reserveB / reserveA) + InitReserveB
\*
\* No IL means V_lp >= V_hold. Multiply both sides by reserveA
\* to stay in integer arithmetic:
\*   2 * reserveA * reserveB >= InitReserveA * reserveB + InitReserveB * reserveA
\*
\* This is the AM-GM inequality: equality holds only when the price
\* ratio is unchanged. Any price movement causes IL, even with fees.

NoImpermanentLoss ==
    2 * reserveA * reserveB
        >= InitReserveA * reserveB + InitReserveB * reserveA

Spec ==
    Init /\ [][Next]_vars

====
