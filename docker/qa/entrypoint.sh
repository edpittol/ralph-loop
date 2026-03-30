#!/bin/sh

# Execute any command passed as parameters
if [ $# -eq 0 ]; then
    FAILED=0

    echo "Running editorconfig checks..."
    cd /app
    git ls-files | while IFS= read -r file; do
        echo "Checking $file..."
        if ! editorconfig-checker "$file"; then
            FAILED=1
        fi
    done

    if [ $FAILED -ne 0 ]; then
        echo "✗ Editorconfig validation failed for some files"
    else
        echo "✓ Editorconfig validation passed"
    fi

    echo ""
    echo "Running bats tests..."
    if [ -d "/app/tests" ]; then
        cd /app
        if ! bats tests/; then
            FAILED=1
        else
            echo "✓ Bats tests passed"
        fi
    fi

    echo ""
    if [ $FAILED -eq 0 ]; then
        echo "All QA checks completed successfully!"
        exit 0
    fi

    echo "QA checks completed with failures"
    exit 1
fi

exec "$@"
