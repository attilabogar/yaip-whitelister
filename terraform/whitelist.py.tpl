#!/usr/bin/env python3
import json
import logging
import boto3
import ipaddress

logger = logging.getLogger()
logger.setLevel(logging.INFO)
s3_client = boto3.client('s3')

def generate(ip_version):
    acl = []
    response = s3_client.list_objects_v2(
        Bucket="${bucket_src}",
        Prefix="ipv{}/".format(ip_version),
        StartAfter="ipv{}/".format(ip_version)
    )
    list = ""
    try:
        s3_objects = response['Contents']
        for key in [ i['Key'] for i in s3_objects]:
            object = s3_client.get_object(
                Bucket="${bucket_src}",
                Key=key
            )['Body'].read().decode('utf-8')
            myip = ipaddress.ip_address(object)
            if myip not in acl:
                acl.append(myip)
        for i in sorted(acl):
            if len(list) == 0:
                list += str(i)
            else:
                list += "\n" + str(i)
        if len(list) > 0:
            list += "\n"
    except KeyError:
        pass
    s3_client.put_object(
        Body=list,
        Bucket="${bucket_dst}",
        Key="ipv{}.txt".format(ip_version)
    )
    s3_client.put_object_acl(
        Bucket="${bucket_dst}",
        Key="ipv{}.txt".format(ip_version),
        ACL='public-read'
    )

def lambda_handler(event, context):
    logger.info("Event: " + str(event))
    dirty_ipv4 = False
    dirty_ipv6 = False
    for record in event['Records']:
        valid_change = record['eventSource'] == 'aws:s3'
        if valid_change and record['eventName'] == 'ObjectRemoved:Delete':
            objectkey = record['s3']['object']['key']
            logger.info("REMOVE: "+objectkey)
            if objectkey[0:5] == 'ipv4/':
                dirty_ipv4 = True
            if objectkey[0:5] == 'ipv6/':
                dirty_ipv6 = True
        if valid_change and record['eventName'] == 'ObjectCreated:Put':
            objectkey = record['s3']['object']['key']
            objectsize = int(record['s3']['object']['size'])
            valid_object = False
            if objectkey[0:5] == 'ipv4/':
                if objectsize < 16:
                    o = s3_client.get_object(
                        Bucket="${bucket_src}",
                        Key=objectkey
                    )['Body'].read().decode('utf-8')
                    try:
                        ip = ipaddress.ip_address(o)
                        if ip.version == 4:
                            valid_object = True
                            dirty_ipv4 = True
                            logger.info("ADD: "+str(ip))
                    except ValueError:
                        pass
            if objectkey[0:5] == 'ipv6/':
                if objectsize < 40:
                    o = s3_client.get_object(
                        Bucket="${bucket_src}",
                        Key=objectkey
                    )['Body'].read().decode('utf-8')
                    try:
                        ip = ipaddress.ip_address(o)
                        if ip.version == 6:
                            valid_object = True
                            dirty_ipv6 = True
                            logger.info("ADD: "+str(ip))
                    except ValueError:
                        pass
            if not valid_object:
                logger.info("REMOVING ROGUE OBJECT: "+objectkey)
                s3_client.delete_object(
                    Bucket="${bucket_src}",
                    Key=objectkey
                )

    # generate lists
    if dirty_ipv4:
        logger.info('GENERATE IPv4')
        generate(4)
    if dirty_ipv6:
        logger.info('GENERATE IPv6')
        generate(6)
