FROM registry.access.redhat.com/ubi9/nodejs-18 as stage

USER root

WORKDIR /tmp

COPY . /tmp/parasol-insurance/app

FROM registry.access.redhat.com/ubi9/nodejs-18

USER root

COPY --from=stage /tmp/parasol-insurance/app/ /tmp/src

RUN chown -R 1001:0 /tmp/src

USER 1001

RUN /usr/libexec/s2i/assemble

CMD /usr/libexec/s2i/run
