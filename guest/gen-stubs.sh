#!/bin/bash
#
# gen-stubs.sh — Generate stub .so files for libraries that libxul.so
# links against but a content process never calls.
#
# Usage: ./gen-stubs.sh /path/to/dist/bin [output-dir]
#
# The script:
#   1. Reads libxul.so's NEEDED entries and dynamic symbol table.
#   2. For each stubbable library, finds which symbols libxul.so imports from it.
#   3. Generates a C file with no-op implementations.
#   4. Compiles into a stub .so with the correct SONAME.

set -euo pipefail

DISTBIN="${1:?Usage: $0 /path/to/dist/bin [output-dir]}"
OUTDIR="${2:-$(dirname "$0")/stubs}"

LIBXUL="$DISTBIN/libxul.so"
if [ ! -f "$LIBXUL" ]; then
    echo "error: $LIBXUL not found" >&2
    exit 1
fi

# Libraries to stub (direct NEEDED entries of libxul.so that content
# processes don't actually call into).
STUB_LIBS=(
    libgtk-3.so.0
    libgdk-3.so.0
    libgdk_pixbuf-2.0.so.0
    libglib-2.0.so.0
    libgobject-2.0.so.0
    libgio-2.0.so.0
    libpangocairo-1.0.so.0
    libpango-1.0.so.0
    libcairo.so.2
    libcairo-gobject.so.2
    libatk-1.0.so.0
    libfreetype.so.6
    libfontconfig.so.1
    libX11.so.6
    libXcomposite.so.1
    libXdamage.so.1
    libXext.so.6
    libXfixes.so.3
    libXrandr.so.2
    libXrender.so.1
    libXcursor.so.1
    libXi.so.6
    libX11-xcb.so.1
    libxcb.so.1
    libxcb-shm.so.0
    libdbus-1.so.3
    libasound.so.2
)

mkdir -p "$OUTDIR"

# Get all undefined (imported) symbols from libxul.so.
# These are symbols libxul.so expects to find in its NEEDED libraries.
echo "Extracting undefined symbols from libxul.so..."
XULSYMS=$(mktemp)
# UND symbols in dynsym with GLOBAL or WEAK binding, excluding empty names.
readelf -W --dyn-syms "$LIBXUL" 2>/dev/null | \
    awk '$7 == "UND" && $5 != "" && ($5 == "GLOBAL" || $5 == "WEAK") && $NF != "" {print $NF}' | \
    sort -u > "$XULSYMS"

echo "  $(wc -l < "$XULSYMS") undefined symbols in libxul.so"

gen_stub() {
    local soname="$1"
    local sopath

    # Find the real library on the host system.
    sopath=$(ldconfig -p 2>/dev/null | grep -F "$soname" | head -1 | sed 's/.*=> //' || true)
    if [ -z "$sopath" ] || [ ! -f "$sopath" ]; then
        # Try common paths.
        for d in /usr/lib/x86_64-linux-gnu /usr/lib64 /lib/x86_64-linux-gnu; do
            if [ -f "$d/$soname" ]; then
                sopath="$d/$soname"
                break
            fi
        done
    fi

    if [ -z "$sopath" ] || [ ! -f "$sopath" ]; then
        echo "  SKIP $soname (not found on host)"
        return
    fi

    # Get exported symbols from the real library.
    local realsyms
    realsyms=$(mktemp)
    readelf -W --dyn-syms "$sopath" 2>/dev/null | \
        awk '$7 != "UND" && $5 != "" && ($5 == "GLOBAL" || $5 == "WEAK") && $4 != "" && $NF != "" {
            print $NF "\t" $4
        }' | sort -u > "$realsyms"

    # Intersect: symbols libxul.so needs AND the real library provides.
    local needed
    needed=$(mktemp)
    while IFS=$'\t' read -r sym typ; do
        if grep -qxF "$sym" "$XULSYMS"; then
            echo "$sym	$typ"
        fi
    done < "$realsyms" > "$needed"

    local count
    count=$(wc -l < "$needed")
    if [ "$count" -eq 0 ]; then
        echo "  SKIP $soname (no symbols needed by libxul.so)"
        rm -f "$realsyms" "$needed"
        return
    fi

    echo "  $soname: $count symbols"

    # Generate C stub file.
    local base
    base=$(echo "$soname" | sed 's/\.so.*//')
    local cfile="$OUTDIR/${base}_stub.c"

    cat > "$cfile" <<'HEADER'
/* Auto-generated stub. All functions abort if called. */
#include <stdlib.h>
#include <stdio.h>

static void __attribute__((noreturn)) _stub_abort(const char *sym) {
    fprintf(stderr, "FATAL: stub called: %s\n", sym);
    abort();
}

HEADER

    while IFS=$'\t' read -r sym typ; do
        case "$typ" in
            FUNC)
                echo "void $sym(void) { _stub_abort(\"$sym\"); }" >> "$cfile"
                ;;
            OBJECT)
                # Data symbols: provide a zero-initialized global.
                echo "char $sym[64] __attribute__((aligned(8)));" >> "$cfile"
                ;;
            *)
                echo "void $sym(void) { _stub_abort(\"$sym\"); }" >> "$cfile"
                ;;
        esac
    done < "$needed"

    # Compile the stub.
    gcc -shared -o "$OUTDIR/$soname" -Wl,-soname,"$soname" \
        -fPIC -nostartfiles "$cfile" 2>/dev/null

    rm -f "$realsyms" "$needed"
}

echo ""
echo "Generating stubs in $OUTDIR..."
for lib in "${STUB_LIBS[@]}"; do
    gen_stub "$lib"
done

rm -f "$XULSYMS"

echo ""
echo "Done. Stubs in $OUTDIR:"
ls -lhS "$OUTDIR"/*.so 2>/dev/null || echo "(none)"
