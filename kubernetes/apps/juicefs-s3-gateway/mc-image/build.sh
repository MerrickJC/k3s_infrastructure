#!/bin/bash
cat ./password.txt | docker login registry.direct.merrickcampbell.au --username merrick.campbell@monashmotorsport.com --password-stdin

docker buildx build --platform linux/amd64 --push -t registry.direct.merrickcampbell.au/mc-juicefs:2021-04-22 .
