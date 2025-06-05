phys_dirpath() {

    [[ $# -eq 0  || $1 == @(-h|--help) ]] && {

        : """Print physical path of a directory

        Usage: phys_dirpath [-L|-P] <path>

        Given the path of a directory, or a symlink that points to a directory, this
        function prints its absolute path after dereferencing any symlinks and relative
        path-refs ('.' and '..'). Only the cd and pwd built-in commands are used. The
        -L and -P options determine how instances of '..' are resolved in paths with
        symlinks, as explained below.

        To print the physical path of a file that may itself be a symlink, use the
        \`physpath\` function.

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
        arguments are passed to cd, so running 'phys_dirpath -P path' would
        resolve any instances of '..' after resolving any symlinks in the path.

        As a side note, both cd and pwd run as the '-L' version by default. However,
        if the shell option 'set -o physical' is enabled, running cd and pwd without
        options uses the 'cd -P' and 'pwd -P' versions. This may also affect any path
        shown in the shell prompt. Explicitly calling the commands with either the
        '-L' or '-P' option is recommneded when troubleshooting.
        """
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

        ### vvv prev allowed non-directory input
        # # use dirname of file path
        # pth=$( dirname -- "$pth" )
        # set -- "${@:1:$(($#-1))}" "$pth"
    fi

    (
        builtin cd -L "$@" &> /dev/null \
            && builtin pwd -P
    )
}
