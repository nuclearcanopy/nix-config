# rust build caches (nidhoggr)

why `CARGO_INCREMENTAL=0` is set in `modules/dev/rust.nix`, and what it costs.

## the incident

2026-11-01, root filesystem at 96% (211G of 234G, 11G free). `/home/loki` was
141G of that; `/nix/store` only 69G. The single largest category was rust build
output for one project, `~/work/repos/personal/wim`, at roughly 41G:

```
17G   ~/.cache/wim-wt            shared per-worktree targets, 16 worktrees
13G   work/repos/personal/wim/target
4.4G  ~/.cache/sccache
2.5G  ~/.cache/wim-perf
2.4G  ~/.cache/wimtest-target
1.5G  ~/.cache/wim-agent-targets
681M  work/repos/personal/fishcli/target
```

`target/*/incremental` accounted for **17G** of it on its own; the worst single
dir was `wim/target/debug/incremental` at 4.8G.

## the actual bug: two caches cancelling out

`wim/flake.nix` wires sccache for the devshell:

```
export RUSTC_WRAPPER="${pkgs.sccache}/bin/sccache"
export SCCACHE_DIR="$HOME/.cache/sccache"
```

while `wim/Cargo.toml` set `incremental = true` on both `[profile.release]` and
`[profile.dev]`. **sccache cannot cache incremental compilation.** It classifies
those invocations as non-cacheable and passes them straight through to rustc.
`sccache --show-stats` before the change:

```
Compile requests                    3599
Cache hits                           180     (all Assembler / C-C++)
Cache misses (Rust)                2137
Cache hits rate (Rust)              0.00 %
Non-cacheable reasons:
incremental                          499
Cache size                             4 GiB / 10 GiB
```

So the 4 GiB sccache was doing nothing whatsoever for Rust, and the thing
disabling it was also the thing eating 17G. The two caches were paying for each
other's existence and delivering one of them.

## the fix

`CARGO_INCREMENTAL=0` as a home-manager session variable. Cargo gives the
environment variable precedence over `[profile.*].incremental` in a manifest, so
this takes effect without patching `wim/Cargo.toml` (or any other project's).
`nix develop` inherits it, since wim's devshell only `export`s `RUSTC_WRAPPER`
and `SCCACHE_DIR` and does not set `CARGO_INCREMENTAL` itself.

Chosen deliberately over the narrower "drop `incremental` from
`[profile.release]` only": the release-only variant keeps the dev loop fast and
still fixes the agent path (`cargo test --release`), but saves ~12G instead of
~17G and requires an edit in the project repo rather than in nix-config.

## the tradeoff, stated plainly

Incremental compilation makes **repeated small edits inside one worktree**
faster. sccache makes **cold builds, and builds of the same code in a different
worktree**, faster. This config picks the second.

That is the right trade *here* specifically because the workload is 16 git
worktrees of the same repo driven by parallel agents, where near-identical crates
get compiled over and over in different directories. Incremental state is
per-target-dir and cannot be shared between worktrees; the sccache store is
shared by all of them. On a machine doing tight single-worktree iteration instead
the answer would flip.

Expect a slower edit-rebuild cycle in a single checkout, and faster first builds
everywhere else.

## caps

`SCCACHE_CACHE_SIZE` is a real hard cap; sccache prunes its own store LRU to stay
under it. It is set to `10G`, which is sccache's own default, made explicit so the
budget is declarative. Raising it buys more hits for more disk now that the cache
is actually being used.

`target/` directories have **no equivalent knob**. Cargo will not bound them and
`cargo clean` is all-or-nothing. Capping them declaratively needs a periodic
pruner (`cargo-sweep`, or an LRU sweep over `~/.cache/wim-wt/*`), which is not
currently wired up. Any such pruner must test the `flock` on
`<target>/.cargo-lock` before deleting, not merely check that the file exists:
the lock file persists after a build finishes, and during agent runs every
worktree target legitimately holds a live lock.

## applying it

`home.sessionVariables` is evaluated for login sessions, so already-open shells
keep the old value until re-login. The sccache **server** also reads
`SCCACHE_CACHE_SIZE` once at startup; after changing it run
`sccache --stop-server` so the next invocation picks the new budget up.
