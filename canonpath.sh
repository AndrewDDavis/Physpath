# this function assumes that docsh and err_msg have been imported
# previously, e.g. by import_func; see github ...

# to make a poor-man's docsh, you could do something like

# if ! command -v docsh >/dev/null
# then
#     declare -pf "${FUNCNAME[0]}" \
#         | head -n $(( LINENO - 10 ))
# fi

import_func canon_dirpath \
    || return 63

canonpath() {

    : "Print canonical path, after resolving symlinks

    Usage: canonpath <path>

    The path argument may be a symbolic link, file, or directory. This function prints
    the absolute path of the target with any symlinks or relative references
    ('.' and '..') resolved.

    Unlike some other similar tools such as GNU 'readlink -f' or 'realpath', the path
    argument must exist on the filesystem.

    Notes:

      - Works on GNU/Linux and BSD-like systems, including macOS. It relies on the
        \`file\` command to resolve symlinks in the basename, which generally has a
        consistent interface across systems, unlike the \`stat\` and \`ls\` commands.

      - Symlinks in the path are resolved after instances of '..', using the shell
        built-in command 'cd -L'. For more on the '-P' and '-L' options to cd and
        pwd, refer to the canon_dirpath function documentation.

      - This function is posted as an [answer](https://apple.stackexchange.com/a/444039/61160),
        with testing examples.

      - It's possible to write short alternatives to this function that may do all
        that's needed for a particular application. E.g., if you know the path is a
        directory, you can call the canon_dirpath function directly, or use a one-liner
        similar to:

        dir=\$( cd -- \"\$path\" &> /dev/null  && pwd -P )

        It's commonly needed to obtain the absolute path of a script file that's being
        executed or sourced. Some would advise to use a line like the one above,
        using the output of 'dirname \${BASH_SOURCE[0]}' for the path. However, this
        won't give the directory holding the actual source file if the filename that
        refers the script file is itself a symlink, which is common. In that case, you
        may as well use this function.
    "

    # docs
    [[ $# -eq 0  || $1 == @(-h|--help) ]] &&
        { docsh -TD; return; }


    # last arg must be path
    local pth opts
    pth=${!#}
    opts=( "${@:1:$(($#-1))}" )
    shift $#

    [[ $pth != '-' ]] || {
        # convert - to OLDPWD, as cd would
        pth=$OLDPWD
    }


    if [[ -z $pth ]]
    then
        err_msg 3 "non-null path required"
        return

    elif [[ -L $pth  && ! -e $pth ]]
    then
        err_msg 4 "broken symlink: '$pth'"
        return

    elif [[ ! -e $pth ]]
    then
        err_msg 5 "path not found: '$pth'"
        return
    fi


    # NB, shell test -d resolves symlinks
    if [[ -d $pth ]]
    then
        # canon_dirpath handles directory paths
        canon_dirpath "${opts[@]}" "$pth"

    else
        # file, or symlink to a file

        # resolve symlink at the basename of the target (possible chain, max 100)
        local pth_dir i=0

        while [[ -L $pth ]]
        do
            # handle relative path
            # - dirname can be function or executable file
            pth_dir=$( dirname -- "$pth" )

            # - NB, readlink prints path if symlink or nothing and status=1 for non-symlink
            #   pth=$( command readlink "$pth" )

            # use 'file' to resolve symlink (prints file-path only, followed by NULL)
            # - NB, file -L dereferences the link, like ls -L, and unlike cd -L
            pth=$( command file -bh0 "$pth" )
            pth=${pth/#symbolic link to /}

            # symlink target may have been absolute or relative path
            # - if relative, reconstruct from the original path
            # - but care is used to handle pth_dir=/ with relative paths
            #   e.g., if /ul is a symlink to usr, dirname /ul = /
            [[ ${pth:0:1} == / ]] ||
                pth=${pth_dir%/}/$pth

            (( ++i, i < 99 )) ||
                { err_msg 99 "tried more than 99 iterations to resolve symlinks"; return; }
        done


        local dn bn
        dn=$( canon_dirpath "${opts[@]}" "$( dirname -- "$pth" )" )
        bn=$( basename -- "$pth" )

        printf '%s/%s\n' "$dn" "$bn"
    fi
}
