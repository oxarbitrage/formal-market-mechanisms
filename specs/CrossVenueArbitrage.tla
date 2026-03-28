---- MODULE CrossVenueArbitrage ----
EXTENDS TLC, Naturals

\* Models cross-venue arbitrage between a CLOB and an AMM trading the same asset.
\*
\* When the AMM price diverges from the CLOB price, an arbitrageur can profit
\* by buying on the cheap venue and selling on the expensive one. This is
\* "productive" MEV — it aligns prices across venues — but the profit comes
\* at the expense of the AMM liquidity provider (impermanent loss).
\*
\* The CLOB is modeled as fixed-price liquidity at bid/ask levels (market maker
\* quotes). The AMM uses the constant-product formula. The arbitrageur atomically
\* trades on both venues in each step.
\*
\* Real-world context:
\*   - CEX/DEX arbitrage: bots buy on Uniswap, sell on Binance (or vice versa)
\*   - DEX/DEX arbitrage: bots trade across Uniswap pools on different L2s
\*   - This is the primary source of impermanent loss for AMM LPs
\*   - Contrast with sandwich attacks: arbitrage is price-aligning (productive),
\*     sandwiching is price-degrading (extractive)
\*
\* Contrast with BatchedAuction: uniform pricing eliminates the cross-venue
\* price difference that arbitrageurs exploit. If both venues used batch
\* auctions, there would be no spread to capture between them.

CONSTANTS
    InitReserveA,   \* AMM initial reserve of token A
    InitReserveB,   \* AMM initial reserve of token B
    FeeNum,         \* AMM fee numerator
    FeeDenom,       \* AMM fee denominator
    CLOBAskPrice,   \* CLOB sell price: A available at this price (B per A)
    CLOBBidPrice,   \* CLOB buy price: A wanted at this price (B per A)
    CLOBQty,        \* quantity available at each CLOB price level
    InitArbB,       \* arbitrageur's starting balance of token B
    MaxArbAmt       \* max units per arbitrage trade (TLC bound)

VARIABLES
    reserveA,       \* AMM reserve of token A
    reserveB,       \* AMM reserve of token B
    clobAskQty,     \* remaining sell-side CLOB liquidity
    clobBidQty,     \* remaining buy-side CLOB liquidity
    arbBalanceB,    \* arbitrageur's token B balance
    arbTrades       \* number of arbitrage trades executed

vars == << reserveA, reserveB, clobAskQty, clobBidQty, arbBalanceB, arbTrades >>

\* ── AMM swap computation (same as AMM.tla) ──
SwapOutput(amtIn, resIn, resOut) ==
    LET effectiveIn == amtIn * (FeeDenom - FeeNum)
        numerator   == resOut * effectiveIn
        denominator == (resIn * FeeDenom) + effectiveIn
    IN numerator \div denominator

\* ── Actions ──

Init ==
    /\ reserveA = InitReserveA
    /\ reserveB = InitReserveB
    /\ clobAskQty = CLOBQty
    /\ clobBidQty = CLOBQty
    /\ arbBalanceB = InitArbB
    /\ arbTrades = 0

\* Arb: buy A on CLOB (cheap), swap A→B on AMM (expensive).
\* Profitable when AMM price of A > CLOB ask price.
\* The arb pays CLOBAskPrice * qty B on the CLOB and receives
\* SwapOutput(qty, reserveA, reserveB) B from the AMM.
ArbBuyCLOBSellAMM ==
    \E qty \in 1..MaxArbAmt :
        /\ qty <= clobAskQty
        /\ LET cost   == qty * CLOBAskPrice
               ammOut  == SwapOutput(qty, reserveA, reserveB)
           IN
            /\ arbBalanceB >= cost
            /\ ammOut > cost                \* strictly profitable
            /\ reserveA' = reserveA + qty
            /\ reserveB' = reserveB - ammOut
            /\ clobAskQty' = clobAskQty - qty
            /\ arbBalanceB' = arbBalanceB - cost + ammOut
            /\ arbTrades' = arbTrades + 1
            /\ UNCHANGED clobBidQty

\* Arb: swap B→A on AMM (cheap), sell A on CLOB (expensive).
\* Profitable when CLOB bid price > AMM effective price.
\* The arb spends amtB on the AMM, receives amtA of token A,
\* then sells amtA on the CLOB at CLOBBidPrice.
ArbBuyAMMSellCLOB ==
    \E amtB \in 1..MaxArbAmt :
        /\ arbBalanceB >= amtB
        /\ LET amtA    == SwapOutput(amtB, reserveB, reserveA)
               revenue  == amtA * CLOBBidPrice
           IN
            /\ amtA > 0
            /\ amtA <= clobBidQty
            /\ revenue > amtB               \* strictly profitable
            /\ reserveB' = reserveB + amtB
            /\ reserveA' = reserveA - amtA
            /\ clobBidQty' = clobBidQty - amtA
            /\ arbBalanceB' = arbBalanceB - amtB + revenue
            /\ arbTrades' = arbTrades + 1
            /\ UNCHANGED clobAskQty

Terminated ==
    /\ UNCHANGED vars

Next ==
    \/ ArbBuyCLOBSellAMM
    \/ ArbBuyAMMSellCLOB
    \/ Terminated

\* ── Invariants (should hold) ──

PositiveReserves ==
    /\ reserveA > 0
    /\ reserveB > 0

ConstantProductInvariant ==
    reserveA * reserveB >= InitReserveA * InitReserveB

\* ── Arbitrage properties (EXPECTED TO FAIL) ──

\* "Arbitrageur cannot profit." FAILS: arb extracts value from price divergence.
NoArbitrageProfit ==
    arbBalanceB <= InitArbB

\* "AMM LP is not harmed by arbitrage." FAILS: arb-driven trades cause IL.
\* Same AM-GM formula as ImpermanentLoss.tla.
NoLPValueLoss ==
    2 * reserveA * reserveB
        >= InitReserveA * reserveB + InitReserveB * reserveA

\* ── Price convergence (should hold after arbitrage) ──

\* AMM effective price for 1 unit of A (in B).
AMMPricePerUnit == SwapOutput(1, reserveA, reserveB)

\* After at least one arb trade, the AMM price is closer to the CLOB range.
\* Specifically: AMM price is at or below the initial AMM price (arb pushed it down).
\* This holds because arb only buys A on CLOB / sells A to AMM (increasing reserveA,
\* decreasing reserveB), which always reduces the AMM price.
PriceNotDiverging ==
    (arbTrades > 0) =>
        AMMPricePerUnit <= SwapOutput(1, InitReserveA, InitReserveB)

Spec ==
    Init /\ [][Next]_vars

====
