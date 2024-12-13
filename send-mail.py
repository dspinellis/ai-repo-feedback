#!/usr/bin/env python
#
# Send an email message via SMTP
#
# Copyright 2024 Diomidis Spinellis
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#


import argparse
import csv
from email import encoders
from email.header import Header
from email.utils import formataddr
from email.mime.text import MIMEText
from email.mime.base import MIMEBase
from email.mime.multipart import MIMEMultipart
import io
import os
import re
# this invokes the secure SMTP protocol (port 465, uses SSL)
from smtplib import SMTP_SSL as SMTP
import sys
import textwrap
import time

def send_mail(args, content):
    try:
        smtp_server = os.environ['SMTP_SERVER']
        username = os.environ['SMTP_USERNAME']
        password = os.environ['SMTP_PASSWORD']
    except KeyError as e:
        sys.exit(f"Unable to find {e.args[0]} environment variable\n")
    destination = [
        args.from_email,
        args.to_email,
    ]

    msg = MIMEMultipart()
    msg['Subject'] = args.subject
    msg['From'] = formataddr((str(Header(args.from_name, 'utf-8')), args.from_email))
    msg['To'] = formataddr((str(Header(args.to_name, 'utf-8')), args.to_email))
    msg['Cc']  = ','.join([
        formataddr((str(Header(name, 'utf-8')), email))
        for name, email in zip(args.cc_email, args.cc_name)
    ])

    # Body
    msg.attach(MIMEText(content, args.content_type, 'utf-8'))

    # Attachments
    for attachment_name in args.attachment:
        with open(attachment_name, 'rb') as attachment:
            # The content type "application/octet-stream" means a binary file
            part = MIMEBase('application', 'octet-stream')
            part.set_payload(attachment.read())

        # Encode the file content in base64
        encoders.encode_base64(part)

        # Add header to the PDF attachment
        part.add_header(
            'Content-Disposition',
            f'attachment; filename={attachment_name}',
        )

        # Attach the PDF to the message
        msg.attach(part)

    # Send the email
    conn = SMTP(smtp_server)
    conn.set_debuglevel(False)
    conn.login(username, password)
    try:
        conn.sendmail(args.from_email, destination, msg.as_string())
    except Exception as exc:
        sys.exit(f"mail to f{args.to_email} failed; {exc}")
    finally:
        conn.quit()


def parse_arguments():
    parser = argparse.ArgumentParser(description="send-email")

    # Required arguments
    parser.add_argument("--from-email", required=True, type=str, help="Sender's email address.")
    parser.add_argument("--from-name", required=True, type=str, help="Sender's name.")
    parser.add_argument("--to-email", required=True, type=str, help="Recipient's email address.")
    parser.add_argument("--subject", required=True, type=str, help="Email subject.")

    # Optional arguments
    parser.add_argument("--attachment", type=str, action='append', default=[], help="Attachment file name (can be repeated).")
    parser.add_argument("--content-type", type=str, default='plain', help="Content type (e.g. html); default is plain.")
    parser.add_argument("--to-name", type=str, default=None, help="Recipient's name (optional).")
    parser.add_argument("--cc-email", type=str, action='append', default=[], help="CC email address (can be repeated).")
    parser.add_argument("--cc-name", type=str, action='append', default=[], help="CC name (can be repeated).")

    args = parser.parse_args()

    # Validating repeated arguments
    if len(args.cc_name) > 0 and len(args.cc_email) != len(args.cc_name):
        parser.error("The number of --cc-email and --cc-name entries must match.")

    return args

def main():
    args = parse_arguments()
    content = io.TextIOWrapper(sys.stdin.buffer, encoding='utf-8').read()
    send_mail(args, content)

if __name__ == "__main__":
    main()
