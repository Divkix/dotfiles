function goup --description "Reinstall every go-installed binary in GOPATH/bin at @latest"
    # Brew-managed tools are upgraded by `brew upgrade`; this covers the rest, which nothing else updates.
    for bin in (go env GOPATH)/bin/*
        set -l pkg (go version -m $bin 2>/dev/null | string match -rg '^\s+path\s+(\S+)')
        test -n "$pkg"; or continue
        echo "go install $pkg@latest"
        go install $pkg@latest; or echo "goup: failed to update $pkg" >&2
    end
end
