---- MODULE SandwichAttack ----
EXTENDS TLC, Naturals

\* Models a sandwich attack against a constant-product AMM.
\* An adversary observes a victim's pending swap and sandwiches it:
\*   1. Front-run: adversary swaps A→B, moving the price against the victim
\*   2. Victim swap: executes at a worse price due to moved reserves
\*   3. Back-run: adversary swaps B→A, converting back at a profit
\*
\* This is the canonical MEV (Maximal Extractable Value) attack on AMMs.
\* Transaction ordering power (e.g. block builder, sequencer) enables it.
\*
\* Real-world context:
\*   - Uniswap, SushiSwap: vulnerable (mempool is public, miners/builders reorder)
\*   - Flashbots: MEV marketplace that formalizes ordering auctions
\*   - Penumbra, CoW Protocol: resistant (batch auctions, uniform price)
\*
\* Contrast with BatchedAuction: OrderingIndependence + UniformClearingPrice
\* make sandwich attacks impossible — there is no price to move between trades.

CONSTANTS
    InitReserveA,   \* initial pool reserve of token A
    InitReserveB,   \* initial pool reserve of token B
    FeeNum,         \* fee numerator (e.g. 3 for 0.3%)
    FeeDenom,       \* fee denominator (e.g. 1000)
    VictimAmtIn,    \* victim wants to swap this much A for B
    MaxFrontrun     \* maximum amount adversary can use to front-run

VARIABLES
    reserveA,           \* current pool reserve A
    reserveB,           \* current pool reserve B
    phase,              \* "frontrun" | "victim" | "backrun" | "done"
    frontrunAmt,        \* how much A the adversary used to front-run
    frontrunOut,        \* how much B the adversary got from front-run
    victimOut,          \* how much B the victim actually received
    backrunOut,         \* how much A the adversary got from back-run
    victimOutBaseline   \* how much B the victim would get without attack

vars == << reserveA, reserveB, phase, frontrunAmt, frontrunOut,
           victimOut, backrunOut, victimOutBaseline >>

\* ── Swap computation (same formula as AMM.tla) ──
\* Returns amount of reserveOut token received for amtIn of reserveIn token.
SwapOutput(amtIn, resIn, resOut) ==
    LET effectiveIn == amtIn * (FeeDenom - FeeNum)
        numerator   == resOut * effectiveIn
        denominator == (resIn * FeeDenom) + effectiveIn
    IN numerator \div denominator

\* ── Actions ──

Init ==
    /\ reserveA = InitReserveA
    /\ reserveB = InitReserveB
    /\ phase = "frontrun"
    /\ frontrunAmt = 0
    /\ frontrunOut = 0
    /\ victimOut = 0
    /\ backrunOut = 0
    \* Compute what victim would get with no attack present
    /\ victimOutBaseline = SwapOutput(VictimAmtIn, InitReserveA, InitReserveB)

\* Step 1: Adversary front-runs by swapping A→B (same direction as victim).
\* This pushes up the price of B, making the victim's swap more expensive.
Frontrun ==
    /\ phase = "frontrun"
    /\ \E amt \in 1..MaxFrontrun :
        LET out == SwapOutput(amt, reserveA, reserveB)
        IN
        /\ out > 0
        /\ reserveA' = reserveA + amt
        /\ reserveB' = reserveB - out
        /\ frontrunAmt' = amt
        /\ frontrunOut' = out
        /\ phase' = "victim"
        /\ UNCHANGED << victimOut, backrunOut, victimOutBaseline >>

\* Step 1 alternative: adversary chooses not to attack.
SkipFrontrun ==
    /\ phase = "frontrun"
    /\ phase' = "victim"
    /\ UNCHANGED << reserveA, reserveB, frontrunAmt, frontrunOut,
                    victimOut, backrunOut, victimOutBaseline >>

\* Step 2: Victim's swap executes (A→B).
\* If adversary front-ran, reserves are skewed and victim gets less B.
VictimSwap ==
    /\ phase = "victim"
    /\ LET out == SwapOutput(VictimAmtIn, reserveA, reserveB)
       IN
        /\ reserveA' = reserveA + VictimAmtIn
        /\ reserveB' = reserveB - out
        /\ victimOut' = out
        /\ phase' = "backrun"
        /\ UNCHANGED << frontrunAmt, frontrunOut, backrunOut, victimOutBaseline >>

\* Step 3: Adversary back-runs by swapping B→A (opposite direction).
\* Converts the B tokens from front-run back to A at the new (favorable) price.
Backrun ==
    /\ phase = "backrun"
    /\ frontrunOut > 0  \* only if adversary actually front-ran
    /\ LET out == SwapOutput(frontrunOut, reserveB, reserveA)
       IN
        /\ out > 0
        /\ reserveB' = reserveB + frontrunOut
        /\ reserveA' = reserveA - out
        /\ backrunOut' = out
        /\ phase' = "done"
        /\ UNCHANGED << frontrunAmt, frontrunOut, victimOut, victimOutBaseline >>

\* Step 3 alternative: no back-run needed (adversary didn't front-run).
SkipBackrun ==
    /\ phase = "backrun"
    /\ frontrunOut = 0
    /\ phase' = "done"
    /\ UNCHANGED << reserveA, reserveB, frontrunAmt, frontrunOut,
                    victimOut, backrunOut, victimOutBaseline >>

Terminated ==
    /\ phase = "done"
    /\ UNCHANGED vars

Next ==
    \/ Frontrun
    \/ SkipFrontrun
    \/ VictimSwap
    \/ Backrun
    \/ SkipBackrun
    \/ Terminated

\* ── Invariants (pool correctness — should hold) ──

\* Pool reserves always positive.
PositiveReserves ==
    /\ reserveA > 0
    /\ reserveB > 0

\* Constant product never decreases (fees grow k).
ConstantProductInvariant ==
    reserveA * reserveB >= InitReserveA * InitReserveB

\* ── Attack properties (EXPECTED TO FAIL) ──
\* Add as INVARIANT to find counterexamples demonstrating the attack.

\* "The victim is not harmed by the sandwich."
\* FAILS: adversary's front-run degrades victim's output.
NoPriceDegradation ==
    (phase = "done" /\ frontrunAmt > 0) => victimOut >= victimOutBaseline

\* "The adversary cannot profit from the sandwich."
\* FAILS: adversary gets back more A than they spent.
NoAdversaryProfit ==
    (phase = "done" /\ frontrunAmt > 0) => backrunOut <= frontrunAmt

Spec ==
    Init /\ [][Next]_vars

====
