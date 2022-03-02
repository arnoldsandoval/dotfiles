while [[ `brew list --formula | wc -l` -ne 0 ]]; do
    for EACH in `brew list --formula`; do
        brew uninstall --cask --force $EACH
    done
done