import os
import smtplib
import ssl
import json
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

SMTP_SERVER   = os.environ["SMTP_SERVER"]
SMTP_USERNAME = os.environ["SMTP_USERNAME"]
SMTP_PASSWORD = os.environ["SMTP_PASSWORD"]
RECIPIENTS    = os.environ["RECIPIENTS"]          # comma-separated: core + extension emails
USERS_JSON    = os.environ["USERS_JSON"]          # [{"username": "...", "password_age_days": 123}]
FROM_ADDRESS  = os.environ.get("FROM_ADDRESS", "adp-technicalservices@allianz.com")
ALLIANZ_CA_CERT = os.environ.get("ALLIANZ_CA_CERT")
NOTIFIED_USERS_FILE = os.environ["NOTIFIED_USERS_FILE"]

users      = json.loads(USERS_JSON)
recipients = [r.strip() for r in RECIPIENTS.split(",") if r.strip()]

# Build a summary table of all affected users for a single notification email
user_rows = "\n".join(
    f"  - {u['username']} (password age: {u['password_age_days']} days, "
    f"login will be disabled in approx. {max(0, 211 - u['password_age_days'])} days after notification)"
    for u in users
)

subject = "[Urgent Action Required] SQL Pool passwords nearing expiry — Allianz Data Platform"

body = f"""Dear Team,

This is an automated notification from the Allianz Data Platform.

The following SQL Pool login(s) have passwords that have not been changed for 180 or more days
and are entering the grace period:

{user_rows}

These logins will be automatically disabled 31 days after this notification is sent.
During this period, affected users must raise a Service Request with the Allianz Data Platform
Technical Support team to reset their SQL Pool login password before the login is disabled.

Contact: adp-technicalservices@allianz.com

This is an automated message — But still you can reply directly to this email.

Regards,
Allianz Data Platform Team
"""

msg = MIMEMultipart()
msg["From"]    = FROM_ADDRESS
msg["To"]      = ", ".join(recipients)
msg["Subject"] = subject
msg.attach(MIMEText(body, "plain"))

context = ssl.create_default_context(cafile=ALLIANZ_CA_CERT)
context.minimum_version = ssl.TLSVersion.TLSv1_2

with smtplib.SMTP(SMTP_SERVER) as server:
    server.starttls(context=context)
    server.ehlo()
    server.login(SMTP_USERNAME, SMTP_PASSWORD)
    server.sendmail(FROM_ADDRESS, recipients, msg.as_string())

print(f"Notification sent to: {', '.join(recipients)}")
print(f"Users covered: {[u['username'] for u in users]}")

# Write all notified usernames so the next step knows who to update in the DB
notified = [{"username": u["username"], "email": RECIPIENTS} for u in users]
with open(NOTIFIED_USERS_FILE, "w") as f:
    json.dump(notified, f)
