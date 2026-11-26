# Fix Division-Before-Multiplication Precision Loss

Performs `(stake[user] * totalReward) / totalStaked` so numerators are scaled before integer division.
