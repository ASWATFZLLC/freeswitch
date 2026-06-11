# Ziwo FreeSWITCH "banshee" — ARM64 / multi-arch Docker build

Builds the **custom FreeSWITCH** (`v1.11.1.1`, with Ziwo's `mod_verto` / `mod_callcenter`
changes) from this source tree into a runnable container image. Works on **arm64**
(Apple Silicon, AWS Graviton, Ampere) and **amd64**.

## Why this exists (vs the other docker/ folders)
- `docker/master`, `docker/release` install **prebuilt SignalWire packages** (need a paid
  token) → they do **not** contain the custom code. Not usable for the fork.
- This image builds **from source**, so the custom modules are included.
- The Ziwo lib forks (`spandsp`, `sofia-sip`, `libks`, `signalwire-c`) were verified to be
  version-pinned **mirrors** of upstream with no functional patches, so this build uses the
  upstream lib versions v1.11.1 expects.

## What's in the image
- Install prefix `/usr/local/banshee`, runs as user `banshee` group `aswat` (matches prod).
- The **38-module "banshee" set** from `docker/arm64/modules.conf` (mirrors the live
  production VM's auto-loaded modules). `mod_signalwire` is intentionally excluded.
- Configure flags: `--enable-core-pgsql-support` and `--enable-zrtp` (toggleable).

## Build
```bash
# From the repo root. Build natively on the target arch (fast).
docker build -f docker/arm64/Dockerfile -t ziwo-freeswitch:1.11.1.1 .

# Parallelise the compile:
docker build -f docker/arm64/Dockerfile --build-arg MAKE_JOBS=$(nproc) -t ziwo-freeswitch:1.11.1.1 .

# If libzrtp fails to compile on arm64, build without ZRTP:
docker build -f docker/arm64/Dockerfile --build-arg ENABLE_ZRTP=false -t ziwo-freeswitch:1.11.1.1 .
```

### Cross-building (slow — avoid if you can build natively)
```bash
docker buildx build --platform linux/arm64 -f docker/arm64/Dockerfile -t ziwo-freeswitch:1.11.1.1 --load .
```
Compiling C under QEMU emulation is very slow; prefer building on a real arm64 host.

## Run
Mount your existing FreeSWITCH configuration (the image ships the stock vanilla config):
```bash
# Linux host (Graviton/Ampere) — full media, host networking:
docker run -d --name fs --network host \
  -v $(pwd)/configuration:/usr/local/banshee/etc/freeswitch \
  -v $(pwd)/tmp:/tmp \
  ziwo-freeswitch:1.11.1.1
```

> **macOS / Apple Silicon:** Docker Desktop has no real `--network host`, so RTP media
> won't flow. Fine for build + signaling/dev only. Use a Linux arm64 host for real calls.

Debug shell / CLI:
```bash
docker run -it --rm ziwo-freeswitch:1.11.1.1 bash
docker exec -it fs /usr/local/banshee/bin/fs_cli
```

## Open items / caveats
- **ZRTP on ARM**: `libzrtp` historically has x86 assembly and may not compile on arm64.
  If `make` fails there, rebuild with `--build-arg ENABLE_ZRTP=false` (confirm whether ZRTP
  is actually required first).
- **Sounds / MoH** are not baked in (lean image). Mount them, or add
  `make sounds-install moh-install` in the builder stage if you need the bundled prompts.
- Dependency lib refs are pinned via build args (`LIBKS_REF`, `SIGNALWIRE_C_REF`,
  `SOFIA_REF`, `SPANDSP_REF`) — bump them if v1.11.x requires newer versions.
