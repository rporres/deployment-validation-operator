#!/bin/bash
set -euo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel)
source $REPO_ROOT/boilerplate/_lib/common.sh

GOLANGCI_LINT_VERSION="1.30.0"
DEPENDENCY=${1:-}
GOOS=$(go env GOOS)

case "${DEPENDENCY}" in

golangci-lint)
    GOPATH=$(go env GOPATH)
    if which golangci-lint ; then
        exit
    else
        mkdir -p "${GOPATH}/bin"
        echo "${PATH}" | grep -q "${GOPATH}/bin"
        IN_PATH=$?
        if [ $IN_PATH != 0 ]; then
            echo "${GOPATH}/bin not in $$PATH"
            exit 1
        fi
        DOWNLOAD_URL="https://github.com/golangci/golangci-lint/releases/download/v${GOLANGCI_LINT_VERSION}/golangci-lint-${GOLANGCI_LINT_VERSION}-${GOOS}-amd64.tar.gz"
        curl -sfL "${DOWNLOAD_URL}" | tar -C "${GOPATH}/bin" -zx --strip-components=1 "golangci-lint-${GOLANGCI_LINT_VERSION}-${GOOS}-amd64/golangci-lint"
    fi
    ;;

operator-sdk)
    #########################################################
    # Ensure operator-sdk is installed at the desired version
    # When done, ./.operator-sdk/bin/operator-sdk will be a
    # symlink to the appropriate executable.
    #########################################################
    # First discover the desired version from go.mod
    # The following properly takes `replace` directives into account.
    wantver=$(go list -json -m github.com/operator-framework/operator-sdk | jq -r 'if .Replace != null then .Replace.Version else .Version end')
    echo "go.mod says you want operator-sdk $wantver"
    # Where we'll put our (binary and) symlink
    mkdir -p .operator-sdk/bin
    cd .operator-sdk/bin
    # Discover existing, giving preference to one already installed in
    # this path, because that has a higher probability of being the
    # right one.
    if [[ -x ./operator-sdk ]] && [[ "$(osdk_version ./operator-sdk)" == "$wantver" ]]; then
        echo "operator-sdk $wantver already installed"
        exit 0
    fi
    # Is there one in $PATH?
    if which operator-sdk && [[ $(osdk_version $(which operator-sdk)) == "$wantver" ]]; then
        osdk=$(realpath $(which operator-sdk))
        echo "Found at $osdk"
    else
        case "$(uname -s)" in
            Linux*)
                binary="operator-sdk-${wantver}-x86_64-linux-gnu"
                ;;
            Darwin*)
                binary="operator-sdk-${wantver}-x86_64-apple-darwin"
                ;;
            *)
                echo "OS unsupported"
                exit 1
                ;;
        esac
        echo "Downloading $binary"
        curl -OJL https://github.com/operator-framework/operator-sdk/releases/download/${wantver}/${binary}
        chmod +x ${binary}
        osdk=${binary}
    fi
    # Create (or overwrite) the symlink to the binary we discovered or
    # downloaded above.
    ln -sf $osdk operator-sdk
    ;;

venv)
    # Set up a python virtual environment
    python3 -m venv .venv
    # Install required libs, if a requirements file was given
    if [[ -n "$2" ]]; then
        .venv/bin/python3 -m pip install -r "$2"
    fi
    ;;

*)
    echo "Unknown dependency: ${DEPENDENCY}"
    exit 1
    ;;
esac
