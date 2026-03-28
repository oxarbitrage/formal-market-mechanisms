---- MODULE WashTrading ----
EXTENDS TLC, Naturals

\* Models wash trading: a manipulator trades with themselves to inflate
\* reported volume without genuine economic activity.
\*
\* On a CLOB, self-trade prevention (STP) blocks this — the matching
\* engine rejects trades where buyer = seller.
\* On an AMM, there is no counterparty identity — swapping A→B then B→A
\* is always permitted. The manipulator loses only fees, but the volume
\* appears genuine on-chain.
\*
\* This spec models AMM wash trading: a single trader repeatedly swaps
\* back and forth. Each round-trip costs fees (k grows), but the trader's
\* total token value decreases — the "volume" is fake.
\*
\* Real-world context:
\*   - AMM volume inflation is widespread (estimated 40-70% on some DEXs)
\*   - Used to game token listings, airdrops, and liquidity mining rewards
\*   - CLOBs (NYSE, Binance) use STP and surveillance to prevent wash trading
\*   - Penumbra/CoW Protocol: batch auctions with self-trade prevention
\*
\* Key result:
\*   - WashTradingPossible FAILS on AMM (trader can always wash trade)
\*   - NoManipulatorLoss FAILS (each round-trip loses fees)
\*   - VolumeInflation FAILS (volume grows with zero net position change)

CONSTANTS
    InitReserveA,   \* initial pool reserve of token A
    InitReserveB,   \* initial pool reserve of token B
    FeeNum,         \* fee numerator (e.g. 3 for 0.3%)
    FeeDenom,       \* fee denominator (e.g. 1000)
    WashAmt,        \* amount per wash trade
    MaxRounds       \* max round-trips (TLC bound)

VARIABLES
    reserveA,       \* pool reserve A
    reserveB,       \* pool reserve B
    traderA,        \* manipulator's token A balance
    traderB,        \* manipulator's token B balance
    initTraderA,    \* initial token A balance (for comparison)
    initTraderB,    \* initial token B balance (for comparison)
    volume,         \* total reported swap volume (in token A)
    rounds,         \* completed round-trips
    phase           \* "swapAB" | "swapBA" | "done"

vars == << reserveA, reserveB, traderA, traderB,
           initTraderA, initTraderB, volume, rounds, phase >>

\* ── Swap computation (same as AMM.tla) ──
SwapOutput(amtIn, resIn, resOut) ==
    LET effectiveIn == amtIn * (FeeDenom - FeeNum)
        numerator   == resOut * effectiveIn
        denominator == (resIn * FeeDenom) + effectiveIn
    IN numerator \div denominator

\* ── Actions ──

Init ==
    /\ reserveA = InitReserveA
    /\ reserveB = InitReserveB
    /\ traderA = WashAmt * MaxRounds  \* enough tokens for all rounds
    /\ traderB = 0
    /\ initTraderA = WashAmt * MaxRounds
    /\ initTraderB = 0
    /\ volume = 0
    /\ rounds = 0
    /\ phase = "swapAB"

\* Leg 1: swap A → B (buy B with A)
SwapAforB ==
    /\ phase = "swapAB"
    /\ rounds < MaxRounds
    /\ traderA >= WashAmt
    /\ LET out == SwapOutput(WashAmt, reserveA, reserveB)
       IN
        /\ out > 0
        /\ reserveA' = reserveA + WashAmt
        /\ reserveB' = reserveB - out
        /\ traderA' = traderA - WashAmt
        /\ traderB' = traderB + out
        /\ volume' = volume + WashAmt
        /\ phase' = "swapBA"
        /\ UNCHANGED << initTraderA, initTraderB, rounds >>

\* Leg 2: swap B → A (sell B for A) — completing the round-trip
SwapBforA ==
    /\ phase = "swapBA"
    /\ traderB > 0
    /\ LET out == SwapOutput(traderB, reserveB, reserveA)
       IN
        /\ out > 0
        /\ reserveB' = reserveB + traderB
        /\ reserveA' = reserveA - out
        /\ traderB' = 0
        /\ traderA' = traderA + out
        /\ volume' = volume + traderB  \* count B-side volume too
        /\ rounds' = rounds + 1
        /\ phase' = "swapAB"
        /\ UNCHANGED << initTraderA, initTraderB >>

\* Stop wash trading.
StopWashing ==
    /\ phase = "swapAB"
    /\ rounds > 0
    /\ phase' = "done"
    /\ UNCHANGED << reserveA, reserveB, traderA, traderB,
                    initTraderA, initTraderB, volume, rounds >>

Terminated ==
    /\ phase = "done"
    /\ UNCHANGED vars

Next ==
    \/ SwapAforB
    \/ SwapBforA
    \/ StopWashing
    \/ Terminated

\* ── Invariants (pool correctness — should hold) ──

PositiveReserves ==
    /\ reserveA > 0
    /\ reserveB > 0

ConstantProductInvariant ==
    reserveA * reserveB >= InitReserveA * InitReserveB

\* ── Wash trading properties (EXPECTED TO FAIL) ──

\* "Wash trading is not possible."
\* FAILS: the manipulator can always complete round-trip swaps.
\* On an AMM there is no identity check — any address can swap.
NoWashTrading ==
    volume = 0

\* "The manipulator does not lose value from wash trading."
\* FAILS: each round-trip costs fees. The manipulator's total value
\* decreases even though their net position hasn't changed.
\* Value comparison: traderA + traderB * (reserveA / reserveB)
\* In integer arithmetic: traderA * reserveB + traderB * reserveA
\*                     >= initTraderA * reserveB + initTraderB * reserveA
NoManipulatorLoss ==
    (phase = "done") =>
        traderA * reserveB + traderB * reserveA
            >= initTraderA * reserveB + initTraderB * reserveA

\* "Volume accurately reflects genuine trading activity."
\* FAILS: volume grows but the manipulator ends each round-trip
\* in approximately the same position (less fees).
\* Genuine volume = 0 (no net position change), but reported volume > 0.
VolumeReflectsActivity ==
    (phase = "done") => volume = 0

Spec ==
    Init /\ [][Next]_vars

====
