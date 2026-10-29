# ffmpeg-tiny

Build recipes for small, decode-only FFmpeg static libraries.

This repo holds configure presets, build scripts and a GitHub Actions matrix. It does not contain FFmpeg itself; the build clones upstream FFmpeg **n7.1** into `src/` and configures it with `--disable-everything`, then turns back on only the decoders, demuxers and parsers a preset asks for.

## What's in a build

Every preset uses the same base:

- Enabled: `libavutil`, `libavcodec`, `libavformat`, `libswscale` (YUV → RGBA), the `file` protocol
- Disabled: programs (`ffmpeg`, `ffprobe`), docs, network, `avdevice`, `avfilter`, `swresample`, `postproc`, autodetected external libraries, debug info
- `--enable-small`, static libraries only (`--enable-static --disable-shared`)
- Image-capable presets also enable zlib (PNG, APNG, lossless WebP)

### Presets

| Preset | Decoders | Demuxers |
|--------|----------|----------|
| `h264` | h264 | mov |
| `h264_vp8` | h264, vp8 | mov, matroska |
| `h264_vp8_vp9` | h264, mpeg4, vp8, vp9 | mov, matroska |
| `h264_vp8_vp9_extra` | + av1, gif, webp, apng, png | + avi, flv, gif, apng, image2 |
| `h264_vp8_vp9_extra_images` | + mjpeg, bmp, targa, psd, hdr, pnm/pam | + image2pipe, `image_*_pipe` |
| `h264_vp8_vp9_extra_images_hw` | same as above, plus GPU hwaccel | same |

The `_hw` preset adds hardware decode per platform:

| Platform | Hardware API |
|----------|--------------|
| linux, windows (default) | Vulkan |
| windows with `HW_API=d3d11` | D3D11VA |
| macos, macos-x86_64, ios, ios-simulator | VideoToolbox |
| android | MediaCodec (JNI) |

Software decoders stay compiled in as FFmpeg's hwaccel shells. Apps using it are expected to fail closed if hardware decode can't be set up, rather than fall back to software video decode.

## Building

Requirements: bash, make, a C toolchain, `nasm` for x86_64 targets, and `pkg-config`.

```bash
git clone --depth 1 --branch n7.1 https://github.com/FFmpeg/FFmpeg.git src

make                                   # same as: make build PRESET=h264
make build PRESET=h264_vp8_vp9_extra_images_hw
make sizes                             # build every preset, write SIZE_REPORT.md
```

Output goes to `out/<preset>/lib/*.a` and `out/<preset>/include/`.

Cross builds are selected with `TARGET_PLATFORM`:

```bash
TARGET_PLATFORM=windows make build PRESET=h264_vp8_vp9_extra_images_hw              # MinGW, Vulkan
TARGET_PLATFORM=windows HW_API=d3d11 make build PRESET=h264_vp8_vp9_extra_images_hw # MinGW, D3D11VA
TARGET_PLATFORM=android make build PRESET=h264_vp8_vp9_extra_images_hw              # needs ANDROID_NDK_HOME
```

Supported values: `linux`, `windows`, `macos` (arm64), `macos-x86_64` (Intel, cross-compiled on Apple Silicon), `ios`, `ios-simulator` (arm64), `android` (arm64), `android-x86_64` (emulator; asm disabled for PIC).

Notes:

- FFmpeg n7.1 needs Vulkan headers 1.3.277 or newer. Ubuntu's `libvulkan-dev` is often older, so `scripts/ensure_vulkan_headers.sh` vendors Khronos headers into `tools/` (gitignored). No GPU is needed to build.
- Object trees are kept per preset, platform and `HW_API` under `src/build-*`, so several targets can share one checkout.
- `make clean` removes `out/`; `make clean-all` also removes the build trees.

## CI

`.github/workflows/build-ffmpeg.yaml` runs on manual dispatch and builds `h264_vp8_vp9_extra_images_hw` by default (override with the `preset` input). It produces nine artifacts, each with `lib/` and `include/`:

`ffmpeg-tiny-linux`, `-windows-vulkan`, `-windows-d3d11`, `-macos`, `-macos-x86_64`, `-ios`, `-ios-simulator`, `-android`, `-android-x86_64`

## Licensing

FFmpeg is licensed under the LGPL 2.1 or later, with some optional parts under the GPL. These builds don't pass `--enable-gpl`, `--enable-version3` or `--enable-nonfree`, and `--disable-autodetect` keeps external libraries out, so the resulting libraries are **LGPL 2.1+**. The configure line is in `scripts/build_preset.sh`.

If you ship these static libraries inside a closed-source program, the LGPL requires you to let users relink against a modified FFmpeg (for example by providing your object files, or by linking FFmpeg dynamically instead) and to offer the FFmpeg source you used. Upstream's checklist: https://ffmpeg.org/legal.html

Codec patents (H.264 in particular) are a separate question from the copyright license. This isn't legal advice.

The build scripts, configs and CI workflows in this repo are MIT licensed (see `LICENSE`). That license doesn't cover the FFmpeg source fetched into `src/` or the libraries built from it, which stay under FFmpeg's own license.
