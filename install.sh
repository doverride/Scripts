#!/bin/bash --
# -*- Shell -*-

# 1. gather info and check sanity

# try to do as much as possible here

# - can't be root

[[ $UID -ne 0 ]] || exit 192

# - have all unconditional commands?

[[ -x "/usr/bin/secon" ]] && [[ -x "/usr/bin/sed" ]] && [[ -x "/usr/bin/grep" ]] \
    && [[ -x "/usr/bin/awk" ]] && [[ -x "/usr/bin/id" ]] && [[ -x "/usr/bin/seq" ]] \
    && [[ -x "/usr/bin/curl" ]] && [[ -x "/usr/bin/cut" ]] && [[ -x "/usr/bin/getconf" ]] \
    && [[ -x "/usr/bin/su" ]] && [[ -x "/usr/share/sandbox/sandboxX.sh" ]] && [[ -x "/usr/sbin/setfiles" ]] \
    && [[ -x "/usr/bin/mktemp" ]] && [[ -h "/usr/sbin/restorecon" ]] && [[ -x "/usr/bin/tar" ]] \
    && [[ -x "/usr/bin/rm" ]] && [[ -x "/usr/bin/chmod" ]] && [[ -x "/usr/bin/mkdir" ]] \
    && [[ -x "/usr/bin/make" ]] && [[ -x "/usr/bin/mv" ]] || exit 192

# - support this distro?

declare -a SUPPORTED_CPE_NAMES[0]=cpe:/o:fedoraproject:fedora:20

. /etc/os-release > /dev/null 2>&1 || exit 192

declare MYCPENAME

for cpe in ${!SUPPORTED_CPE_NAMES[*]}; do
    if [[ ${SUPPORTED_CPE_NAMES[cpe]} == $CPE_NAME ]]; then
        MYCPENAME=${SUPPORTED_CPE_NAMES[cpe]}
    fi
done

[[ -n $MYCPENAME ]] || exit 192

# - support context of user?

declare -a SUPPORTED_ROLE_TYPE_TUPLES[0]=unconfined_r:unconfined_t

declare MYROLETYPETUPLE

for roletypetuple in ${!SUPPORTED_ROLE_TYPE_TUPLES[*]}; do
if [[ ${SUPPORTED_ROLE_TYPE_TUPLES[roletype]} == $(/usr/bin/secon --role):$(/usr/bin/secon --type) ]]; then
        MYROLETYPETUPLE=${SUPPORTED_ROLE_TYPE_TUPLES[roletypetuple]}
    fi
done

[[ -n $MYROLETYPETUPLE ]] || exit 192

# - support categories (currently only group of two)

declare -a SUPPORTED_CATEGORIES[0]=555
declare -a SUPPORTED_CATEGORIES[1]=666

declare -a MYCATEGORIES=()
declare -a MATCHED_CATEGORIES=()

declare IFS=':'

while read user role type sensitivities categories; do
    ## do we have categories at all?
    if [[ -z $categories ]]; then
        exit 192

    ## group, range or single?
    elif [ $(printf "%s\n" "$categories" | /usr/bin/grep "\,") ]; then

        ## if there is a comma separator in there then were dealing with group
        declare IFS=','

        for category in $categories; do
            MYCATEGORIES+=($(printf "%s\n" "$category" | /usr/bin/sed 's/c//'))
        done

        unset IFS

    elif [ $(printf "%s\n" "$categories" | /usr/bin/grep "\.") ]; then

        ## if there is a period in there then were dealing with a range
        declare IFS='.'

        declare -i LOW=$(printf "%s\n" "$categories" | /usr/bin/awk -F "." '{ print $1 }' | /usr/bin/sed 's/c//')
        declare -i HIGH=$(printf "%s\n" "$categories" | /usr/bin/awk -F "." '{ print $2 }' | /usr/bin/sed 's/c//')

        unset IFS

        for category in $(/usr/bin/seq $LOW $HIGH); do
            MYCATEGORIES+=($category)
        done

    else

        unset IFS

        ## must be single then
        for category in $categories; do
            MYCATEGORIES+=($(printf "%s\n" "$category" | /usr/bin/sed 's/c//'))
        done
    fi
