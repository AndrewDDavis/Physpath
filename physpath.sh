# dependencies
# - implied: err_msg, docsh
import_func phys_dirpath \
    || return 63

physpath() {

    # docs
    if [[ $# -eq 0  || $1 == @(-h|--help) ]]
    then
        : "Print physical path, after resolving symlinks

        Usage: physpath <path>

        The path argument may be a symbolic link, file, or directory. This function
        prints the absolute path of the target with any symlinks or relative references
        ('.' and '..') resolved.

        Unlike some other similar tools such as GNU 'readlink -f' or 'realpath', the
        path argument must exist on the filesystem. Since physpath is written as a
        shell script and relies on cross-platform tools, it runs quickly and can be
        used on Linux and macOS systems.

        Notes

          - Works on GNU/Linux and BSD-like systems, including macOS. It relies on the
            \`file\` command to resolve symlinks in the basename, which generally has a
            consistent interface across systems, unlike the \`stat\`, \`ls\`, and
            \`readlink\` commands.

          - Symlinks in the path are resolved after instances of '..', using the shell
            built-in command 'cd -L'.

            For more on the '-P' and '-L' options to cd and pwd, refer to the
            phys_dirpath function documentation. The -L or -P option may be supplied on
            the command-line of this function, to be passed along to the phys_dirpath
            command when resolving directory paths.

          - An earlier version of this function is posted as an [answer](https://apple.stackexchange.com/a/444039/61160),
            with testing examples.

        Alternatives

          - For some applications, it's possible to write safe and effective one-liners to
            resolve symbolic links. E.g., if you know that you're resolving a directory
            path, you can use a one-liner similar to:

            dir=\$( cd -- \"\$path\" &> /dev/null  && pwd -P )

          - A common use case is the need to obtain the absolute path of a script file while
            it's running. Some would advise to use a line like the one above, using the
            output of 'dirname \${BASH_SOURCE[0]}' for the path. However, this fails in the
            common case that the basename of the path is a symlink. The subtleties that can
            happen when resolving symlinks is the reason this function exists.
        "
        docsh -TD
        return
    fi

    # clean up
    # - NB, I would like to put _rslv_link in a separate file and use 'import_func -l'
    #   to grab it at run-time, but that would set up an infinite loop, since
    #   import_func actually calls physpath
    trap '
        unset -f _rslv_link
        trap - return
    ' RETURN

    _rslv_link() {
        # resolve symlink target with 'file' command
        # - prints e.g. 'symbolic link to ...', 'cannot open ...', 'directory', 'empty',
        #   'ASCII text', etc.
        # - for broken symlinks, prints 'broken symbolic link to ...'
        # - this is consistent across Linux and macOS
        # - NB, file -L dereferences the link, like ls -L, and unlike cd -L
        # - with -E, would print an error message, otherwise returns true regardless
        local tgt
        tgt=$( command file -bh0 "$1" )

        case $tgt in
            ( 'symbolic link to '* )
                printf '%s\n' "${tgt/#symbolic link to /}" ;;
            ( 'broken symbolic link to '* )
                printf '%s\n' "${tgt/#broken symbolic link to /}" ;;
            ( * )
                printf >&2 '%s\n' "unkown file output: $tgt"
                return 2 ;;
        esac
    }

    # last arg must be path
    local pth opts
    pth=${!#}
    opts=( "${@:1:$(($#-1))}" )
    shift $#

    [[ $pth != '-' ]] || {
        # convert - to OLDPWD, as cd would
        pth=$OLDPWD
    }

    # test pth veracity
    local tgt

    if [[ -z $pth ]]
    then
        err_msg 2 "non-null path required"
        return

    elif [[ -L $pth  && ! -e $pth ]]
    then
        tgt=$( _rslv_link "$pth" )
        err_msg 1 "'$pth' is a broken symlink to '$tgt'"
        return

    elif [[ ! -e $pth ]]
    then
        err_msg 3 "path not found: '$pth'"
        return

    elif [[ -d $pth ]]
    then
        # NB, shell test -d resolves symlinks

        # phys_dirpath handles directory paths
        phys_dirpath "${opts[@]}" "$pth"

    else
        # file, or symlink to a file (or special thing like socket)

        # resolve symlink at the basename of the target
        # - bash test -L returns true for working or broken symlinks, but
        #   it only tests the basename of the path
        # - this while loop can handle a chain of links (max 100)
        local pth_dir i=0

        while [[ -L $pth ]]
        do
            # handle relative path
            # - dirname may be function or executable file
            pth_dir=$( dirname -- "$pth" )

            # - NB, readlink prints path if symlink or nothing and status=1 for non-symlink
            #   pth=$( command readlink "$pth" )

            # resolve symlink to target path
            pth=$( _rslv_link "$pth" )

            # symlink target may have been absolute or relative path
            # - if relative, reconstruct from the original path
            # - but care is used to handle pth_dir=/ with relative paths
            #   e.g., if /ul is a symlink to usr, dirname /ul = /
            [[ ${pth:0:1} == / ]] ||
                pth=${pth_dir%/}/$pth

            (( ++i, i < 99 )) ||
                { err_msg 99 "tried more than 99 iterations to resolve symlinks"; return; }
        done

        # now call phys_dirpath to resolve any links in the directory path
        local dn bn
        dn=$( phys_dirpath "${opts[@]}" "$( dirname -- "$pth" )" )
        bn=$( basename -- "$pth" )

        printf '%s/%s\n' "$dn" "$bn"
    fi
}
