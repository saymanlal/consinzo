# Dutch-Auction Liquidation Notes

## Why a falling price

When a position is liquidated the protocol holds collateral and needs quote tokens. A
falling-price auction lets the market discover the clearing price without bids: the first
taker who finds the current price acceptable buys. Takers compete on timing, which pushes
the sale price towards the market price minus the cost of capital.

## Partial takes

Letting takers buy part of the lot means small liquidators can participate and a large lot
does not depend on one buyer. Each take reduces both the lot and the debt.

## Debt as a ceiling

The purpose of the auction is to recover a specific debt. Raising more than that would be a
transfer from the liquidated user to the protocol, so the final take is trimmed to the
remaining debt and the user receives the unsold collateral.

## Bad debt

If the price reaches the floor and the whole lot sells for less than the debt, the shortfall
has no collateral behind it. Recording it explicitly lets the surrounding protocol decide
how to cover it (reserves, insurance, socialisation).

## Rounding

Integer division always truncates. Each formula must round in the direction that protects
the system: amounts paid to the house round up, amounts paid out round down.
