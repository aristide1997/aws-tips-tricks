#!/bin/bash

# This code will help you make use of the AWS CLI v2 to send a raw email via commandline with an attachment. 
# This attachment can be any binary data that you want.

# First, we need to create the data blob as per the documentation:
# https://awscli.amazonaws.com/v2/documentation/api/latest/reference/ses/send-raw-email.html

# Then, we take the json message file and use that to send the email. Please note, we need to encode with base64 the file that we want to send.

echo '{"Data": "From: test@test.com\nTo: test@test.com\nSubject: Test email sent using the AWS CLI (contains an attachment)\nMIME-Version: 1.0\nContent-type: Multipart/Mixed; boundary=\"NextPart\"\n\n--NextPart\nContent-Type: text/plain\n\nThis is the message body.\n\n--NextPart\nContent-Type: application/zip;\nContent-Disposition: attachment; filename=\"file.zip\"\nContent-Transfer-Encoding: base64\n\n'$(base64 file.zip)'\n\n--NextPart--"}' > message2.json

/usr/local/bin/aws ses send-raw-email --cli-binary-format raw-in-base64-out --raw-message file://message2.json


# All in one:

echo '{"Data": "From: test@test.com\nTo: test@test.com\nSubject: Test email sent using the AWS CLI (contains an attachment)\nMIME-Version: 1.0\nContent-type: Multipart/Mixed; boundary=\"NextPart\"\n\n--NextPart\nContent-Type: text/plain\n\nThis is the message body.\n\n--NextPart\nContent-Type: application/zip;\nContent-Disposition: attachment; filename=\"file.zip\"\nContent-Transfer-Encoding: base64\n\n'$(base64 file.zip)'\n\n--NextPart--"}' > message2.json; /usr/local/bin/aws ses send-raw-email --cli-binary-format raw-in-base64-out --raw-message file://message2.json
