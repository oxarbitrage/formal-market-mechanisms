# ZKRefinement

<sub>[spec](https://github.com/oxarbitrage/formal-market-mechanisms/blob/main/specs/ZKRefinement.tla) · [config](https://github.com/oxarbitrage/formal-market-mechanisms/blob/main/specs/ZKRefinement.cfg)</sub>

Formal refinement proof: [ZKDarkPool](../mechanisms/zk-dark-pool.md) implements [BatchedAuction](../mechanisms/batched-auction.md). Adding privacy (sealed bids + order destruction) to a batch auction could, in principle, break correctness — perhaps the commit-reveal protocol changes the clearing outcome, or destroying orders violates conservation. This proof rules that out: it instantiates `BatchedAuction` with a variable mapping from `ZKDarkPool`'s state, then verifies that all 6 BatchedAuction invariants still hold. This is TLA+'s native method for proving that one specification implements another.

## Variable mapping (ZKDarkPool → BatchedAuction)

| ZKDarkPool | BatchedAuction |
|---|---|
| `phase = "commit"` | `phase = "collecting"` |
| `phase = "clear"` | `phase = "clearing"` |
| `phase = "done"` | `phase = "collecting"`, `batch = 1` |
| `clearPrice` | `lastClearPrice` |
| `buyOrders`, `sellOrders`, `trades`, `nextOrderId` | same |

## Verified: all 6 BatchedAuction invariants hold on ZKDarkPool's state space

| Refined Property | Status |
|---|---|
| `BA!UniformClearingPrice` | Pass (8,735 states) |
| `BA!PriceImprovement` | Pass |
| `BA!PositiveTradeQuantities` | Pass |
| `BA!NoSelfTrades` | Pass |
| `BA!OrderingIndependence` | Pass |
| `BA!NoSpreadArbitrage` | Pass |

This confirms that privacy (sealed bids + post-trade order destruction) is a pure addition — it does not alter the clearing mechanism in any way. ZKDarkPool = BatchedAuction + information hiding. This result underpins the claim in [conclusions](../conclusions.md) that privacy is a mechanism design tool for MEV elimination: it adds resistance to sandwich attacks and front-running without sacrificing any batch auction guarantee.
