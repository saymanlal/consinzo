# Mitigate Spot AMM Oracle Price Manipulation

Enforces a 10% maximum deviation bound between spot and TWAP prices and computes collateral value from `min(spot, twap)`.
