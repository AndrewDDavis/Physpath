#!/bin/bash

canonpath() {

    : "Print absolute path after resolving symlinks (canonical path)

    Usage: canonpath <path>

    Notes:

    - The target path may be symbolic link, file or directory. The path may contain
      symlinks or relative references like '.' and '..'.

    - Works on GNU/Linux or BSD-like systems, including macOS.

    - Unlike GNU 'readlink -f' or 'realpath', the full path must exist.

    - Symlinks in the path are resolved before instances of '..', using the shell
      built-in command 'cd -P'. Thus, paths like 'a/b/s/../', in which 's' is a symlink
      to '/tmp/c/', resolve to '/tmp/'. With the default 'cd -L' behaviour, the path
      would resolve to 'a/b/'.
    "

    # I have posted this function as an
    # [answer](https://apple.stackexchange.com/a/444039/61160), with testing examples.


    # function docs
    [[ $# -eq 0 || $1 == -h ]] && {
        [[ -n $( command -v docsh ) ]] &&
            { docsh -TD; return; }

        declare -pf "${FUNCNAME[0]}" | head -n $(( $LINENO - 5 ))
        return
    }

    # only handle 1 path, otherwise would need a -0 option
    [[ $1 == -- ]] && shift
    if [[ $# -gt 1 ]]
    then
        echo >&2 "canonpath: only one path allowed"
        return 2

    elif [[ -z $1 ]]
    then
        echo >&2 "canonpath: non-null path required"
        return 2
    fi

    local tgt=$1
    shift

    if [[ -L $tgt  &&  ! -e $tgt ]]
    then
        # broken symlink
        echo >&2 "canonpath: broken symlink: '$tgt'"
        return 2
    elif [[ ! -e $tgt ]]
    then
        # otherwise non-exsitent
        echo >&2 "canonpath: path not found: '$tgt'"
        return 2
    fi

    # resolve symlink at the basename of the target (possible chain, max 100)
    local tgt_dir i=0
    while [[ -L $tgt ]]
    do
        # handle relative path
        tgt_dir=$( command dirname -- "$tgt" )

        # symlink target may be absolute or relative path
        # - readlink prints path if symlink or nothing and status=1 for non-symlink
        # tgt=$( command readlink "$tgt" )
        # - use 'file' to resolve symlink, terminating the filename with NULL
        tgt=$( command file -bh0 "$tgt" | sed 's/^symbolic link to //' )

        # handle tgt_dir=/ with relative paths
        [[ ${tgt:0:1} == / ]] ||
            tgt=${tgt_dir%/}/$tgt

        (( i++ ))
        [[ $i -lt 99 ]] || {
            echo >&2 "canonpath: more than 99 iterations to resolve symlinks"
            return 99
        }
    done

    _canon_dir() (
        # print real path of a dir
        builtin cd -P "$1" &>/dev/null && builtin pwd
    )

    if [[ -d $tgt ]]
    then
        # handle paths like this/is/a/link/..
        printf '%s\n' "$( _canon_dir "$tgt" )"

    elif [[ -f $tgt ]]
    then
        printf '%s/%s\n' "$( _canon_dir "$( command dirname -- "$tgt" )" )" \
            "$( command basename -- "$tgt" )"

    else
        echo >&2 "canonpath: unknown file type"
        return 3
    fi
}
