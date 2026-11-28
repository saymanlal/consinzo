/**
 * Browser-side wallet helpers. viem is loaded on demand so pages that never touch a wallet
 * do not pay for it.
 */
interface Eip1193Provider {
  request: (args: { method: string; params?: unknown[] }) => Promise<unknown>;
}

export class WalletError extends Error {}

export function getInjectedProvider(): Eip1193Provider | null {
  if (typeof window === "undefined") return null;
  return (window as unknown as { ethereum?: Eip1193Provider }).ethereum ?? null;
}

async function apiError(res: Response, fallback: string): Promise<never> {
  const json = (await res.json().catch(() => null)) as { error?: { message?: string } } | null;
  throw new WalletError(json?.error?.message ?? fallback);
}

async function fetchSignInMessage(address: string): Promise<string> {
  const res = await fetch(`/api/v1/auth/wallet/nonce?address=${address}`, { cache: "no-store" });
  if (!res.ok) await apiError(res, "Could not start wallet sign-in.");
  return ((await res.json()) as { message: string }).message;
}

async function submitSignature(message: string, signature: string): Promise<void> {
  const res = await fetch("/api/v1/auth/wallet/verify", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ message, signature }),
  });
  if (!res.ok) await apiError(res, "Wallet sign-in failed.");
}

/** Sign in with a browser wallet (MetaMask, Rabby, Coinbase Wallet, Brave…). */
export async function signInWithInjectedWallet(): Promise<string> {
  const provider = getInjectedProvider();
  if (!provider) {
    throw new WalletError(
      "No browser wallet found. Install one such as MetaMask, or create a wallet here."
    );
  }
  const { getAddress, toHex } = await import("viem");
  let accounts: string[];
  try {
    accounts = (await provider.request({ method: "eth_requestAccounts" })) as string[];
  } catch {
    throw new WalletError("The wallet connection was rejected.");
  }
  if (!accounts?.[0]) throw new WalletError("The wallet returned no account.");
  const address = getAddress(accounts[0]);
  const message = await fetchSignInMessage(address);
  let signature: string;
  try {
    signature = (await provider.request({
      method: "personal_sign",
      params: [toHex(message), address],
    })) as string;
  } catch {
    throw new WalletError("The signature request was rejected.");
  }
  await submitSignature(message, signature);
  return address;
}

/** Generate a new 12-word wallet entirely in this browser. */
export async function generateWallet(): Promise<{ mnemonic: string; address: string }> {
  const { english, generateMnemonic, mnemonicToAccount } = await import("viem/accounts");
  const mnemonic = generateMnemonic(english);
  return { mnemonic, address: mnemonicToAccount(mnemonic).address };
}

export async function addressFromMnemonic(mnemonic: string): Promise<string> {
  const { mnemonicToAccount } = await import("viem/accounts");
  return mnemonicToAccount(mnemonic.trim().replace(/\s+/g, " ")).address;
}

/** Sign in with a recovery phrase held in memory. The phrase never leaves the browser. */
export async function signInWithMnemonic(mnemonic: string): Promise<string> {
  const { mnemonicToAccount } = await import("viem/accounts");
  const account = mnemonicToAccount(mnemonic.trim().replace(/\s+/g, " "));
  const message = await fetchSignInMessage(account.address);
  const signature = await account.signMessage({ message });
  await submitSignature(message, signature);
  return account.address;
}

export function shortAddress(address: string): string {
  return `${address.slice(0, 6)}…${address.slice(-4)}`;
}
