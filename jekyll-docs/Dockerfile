# Copyright (c) 2012-2016 Codenvy, S.A.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
#
# Contributors:
#   Tyler Jewell - Initial implementation
#
FROM jekyll/jekyll:3.2.1

ENV UNISON_VERSION=2.40.102

RUN apk update && apk upgrade && \
    apk add build-base curl alpine-sdk openssh bash nano ncurses-dev  && \
    cd /etc/apk/keys && curl -OL http://www.cl.cam.ac.uk/~avsm2/alpine-ocaml/x86_64/anil@recoil.org-5687cc79.rsa.pub && \
    apk add ocaml --update-cache --repository http://www.cl.cam.ac.uk/~avsm2/alpine-ocaml/3.4 --allow-untrusted && \
    curl -L https://www.seas.upenn.edu/~bcpierce/unison/download/releases/unison-$UNISON_VERSION/unison-$UNISON_VERSION.tar.gz | tar xzv -C /tmp && \
    cd /tmp/unison-$UNISON_VERSION && \
    make && \
    cp /tmp/unison-$UNISON_VERSION/unison /usr/local/bin && \
    echo "%sudo ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
    chown -R jekyll:jekyll /srv/jekyll
    
RUN apk del ocaml curl build-base && \
    echo "ChallengeResponseAuthentication no" >> /etc/ssh/sshd_config && \
    echo "PasswordAuthentication no" >> /etc/ssh/sshd_config && \
    echo "LogLevel VERBOSE" >> /etc/ssh/sshd_config && \
    echo "SyslogFacility AUTH" >> /etc/ssh/sshd_config && \
    rm -rf /tmp /var/cache/apk/* /var/lib/apt/lists/* && \
    syslogd && passwd -d jekyll && \
    mv /usr/local/bin/unison /bin/unison && \
    gem install kramdown rouge
 
RUN echo "#!/bin/bash" >> /usr/bin/entrypoint.sh && \
    echo "ssh-keygen -f \${HOME}/.ssh/id_rsa -t rsa -q -C '' -N ''" >> /usr/bin/entrypoint.sh && \
    echo "mv /home/jekyll/.ssh/id_rsa.pub /home/jekyll/.ssh/authorized_keys" >> /usr/bin/entrypoint.sh && \
    echo "chmod 600 /home/jekyll/.ssh/authorized_keys" >> /usr/bin/entrypoint.sh && \
    chmod 755 /usr/bin/entrypoint.sh
    
USER jekyll

WORKDIR /srv/jekyll

CMD sudo ssh-keygen -A && sudo /usr/sbin/sshd -D && \
    tail -f /dev/null