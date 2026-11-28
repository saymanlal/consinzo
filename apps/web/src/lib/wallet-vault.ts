/**
 * Browser-only encrypted storage for a wallet recovery phrase.
 *
 * The phrase is encrypted with AES-256-GCM under a key derived from the user's password
 * (PBKDF2-SHA256, 600,000 iterations, random salt). Only the ciphertext is written to
 * localStorage. Nothing in this file talks to the network: the server never receives the
 * phrase, the password, or the ciphertext.
 */
export interface WalletVault {
  v: 1;
  address: string;
  kdf: "PBKDF2-SHA256";
  iterations: number;
  salt: string;
  iv: string;
  ciphertext: string;
  createdAt: string;
}

const STORAGE_KEY = "consinzo:wallet-vaults:v1";
const ITERATIONS = 600_000;

const toB64 = (bytes: Uint8Array) => btoa(String.fromCharCode(...bytes));
const fromB64 = (b64: string) => Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));

async function deriveKey(password: string, salt: Uint8Array, iterations: number) {
  const material = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(password),
    "PBKDF2",
    false,
    ["deriveKey"]
  );
  return crypto.subtle.deriveKey(
    { name: "PBKDF2", hash: "SHA-256", salt: salt as BufferSource, iterations },
    material,
    { name: "AES-GCM", length: 256 },
    false,
    ["encrypt", "decrypt"]
  );
}

export async function encryptVault(
  address: string,
  mnemonic: string,
  password: string
): Promise<WalletVault> {
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const key = await deriveKey(password, salt, ITERATIONS);
  const ciphertext = await crypto.subtle.encrypt(
    { name: "AES-GCM", iv: iv as BufferSource },
    key,
    new TextEncoder().encode(mnemonic)
  );
  return {
    v: 1,
    address,
    kdf: "PBKDF2-SHA256",
    iterations: ITERATIONS,
    salt: toB64(salt),
    iv: toB64(iv),
    ciphertext: toB64(new Uint8Array(ciphertext)),
    createdAt: new Date().toISOString(),
  };
}

/** Returns the recovery phrase, or throws if the password is wrong or the data was altered. */
export async function decryptVault(vault: WalletVault, password: string): Promise<string> {
  const key = await deriveKey(password, fromB64(vault.salt), vault.iterations);
  try {
    const plain = await crypto.subtle.decrypt(
      { name: "AES-GCM", iv: fromB64(vault.iv) as BufferSource },
      key,
      fromB64(vault.ciphertext) as BufferSource
    );
    return new TextDecoder().decode(plain);
  } catch {
    throw new Error("Wrong password.");
  }
}

function readAll(): Record<string, WalletVault> {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    return raw ? (JSON.parse(raw) as Record<string, WalletVault>) : {};
  } catch {
    return {};
  }
}

export function listVaults(): WalletVault[] {
  return Object.values(readAll());
}

export function getVault(address: string): WalletVault | null {
  return readAll()[address.toLowerCase()] ?? null;
}

export function saveVault(vault: WalletVault): void {
  const all = readAll();
  all[vault.address.toLowerCase()] = vault;
  localStorage.setItem(STORAGE_KEY, JSON.stringify(all));
}

export function removeVault(address: string): void {
  const all = readAll();
  delete all[address.toLowerCase()];
  localStorage.setItem(STORAGE_KEY, JSON.stringify(all));
}

/** Offers the encrypted vault as a file download. The file is useless without the password. */
export function downloadVault(vault: WalletVault): void {
  const blob = new Blob([JSON.stringify(vault, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = `consinzo-wallet-${vault.address.slice(0, 8)}.encrypted.json`;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
}

export function isVaultFile(value: unknown): value is WalletVault {
  const v = value as Partial<WalletVault> | null;
  return Boolean(
    v &&
      v.v === 1 &&
      typeof v.address === "string" &&
      typeof v.salt === "string" &&
      typeof v.iv === "string" &&
      typeof v.ciphertext === "string" &&
      typeof v.iterations === "number"
  );
}
