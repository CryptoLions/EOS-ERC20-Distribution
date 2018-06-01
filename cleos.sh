#!/bin/bash
################################################################################
#
# Scrip Created by http://CryptoLions.io
# For EOS Junlge testnet
#
# https://github.com/CryptoLions/
#
################################################################################


CLEOS=/home/eos/build/programs/cleos/cleos
$CLEOS -u http://127.0.0.1:8888 --wallet-url http://127.0.0.1:8890 "$@"

