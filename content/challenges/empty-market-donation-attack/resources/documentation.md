# Exchange-rate manipulation in share-based lending markets

## Shares and the exchange rate

Suppliers receive shares. One share is a claim on

```
exchangeRate = (cash + totalBorrows) / totalShares
```

The rate rises as borrowers pay interest or fees. Lending protocols also use shares as
collateral, valued at the exchange rate, so the rate is a price oracle that the protocol
computes about itself.

## Why an empty market is special

Manipulating the rate by donating tokens normally gives most of the donation away to other
suppliers. In an empty (or nearly empty) market there are none. An attacker can:

1. become the sole supplier,
2. redeem down to a dust amount of shares,
3. donate, making each dust share worth an arbitrary amount.

The attacker has not lost the donation: it is still claimable through the shares they hold.

## Turning the inflated rate into profit

The inflated collateral supports a borrow from another market. To leave with both the
borrowed funds and the donation, the attacker needs to redeem the donation without the
protocol noticing that collateral is gone. Two flaws make that possible:

- **Truncating division** when converting an underlying amount to shares. With huge share
  values, a withdrawal just under two shares' worth burns only one share.
- **Stale health checks**, performed with the rate from before the withdrawal.

## Defences

- Track cash internally. Only the protocol's own entry points change it.
- Round every conversion against the caller: shares minted down, assets redeemed down,
  shares burned for a requested amount up.
- Run solvency checks after all state of the operation is updated.
- Operationally, seed new markets with supply that is never withdrawn before enabling them
  as collateral.

The rounding directions are the same ones EIP-4626 prescribes for vaults.
