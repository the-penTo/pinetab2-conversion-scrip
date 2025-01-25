#!/bin/sh

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

# check internet connection
check_internet()
{
  tool='curl'
  tool_opts='-s --connect-timeout 8'
  if ! $tool $tool_opts https://blackarch.org/ > /dev/null 2>&1; then
    err "You don't have an Internet connection!"
  fi
  return $SUCCESS
}

# check priv2
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

# retrieve armitage from the internet
fetch_armitage()
{
 wget-O /tmp/armitage.tgz https://web.archive.org/web/20160610041827if_/http://www.fastandeasyhacking.com/download/armitage150813.tgz
}

#untar armitage
untar_armitage()
{
  tar -xvzf /tmp/armitage.tgz
}

#move armitage to /opt/
move_armitage()
{
  sudo mv armitage /opt/
}

#link armitage 
link_armitage()
{
  sudo ln -s /opt/armitage/armitage /usr/local/bin/armitage
  sudo ln -s /opt/armitage/teamserver /usr/local/bin/teamserver
}

#amitage configuration
armitage_config()
{
  sh -c "echo java -jar /opt/armitage/armitage.jar \$\* > /usr/local/bin/armitage"
  sudo perl -pi -e 's/armitage.jar/\/opt\/armitage\/armitage.jar/g' /opt/armitage/teamserver
  sudo chown -R $USER:users /opt/armitage
}

#fetch burp suite
fetch_burp()
{
  wget -O /tmp/burpsuite_community_linux_arm64_v2021_11_2.sh https://portswigger-cdn.net/burp/releases/download?product=community&version=2025.1&type=LinuxArm64
}

#install burp suite
install_burp()
{
  sudo chmod +x /tmp/burpsuite_community_linux_arm64_v2021_11_2.sh
  sudo ./tmp/burpsuite_community_linux_arm64_v2021_11_2.sh
}

#armitage service start
armitage_service()
{
  cd /opt/armitage/
  ./msfrpcd -U msf -P test -f -S -a 127.0.0.1
}   

#start armitage
start_armitage()
{
  sh -c "armitage"
}

#install metasploit-framework & armitage
armitage_setup()
{
  step=$(load_status)
  case $step in 
    0)
    msg 'Downloading armitage...'
    check_internet
    fetch_armitage
    msg 'un-taring armitage...'
    untar_armitage
    msg 'Armitage un-tared successfully'
    check_priv2
    move_armitage
    msg 'Armitage moved to /opt/ successfully'
    link_armitage
    msg 'Armitage linked to /usr/local/bin/ successfully'
    armitage_config
    msg 'Armitage installed successfully'
    save_status 1
    ;;
    1)
    msg 'fetching burp suite...'
    check_internet
    fetch_burp
    msg 'Burp Suite downloaded successfully'
    install_burp
    msg 'Burp Suite installed successfully'
    save_status 2
    ;;
    2)
    msg 'Starting armitage service...'
    armitage_service
    msg 'Armitage service started successfully...'
    save_status 3
    ;;
    3)msg 'Starting armitage...'
    start_armitage  
}  

exit 0