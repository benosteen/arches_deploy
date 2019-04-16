from benosteen/arches:latest
USER root

## Mirroring default environment variables
ENV WEB_ROOT=/web_root
ENV DOCKER_DIR=/docker

# Root project folder
ENV ARCHES_ROOT=${WEB_ROOT}/arches

COPY setup ${ARCHES_ROOT}/base_config
COPY setup/ontology ${ARCHES_ROOT}/ontology
COPY settings_local.py ${ARCHES_ROOT}/arches/settings_local.py
COPY aata_entrypoint.sh ${DOCKER_DIR}/main_entrypoint.sh

RUN chmod -R 700 ${DOCKER_DIR}

# unset the ENTRYPOINT from the parent image
ENTRYPOINT []

CMD ["/docker/main_entrypoint.sh", "run_arches"]

EXPOSE 8000

# Set default workdir
WORKDIR ${ARCHES_ROOT}