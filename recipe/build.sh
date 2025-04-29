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
    export ACLOCAL=aclocal-$am_version
    export AUTOMAKE=automake-$am_version
    autoreconf_args=(
        --force
        --install
        -I "$mprefix/share/aclocal"
        -I "$BUILD_PREFIX_M/Library/usr/share/aclocal"
    )
    autoreconf "${autoreconf_args[@]}"

    # Look in standard mingw-w64 library locations
    for lib_path in "$BUILD_PREFIX_M/Library/mingw-w64/bin" "$BUILD_PREFIX_M/Library/bin" "$mprefix/Library/mingw-w64/lib" "$mprefix/Library/lib"; do
        if [ -d "$lib_path" ]; then
            # Convert to Windows path
            win_path=$(cygpath -w "$lib_path")
            echo "Adding path to library search: $win_path"
            export PATH="$PATH:$win_path"
            export LIBRARY_PATH="$LIBRARY_PATH:$win_path"
            # For ld
            export LDFLAGS="$LDFLAGS -L$win_path"
        fi
    done
    
    # Explicitly add the Windows socket library to LIBS
    export LIBS="$LIBS -lws2_32"
    
    # Skip tests on Windows
    export do_check=no
else
    export do_check=yes
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

# Disable make check because it fails on win-64:
# FAIL: Array.exe
if [[ "${CONDA_BUILD_CROSS_COMPILATION:-}" != "1" && "${do_check:-yes}" == "yes" ]]; then
    make check
fi

rm -rf $uprefix/share/doc/libXdmcp
