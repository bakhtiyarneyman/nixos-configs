function fish_user_key_bindings
    bind \cs 'exec fish'
    bind \cr 'peco_select_history (commandline -b)'
end

function print_error -d "Print error message"
    set_color red
    echo $argv
    set_color normal
end

function print_warning -d "Print warning message"
    set_color yellow
    echo $argv
    set_color normal
end

function print_info -d "Print info message"
    set_color blue
    echo $argv
    set_color normal
end

function print_success -d "Print success message"
    set_color green
    echo $argv
    set_color normal
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
    set --function options (fish_opt --short h --long help)
    set options $options (fish_opt --required-val --short n --long noise)
    set options $options (fish_opt --required-val --short s --long speed)
    set options $options (fish_opt --required-val --short i --long input-file)
    set options $options (fish_opt --required-val --short o --long output-dir)
    set options $options (fish_opt --required-val --short c --long container)

    set --function global_quality 25
    set --function preset veryfast

    argparse --name="recode" $options -- $argv
    or return

    if set --query _flag_help
        echo "Recode video files using ffmpeg/qsv"
        echo "Usage:"
        echo "  recode --help"
        echo "  recode [--noise <noise>] [--max-keyframe-gap <max-keyframe-gap>] [--speed <speed>] --input-file <input-file> --output-dir <output-dir>"
        echo "Options:"
        echo " -h, --help: show this help"
        echo " -n, --noise: noise level (-global_quality in QSV). Default: $global_quality"
        echo " -s, --speed: speed of encoding. Default: $preset"
        echo " -c, --container: Container format. Default: same as input file"
        echo " -i, --input-file: input file"
        echo " -o, --output-dir: output directory"
        return 0
    end

    if set --query _flag_noise
        echo "Using noise level: $_flag_noise"
        set --function global_quality $_flag_noise
    end

    if set --query _flag_speed
        echo "Using encoding speed: $_flag_speed"
        set --function preset $_flag_speed
    end

    if set --query _flag_container
        echo "Using container format: $_flag_container"
        set --function container $_flag_container
    else
        set --function container (path extension $_flag_input_file)
    end

    set --function file $_flag_input_file
    set --function output_dir $_flag_output_dir
    set --function base (path basename $file)

    set --function temp_target $output_dir/(path change-extension gq=$global_quality.preset=$preset.unfinished.$container $base)
    set --function target (path change-extension $container (path change-extension "" $temp_target))

    if test -e "$target"
        set_color green
        echo "'$target' already exists."
        return 0
    end

    set_color yellow
    echo "Recoding '$file' as '$target'..."
    set_color normal

    ffmpeg \
        -hwaccel qsv \
        -i $file \
        -copy_unknown \
        -map 0 \
        -map_metadata 0 \
        -c copy \
        -c:v hevc_qsv \
        -preset $preset \
        -global_quality $global_quality \
        -y \
        $argv \
        $temp_target
    or return 1

    mv $temp_target $target
end

function move_to_cache -d "Move to cache"
    argparse --name='move_to_cache' f/force h/help -- $argv
    or return

    if test $_flag_help
        echo "Usage:"
        echo "  move_to_cache [--help] [--force] <path>"
        echo "    -h / --help             Show this help"
        echo "    -f / --force            Overwrite existing cache"
        echo "    path     The path to move to cache"
        return 0
    end

    if test (count $argv) -lt 1
        print_error "You must specify a path."
        return 1
    end

    if test (count $argv) -gt 1
        print_error "You must specify only one path."
        return 1
    end

    # Remove trailing slash from the src.
    set src (path dirname $argv[1]/foo)
    string match --regex '^/' $src
    if test $status -eq 0
        # Absolute path.
        set dst /var/cache$src
    else
        # Relative path.
        set dst /var/cache(pwd)/$src
    end

    if not test -e $src
        print_error "Path `$src` does not exist."
        return 1
    end

    if test -L $src
        set link_target (readlink $src)
        if test $link_target = $dst
            print_info "Path `$src` is already a symlink to the cache."
            return 0
        else
            print_error "Path `$src` is a symlink to `$link_target`."
            return 1
        end
    end

    if test -e $dst
        if test $_flag_force
            rm -rf $dst; or return 1
        else
            print_error "Path `$dst` already exists. Run with --force to overwrite."
            return 1
        end
    end

    mkdir --parents (path dirname $dst); or return 1
    mv --no-target-directory $src $dst; or return 1
    ln --symbolic $dst $src; or return 1
    print_success "Moved `$src` to cache."
end
