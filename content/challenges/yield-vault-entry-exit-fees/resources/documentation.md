# Vault Share Accounting with Fees

## Shares

A vault pools one asset from many users. Instead of tracking each user's assets, it tracks
shares. The exchange rate is

```
assets per share = totalAssets / totalSupply
```

Depositing mints `assets * totalSupply / totalAssets` shares; redeeming pays
`shares * totalAssets / totalSupply`. When yield is added, `totalAssets` grows while
`totalSupply` does not, so every share becomes worth more. EIP-4626 standardises this model.

## Where fees fit

A fee can be taken in assets at the boundary of the pool:

- **Entry fee:** split the incoming assets into fee and net; only the net amount is exchanged
  for shares.
- **Exit fee:** convert the shares to their gross asset value; split that into fee and payout.

In both cases the fee leaves the system for the fee recipient and must not be counted in
`totalAssets`. A useful check: after any operation, the vault's token balance must be at least
`totalAssets`.

## Rounding

Round in favour of the pool (down on both conversions). Rounding in favour of the user lets
repeated small operations extract value from other holders.

## Donations and the first depositor

If the share price can be raised cheaply while very few shares exist, a later deposit may round
down to zero shares. Defences include tracking assets internally, rejecting zero-share mints,
virtual shares, and seeding the vault at deployment.
