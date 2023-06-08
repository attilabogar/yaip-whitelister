# Yet Another IP Whitelister

## Description

This project is a minimalistic approach to maintain a list of IPv4/IPv6
addresses with emphasis on security and cost.

This project can be used to maintain an IP whitelist for roaming users and
apply these to firewalls, file server acl's, etc.


The architecture is composed on AWS Cloud using components such as:
- S3 for input IP uploads and publicly available whitelist objects
- IAM users and policies shaped to match security
- Lambda to intercept S3 upload events and generate the whitelist

The key components are in directories, we will cover these in-depth later:
- edge-door-key
- edge-door-server
- terraform
- terragrunt

## terragrunt

`terragrunt.hcl` and `config.yml` to be customized as a first step.
Change the `bucket` reference for the _terraform_ state.

`config.yml` customization includes defining a project for the whitelister,
which will infer the bucket names for uploads the merged/generated lists.
Note: S3 bucket names are in a global namespace, must be unique.

This file also defines the list of users who are to be created for the roaming.

Initialize terragrunt by `terragrunt init` - then you are ready to deploy the
terraform module with `terragrunt apply`.

## terraform

The `terraform` directory is a terraform module for the AWS Cloud part of the
project.  The IAM policies restrict that only valid S3 object key is accepted
by the `edge-door-key` client.  The lambda code includes feature to
automatically drop large objects or invalid IP address uploads if they are
non-conformant.  Hence, the S3 cost abuse vector is limited.

## edge-door-key

This is simple client written in golang, the config file `edge-door-key.yml` is
expected in `$HOME/.config/edge-door-key.yml` location.

The _key_ term comes as this opens the _door_ to the remote infra.

## edge-door-server

This component is also golang written, the systemd unit file can be installed
to start this every 20 seconds, it checks whether the IPv4 or IPv6 list changed
_and if so_ templates a shell script and applies it.  An example shell script
is included in the contrib directory for NFS server export changes, however
the there is no limit to any usage.  Another build snippet is for
cross-architecture golang build (in case you want to run the server component
on SOC component).

## DISCLAIMER

This should be used in small-scale teams, hasn't been tested in large-scale
deployment.

## LICENSE

    MIT License

    Copyright (c) 2022,2023 Attila Bogár

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.

**NOTE**: This software depends on other packages that may be licensed under
different open source licenses.
