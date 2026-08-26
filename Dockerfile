# Adds ffmpeg/ffprobe to the official n8n image, which doesn't include them.
# mwader/static-ffmpeg ships fully static binaries (--disable-shared) built for
# exactly this multi-stage-copy pattern, so no shared-library dependency chasing
# is needed on top of n8n's hardened (package-manager-less) base image.
FROM mwader/static-ffmpeg@sha256:78ebc8cc0368a109db21961a14a4e890a7b1ccafb373a1b3109f0be7fcec8171 AS ffmpeg

FROM n8nio/n8n:latest
COPY --from=ffmpeg --chmod=755 /ffmpeg /usr/local/bin/ffmpeg
COPY --from=ffmpeg --chmod=755 /ffprobe /usr/local/bin/ffprobe
