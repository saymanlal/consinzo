# Epoch Vault Notes

## Covered-call vaults

A covered-call vault holds an asset and repeatedly sells call options on it. Each cycle the
vault receives a premium. If the option expires out of the money the vault keeps everything;
if it expires in the money the vault owes the buyer the difference. Depositors therefore
earn premium in quiet markets and give up part of the upside in rallies.

## Why epochs

The option is priced and collateralised for a fixed amount at the start of the cycle.
Capital cannot join or leave in the middle without changing who bears the result. Vaults
solve this with queues: new capital waits for the next cycle, and departing capital stays
until the current cycle settles.

## Price per share

Shares represent a pro-rata claim on locked assets. The price per share at settlement is
`locked assets after premium and payout / share supply`. Using one price for all entries and
exits at a settlement means that no participant can gain at another's expense by timing a
transaction within the cycle.

## Lazy accounting

Storing a price per epoch lets the contract settle any number of users in constant gas per
roll. Each user's conversion happens on its next interaction. Views must apply the same
conversion so that balances are correct before the user acts.
