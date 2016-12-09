#!/bin/bash
  mkdir -p /usr/hdp/current/custom
  cd /usr/hdp/current/custom
  wget https://hdinsightsjbstore.blob.core.windows.net/scripts/HadoopCryptoCompressor-0.0.6-SNAPSHOT.jar
  chmod 644  HadoopCryptoCompressor-0.0.6-SNAPSHOT.jar
