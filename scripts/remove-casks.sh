while [[ `brew list --cask | wc -l` -ne 0 ]]; do
    for EACH in `brew list --cask`; do
        brew uninstall --cask --force $EACH
    done
done