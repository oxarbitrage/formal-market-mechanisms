# Shared Definitions

[`Common.tla`](https://github.com/alfredogarcia/formal-market-mechanisms/blob/main/specs/Common.tla) contains reusable definitions across all mechanisms:

- Order tuple accessors: `OTrader`, `OPrice`, `OQty`, `OId`, `OTime`
- Trade tuple accessors: `TBuyer`, `TSeller`, `TPrice`, `TQty`, `TTime`, `TBuyLimit`, `TSellLimit`
- Sequence helpers: `RemoveAt`, `ReplaceAt`
- Arithmetic helpers: `Min`, `Max`
