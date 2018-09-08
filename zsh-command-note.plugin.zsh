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
        local attr_val=$arr[2]

        eval $ret_names"[$name]"+=\"$attr_key \"
        eval $ret_records"[$name-$attr_key]"=\"$attr_val\"
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
        eval $output_var"[$attr]="${${(P)records_var}[$key]}
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
        echo "    "$k"\t\t->\t"$v
    done
}

_s_list_session() {
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

    local config_file=$_s_config_dir/$prefix
    for k v in ${(Pkv)input_dict_var};do
        echo $k":" $v >> $config_file
    done
}

_s_remove_record() {
    echo -n "Removing session"
    _s_list_session $1
    _s_check_record_exist "$1" && rm -f $_s_config_dir/$1
}

_s_add_record() {
    local cmd
    local name
    local comment
    echo -n "Enter command and press [ENTER] "
    read cmd
    echo -n "Enter name and press [ENTER] "
    read name
    echo -n "Enter comment and press [ENTER] "
    read comment

    typeset -A a
    a[name]=$name
    a[comment]=$comment
    a[command]=$cmd
    _s_put_record a
}

_s_execute() {
    local name=$1

    typeset -A names
    typeset -A records

    echo $name
    _s_read_single_record names records "$name"

    typeset -A dict
    _s_convert_record names records dict "$name"

    echo Executing: ${dict[name]}
    ${dict[name]}
}

_s_main() {
    local _s_config_dir=~/.cache/ZshSessionManager
    local editor=vim
    if [[ -n $EDITOR ]];then
        if command -v $EDITOR; then
            editor=$EDITOR
        fi
    fi


    if [ ! -d $_s_config_dir ]; then
        mkdir -p $_s_config_dir
    fi

    if (( $# == 0 ));then
        _s_list_session
        return $?
    fi

    local cmd=$1
    if [[ $cmd == -* ]]; then
        shift
    fi

    case $cmd in
        -list)
            _s_list_session $@
            ;;
        -edit)
            for i in $@; do
                _s_edit_session $@
            done
            ;;
        -add)
            _s_add_record
            ;;
        -remove)
            _s_remove_record $@
            ;;
        *)
            _s_execute $@
            ;;
    esac
}

compdef s_main s

alias s="_s_main "