---- MODULE Common ----
EXTENDS Naturals, Sequences

\* Shared definitions used across all mechanism and attack specifications.
\* Provides order/trade tuple accessors, sequence manipulation helpers,
\* and arithmetic utilities. Imported via EXTENDS Common.

\* ── Order field accessors ──
\* Order tuple: <<trader, price, quantity, orderId, time>>
OTrader(o)  == o[1]
OPrice(o)   == o[2]
OQty(o)     == o[3]
OId(o)      == o[4]
OTime(o)    == o[5]

\* ── Trade field accessors ──
\* Trade tuple: <<buyer, seller, tradePrice, qty, time, buyLimit, sellLimit>>
TBuyer(t)     == t[1]
TSeller(t)    == t[2]
TPrice(t)     == t[3]
TQty(t)       == t[4]
TTime(t)      == t[5]
TBuyLimit(t)  == t[6]
TSellLimit(t) == t[7]

\* ── Sequence helpers ──
RemoveAt(s, i)      == SubSeq(s, 1, i-1) \o SubSeq(s, i+1, Len(s))
ReplaceAt(s, i, v)  == SubSeq(s, 1, i-1) \o <<v>> \o SubSeq(s, i+1, Len(s))

Min(a, b) == IF a <= b THEN a ELSE b
Max(a, b) == IF a >= b THEN a ELSE b

====