#!/bin/bash -xe

rm -rf /etc/yum.repos.d/*

cat << EOF > /etc/yum.repos.d/nailgun.repo
[nailgun]
name=Nailgun Local Repo
baseurl=http://$(route -n | awk '/^0.0.0.0/ {print $2}'):${DOCKER_PORT}/repo/os/x86_64/
gpgcheck=0

[mos]
name=MOS Local Repo
baseurl=http://$(route -n | awk '/^0.0.0.0/ {print $2}'):${DOCKER_PORT}/mos-repo/
gpgcheck=0
EOF

for repo in ${EXTRA_RPM_REPOS}; do
  IFS=, read -a repo_args <<< "$repo"
  cat << EOF >> /etc/yum.repos.d/nailgun.repo

[extra-repo-${repo_args[0]}]
name=MOS Extra Repo ${repo_args[0]}
baseurl=http://$(route -n | awk '/^0.0.0.0/ {print $2}'):${DOCKER_PORT}/extra-repos/${repo_args[0]}
gpgcheck=0
EOF
done

yum clean expire-cache
yum update -y

#FIXME(dteselkin): install the packages below explicitely to
#                  fix their dependenceis BEFORE puppet run
packages="python-fuelclient postgresql-libs python-editor python-unicodecsv "
packages+="python-saharaclient python-muranoclient python-cliff"
echo $packages | xargs -n1 yum install -y

sed -i 's/^\(argparse.*\)/#\1/' /usr/lib/python2.7/site-packages/*egg-info/requires.txt


systemctl daemon-reload
puppet apply --debug --verbose --color false --detailed-exitcodes \
  /etc/puppet/modules/nailgun/examples/ostf-only.pp || [[ $? == 2 ]]


cat << EOF > /etc/yum.repos.d/nailgun.repo
[nailgun]
name=Nailgun Local Repo
baseurl=file:/var/www/nailgun/centos/x86_64
gpgcheck=0

[mos]
name=MOS Local Repo
baseurl=file:/var/www/nailgun/mos-centos/x86_64
gpgcheck=0
EOF

yum clean all


systemctl enable start-container.service
