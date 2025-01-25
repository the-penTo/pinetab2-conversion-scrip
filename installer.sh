#!/bin/sh
# strap.sh - setup BlackArch Linux keyring and install initial packages

ARCH=$(uname -m)
MIRROR_F='blackarch-mirrorlist'
GPG_CONF='/etc/pacman.d/gnupg/gpg.conf'
STATUS_FILE='/tmp/strap_status'

# simple error message wrapper
err()
{
  echo >&2 "$(tput bold; tput setaf 1)[-] ERROR: ${*}$(tput sgr0)"
  exit 1337
}

# simple warning message wrapper
warn()
{
  echo >&2 "$(tput bold; tput setaf 1)[!] WARNING: ${*}$(tput sgr0)"
}

# simple echo wrapper
msg()
{
  echo "$(tput bold; tput setaf 2)[+] ${*}$(tput sgr0)"
}

# check for root privilege
check_priv()
{
  if [ "$(id -u)" -ne 0 ]; then
    err "you must be root"
  fi
}

# save the current step to the status file
save_status()
{
  echo "$1" > "$STATUS_FILE"
}

# load the current step from the status file
load_status()
{
  if [ -f "$STATUS_FILE" ]; then
    cat "$STATUS_FILE"
  else
    echo "0"
  fi
}

# make a temporary directory and cd into
make_tmp_dir()
{
  tmp="$(mktemp -d /tmp/blackarch_strap.XXXXXXXX)"
  trap 'rm -rf $tmp' EXIT
  cd "$tmp" || err "Could not enter directory $tmp"
}

set_umask()
{
  OLD_UMASK=$(umask)
  umask 0022
  trap 'reset_umask' TERM
}

reset_umask()
{
  umask $OLD_UMASK
}

check_internet()
{
  tool='curl'
  tool_opts='-s --connect-timeout 8'
  if ! $tool $tool_opts https://blackarch.org/ > /dev/null 2>&1; then
    err "You don't have an Internet connection!"
  fi
  return $SUCCESS
}

# add necessary GPG options
add_gpg_opts()
{
  if ! grep -q 'allow-weak-key-signatures' $GPG_CONF; then
    echo 'allow-weak-key-signatures' >> $GPG_CONF
  fi
  return $SUCCESS
}

# retrieve the BlackArch Linux keyring
fetch_keyring()
{
  curl -s -O 'https://www.blackarch.org/keyring/blackarch-keyring.pkg.tar.zst'
  curl -s -O 'https://www.blackarch.org/keyring/blackarch-keyring.pkg.tar.zst.sig'
}

# verify the keyring signature
verify_keyring()
{
  if ! gpg --keyserver keyserver.ubuntu.com --recv-keys 4345771566D76038C7FEB43863EC0ADBEA87E4E3 > /dev/null 2>&1; then
    if ! gpg --keyserver hkps://keyserver.ubuntu.com:443 --recv-keys 4345771566D76038C7FEB43863EC0ADBEA87E4E3 > /dev/null 2>&1; then
      if ! gpg --keyserver hkp://pgp.mit.edu:80 --recv-keys 4345771566D76038C7FEB43863EC0ADBEA87E4E3 > /dev/null 2>&1; then
        err "could not verify the key. Please check: https://blackarch.org/faq.html"
      fi
    fi
  fi

  if ! gpg --keyserver-options no-auto-key-retrieve --with-fingerprint blackarch-keyring.pkg.tar.zst.sig > /dev/null 2>&1; then
    err "invalid keyring signature. please stop by https://matrix.to/#/#/BlackaArch:matrix.org"
  fi
}

# delete the signature files
delete_signature()
{
  if [ -f "blackarch-keyring.pkg.tar.zst.sig" ]; then
    rm blackarch-keyring.pkg.tar.zst.sig
  fi
}

# make sure /etc/pacman.d/gnupg is usable
check_pacman_gnupg()
{
  pacman-key --init
}

# install the keyring
install_keyring()
{
  if ! pacman --config /dev/null --noconfirm -U blackarch-keyring.pkg.tar.zst ; then
    err 'keyring installation failed'
  fi
  pacman-key --populate
}

# ask user for mirror
get_mirror()
{
  mirror_p="/etc/pacman.d"
  mirror_r="https://blackarch.org"
  msg "fetching new mirror list..."
  if ! curl -s "$mirror_r/$MIRROR_F" -o "$mirror_p/$MIRROR_F" ; then
    err "we couldn't fetch the mirror list from: $mirror_r/$MIRROR_F"
  fi
  msg "you can change the default mirror under $mirror_p/$MIRROR_F"
}

