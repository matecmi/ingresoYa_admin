FROM jenkins/jenkins:lts

USER root

RUN apt-get update && apt-get install -y \
    git \
    curl \
    unzip \
    wget \
    xz-utils \
    zip \
    libglu1-mesa \
    && apt-get clean

RUN git clone https://github.com/flutter/flutter.git /opt/flutter

WORKDIR /opt/flutter

RUN git checkout 3.35.5

ENV PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:${PATH}"

RUN flutter config --enable-web
RUN flutter doctor

USER jenkins