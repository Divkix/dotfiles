#!/bin/bash

# shellcheck source=../scripts/functions.sh

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$DIR" || exit 1

. ../scripts/functions.sh

SOURCE="$DIR"
DESTINATION="$HOME/.omp/agent"

info "Setting up OMP..."

mkdir -p "$DESTINATION"
scopy "$SOURCE/config.yml" "$DESTINATION/config.yml" || exit 1
scopy "$SOURCE/AGENTS.md" "$DESTINATION/AGENTS.md" || exit 1

success "Finished configuring OMP."