# update pacman.conf
update_pacman_conf()
{
  sed -i '/blackarch/{N;d}' /etc/pacman.conf
  cat >> "/etc/pacman.conf" << EOF
[blackarch]
Include = /etc/pacman.d/$MIRROR_F
EOF
}

# synchronize and update
pacman_update()
{
  if pacman -Syy; then
    return $SUCCESS
  fi
  warn "Synchronizing pacman has failed. Please try manually: pacman -Syy"
  return $FAILURE
}

pacman_upgrade()
{
  echo 'perform full system upgrade? (pacman -Su) [Yn]:'
  read conf < /dev/tty
  case "$conf" in
    ''|y|Y) pacman -Su ;;
    n|N) warn 'some blackarch packages may not work without an up-to-date system.' ;;
  esac
}

# setup blackarch linux
blackarch_setup()
{
  step=$(load_status)
  case $step in
    0)
      msg 'installing blackarch keyring...'
      check_priv
      set_umask
      make_tmp_dir
      check_internet
      add_gpg_opts
      fetch_keyring
      save_status 1
      reboot
      ;;
    1)
      delete_signature
      check_pacman_gnupg
      install_keyring
      save_status 2
      reboot
      ;;
    2)
      msg 'keyring installed successfully'
      if ! grep -q "\[blackarch\]" /etc/pacman.conf; then
        msg 'configuring pacman'
        get_mirror
        msg 'updating pacman.conf'
        update_pacman_conf
      fi
      msg 'updating package databases'
      pacman_update
      reset_umask
      msg 'installing blackarch-officials meta-package...'
      pacman -S --noconfirm --needed blackarch-officials
      msg 'BlackArch Linux is ready!'
      save_status 3
      ;;
    3)
      msg 'BlackArch Linux is already set up!'
      ;;
  esac
}

##blackarch_setup
#System update
pacman_update()
{
  if pacman -Syy; then
    return $SUCCESS
  fi
  warn "Synchronizing pacman has failed. Please try manually: pacman -Syy"
  return $FAILURE
}
# simple error message wrapper
error()
{
  echo >&2 "$(tput bold; tput setaf 1)[-] ERROR: ${*}$(tput sgr0)"
  sudo -i 
}

check_priv2()
{
  if [ "$(id -u)" -ne 0 ]; then 
      warn 'you must be root!'
      return $FAILURE
    fi
    else
      return $SUCCESS
    fi
}

# sudo
sudo()
{
    if check_priv2 == $SUCCESS; then
    else
      sudo -i       
    fi
}    
    return $FAILURE
    msg 'Successfully switched to root user'
    else
      err 'you must be root'
    fi
  fi
}
#install metasploit-framework & armitage
armitage_setup()
{
  step=$(load_status)
  case $step in 
    0)
    msg 'Downloading armitage...'
    check_internet
    wget-O /tmp/armitage.tgz https://web.archive.org/web/20160610041827if_/http://www.fastandeasyhacking.com/download/armitage150813.tgz
    msg 'un-taring armitage...'
    tar -xvzf /tmp/armitage.tgz
    msg 'Armitage un-tared successfully'
    check_priv2
    sudo mv armitage /opt/
    msg 'Armitage moved to /opt/ successfully'
    sudo ln -s /opt/armitage/armitage /usr/local/bin/armitage
    sudo ln -s /opt/armitage/teamserver /usr/local/bin/teamserver
    msg 'Armitage linked to /usr/local/bin/ successfully'
    sh -c "echo java -jar /opt/armitage/armitage.jar \$\* > /usr/local/bin/armitage"
    sudo perl -pi -e 's/armitage.jar/\/opt\/armitage\/armitage.jar/g' /opt/armitage/teamserver
    sudo chown -R $USER:users /opt/armitage
    msg 'Armitage installed successfully'
    save_status 1
    ;;
    1)cd /opt/armitage/
    msg 'Starting armitage service...'
    ./msfrpcd -U msf -P test -f -S -a 127.0.0.1
    msg 'Armitage service started successfully...'
    save_status 2
    ;;
    2)msg 'Starting armitage...'
    sh -c "armitage"    

    msg 'Burp Suite downloaded successfully'
    sudo chmod +x burpsuite_community_linux_arm64_v2021_11_2.sh
    msg 'Installing burp suite...'
    sudo ./burpsuite_community_linux_arm64_v2021_11_2.sh
    msg 'Burp Suite installed successfully'
    exit 0


}   
