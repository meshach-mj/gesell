# Gesell (GSLL)

A demurrage currency where holding costs you and spending saves you.

## Deployed Contract

| Network | Address |
|---------|---------|
| Base | [0xb8001Eea9C4D01570b7F0B8DA5e194C4061aeCc9](https://basescan.org/address/0xb8001Eea9C4D01570b7F0B8DA5e194C4061aeCc9) |

## What is Gesell?

Gesell is a cryptocurrency that implements Silvio Gesell's 1916 theory of "free money" — currency that loses value over time to encourage circulation.

**Key features:**
- Balances decay at 0.01% every 300,000 seconds (~1.05% annually)
- Backed by USDC
- Priced to reflect honest monetary inflation since 1900

## The Philosophy

In 1900, gold cost $20.67 per ounce.

If the dollar had inflated at an honest 1.05% annually, gold would cost ~$77 today.

Instead, gold costs ~$2,850 — the dollar has lost 97%+ of its value through hidden inflation.

**Gesell makes inflation explicit.** You know exactly how much your money decays. No hidden manipulation.

## Quick Start

```bash
# Clone the repository
git clone https://github.com/[your-username]/gesell.git
cd gesell

# Install dependencies
npm install

# Compile contracts
npx hardhat compile

# Run tests
npx hardhat test

# Deploy to Base
npx hardhat run scripts/deploy.js --network base
```

## Contract Details

| Parameter | Value |
|-----------|-------|
| Chain | Base |
| Token | GSLL |
| Decimals | 6 |
| Launch price | 1 GSLL = 37.07 USDC |
| Decay rate | 0.01% per 300,000 seconds |

## How It Works

1. **Mint**: Send USDC, receive GSLL at current exchange rate
2. **Hold**: Your balance decays 0.01% every ~3.47 days
3. **Spend**: Transfer GSLL to others (they receive decayed amount)
4. **Redeem**: Burn GSLL, receive USDC (minus decay)

## Documentation

- [SPECIFICATION.md](./SPECIFICATION.md) — Full technical specification
- [contracts/Gesell.sol](./contracts/Gesell.sol) — Smart contract

## Named After

Silvio Gesell (1862-1930), German-Argentine economist who proposed demurrage currency to encourage economic circulation. His ideas were tested in the Wörgl experiment (Austria, 1932-1933) with remarkable success before being shut down by the central bank.

## License

MIT
