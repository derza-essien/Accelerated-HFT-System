1. Install Basic Host Tools

```bash
sudo apt update

sudo apt install -y \
    git \
    curl \
    ca-certificates \
    tar \
    xz-utils \
    make \
    python3 \
    python3-venv
```

2. Download Latest OSS CAD Suite

```bash
mkdir -p "$HOME/tools/oss-cad-download"
cd "$HOME/tools/oss-cad-download"

TAG="$(
    curl -fsSL \
        https://api.github.com/repos/YosysHQ/oss-cad-suite-build/releases/latest \
    | python3 -c 'import json, sys; print(json.load(sys.stdin)["tag_name"])'
)"

STAMP="${TAG//-/}"
ARCHIVE="oss-cad-suite-linux-x64-${STAMP}.tgz"

echo "Downloading OSS CAD Suite release: ${TAG}"

curl -fL \
    "https://github.com/YosysHQ/oss-cad-suite-build/releases/download/${TAG}/${ARCHIVE}" \
    -o "${ARCHIVE}"

rm -rf "$HOME/tools/oss-cad-suite"
tar -xzf "${ARCHIVE}" -C "$HOME/tools"

rm "${ARCHIVE}"

echo "Installed at: $HOME/tools/oss-cad-suite"
```

3. Automatically activate it

```bash
ACTIVATION_LINE='source "$HOME/tools/oss-cad-suite/environment"'

grep -qxF "${ACTIVATION_LINE}" "$HOME/.bashrc" \
    || echo "${ACTIVATION_LINE}" >> "$HOME/.bashrc"

source "$HOME/tools/oss-cad-suite/environment"
```

4. Confirm installation
```bash
printf '\nTool locations:\n'
command -v yosys
command -v sby
command -v yosys-smtbmc
command -v boolector
command -v bitwuzla
command -v z3
command -v verilator
command -v iverilog
command -v gtkwave

printf '\nTool versions:\n'
yosys -V
sby --help | head -n 3
boolector --version | head -n 1
bitwuzla --version | head -n 1
z3 --version
verilator --version
iverilog -V 2>&1 | head -n 2
```