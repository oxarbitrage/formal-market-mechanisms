# ZKRefinement

<sub>[spec](https://github.com/alfredogarcia/formal-market-mechanisms/blob/main/specs/ZKRefinement.tla) · [config](https://github.com/alfredogarcia/formal-market-mechanisms/blob/main/specs/ZKRefinement.cfg)</sub>

Formal refinement proof: ZKDarkPool implements BatchedAuction. This module instantiates `BatchedAuction` with a variable mapping from `ZKDarkPool`'s state, then verifies that all BatchedAuction invariants hold under the mapping. This is the TLA+ native way to prove that two specifications describe the same mechanism.

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

This confirms that privacy (sealed bids + post-trade order destruction) is a pure addition — it does not alter the clearing mechanism in any way. ZKDarkPool = BatchedAuction + information hiding.
