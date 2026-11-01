{
  # Rust build-cache budget. sccache cannot cache incremental compilation and
  # reports those calls as non-cacheable, so `incremental` and sccache are
  # mutually exclusive in practice: measured 0.00% Rust hit rate (2137 misses,
  # 0 hits) against 17G of target/*/incremental on 2026-11-01. CARGO_INCREMENTAL
  # takes precedence over any Cargo.toml [profile.*] incremental setting, so this
  # wins without patching project manifests. See docs/rust-cache.md.
  homeManager.modules.rust = {
    home.sessionVariables = {
      CARGO_INCREMENTAL = "0";

      # The only Rust cache with a real self-pruning (LRU) cap; target/ dirs
      # have no equivalent knob. Default is 10G, set explicitly so the budget
      # is declarative rather than inherited.
      SCCACHE_CACHE_SIZE = "10G";
    };
  };
}
