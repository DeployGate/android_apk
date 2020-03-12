FROM ruby:2.5.1

WORKDIR /android_apk

ENV RUBYOPT -EUTF-8

RUN apt-get update && \
    apt-get install -y unzip \
                       openjdk-8-jdk \
                       --no-install-recommends && \
    rm -rf /var/lib/apt/lists/*

# Setup aapt

ARG SDK_HASH

RUN mkdir -p /android
ENV ANDROID_HOME /android
ADD ./docker/licenses /android/licenses
RUN wget -q -O sdk-tools.zip https://dl.google.com/android/repository/sdk-tools-linux-${SDK_HASH}.zip && \
            unzip -qq sdk-tools.zip -d /android && \
            rm sdk-tools.zip

ARG BUILD_TOOLS_VERSION

ENV PATH "/android/build-tools/$BUILD_TOOLS_VERSION:$PATH"
RUN yes | /android/tools/bin/sdkmanager "build-tools;$BUILD_TOOLS_VERSION"

RUN type aapt && type apksigner

ARG BUNDLETOOL_VERSION
ADD ./bin/bundletool /usr/bin/bundletool
RUN curl -sSL \
    https://github.com/google/bundletool/releases/download/$BUNDLETOOL_VERSION/bundletool-all-$BUNDLETOOL_VERSION.jar \
    -o $ANDROID_HOME/bundletool.jar && \
    type bundletool

RUN gem update bundler
