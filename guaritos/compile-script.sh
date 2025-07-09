#!/bin/bash

source ./.env

aptos move compile --named-addresses guaritos=$account

aptos move deploy-object --address-name guaritos --assume-yes