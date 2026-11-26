# Secure Cross-Chain Bridge Message Verification

`BridgeReceiver.receiveMessage` accepts any relayer call without verifying `srcChainId`, `srcSender`, or `processed[msgId]`.

## Objective
Restrict calls to `relayer`, validate `trustedRemote[srcChainId] == srcSender`, and prevent `msgId` replay.