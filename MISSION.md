# MISSION

Get Voyager verification working. Ship one upgrade: skip events on no-ops. Then delete this file.

## Live (mainnet)

- NFT: [`0x03d7811b831bfb98d3c3ac9d7dcc28b43445c35afc82a931d5c06ebc2804f740`](https://voyager.online/nft-contract/0x03d7811b831bfb98d3c3ac9d7dcc28b43445c35afc82a931d5c06ebc2804f740)
- Class: [`0x03bb34bcffb6197f7559121d2c40122c6ccf9be72903405b89342f5d29e077f0`](https://voyager.online/class/0x03bb34bcffb6197f7559121d2c40122c6ccf9be72903405b89342f5d29e077f0)
- Version: `1` (never upgraded)
- Official tags: `TITLE MESSAGE URL X_HANDLE GITHUB_HANDLE`
- Deploy tx: `0x680a47c83d9463071d653e7bba2aa1b14bfcf11b31f78c5c427c300572e43f1` (2025-11-14)
- Contract name for verify: `Ethrx`

## Wallets

**Admin / upgrade signer = Braavos** (biometrics device)

- Live `owner()`: [`0x0280dcce9a73506ce6b5a1e605e8082b4c3ecb408d18e556968b7e8aac44cf2d`](https://voyager.online/contract/0x0280dcce9a73506ce6b5a1e605e8082b4c3ecb408d18e556968b7e8aac44cf2d)
- Class: `0x03957f9f5a1cbfe918cedc2015c85200ca51a5f7506ecb6de98a5207b759bf8a` = Braavos
- `example.env` `MAINNET_ETHRX_OWNER` (`0x069a08c0…`) is a *different* Braavos addr. Not the live owner. Ownership moved after deploy.

**Declare signer = local Argent** (`sncast` account `etheracts_deployer` / `mainnet_deployer`)

- Addr: `0x03f4e6b58db4417cd7d832b40c91aa12802625e973cc745e2e573a71b99f7e08`
- Class: Argent X. Can declare. Cannot call `upgrade_contract`.

**Sepolia** owner = same Argent as `testnet_deployer` (`0x03ff18229…`). Declare + upgrade can be one account there.

Plan: local Argent declares new class → Braavos invokes `upgrade_contract(new_class_hash)`.

## Tooling now vs target

| | This branch (now) | Latest (Aug 2026) |
|---|---|---|
| Scarb / Cairo | **2.19.4** / Sierra **1.9.3** | Scarb **2.20.1** / Cairo **2.20.0** |
| Foundry (`snforge`/`sncast`) | **0.63.0** | **0.63.0** |
| voyager CLI | **2.3.1** | **2.3.1** |
| OZ | **2.0.0** (kept) | 3.0.0 stable, **4.0.0** current |
| SN mainnet | — | **0.14.3** → Cairo 2.19.0 / Sierra **1.9.0** |

Started from `main` at 2.12.2 / Foundry 0.50. Old `verification` branch had stopped at 2.13.1.

Starkup = the official installer (`curl https://sh.starkup.sh \| sh`). Under the hood it is still asdf. We already have asdf. Do not reinstall from scratch. Bump versions in `.tool-versions`.

**Pin decision:** first target **Scarb 2.19.4 + Foundry 0.63**. SN 0.14.3 lists Cairo 2.19 / Sierra 1.9. Scarb 2.20.1 only if a Sepolia declare of that Sierra version actually lands.

Keep **OZ 2.0.0** unless it will not compile. OZ 4.0 adds ERC721 hook changes → storage-layout risk on upgrade. Do not bump OZ without a storage audit.

No new `/integration`. Root `sncast` is the deploy/verify tool. Old Go deployer parked in `integration2/`.

## Verify path (the actual goal)

Two equivalent CLIs. Prefer **sncast** (already in Foundry):

```bash
scarb build
sncast verify \
  --network sepolia \
  --verifier voyager \
  --class-hash <HASH> \
  --contract-name Ethrx
```

Also exists: standalone `voyager verify` ([docs](https://nethermindeth.github.io/voyager-verifier/getting-started/quickstart.html)). Update CLI 2.0.1 → 2.3.1 if we use it.

Walnut is the other `sncast verify --verifier` backend. Nice for traces. Voyager is what we need on the explorer.

Sepolia first. Mainnet after it matches.

Optional rehearsal: verify the *current* class (same hash on Sepolia `0x46936daf…`) with untouched source, to prove the pipeline before any code change.

## Cairo since 2.12.2 (only what matters)

- **2.13** — iterator/corelib tweaks. Old verification branch stopped here. Skip it; jump toward 2.19.
- **2.14** — ecdsa / pubkey-recovery breaks. We do not use that.
- **2.15** — edition `2025_12`. Stay on `2024_07` unless we need it.
- **2.16–2.18** — compiler, LS, const-eval. No storage model change for us.
- **2.19** — Sierra 1.9. This is what mainnet speaks.
- **2.20** — tuple `.0` access, `#[panic_with]` deprecated. Newer Sierra possible. Prove on Sepolia first.

We already use `Map`, components, OZ Upgradeable. No `LegacyMap` migration. Storage rule for the upgrade: **do not rename/reorder `Storage` fields.**

## Code change (the only feature)

Events fire only when state actually changes.

1. `set_tags` modify: if `old_tag == new_tag`, skip `TagReregistered`.
2. `_engrave_artifact`: if `old_data == new_engraving.data`, skip write **and** `ArtifactEngraved`. (`Engraving` already `PartialEq`.)

Skip storage write, not just the event — otherwise nonce still bumps and history gets a duplicate slot.

New tests: no-op engrave, no-op tag rewrite, mixed batch (some change / some don’t).

## Commands we will use

```bash
# declare (any funded account)
sncast --account etheracts_deployer declare --contract-name Ethrx --network sepolia

# upgrade (must be owner)
sncast invoke \
  --contract-address <ETHRX> \
  --function upgrade_contract \
  --arguments '<NEW_CLASS_HASH>' \
  --network sepolia
# mainnet: Braavos wallet UI / voyager write, not this Argent key
```

## Order of work

1. ~~Bump asdf: Scarb 2.19.4, Foundry 0.63, voyager 2.3.1.~~ Done. Sierra **1.9.3**. OZ 2.0.0 still compiles. `scarb build` green. Tests: snforge now appends `ENTRYPOINT_FAILED` on nested ERC20 panics — assert on first felt.
2. Keep OZ 2.0.0. Fix whatever the compiler yells about.
3. `scarb test` green on current behavior.
4. ~~Implement no-op events + tests.~~
5. Sepolia: declare → `sncast verify --verifier voyager` → owner `upgrade_contract` → call `version() == 2`.

## sncast wallet

Default file: `~/.starknet_accounts/starknet_open_zeppelin_accounts.json`  
Repo `snfoundry.toml` points at that path.

- Sepolia (`testnet_deployer` / `work-sepolia-wallet` / `bonsai-testnet`): `0x03ff18229…` — this **is** the Sepolia owner. Declare + upgrade from this account.
- Mainnet declare (`etheracts_deployer`): `0x03f4e6b58…` Argent/Ready. Cannot upgrade.
- Mainnet upgrade: Braavos `0x0280dcce9…` — not in this file. Wallet UI.

sncast does **not** use `starkli_keystore_*.json` unless you pass `--keystore`.

If you have a newer accounts JSON, change `accounts-file` in `snfoundry.toml` (or pass `--accounts-file`).
6. Mainnet: Argent declares → Braavos `upgrade_contract` → verify new class.
7. Delete `integration2/` when we trust sncast. Delete this file.

## Open

- [ ] Confirm Braavos device that holds `0x0280dcce9…`
- [ ] Does Scarb 2.20.1 declare on Sepolia, or stay on 2.19.4?
- [ ] OZ 2.0.0 compile on 2.19, or forced bump (then storage audit)
- [ ] Add root `snfoundry.toml` (account + network). No Go wrapper.
- [ ] Makefile still talks about the old deployer — replace with sncast later

## Links

- Env setup: https://docs.starknet.io/build/quickstart/environment-setup
- Sepolia sncast: https://docs.starknet.io/build/quickstart/sepolia
- Compat: https://docs.starknet.io/learn/cheatsheets/compatibility
- sncast verify: https://foundry-rs.github.io/starknet-foundry/starknet/verify.html
- Voyager verifier: https://nethermindeth.github.io/voyager-verifier/
- Forum: https://community.starknet.io/
