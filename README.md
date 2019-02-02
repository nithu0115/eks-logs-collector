### <span style="font-family: times, serif; font-size:16pt; font-style:italic;"> EKS Logs Collector 

<span style="font-family: calibri, Garamond, 'Comic Sans MS' ;">This project was created to collect Amazon EKS log files and OS logs for troubleshooting Amazon EKS customer support cases.</span>

#### Usage
Run this project as the root user:
```
curl -O https://raw.githubusercontent.com/nithu0115/eks-logs-collector/master/eks-log-collector.sh
sudo bash eks-log-collector.sh
```

Confirm if the tarball file was successfully created (it can be .tgz or .tar.gz)

#### Retrieving the logs
Download the tarball using your favourite Secure Copy tool.

#### Example output
The project can be used in normal or enable_debug(**Caution: enable_debug will prompt to confirm if we can restart Docker daemo which would kill running containers**).

```
# sudo bash eks-log-collector.sh --help
USAGE: eks-log-collector --mode=collect|enable_debug
       eks-log-collector --help

OPTIONS:
     --mode  Sets the desired mode of the script. For more information,
             see the MODES section.
     --help  Show this help message.

MODES:
     collect        Gathers basic operating system, Docker daemon, and Amazon
                    EKS related config files and logs. This is the default mode.
     enable_debug   Enables debug mode for the Docker daemon
```
#### Example output in normal mode
The following output shows this project running in normal mode.

```
sudo bash eks-log-collector.sh

	This is version 0.0.4. New versions can be found at https://github.com/awslabs/amazon-eks-ami

Trying to collect common operating system logs... 
Trying to collect kernel logs... 
Trying to collect mount points and volume information... 
Trying to collect SELinux status... 
Trying to collect iptables information... 
Trying to collect installed packages... 
Trying to collect active system services... 
Trying to collect Docker daemon information... 
Trying to collect kubelet information... 
Trying to collect L-IPAMD information... 
Trying to collect sysctls information... sysctl: reading key "net.ipv6.conf.all.stable_secret"
sysctl: reading key "net.ipv6.conf.default.stable_secret"
sysctl: reading key "net.ipv6.conf.docker0.stable_secret"
sysctl: reading key "net.ipv6.conf.eni0ba57e14be5.stable_secret"
sysctl: reading key "net.ipv6.conf.eni1991d8b7bf7.stable_secret"
sysctl: reading key "net.ipv6.conf.eni2d6184bb26d.stable_secret"
sysctl: reading key "net.ipv6.conf.eni45836037bdd.stable_secret"
sysctl: reading key "net.ipv6.conf.eni51b59eb2eaf.stable_secret"
sysctl: reading key "net.ipv6.conf.eni619d920a18d.stable_secret"
sysctl: reading key "net.ipv6.conf.eni8ae8a1e4151.stable_secret"
sysctl: reading key "net.ipv6.conf.eni9a0fe9f8660.stable_secret"
sysctl: reading key "net.ipv6.conf.enib0576570462.stable_secret"
sysctl: reading key "net.ipv6.conf.enib8a2295c1df.stable_secret"
sysctl: reading key "net.ipv6.conf.enid2bb16ac515.stable_secret"
sysctl: reading key "net.ipv6.conf.enid5ec2fb4c28.stable_secret"
sysctl: reading key "net.ipv6.conf.enie617007cc63.stable_secret"
sysctl: reading key "net.ipv6.conf.eth0.stable_secret"
sysctl: reading key "net.ipv6.conf.eth1.stable_secret"
sysctl: reading key "net.ipv6.conf.eth2.stable_secret"
sysctl: reading key "net.ipv6.conf.lo.stable_secret"

Trying to collect networking infomation... 
Trying to collect CNI configuration information... 
Trying to collect running Docker containers and gather container data... 
Trying to collect Docker daemon logs... 
Trying to archive gathered information... 

	Done... your bundled logs are located in /opt/log-collector/eks_i-0717c9d54b6cfaa19_2019-02-02_0103-UTC_0.0.4.tar.gz
```


