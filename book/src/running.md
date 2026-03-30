# Running the Specs

Requires Java and [tla2tools.jar](https://github.com/tlaplus/tlaplus/releases). From the `specs/` directory:

```bash
java -DTLC -cp /path/to/tla2tools.jar tlc2.TLC CentralizedCLOB -config CentralizedCLOB.cfg -modelcheck
java -DTLC -cp /path/to/tla2tools.jar tlc2.TLC BatchedAuction -config BatchedAuction.cfg -modelcheck
java -DTLC -cp /path/to/tla2tools.jar tlc2.TLC AMM -config AMM.cfg -modelcheck
java -DTLC -cp /path/to/tla2tools.jar tlc2.TLC DecentralizedCLOB -config DecentralizedCLOB.cfg -modelcheck
java -DTLC -cp /path/to/tla2tools.jar tlc2.TLC LatencyArbitrage -config LatencyArbitrage.cfg -modelcheck
java -DTLC -cp /path/to/tla2tools.jar tlc2.TLC FrontRunning -config FrontRunning.cfg -modelcheck
java -DTLC -cp /path/to/tla2tools.jar tlc2.TLC WashTrading -config WashTrading.cfg -modelcheck
java -DTLC -cp /path/to/tla2tools.jar tlc2.TLC SandwichAttack -config SandwichAttack.cfg -modelcheck
java -DTLC -cp /path/to/tla2tools.jar tlc2.TLC ImpermanentLoss -config ImpermanentLoss.cfg -modelcheck
java -DTLC -cp /path/to/tla2tools.jar tlc2.TLC CrossVenueArbitrage -config CrossVenueArbitrage.cfg -modelcheck
java -DTLC -cp /path/to/tla2tools.jar tlc2.TLC ZKDarkPool -config ZKDarkPool.cfg -modelcheck
java -DTLC -cp /path/to/tla2tools.jar tlc2.TLC ZKRefinement -config ZKRefinement.cfg -modelcheck
java -DTLC -cp /path/to/tla2tools.jar tlc2.TLC ShieldedDEX -config ShieldedDEX.cfg -modelcheck
```

Or use the [TLA+ VS Code extension](https://marketplace.visualstudio.com/items?itemName=tlaplus.vscode-tlaplus).