done < <(printf "%s\n" "$(/usr/bin/id -Z)")

for supportedcategory in ${!SUPPORTED_CATEGORIES[*]}; do
    for mycategory in ${!MYCATEGORIES[*]}; do
        if (( ${SUPPORTED_CATEGORIES[supportedcategory]} == ${MYCATEGORIES[mycategory]} )); then
            MATCHED_CATEGORIES+=(${SUPPORTED_CATEGORIES[supportedcategory]})
        fi
    done
done

if [[ ${MATCHED_CATEGORIES[*]} != ${SUPPORTED_CATEGORIES[*]} ]]; then
    exit 192
fi

# - support version available

declare TOR_BROWSER_URL=https://www.torproject.org/dist/torbrowser/

declare -a SUPPORTED_TOR_BROWSER_VERSIONS[0]=3.5.3

declare -a TOR_BROWSER_VERSIONS=()
declare -a MATCHED_TOR_BROWSER_VERSIONS=()

for version in $(/usr/bin/curl -s "$TOR_BROWSER_URL" | /usr/bin/grep "^<img" | /usr/bin/awk -F "\"" '{ print $6 }' | /usr/bin/cut -d/ -f1); do
    TOR_BROWSER_VERSIONS+=($version)
done

for torbrowserversion in ${!TOR_BROWSER_VERSIONS[*]}; do
    for supportedtorbrowserversion in ${!SUPPORTED_TOR_BROWSER_VERSIONS[*]}; do
        if [[ ${TOR_BROWSER_VERSIONS[torbrowserversion]} == ${SUPPORTED_TOR_BROWSER_VERSIONS[supportedtorbrowserversion]} ]]; then
            MATCHED_TOR_BROWSER_VERSIONS+=(${SUPPORTED_TOR_BROWSER_VERSIONS[supportedtorbrowserversion]})
        fi
    done
done

[[ -n ${MATCHED_TOR_BROWSER_VERSIONS[*]} ]] || return 192

# - support bit length?

declare KERNEL_BIT_LENGTH

KERNEL_BIT_LENGTH=$(/usr/bin/getconf LONG_BIT) || return 192

# - support language

declare -a LANGUAGES=()

declare PREFERRED_LANGUAGE=$(printf "%s\n" "$LANG" | /usr/bin/awk -F "." '{ print $1 }' | /usr/bin/sed 's/_/-/')

declare MATCHED_LANGUAGE

for language in $(/usr/bin/curl --silent $TOR_BROWSER_URL/${MATCHED_TOR_BROWSER_VERSIONS[0]}/ \
    | /usr/bin/grep linux$KERNEL_BIT_LENGTH | /usr/bin/awk -F "\"" '{ print $6 }' \
    | /usr/bin/grep xz$ | /usr/bin/awk -F "_" '{ print $2 }' | /usr/bin/awk -F "." '{ print $1 }'); do
    LANGUAGES+=($language)
done

for language in ${!LANGUAGES[*]}; do
    if [[ ${LANGUAGES[language]} == $PREFERRED_LANGUAGE ]]; then
        MATCHED_LANGUAGE=${LANGUAGES[language]}
    fi
done

if [[ -z $MATCHED_LANGUAGE ]]; then
    MATCHED_LANGUAGE=en-US
fi

# - do integrity check?

declare TOR_BROWSER_INTEGRITY_CHECK=1

if [[ -n $TOR_BROWSER_INTEGRITY_CHECK ]]; then
    [[ -x "/usr/bin/sha256sum" ]] && [[ -x "/usr/bin/gpg2" ]] || exit 192
fi

# - have workspace

