# Running the Specs

Requires Java and [tla2tools.jar](https://github.com/tlaplus/tlaplus/releases). From the `specs/` directory:

```bash
java -DTLC -cp /path/to/tla2tools.jar tlc2.TLC <SpecName> -config <SpecName>.cfg -modelcheck
```

Or use the [TLA+ VS Code extension](https://marketplace.visualstudio.com/items?itemName=tlaplus.vscode-tlaplus).
