#!/bin/bash -ue

# Shell script to generate an IODS release from a set of current git repos.

verbose=1
testing=1

function usage () {
    echo "$0 [flags]:  Generate IODS release"
    echo "Required flags:"
    echo "  -r <rel>:       The git tag of the release"
    echo "Optional flags:"
    echo "  -p <plat-dir>:  Platform directory to use; can use multiple times"
    echo "  -d <dir>:       The IODS directory: default is <top>/iods-<rel>"
    echo "  -t <dir>:       Top level directory name; default to current"
}

# Simple minded arg parsing
set +u
platforms=""
while [ -n "$1" ]; do
    flag=$1
    shift
    case $flag in
        -r)
            rel=$1
            shift
            echo "Release $rel"
            ;;
        -p) # Allow multiple platforms to be specified
            platforms="$platforms $1"
            shift
            ;;
        -t)
            topdir=$1
            shift
            ;;
        -d)
            iodsdir=$1
            shift
            ;;
#        -f)
#            force=1
#            ;;
        *)
            echo Unknown flag: $flag
            usage
            exit 1
            ;;
    esac
done

if [ -z "$rel" ]; then
    echo "Release is required."
    usage
    exit 1
fi
if [ -z "$platforms" ]; then
    platforms="indigo-gsm73xx indigo-lb9a indigo-lb8 indigo-lb4g indigo-bcm-ref"
fi
if [ -z "$topdir" ]; then
    topdir=`pwd`
    echo "Using current directory as top"
fi
if [ -z "$iodsdir" ]; then
    iodsdir=$topdir/iods-$rel
    echo "Using $iodsdir for IODS directory"
fi
set -u

# May check -f in the future to allow override
if test -e $iodsdir; then
    echo "Destination directory $iodsdir exits in $topdir."
    echo "Destination must not exist"
    exit 1
fi

# Check required dirs are present
# TODO:  Add cmdsrv directory
git_repos="cmdsrv indigo-core indigo-ui $platforms"
for dir in $git_repos; do
    if ! test -d $topdir/$dir; then
        echo "Required directory $dir not found in $topdir"
        exit 1
    fi
done

if test -n "$verbose"; then
    echo "Platforms: $platforms"
    echo "git repos: $git_repos"
    echo "top level dir: $topdir"
    echo "IODS dir: $iodsdir"
fi

clean_iods=$topdir/indigo-core/tools/clean_iods.lua
if ! test -x $clean_iods; then
    echo "Can not find clean_iods at $clean_iods"
    exit 1
fi

mkdir -p $iodsdir
cd $iodsdir

for dir in $git_repos; do
    srcdir=$topdir/$dir
    echo "Cloning from $srcdir"
    git clone $srcdir
    cd $dir
    [ $testing ] || git checkout $rel
    if test -e iods-strip; then
        # TODO: Skip comments in iods files
        for file in `cat iods-strip`; do
            echo "Stripping IODS from file $file"
            $clean_iods $file
            mv $file.iods $file
        done
    fi
    # Remove files listed in iods-remove
    if test -e iods-remove; then
        # TODO: Skip comments in iods files
        for file in `cat iods-remove`; do
            echo "Removing file $dir/$file"
            rm -rf $file
        done
    fi
    set +e
    # Strip files containing IODS_EXCLUDE tags
    strip_files=`grep -l IODS_EXCLUDE_BEGIN *`
    set -e
    if test -n "$strip_files"; then
        for file in $strip_files; do
            echo "Stripping IODS_EXCLUDE from $dir/$file"
            $clean_iods $file
            mv $file.iods $file
        done
    fi
    echo "Removing .git from $dir"
    rm -rf .git
    cd ..
done

# Verify these files are not found in the IODS release dir
binary_files="ofswd linux-kernel-bde.ko linux-user-bde.ko"
exitval=0
for file in $binary_files; do
    set +e
    f=`find . -name $file -type f -print`
    set -e
    if test -n "$f"; then
        echo "WARNING: Found file $f"
        exitval=1
    fi
done

exit $exitval
