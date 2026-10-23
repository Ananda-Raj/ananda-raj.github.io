# Contact form email.
import re

import aws
import config

TOPICS = {
    "question": "A question",
    "work": "Working together",
    "community": "Community or speaking",
    "hello": "Just saying hi",
}
EMAIL = re.compile(r"^[^@\s]{1,64}@[^@\s]+\.[^@\s]{2,}$")


class BadForm(Exception):
    pass


def _line(value, limit):
    return re.sub(r"[\r\n\t]+", " ", str(value or "")).strip()[:limit]


def validate(body):
    # Bots fill the hidden "website" field; accept quietly and send nothing.
    if str(body.get("website", "")).strip():
        return None
    name = _line(body.get("name"), 100)
    email = _line(body.get("email"), 200)
    topic = str(body.get("topic", ""))
    message = str(body.get("message", "")).strip()
    transcript = str(body.get("transcript", "")).strip()
    if not name:
        raise BadForm("name")
    if not EMAIL.match(email):
        raise BadForm("email")
    if topic not in TOPICS:
        raise BadForm("topic")
    if not 2 <= len(message) <= 4000:
        raise BadForm("message")
    if len(transcript) > 8000:
        raise BadForm("transcript")
    return {"name": name, "email": email, "topic": topic, "message": message, "transcript": transcript}


def send(form):
    body = f"Name: {form['name']}\nEmail: {form['email']}\nTopic: {TOPICS[form['topic']]}\n\n{form['message']}\n"
    if form["transcript"]:
        body += f"\n--- Chat with the site assistant ---\n{form['transcript']}\n"
    aws.ses().send_email(
        FromEmailAddress=config.MAIL_FROM,
        Destination={"ToAddresses": [config.MAIL_TO]},
        ReplyToAddresses=[form["email"]],
        Content={
            "Simple": {
                "Subject": {"Data": f"[Website] {TOPICS[form['topic']]}: {form['name']}", "Charset": "UTF-8"},
                "Body": {"Text": {"Data": body, "Charset": "UTF-8"}},
            }
        },
    )
