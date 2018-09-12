#
# edit session
# open session
# list session

_s_help() {
    cat <<EOF
     edit
     open
     list
EOF
}

_s_read_single_record() {
    #
    # ret_names = {
    #               "key1": "command comment",
    #               "key2": "command",
    #               "key3": "command comment",
    #             }
    # ret_records = {
    #                   "key1-command": "ssh 127.0.0.1",
    #                   "key1-comment": "ssh to local",
    #                   "key2-command": "ssh fdslakjf",
    #                   ....
    #               }
    #
    #
    if [[ $# == 0 ]];then
        echo "BUG _s_read_single_record called with 0 arg"
        exit -1
    fi

    local ret_names=$1
    local ret_records=$2
    local name=$3

    local flag=0

    O_IFS=$IFS
    IFS=$'\n' 
    for line in $(cat $_s_config_dir/$name); do
        local arr=(${(s.: .)line})
        local attr_key=$arr[1]
        local attr_val=${arr[@]:1}

        local tmp=${attr_val//\\/\\\\\\\\}
        tmp=${tmp//\'/\\\'}
        eval $ret_names"[$name]"+="'${attr_key} '"
        eval $ret_records"[$name-$attr_key]"="$'$tmp'"
    done

    IFS=$O_IFS
}

_s_read_records() {
    for f in $(ls $_s_config_dir); do
        _s_read_single_record $1 $2 $f
    done 
}

_s_convert_record() {
    local names_var=$1
    local records_var=$2
    local output_var=$3
    local name=$4

    local attr_str=${${(P)names_var}[$name]}
    attrs=(${(s: :)attr_str})
    for attr in $attrs;do
        local key=$name"-"$attr
        key=${key// /}

        local tmp=${${(P)records_var}[$key]}
        tmp=${tmp//\\/\\\\}
        tmp=${tmp//\'/\\\'}
        eval $output_var"[$attr]="$"'$tmp'"
    done
}

_s_print_item() {
    local names_var=$1
    local records_var=$2
    local name=$3

    typeset -A dict
    _s_convert_record $names_var $records_var dict $name

    echo $name":"
    for k v in ${(kv)dict};do
        if [[ $k != "name" ]]; then
            echo "    "$k"\t\t->\t"$v
        fi
    done
}

_s_list_commands() {
    typeset -A names
    typeset -A records

    if [[ $# == 0 ]]; then
        _s_read_records names records
        for name in ${(k)names};do
            _s_print_item names records "$name"
            echo
        done
    else
        for name in $@; do
            _s_check_record_exist $name || continue
            _s_read_single_record names records "$name"
            _s_print_item names records "$name"
            echo
        done
    fi
}

_s_check_record_exist() {
    local f=$_s_config_dir/$1
    if [[ ! -f $f ]]; then
        echo "No such session name" $1
        return -1
    fi
}

_s_edit_session() {
    local f=$_s_config_dir/$1
    _s_check_record_exist "$1" && $editor $f
}

_s_put_record() {
    local input_dict_var=$1

    local prefix=${${(P)input_dict_var}[name]}
    if [ ! -n "$prefix" ]; then
        echo "BUG: no prefix specified"
    fi

    if [[ "$prefix" != "${prefix// /}" ]];then
        echo "name should not contain space"
        return -1
    fi

    local config_file=$_s_config_dir/$prefix
    for k v in ${(Pkv)input_dict_var};do
        echo $k":" $v >> $config_file
    done
}

_s_remove_record() {
    echo -n "Removing session"
    _s_list_commands $1
    _s_check_record_exist "$1" && rm -f $_s_config_dir/$1
}

_s_add_record() {
    local cmd
    local name
    local comment
    
    local prev=$(fc -ln -1)
    echo "Previous command is: $prev"
    vared -p "Enter command and press, use previous command if empty [ENTER] " -c cmd
    vared -p "Enter name and press [ENTER] " -c name
    vared -p "Enter comment and press [ENTER] " -c comment

    if [[ ! -n ${cmd// /} ]]; then
        cmd=$prev
    fi

    typeset -A a
    a[name]=$name
    a[comment]=$comment
    a[command]=$cmd
    _s_put_record a && _s_list_commands $name || echo "Failed to add command"
}

_s_execute() {
    local name=$1
    local options=${@:2}

    typeset -A names
    typeset -A records

    _s_check_record_exist $name || return -1
    _s_read_single_record names records "$name"

    typeset -A dict
    _s_convert_record names records dict "$name"

    echo Executing: ${dict[comment]} ${dict[command]}

    local cmd=${dict[command]}

    if [[ "$options" == "-nohup" ]]; then
        eval "nohup ${cmd} > ${name}.out &"
        tail -f ${name}.out
    else
        eval "${cmd}"
    fi
}

_s_main() {
    local editor=vim
    if [[ -n $EDITOR ]];then
        if command -v $EDITOR > /dev/null; then
            editor=$EDITOR
        fi
    fi


    if [ ! -d $_s_config_dir ]; then
        mkdir -p $_s_config_dir
    fi

    if (( $# == 0 ));then
        _s_list_commands
        return $?
    fi

    local cmd=$1
    if [[ $cmd == -* ]]; then
        shift
    fi

    case $cmd in
        -list)
            _s_list_commands ${(s.,.)1}
            ;;
        -edit)
            for i in ${(s.,.)1}; do
                _s_edit_session $i
            done
            ;;
        -add)
            _s_add_record
            ;;
        -remove)
            for i in ${(s.,.)1}; do
                _s_remove_record $i
            done
            ;;
        *)
            for i in ${(s.,.)1}; do
                _s_execute $i ${@:2}
            done
            ;;
    esac
}

_s_completion_main() {
    local _s_config_dir=~/.cache/ZshSessionManager
    _arguments '-list[list commands]:List Commands:->list' \
        '-remove[remove commands]:Remove Command:->list' \
        '-edit[edit commands]:Remove Command:->list' \
        '-add[add command]:Remove Command:->list'

    typeset -A names
    typeset -A records
    typeset -A dict

    typeset -a list
    _s_read_records names records
    for name in ${(k)names};do
        _s_convert_record names records dict $name

        local comment=${dict[comment]}
        list+="$name""[$comment]"
    done
    if [[ ${#list} != 0 ]];then
        _values -s ',' "description" ${list[@]}
    fi
}

_s() {
    local _s_config_dir=~/.cache/ZshSessionManager

    local sub=$1
    shift
    case $sub in
        __s_completion)
            _s_completion_main $@
            ;;
        __s_main)
            _s_main $@
            ;;
    esac
}

s() {
    _s __s_main $@
}

_s_completion_entry() {
    _s __s_completion $@
}

compdef _s_completion_entry s
