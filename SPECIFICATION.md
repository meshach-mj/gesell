# Gesell Protocol Specification v1.0

## Overview

Gesell (GSLL) is a demurrage currency that implements Silvio Gesell's 1916 economic theory of "free money" — currency that decays over time to encourage circulation over hoarding.

Unlike fiat currencies that hide inflation, Gesell makes decay explicit, predictable, and honest.

Created by Meshach, February 2025.

---

## Core Philosophy

In 1900, one ounce of gold cost $20.67 USD.

If the dollar had inflated at a modest, honest rate of 0.01% per 300,000 seconds (~1.05% annually), gold would cost approximately $76.89 today.

Instead, gold costs ~$2,850 — evidence of 37x "corruption" in the dollar's value.

Gesell is priced to reflect what honest money should be worth.

---

## Core Parameters

| Parameter | Value |
|-----------|-------|
| Name | Gesell |
| Symbol | GSLL |
| Chain | Base (Ethereum L2) |
| Decimals | 6 (matches USDC) |
| Launch mint price | 1 GSLL = 37.07 USDC |
| Decay rate | 0.01% per 300,000 seconds |
| Transaction fee | 0.01 USDC/GSLL (1 cent) |

---

## Mechanism

### Minting

Users send USDC to the contract and receive GSLL at the current exchange rate.

```
GSLL received = (USDC sent - 0.01 fee) / mint_price
```

At launch: Sending 37.08 USDC yields 1 GSLL (after 0.01 fee).

### Redemption

Users burn GSLL and receive USDC at the current exchange rate, minus decay.

```
USDC received = (GSLL balance after decay) × mint_price - 0.01 fee
```

### Demurrage (Decay)

All GSLL balances decay continuously at 0.01% per 300,000 seconds.

```
current_balance = original_balance × (0.9999)^(elapsed_seconds / 300,000)
```

This decay is calculated on-the-fly when balances are read — no periodic transactions required.

The USDC equivalent of decayed GSLL is sent to a burn address (0x000...dEaD), permanently removing it from circulation.

### Exchange Rate Updates

The admin can update the GSLL/USDC exchange rate to reflect ongoing dollar corruption.

The formula used:
```
mint_price = current_gold_price / gesell_predicted_gold_price
```

Where:
- `current_gold_price` = live gold price in USD
- `gesell_predicted_gold_price` = $20.67 × (1.0001)^(periods since 1900)

---

## Fee Structure

| Action | Fee | Recipient |
|--------|-----|-----------|
| Mint | 0.01 USDC | Admin wallet |
| Redeem | 0.01 GSLL worth of USDC | Admin wallet |
| Transfer | 0.01 GSLL | Admin wallet |

---

## Balance Calculation

Balances are stored as "shares" internally. When a balance is queried:

1. Calculate elapsed time since last update
2. Calculate number of decay periods: `periods = elapsed_seconds / 300,000`
3. Apply decay: `balance = shares × (0.9999)^periods`

This ensures decay is continuous and automatic without requiring transactions.

---

## Smart Contract Functions

### Public Functions

| Function | Description |
|----------|-------------|
| `mint(uint256 usdcAmount)` | Deposit USDC, receive GSLL |
| `redeem(uint256 gsllAmount)` | Burn GSLL, receive USDC |
| `transfer(address to, uint256 amount)` | Transfer GSLL (standard ERC-20) |
| `balanceOf(address account)` | Returns decayed balance |
| `totalSupply()` | Returns total GSLL in circulation (after decay) |

### Admin Functions

| Function | Description |
|----------|-------------|
| `updateMintPrice(uint256 newPrice)` | Update USDC/GSLL exchange rate |
| `setFeeRecipient(address newRecipient)` | Change fee recipient address |

---

## Historical Basis

### Gold Price Timeline

| Year | Official Gold Price | Event |
|------|---------------------|-------|
| 1834 | $20.67/oz | US adopts this rate |
| 1900 | $20.67/oz | Our reference point |
| 1934 | $35.00/oz | FDR devalues dollar |
| 1971 | $35.00/oz | Nixon ends gold convertibility |
| 2025 | ~$2,850/oz | Current market price |

### Gesell Calculation

From 1900 to 2025 (125 years):
- Seconds elapsed: 3,944,700,000
- Decay periods: 13,149
- Gesell predicted price: $20.67 × (1.0001)^13,149 = $76.89
- Actual price: ~$2,850
- Corruption ratio: 2,850 / 76.89 = 37.07

Therefore: **1 GSLL = 37.07 USDC**

---

## Security Considerations

1. **Decay precision**: Uses fixed-point math to avoid rounding errors
2. **Overflow protection**: All arithmetic uses SafeMath or Solidity 0.8+ built-in checks
3. **Reentrancy**: Protected via checks-effects-interactions pattern
4. **Admin controls**: Limited to exchange rate and fee recipient updates

---

## Deployment

- **Chain**: Base (Chain ID: 8453)
- **USDC Address**: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
- **Burn Address**: 0x000000000000000000000000000000000000dEaD

---

## License

MIT License

Copyright (c) 2025 Meshach

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files, to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software.

---

## References

- Gesell, Silvio. "The Natural Economic Order" (1916)
- The Wörgl Experiment (1932-1933)
- US Gold Price History: National Mining Association
