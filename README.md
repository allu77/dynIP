# dynIP
A Script to update a CloudFlare DNS entry based on the host public IP address.

dynIP checks your public IP address using [WhatIs MyIPAddress](https://whatismyipaddress.com/) public API. In case public API changes from the previous execution, it will update an A record on Cloud Flare DNS.

## Pre-requisites
You will need to following in order to use dynIP

1. A Cloud Flare account
2. A Cloud Flare API key
3. [./jq](https://stedolan.github.io/jq/) installed in you binary path

## Usage

```
Usage: ./dynIP.sh [OPTIONS] [DNS Entry]

Valid OPTIONS
  -e CLOUDFLARE_EMAIL
  -a CLOUDFLARE_API_KEY
  -j JQ_PATH

OPTIONS and DNS Entry can either be provided as cmd line options or inside
configuration files:
  /etc/dynIP
  ~/.dynIP
```