declare WORKSPACE

if [[ -w $XDG_RUNTIME_DIR ]]; then
    WORKSPACE=$XDG_RUNTIME_DIR
elif [[ -w $HOME ]]; then
    WORKSPACE=$HOME
elif [[ -w /tmp ]]; then
    WORKSPACE=/tmp
elif [[ -w /var/tmp ]]; then
    WORKSPACE=/var/tmp
elif [[ -w /dev/shm ]]; then
    WORKSPACE=/dev/shm
else
    exit 192
fi

# - have policy devel

[[ -r "/usr/share/selinux/devel/Makefile" ]] \
    && [[ -r "/usr/share/selinux/devel/include/Makefile" ]] \
    || exit 192

# - determine where to install desktop file and script (*)

if [[ ! -w $HOME/.local/share/applications ]]; then
    exit 192
fi

declare -a PATHS=()

declare -a SUPPORTED_PATHS[0]=$HOME/.local/bin
declare -a SUPPORTED_PATHS[1]=$HOME/bin
declare -a SUPPORTED_PATHS[2]=$HOME/.local/Bin
declare -a SUPPORTED_PATHS[3]=$HOME/Bin

declare IFS=':'

for mypath in $PATH; do
    PATHS+=($mypath)
done

unset IFS

for mypath in ${!PATHS[*]}; do
    for supportedpath in ${!SUPPORTED_PATHS[*]}; do
        if [[ ${PATHS[mypath]} == ${SUPPORTED_PATHS[supportedpath]} ]]; then
            MATCHED_PATHS+=(${SUPPORTED_PATHS[supportedpath]})
        fi
    done
done

[[ -n ${MATCHED_PATHS[*]} ]] || exit 192

# 2. gather info and check sanity (needs root)

/usr/bin/su -c '[[ $UID -eq 0 ]] \
    && [[ -w "/opt" ]] \
    && [[ -x "/usr/sbin/semodule" ]] \
    && /usr/sbin/semodule -l | grep ^sandboxX >/dev/null' || exit 192

# 3. do stuff

# - get package

declare TEMPORARY=$(/usr/bin/mktemp -d $WORKSPACE/mytb-XXXXX )

trap '/usr/bin/rm -rf $TEMPORARY > /dev/null 2>&1' EXIT

/usr/bin/curl --silent\
    $TOR_BROWSER_URL/${MATCHED_TOR_BROWSER_VERSIONS[0]}/tor-browser-linux$KERNEL_BIT_LENGTH-${MATCHED_TOR_BROWSER_VERSIONS[0]}_$MATCHED_LANGUAGE.tar.xz \
    -o $TEMPORARY/tor-browser-linux$KERNEL_BIT_LENGTH-${MATCHED_TOR_BROWSER_VERSIONS[0]}_$MATCHED_LANGUAGE.tar.xz || exit 192

[[ -n $TOR_BROWSER_INTEGRITY_CHECK ]] \
    && /usr/bin/curl --silent \
    $TOR_BROWSER_URL/${MATCHED_TOR_BROWSER_VERSIONS[0]}/tor-browser-linux$KERNEL_BIT_LENGTH-${MATCHED_TOR_BROWSER_VERSIONS[0]}_$MATCHED_LANGUAGE.tar.xz.asc \
    -o $TEMPORARY/tor-browser-linux$KERNEL_BIT_LENGTH-${MATCHED_TOR_BROWSER_VERSIONS[0]}_$MATCHED_LANGUAGE.tar.xz.asc \
    && /usr/bin/curl --silent \
    $TOR_BROWSER_URL/${MATCHED_TOR_BROWSER_VERSIONS[0]}/sha256sums.txt \
    -o $TEMPORARY/sha256sums.txt \
    && /usr/bin/curl --silent \
    $TOR_BROWSER_URL/${MATCHED_TOR_BROWSER_VERSIONS[0]}/sha256sums.txt-gk.asc \
    -o $TEMPORARY/sha256sums.txt-gk.asc || exit 192

