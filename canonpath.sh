# this function assumes that docsh and err_msg have been imported
# previously, e.g. by import_func; see github ...

# to make a poor-man's docsh, you could do something like

# if ! command -v docsh >/dev/null
# then
#     declare -pf "${FUNCNAME[0]}" \
#         | head -n $(( LINENO - 10 ))
# fi

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


        # TODO: given a filename, canon_dirpath should print the (canonical) dirname of it
        local dn bn
        dn=$( canon_dirpath "${opts[@]}" "$( dirname -- "$pth" )" )
        bn=$( basename -- "$pth" )

        printf '%s/%s\n' "$dn" "$bn"
    fi
}


canon_dirpath() {

    [[ $# -eq 0  || $1 == @(-h|--help) ]] && {

        : "Print canonical path of a directory

        Usage: canon_dirpath [-L|-P] <path>

        Given the path of a directory, or a symlink that points to a directory, this
        function prints its absolute path after dereferencing any symlinks and relative
        path-refs ('.' and '..'). Only the cd and pwd built-in commands are used. The
        -L and -P options determine how instances of '..' are resolved in paths with
        symlinks, as explained below.

        To print the canonical path of a file that may itself be a symlink, use the
        \`canonpath\` function.

        Background on cd and pwd

        After each run, cd sets the PWD variable and moves the previous PWD value to
        the OLDPWD variable. When cd is used to change to a directory path that
        contains a symbolic link, the path written to PWD depends on whether the
        '-L' or '-P' options were used. Consider the following example:

        cd -P /tmp
        mkdir -p d1/d2
        ln -s d1/d2 l1

        ( builtin cd -P l1  && echo \"\$PWD\" )
        # /tmp/d1/d2

        ( builtin cd -L l1  && echo \"\$PWD\" )
        # /tmp/l1

        There is also a difference in how paths that include '..' are handled:
        'cd -P' resolves symlinks before processing instances of '..', whereas
        'cd -L' does not. Continuing the previous example:

        ( builtin cd -P l1/..  && echo \"\$PWD\" )
        # /tmp/d1

        ( builtin cd -L l1/..  && echo \"\$PWD\" )
        # /tmp

        The pwd command has an analagous behaviour, in that 'pwd -L' simply prints
        the value of PWD, while 'pwd -P' resolves symlinks in PWD first.

        ( builtin cd -L l1  && pwd -P )
        # /tmp/d1/d2

        The 'cd -L' command form is used herein, followed by 'pwd -P'. However, all
        arguments are passed to cd, so running 'canon_dirpath -P path' would
        resolve any instances of '..' after resolving any symlinks in the path.

        As a side note, both cd and pwd run as the '-L' version by default. However,
        if the shell option 'set -o physical' is enabled, running cd and pwd without
        options uses the 'cd -P' and 'pwd -P' versions. This may also affect any path
        shown in the shell prompt. Explicitly calling the commands with either the
        '-L' or '-P' option is recommneded when troubleshooting.
        "
        docsh -TD
        return
    }

    # last arg must be path
    local pth=${!#}

    # NB shell tests other than -L resolve symlinks
    if [[ -L $pth  && ! -e $pth ]]
    then
        err_msg 4 "broken symlink: '$pth'"

    elif [[ ! -d $pth ]]
    then
        err_msg 5 "not a directory: '$pth'"
        return

        # # use dirname of file path
        # pth=$( dirname -- "$pth" )
        # set -- "${@:1:$(($#-1))}" "$pth"
    fi

    (
        builtin cd -L "$@" &> /dev/null \
            && builtin pwd -P
    )
}
