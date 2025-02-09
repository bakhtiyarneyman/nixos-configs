function fish_user_key_bindings
    bind \cs 'exec fish'
    bind \cr 'peco_select_history (commandline -b)'
end


function list
    eza -l --icons --color=always | bat -
end

function goin -w cd
    cd $argv; and list
end

function goto -w z
    z $argv; and list
end

alias nix-shell-fish 'nix-shell --run fish'

function bluetoothctl
    command bluetoothctl devices Paired; and command bluetoothctl
end

function delete_old_snapshots
    argparse --max-args=1 "older-than=?" confirm help -- $argv

    if test $_flag_help
        echo "Usage: delete_old_snapshots --older-than=DATE [--confirm] [FILESYSTEM]"
        echo "  --older-than=DATE  Delete snapshots older than this date, e.g. '05/14/2023 00:00:00+07'"
        echo "  --confirm            Actually delete snapshots"
        echo "  FILESYSTEM         The pool or dataset to delete snapshots from"
        return 0
    end


    if test $_flag_older_than
        set threshold (date -d $_flag_older_than +%s)
    else
        echo "You must specify --older-than"
        return 1
    end

    zfs list -H -o name,creation -t snapshot $argv | while read -s line
        set name (echo $line | cut -f1)
        set date (echo $line | cut -f2- -d' ' | date -f - +%s)

        if test $date -lt $threshold
            if test $_flag_confirm
                echo Deleting $name
                sudo zfs destroy $name; or return 1
            else
                echo Would have deleted $name
            end
        end
    end
end

function rename_gopro_files

    argparse --max-args=0 confirm help -- $argv

    if test $_flag_help
        echo "Usage: rename_gopro_files [--confirm]"
        echo "  --confirm          Actually rename files"
        return 0
    end

    # Loop through each MP4 file
    for old in (find -maxdepth 1 -type f -iname '*.mp4' | sort --numeric-sort)
        # Extract the filename without extension
        set filename (basename --suffix=.mp4 $old)

        # Extract relevant parts from the filename
        set gopro_marker (string sub --start=1 --length=1 $filename)
        set encoding (string sub --start=2 --length=1 $filename)
        set chapter_number (string sub --start=3 --length=2 $filename)
        set file_number (string sub --start=5 --length=4 $filename)
        set suffix (string sub --start=9 $filename)

        echo "gopro_marker=$gopro_marker"
        echo "encoding=$encoding"
        echo "chapter_number=$chapter_number"
        echo "file_number=$file_number"

        # Verify that the filename is in the format G%encoding%%chapter_number%%file_number%.MP4
        #   1. G is a literal character
        #   2. encoding is either 'H' or 'X'
        #   3. chapter_number is a two-digit number
        #   4. file_number is a four-digit number

        if test $gopro_marker != G
            echo "$filename doesn't start with G: $gopro_marker"
            return 1
        end

        if test $encoding != H -a $encoding != X
            echo "encoding of $filename doesn't have encoding H or X: $encoding"
            return 1
        end

        if test $chapter_number -lt 1 -o $chapter_number -gt 99
            echo "chapter_number of $filename isn't between 1 and 99: $chapter_number"
            return 1
        end

        if test $file_number -lt 1 -o $file_number -gt 9999
            echo "file_number of $filename isn't between 1 and 9999: $file_number"
            return 1
        end

        if test -n $suffix
            echo "$filename doesn't end with .MP4: $suffix"
            return 1
        end

        # Create the new filename
        set new "$file_number.$chapter_number.mp4"

        if test $_flag_confirm
            echo "Renaming $old to $new"
            # mv $old $new; or return 1
        else
            echo Would have renamed $old to $new
        end
    end
end

function recode
    set --local options (fish_opt --long-only --short h --long help)
    set options $options (fish_opt --optional-val --long-only --short n --long noise)
    set options $options (fish_opt --optional-val --long-only --short g --long max-keyframe-gap)
    set options $options (fish_opt --optional-val --long-only --short s --long speed )
    set options $options (fish_opt --required-val --long-only --short i --long input-file)
    set options $options (fish_opt --required-val --long-only --short o --long output-dir)

    set --local crf 32
    set --local preset 4
    set --local g 300

    argparse --name="recode" --ignore-unknown $options -- $argv
    or return

    if test -n "$_flag_help"
        echo "Recode video files using ffmpeg/libsvtav1"
        echo "Usage:"
        echo "  recode --help"
        echo "  recode [--noise <noise>] [--max-keyframe-gap <max-keyframe-gap>] [--speed <speed>] --input-file <input-file> --output-dir <output-dir>"
        echo "Options:"
        echo " -h, --help: show this help"
        echo " -n, --noise: noise level (-crf in libsvtav1). Default: $crf"
        echo " -g, --max-keyframe-gap: max keyframe gap (-g in libsvtav1). Default: $g"
        echo " -s, --speed: speed (-preset in libsvtav1). Default: $preset"
        echo " -i, --input-file: input file"
        echo " -o, --output-dir: output directory"
        return 0
    end

    if test -n "$_flag_noise"
        set crf $_flag_noise
    end

    if test -n "$_flag_max_keyframe_gap"
        set g $_flag_max_keyframe_gap
    end

    if test -n "$_flag_speed"
        set preset $_flag_speed
    end


    set --local file $_flag_input_file
    set --local output_dir $_flag_output_dir
    set --local base (path basename $file)

    set --local temp_target $output_dir/(path change-extension crf=$crf.preset=$preset.g=$g.unfinished.mkv $base)
    set --local target (path change-extension mkv (path change-extension "" $temp_target))

    if test -e "$target"
        set_color green
        echo "'$target' already exists."
        return 0
    end

    set_color yellow
    echo "Recoding '$file' as '$target'..."
    set_color normal

    ffmpeg \
        -i $file \
        -c:v libsvtav1 \
        -preset $preset \
        -crf $crf \
        -g $g \
        -svtav1-params tune=0 \
        -c:a copy \
        -y \
        $argv \
        $temp_target
    or return 1

    mv $temp_target $target
end

function move_to_cache -d "Move to cache"
    set cache_dir /var/cache(pwd)
    set moved_path $argv[1]
    # Remove trailing slash from the moved_path.
    set moved_path (path dirname $moved_path/foo)

    if not test -e $moved_path
        echo "Path $moved_path does not exist"
        return 1
    end

    # Check if the moved_path is already a symlink to the cache.
    if test -L $moved_path
        set link_target (readlink $moved_path)
        if test $link_target = $cache_dir/$moved_path
            echo "Path $moved_path is already a symlink to the cache"
            return 0
        end
    end

    if test -e $cache_dir/$moved_path
        echo "Path $cache_dir/$moved_path already exists"
        return 1
    end

    mkdir --parents $cache_dir/$moved_path
    mv --no-target-directory $moved_path $cache_dir/$moved_path
    # Strip a trailing slash from the moved_path if present

    ln --symbolic $cache_dir/$moved_path $moved_path
end