# - optionally check integrity

if [[ -n $TOR_BROWSER_INTEGRITY_CHECK ]]; then
    /usr/bin/gpg2 --homedir $TEMPORARY/.gnupg --keyserver x-hkp://pool.sks-keyservers.net --recv-keys 0x416F061063FEE659 > /dev/null 2>&1 \
        && /usr/bin/gpg2 --homedir $TEMPORARY/.gnupg --keyserver x-hkp://pool.sks-keyservers.net --recv-keys 0x94373aa94b7c3223 > /dev/null 2>&1 || exit 192

    /usr/bin/gpg2 --homedir $TEMPORARY/.gnupg --verify $TEMPORARY/sha256sums.txt-gk.asc $TEMPORARY/sha256sums.txt > /dev/null 2>&1 || exit 192
    /usr/bin/gpg2 --homedir $TEMPORARY/.gnupg --verify $TEMPORARY/tor-browser-linux$KERNEL_BIT_LENGTH-${MATCHED_TOR_BROWSER_VERSIONS[0]}_$MATCHED_LANGUAGE.tar.xz.asc $TEMPORARY/tor-browser-linux$KERNEL_BIT_LENGTH-${MATCHED_TOR_BROWSER_VERSIONS[0]}_$MATCHED_LANGUAGE.tar.xz > /dev/null 2>&1 || exit 192

    THEIRSHA256SUM=$(/usr/bin/grep tor-browser-linux$KERNEL_BIT_LENGTH-${MATCHED_TOR_BROWSER_VERSIONS[0]}_$MATCHED_LANGUAGE.tar.xz $TEMPORARY/sha256sums.txt | /usr/bin/awk -F " " '{ print $1 }') || exit 192
    OURSHA256SUM=$(/usr/bin/sha256sum $TEMPORARY/tor-browser-linux$KERNEL_BIT_LENGTH-${MATCHED_TOR_BROWSER_VERSIONS[0]}_$MATCHED_LANGUAGE.tar.xz | /usr/bin/awk -F " " '{ print $1 }') || exit 192

    if [[ $THEIRSHA256SUM != $OURSHA256SUM ]]; then
        exit 192
    fi
fi

# - extract package in workdir

/usr/bin/tar -xf $TEMPORARY/tor-browser-linux$KERNEL_BIT_LENGTH-${MATCHED_TOR_BROWSER_VERSIONS[0]}_$MATCHED_LANGUAGE.tar.xz -C $TEMPORARY || exit 192

# do we have (sandbox) headers?

[[ -f "/usr/share/selinux/devel/include/contrib/sandboxX.if" ]] || exit 192

# compile policy module

/usr/bin/mkdir $TEMPORARY/module || exit 192

/usr/bin/cat > $TEMPORARY/module/tor-browser-sandbox.te <<EOF
policy_module(tor-browser-sandbox, 1.0.0)

type tor_browser_sandbox_conf_t;
files_type(tor_browser_sandbox_conf_t)

