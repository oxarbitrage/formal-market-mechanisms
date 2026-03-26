---- MODULE Common ----
EXTENDS Naturals, Sequences

\* ── Order field accessors ──
\* Order tuple: <<trader, price, quantity, orderId, time>>
OTrader(o)  == o[1]
OPrice(o)   == o[2]
OQty(o)     == o[3]
OId(o)      == o[4]
OTime(o)    == o[5]

\* ── Sequence helpers ──
RemoveAt(s, i)      == SubSeq(s, 1, i-1) \o SubSeq(s, i+1, Len(s))
ReplaceAt(s, i, v)  == SubSeq(s, 1, i-1) \o <<v>> \o SubSeq(s, i+1, Len(s))

Min(a, b) == IF a <= b THEN a ELSE b

====