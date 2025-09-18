FROM gitpod/openvscode-server:latest@sha256:af624c0dd6c6933d2aa53914b7396bfba58223fae2942266d8878d06d2778142

ENV OPENVSCODE_SERVER_ROOT="/home/.openvscode-server"
ENV OPENVSCODE="${OPENVSCODE_SERVER_ROOT}/bin/openvscode-server"

USER root
# Combine update+install in one layer; add cleanup
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      gh openssh-client ansible ca-certificates curl wget gnupg lsb-release \
    && rm -rf /var/lib/apt/lists/*

# arch-aware tools (needed for linux/arm64 builds)
ARG TARGETARCH
RUN set -eux; \
    # OpenTofu (official script handles arch)
    curl --proto '=https' --tlsv1.2 -fsSL https://get.opentofu.org/install-opentofu.sh -o install-opentofu.sh && \
    chmod +x install-opentofu.sh && ./install-opentofu.sh --install-method deb && rm -f install-opentofu.sh && \
    # Helm (script handles arch)
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 && \
    chmod +x get_helm.sh && ./get_helm.sh && rm -f get_helm.sh && \
    # kubectl + k9s need explicit arch selection
    if [ "$TARGETARCH" = "amd64" ]; then KARCH=amd64; K9S=k9s_linux_amd64.deb; \
    elif [ "$TARGETARCH" = "arm64" ]; then KARCH=arm64; K9S=k9s_linux_arm64.deb; \
    else echo "Unsupported arch: $TARGETARCH" && exit 1; fi; \
    curl -fsSL -o /usr/local/bin/kubectl "https://dl.k8s.io/release/$(curl -fsSL https://dl.k8s.io/release/stable.txt)/bin/linux/${KARCH}/kubectl" && \
    chmod 0755 /usr/local/bin/kubectl && \
    wget -q "https://github.com/derailed/k9s/releases/download/v0.50.9/${K9S}" && \
    apt-get update && apt-get install -y "./${K9S}" && rm -f "${K9S}"

USER openvscode-server
SHELL ["/bin/bash", "-c"]
RUN \
  urls=( \
    https://github.com/rust-lang/rust-analyzer/releases/download/2025-08-25/rust-analyzer-linux-x64.vsix \
    https://github.com/VSCodeVim/Vim/releases/download/v1.30.1/vim-1.30.1.vsix \
    https://github.com/DragonSecurity/drill-vscode/releases/download/v/drill-vscode-0.5.0.vsix \
  ) && \
  tdir=/tmp/exts && mkdir -p "${tdir}" && cd "${tdir}" && \
  wget "${urls[@]}" && \
  exts=( gitpod.gitpod-theme smartmanoj.github-codespaces-connector "${tdir}"/* ) && \
  for ext in "${exts[@]}"; do ${OPENVSCODE} --install-extension "${ext}"; done && \
  rm -rf "${tdir}"
