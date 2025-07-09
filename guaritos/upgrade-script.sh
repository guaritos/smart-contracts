#!/bin/bash

source ./.env

aptos move compile --named-addresses guaritos=$account

aptos move upgrade-object --address-name guaritos --object-address $guaritos_object_address \
  --assume-yes \
  --override-size-check \
  --skip-fetch-latest-git-deps