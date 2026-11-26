# EIP-3156 Flash Loan Provider

Implement `flashFee(amount)` (0.1% = 10 bps) and `flashLoan(receiver, amount, data)` which transfers tokens, requires `onFlashLoan(...) == keccak256("ERC3156FlashBorrower.onFlashLoan")`, and pulls `amount + fee` back.