optional_policy(\`

gen_require(\`
attribute sandbox_web_type;
type user_home_t;
role $(/usr/bin/id -Z | /usr/bin/awk -F ":" '{ print $2 }');
')

sandbox_x_domain_template(torbrowsersandbox)

role $(/usr/bin/id -Z | /usr/bin/awk -F ":" '{ print $2 }') types { torbrowsersandbox_t torbrowsersandbox_client_t };

typeattribute torbrowsersandbox_client_t sandbox_web_type;
selinux_get_fs_mount(torbrowsersandbox_client_t)
auth_use_nsswitch(torbrowsersandbox_client_t)
logging_send_syslog_msg(torbrowsersandbox_client_t)

allow torbrowsersandbox_client_t self:process setrlimit;

corenet_tcp_bind_tor_port(torbrowsersandbox_client_t)
corenet_tcp_bind_generic_node(torbrowsersandbox_client_t)

corenet_tcp_connect_websm_port(torbrowsersandbox_client_t)
corenet_tcp_connect_pop_port(torbrowsersandbox_client_t)

allow torbrowsersandbox_client_t tor_browser_sandbox_conf_t:file { read_file_perms rename };
')
EOF

/usr/bin/cat > $TEMPORARY/module/tor-browser-sandbox.fc <<EOF
/opt/tor-browser_$MATCHED_LANGUAGE -d system_u:object_r:sandbox_file_t:s0:c${SUPPORTED_CATEGORIES[0]},c${SUPPORTED_CATEGORIES[1]}
/opt/tor-browser_$MATCHED_LANGUAGE/\.cache(/.*)? <<none>>
/opt/tor-browser_$MATCHED_LANGUAGE/\.config(/.*)? <<none>>
/opt/tor-browser_$MATCHED_LANGUAGE/\.esd_auth -- <<none>>
/opt/tor-browser_$MATCHED_LANGUAGE/Browser -d system_u:object_r:sandbox_file_t:s0:c${SUPPORTED_CATEGORIES[0]},c${SUPPORTED_CATEGORIES[1]}
/opt/tor-browser_$MATCHED_LANGUAGE/Browser/browser/components/libbrowsercomps\.so -- system_u:object_r:lib_t:s0
/opt/tor-browser_$MATCHED_LANGUAGE/Data/Browser/profile\.default -d system_u:object_r:sandbox_file_t:s0:c${SUPPORTED_CATEGORIES[0]},c${SUPPORTED_CATEGORIES[1]}
/opt/tor-browser_$MATCHED_LANGUAGE/Data/Browser/profile\.default/bookmarks\.html -- system_u:object_r:usr_t:s0
/opt/tor-browser_$MATCHED_LANGUAGE/Data/Browser/profile\.default/extensions(/.*)? system_u:object_r:usr_t:s0
/opt/tor-browser_$MATCHED_LANGUAGE/Data/Browser/profile\.default/preferences -d system_u:object_r:sandbox_file_t:s0:c${SUPPORTED_CATEGORIES[0]},c${SUPPORTED_CATEGORIES[1]}
/opt/tor-browser_$MATCHED_LANGUAGE/Data/Browser/profile\.default/preferences/extension-overrides\.js -- system_u:object_r:usr_t:s0
/opt/tor-browser_$MATCHED_LANGUAGE/Data/Browser/profile\.default/.* <<none>>
/opt/tor-browser_$MATCHED_LANGUAGE/Desktop(/.*)? <<none>>
/opt/tor-browser_$MATCHED_LANGUAGE/Data/Tor/torrc -- system_u:object_r:tor_browser_sandbox_conf_t:s0
/opt/tor-browser_$MATCHED_LANGUAGE/Data/Tor/torrc\.orig\.1 -- <<none>>
/opt/tor-browser_$MATCHED_LANGUAGE/Data/Tor/torrc\.tmp -- <<none>>
/opt/tor-browser_$MATCHED_LANGUAGE/Data/Tor/torrc-defaults -- system_u:object_r:tor_browser_sandbox_conf_t:s0
/opt/tor-browser_$MATCHED_LANGUAGE/Data/Tor -d system_u:object_r:sandbox_file_t:s0:c${SUPPORTED_CATEGORIES[0]},c${SUPPORTED_CATEGORIES[1]}
/opt/tor-browser_$MATCHED_LANGUAGE/Data/Tor/.* <<none>>
/opt/tor-browser_$MATCHED_LANGUAGE/Docs/sources/versions -- system_u:object_r:bin_t:s0
/opt/tor-browser_$MATCHED_LANGUAGE/start-tor-browser -- system_u:object_r:bin_t:s0
/opt/tor-browser_$MATCHED_LANGUAGE/Tor/libcrypto\.so\.1\.0\.0 -- system_u:object_r:lib_t:s0
/opt/tor-browser_$MATCHED_LANGUAGE/Tor/libevent-2\.0\.so\.5 -- system_u:object_r:lib_t:s0
/opt/tor-browser_$MATCHED_LANGUAGE/Tor/libssl\.so\.1\.0\.0 -- system_u:object_r:lib_t:s0
/opt/tor-browser_$MATCHED_LANGUAGE/Tor/tor -- system_u:object_r:bin_t:s0
/opt/tor-browser_$MATCHED_LANGUAGE/Browser/firefox -- system_u:object_r:bin_t:s0
/opt/tor-browser_$MATCHED_LANGUAGE/Browser/libfreebl3\.so -- system_u:object_r:lib_t:s0
/opt/tor-browser_$MATCHED_LANGUAGE/Browser/libmozalloc\.so -- system_u:object_r:lib_t:s0
/opt/tor-browser_$MATCHED_LANGUAGE/Browser/libmozsqlite3\.so -- system_u:object_r:lib_t:s0
/opt/tor-browser_$MATCHED_LANGUAGE/Browser/libnspr4\.so -- system_u:object_r:lib_t:s0
/opt/tor-browser_$MATCHED_LANGUAGE/Browser/libnss3\.so -- system_u:object_r:lib_t:s0
/opt/tor-browser_$MATCHED_LANGUAGE/Browser/libnssckbi\.so -- system_u:object_r:lib_t:s0
/opt/tor-browser_$MATCHED_LANGUAGE/Browser/libnssdbm3\.so -- system_u:object_r:lib_t:s0
/opt/tor-browser_$MATCHED_LANGUAGE/Browser/libnssutil3\.so -- system_u:object_r:lib_t:s0
/opt/tor-browser_$MATCHED_LANGUAGE/Browser/libplc4\.so -- system_u:object_r:lib_t:s0
/opt/tor-browser_$MATCHED_LANGUAGE/Browser/libplds4\.so -- system_u:object_r:lib_t:s0
/opt/tor-browser_$MATCHED_LANGUAGE/Browser/libsmime3\.so -- system_u:object_r:lib_t:s0
/opt/tor-browser_$MATCHED_LANGUAGE/Browser/libsoftokn3\.so -- system_u:object_r:lib_t:s0
/opt/tor-browser_$MATCHED_LANGUAGE/Browser/libssl3\.so -- system_u:object_r:lib_t:s0
/opt/tor-browser_$MATCHED_LANGUAGE/Browser/libxul\.so -- system_u:object_r:lib_t:s0
/opt/tor-browser_$MATCHED_LANGUAGE/Browser/mozilla-xremote-client -- system_u:object_r:bin_t:s0
/opt/tor-browser_$MATCHED_LANGUAGE/Browser/plugin-container -- system_u:object_r:bin_t:s0
/opt/tor-browser_$MATCHED_LANGUAGE/Browser/run-mozilla\.sh -- system_u:object_r:bin_t:s0
/opt/tor-browser_$MATCHED_LANGUAGE/Browser/webapprt-stub -- system_u:object_r:bin_t:s0
/opt/tor-browser_$MATCHED_LANGUAGE/Browser/components/libdbusservice\.so -- system_u:object_r:lib_t:s0
/opt/tor-browser_$MATCHED_LANGUAGE/Browser/components/libmozgnome\.so -- system_u:object_r:lib_t:s0
EOF

/usr/bin/make -f /usr/share/selinux/devel/Makefile tor-browser-sandbox.pp -C $TEMPORARY/module/ > /dev/null 2>&1

# - install desktop file and script (*)

if [[ -f "$HOME/.local/share/applications/tor-browser-sandbox.desktop" ]]; then
    exit 192
else
    /usr/bin/cat > $HOME/.local/share/applications/tor-browser-sandbox.desktop <<EOF
[Desktop Entry]
Name=Tor Browser Sandbox
Exec=${MATCHED_PATHS[0]}/tor-browser-sandbox
Type=Application
Icon=/opt/tor-browser_$MATCHED_LANGUAGE/Browser/browser/icons/mozicon128.png
Categories=Application;
EOF
fi

if [[ -f "${MATCHED_PATHS[0]}/tor-browser-sandbox" ]]; then
    exit 192
else
    if [[ ! -d "${MATCHED_PATHS[0]}" ]]; then
        /usr/bin/mkdir -p "${MATCHED_PATHS[0]}"
    fi

    /usr/bin/cat > ${MATCHED_PATHS[0]}/tor-browser-sandbox <<EOF
#!/bin/bash --

[[ -x "/usr/bin/openssl" ]] && [[ -x "/usr/bin/mkdir" ]] && [[ -x "/usr/bin/sandbox" ]] \
    && [[ -x "/usr/bin/rm" ]] && [[ -x "/usr/bin/id" ]] || exit 192

not_here ()
{
    if [[ -x "/usr/bin/zenity" ]]; then
        /usr/bin/zenity --error --text="Could not find /opt/tor-browser_$MATCHED_LANGUAGE/start-tor-browser"
    fi

    exit 192
}

[[ -x "/opt/tor-browser_$MATCHED_LANGUAGE/start-tor-browser" ]] || not_here

SUFFIX=\$(/usr/bin/openssl rand -base64 5)

trap '/usr/bin/rm -rf /tmp/tor-browser-sandbox-home-\$SUFFIX && /usr/bin/rm -rf /tmp/tor-browser-sandbox-temp-\$SUFFIX > /dev/null 2>&1' EXIT

/usr/bin/mkdir -m 0700 -Z $(/usr/bin/id -Z | /usr/bin/awk -F ":" '{ print $1 }'):object_r:sandbox_file_t:s0:c${SUPPORTED_CATEGORIES[0]},c${SUPPORTED_CATEGORIES[1]} "/tmp/tor-browser-sandbox-home-\$SUFFIX" "/tmp/tor-browser-sandbox-temp-\$SUFFIX" || exit 192
/usr/bin/sandbox -X -M -l s0:c${SUPPORTED_CATEGORIES[0]},c${SUPPORTED_CATEGORIES[1]} -H /tmp/tor-browser-sandbox-home-\${SUFFIX} -T /tmp/tor-browser-sandbox-temp-\${SUFFIX} -t torbrowsersandbox_t /opt/tor-browser_$MATCHED_LANGUAGE/start-tor-browser || exit 192

#EOF
EOF

/usr/bin/chmod +x ${MATCHED_PATHS[0]}/tor-browser-sandbox || exit 192
fi

# 4. do stuff (needs root)

/usr/bin/cat > $TEMPORARY/root <<EOF
#!/bin/bash --
[[ -x "/usr/bin/whoami" ]] \
&& [[ -x "/usr/bin/mv" ]] \
&& [[ -x "/usr/sbin/semodule" ]] \
&& [[ -h "/usr/sbin/restorecon" ]] \
&& [[ -x "/usr/sbin/semanage" ]] \
&& [[ -x "/usr/sbin/setfiles" ]] || exit 192
if [[ "\$(/usr/bin/whoami)" == "root" ]]; then
/usr/bin/mv $TEMPORARY/tor-browser_$MATCHED_LANGUAGE /opt/ \
&& /usr/sbin/semodule -i $TEMPORARY/module/tor-browser-sandbox.pp \
&& /usr/sbin/semanage port -a -t tor_port_t -p tcp 9151 \
&& /usr/sbin/restorecon -R -F /opt/tor-browser_$MATCHED_LANGUAGE || exit 192
else
    exit 192
fi
#EOF
EOF

/usr/bin/chmod +x $TEMPORARY/root
/usr/bin/su -c $TEMPORARY/root

#EOF
