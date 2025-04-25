#! /bin/bash

set -xe

# Adopt a Unix-friendly path if we're on Windows (see bld.bat).
[ -n "$PATH_OVERRIDE" ] && export PATH="$PATH_OVERRIDE"

# On Windows we want $LIBRARY_PREFIX in both "mixed" (C:/Conda/...) and Unix
# (/c/Conda) forms, but Unix form is often "/" which can cause problems.
if [ -n "$LIBRARY_PREFIX_M" ] ; then
    mprefix="$LIBRARY_PREFIX_M"
    if [ "$LIBRARY_PREFIX_U" = / ] ; then
        uprefix=""
    else
        uprefix="$LIBRARY_PREFIX_U"
    fi
else
    mprefix="$PREFIX"
    uprefix="$PREFIX"
fi

# On Windows we need to regenerate the configure scripts.
if [ -n "$CYGWIN_PREFIX" ] ; then
    am_version=1.15 # keep sync'ed with meta.yaml
    export ACLOCAL=aclocal-$am_version
    export AUTOMAKE=automake-$am_version
    autoreconf_args=(
        --force
        --install
        -I "$mprefix/share/aclocal"
        -I "$BUILD_PREFIX_M/Library/usr/share/aclocal"
    )
    autoreconf "${autoreconf_args[@]}"

    # And we need to add the search path that lets libtool find the
    # msys2 stub libraries for ws2_32.
    for potential_path in "$BUILD_PREFIX_M/Library/mingw-w64/lib" "$mprefix/mingw-w64/lib"; do
        if [ -e "$potential_path/libws2_32.a" ]; then
            platlibs=$(cygpath -w "$potential_path")
            echo "Found msys2 libs at: $platlibs"
            export LDFLAGS="$LDFLAGS -L$platlibs"
            break
        fi
    done
    
    if [ -z "$platlibs" ]; then
        echo "Warning: Could not locate libws2_32.a, using default path"
        default_path="$BUILD_PREFIX_M/Library/mingw-w64/lib"
        platlibs=$(cygpath -w "$default_path")
        export LDFLAGS="$LDFLAGS -L$platlibs"
    fi
else
    # for other platforms we just need to reconf to get the correct achitecture
    echo libtoolize
    libtoolize
    echo aclocal -I $PREFIX/share/aclocal -I $BUILD_PREFIX/share/aclocal
    aclocal -I $PREFIX/share/aclocal -I $BUILD_PREFIX/share/aclocal
    echo autoconf
    autoconf
    echo automake --force-missing --add-missing --include-deps
    automake --force-missing --add-missing --include-deps

    export CONFIG_FLAGS="--build=${BUILD}"
fi

export PKG_CONFIG_LIBDIR=$uprefix/lib/pkgconfig:$uprefix/share/pkgconfig
configure_args=(
    $CONFIG_FLAGS
    --prefix=$mprefix
    --disable-static
    --disable-dependency-tracking
    --disable-selective-werror
    --disable-silent-rules
)

./configure "${configure_args[@]}"
make -j$CPU_COUNT
make install

# Disable make check because it fails on win-64
# FAIL: Array.exe
# if [[ "${CONDA_BUILD_CROSS_COMPILATION:-}" != "1" || "${CROSSCOMPILING_EMULATOR}" != "" ]]; then
#     make check
# fi

rm -rf $uprefix/share/doc/libXdmcp
