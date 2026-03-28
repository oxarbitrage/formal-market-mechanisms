---- MODULE FrontRunning ----
EXTENDS TLC, Naturals

\* Models front-running on a CLOB. An adversary who controls transaction
\* ordering can consume cheap sell-side liquidity before a victim's buy
\* order, forcing the victim to fill at worse prices.
\*
\* This is the CLOB analog of SandwichAttack.tla (which targets AMMs).
\* Both exploit ordering power, but through different mechanisms:
\*   - AMM sandwich: adversary shifts the price curve with their own swap
\*   - CLOB front-run: adversary depletes cheap resting orders from the book
\*
\* The sell book has liquidity at two price levels (LowPrice < HighPrice).
\* Without front-running, the victim fills cheapest-first.
\* With front-running, the adversary takes the cheap units first, and the
\* victim is forced to fill at the more expensive level.
\*
\* Real-world examples:
\*   - HFT latency arbitrage (fast trader sees & acts before slower order)
\*   - Block builder front-running (reorders transactions within a block)
\*   - Validator front-running in on-chain CLOBs (dYdX, Serum/OpenBook)
\*
\* Key result: NoPriceDegradation and NoAdversaryProfit both FAIL.
\* Contrast with BatchedAuction/ZKDarkPool where OrderingIndependence
\* makes front-running structurally impossible.

CONSTANTS
    LowPrice,       \* cheaper sell level (e.g., 10)
    HighPrice,      \* more expensive sell level (e.g., 15)
    LowQty,         \* units available at LowPrice
    HighQty,        \* units available at HighPrice
    VictimQty,      \* how many units the victim wants to buy
    MaxFrontrun     \* max adversary front-run size (TLC bound)

VARIABLES
    lowRem,             \* remaining units at LowPrice
    highRem,            \* remaining units at HighPrice
    advQty,             \* units adversary bought
    advCost,            \* total cost adversary paid
    victimFilled,       \* units victim filled
    victimCost,         \* total cost victim paid
    victimCostBaseline, \* what victim would pay without front-running
    phase               \* "frontrun" | "victim" | "done"

vars == << lowRem, highRem, advQty, advCost,
           victimFilled, victimCost, victimCostBaseline, phase >>

Min(a, b) == IF a <= b THEN a ELSE b

\* ── Book operations (fill from cheapest first) ──

\* Cost to fill qty units from remaining book.
FillCost(lr, hr, qty) ==
    LET fromLow  == Min(qty, lr)
        fromHigh == Min(qty - fromLow, hr)
    IN fromLow * LowPrice + fromHigh * HighPrice

\* Remaining low units after filling qty.
LowAfterFill(lr, qty) == lr - Min(qty, lr)

\* Remaining high units after filling qty (low consumed first).
HighAfterFill(lr, hr, qty) ==
    LET fromLow == Min(qty, lr)
    IN hr - Min(qty - fromLow, hr)

\* ── Actions ──

Init ==
    /\ lowRem = LowQty
    /\ highRem = HighQty
    /\ advQty = 0
    /\ advCost = 0
    /\ victimFilled = 0
    /\ victimCost = 0
    \* Baseline: victim's cost if they buy first (no front-running)
    /\ victimCostBaseline = FillCost(LowQty, HighQty, VictimQty)
    /\ phase = "frontrun"

\* Adversary front-runs: buys from the book before the victim.
\* Consumes cheap liquidity, leaving expensive levels for the victim.
Frontrun ==
    /\ phase = "frontrun"
    /\ \E qty \in 1..MaxFrontrun :
        LET cost == FillCost(lowRem, highRem, qty)
            lr   == LowAfterFill(lowRem, qty)
            hr   == HighAfterFill(lowRem, highRem, qty)
        IN
        /\ qty <= lowRem + highRem       \* enough liquidity for front-run
        /\ VictimQty <= lr + hr          \* leave enough for victim to fill
        /\ advQty' = qty
        /\ advCost' = cost
        /\ lowRem' = lr
        /\ highRem' = hr
        /\ phase' = "victim"
        /\ UNCHANGED << victimFilled, victimCost, victimCostBaseline >>

\* Adversary chooses not to front-run.
SkipFrontrun ==
    /\ phase = "frontrun"
    /\ phase' = "victim"
    /\ UNCHANGED << lowRem, highRem, advQty, advCost,
                    victimFilled, victimCost, victimCostBaseline >>

\* Victim buys from the (possibly depleted) book.
VictimBuy ==
    /\ phase = "victim"
    /\ LET qty == Min(VictimQty, lowRem + highRem)
       IN
        /\ victimFilled' = qty
        /\ victimCost' = FillCost(lowRem, highRem, qty)
        /\ lowRem' = LowAfterFill(lowRem, qty)
        /\ highRem' = HighAfterFill(lowRem, highRem, qty)
        /\ phase' = "done"
        /\ UNCHANGED << advQty, advCost, victimCostBaseline >>

Terminated ==
    /\ phase = "done"
    /\ UNCHANGED vars

Next ==
    \/ Frontrun
    \/ SkipFrontrun
    \/ VictimBuy
    \/ Terminated

\* ── Invariants (should hold) ──

\* Victim always gets fully filled (enough book liquidity).
VictimFullyFilled ==
    (phase = "done") => victimFilled = VictimQty

\* ── Attack properties (EXPECTED TO FAIL) ──
\* Add as INVARIANT to find counterexamples demonstrating the attack.

\* "Front-running doesn't make the victim pay more."
\* FAILS: adversary consumes cheap levels, victim pays HighPrice instead of LowPrice.
NoPriceDegradation ==
    (phase = "done") => victimCost <= victimCostBaseline

\* "Adversary cannot profit from front-running."
\* The adversary bought at a lower average price than the victim.
\* Their profit = advQty * victimAvgPrice - advCost (selling at market).
\* In integer arithmetic: no profit means advCost * victimFilled >= advQty * victimCost.
\* FAILS: adversary buys at LowPrice, market moved to HighPrice.
NoAdversaryProfit ==
    (phase = "done" /\ advQty > 0 /\ victimFilled > 0) =>
        advCost * victimFilled >= advQty * victimCost

Spec ==
    Init /\ [][Next]_vars

====
