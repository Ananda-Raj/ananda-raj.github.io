# Entry point for the site API behind CloudFront: POST /api/chat and POST /api/contact.
import base64
import json
import time

import assistant
import aws
import config
import guard
import mailer

MAX_BODY = 20_000
HEADERS = {"content-type": "application/json", "cache-control": "no-store"}


def respond(status, body):
    return {"statusCode": status, "headers": HEADERS, "body": json.dumps(body)}


def log(**fields):
    print(json.dumps(fields, ensure_ascii=False))


def client_ip(event, headers):
    # CloudFront passes the viewer as "ip:port" (IPv6 too, port after the last colon).
    viewer = headers.get("cloudfront-viewer-address", "")
    if viewer:
        return viewer.rsplit(":", 1)[0].strip("[]")
    forwarded = headers.get("x-forwarded-for", "")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return event.get("requestContext", {}).get("http", {}).get("sourceIp", "unknown")


def parse_body(event):
    raw = event.get("body") or ""
    if event.get("isBase64Encoded"):
        raw = base64.b64decode(raw).decode("utf-8")
    if len(raw) > MAX_BODY:
        raise assistant.BadInput("body too large")
    try:
        body = json.loads(raw)
    except ValueError:
        raise assistant.BadInput("invalid json")
    if not isinstance(body, dict):
        raise assistant.BadInput("invalid json")
    return body


def chat(body, h, now):
    messages = assistant.clean_messages(body.get("messages"))
    guard.check_budget(now)
    guard.check_chat(h, now)
    try:
        text, tokens_in, tokens_out = assistant.reply(messages, now)
    except Exception as err:
        code = aws.error_code(err)
        log(event="model_error", code=code, error=str(err)[:300])
        if code in ("ThrottlingException", "ServiceQuotaExceededException", "ModelNotReadyException"):
            raise guard.Limited(503, "busy")
        raise guard.Limited(503, "unavailable")
    guard.record_spend(tokens_in, tokens_out, now)
    log(
        event="chat",
        ip=h,
        source=str(body.get("source", ""))[:20],
        question=messages[-1]["content"][:500],
        answer=text[:500],
        tokens_in=tokens_in,
        tokens_out=tokens_out,
    )
    return respond(200, {"reply": text})


def contact(body, h, now):
    form = mailer.validate(body)
    if form is None:
        log(event="contact_honeypot", ip=h)
        return respond(200, {"ok": True})
    guard.check_contact(h, now)
    mailer.send(form)
    log(event="contact", ip=h, topic=form["topic"], length=len(form["message"]))
    return respond(200, {"ok": True})


ROUTES = {"/api/chat": chat, "/api/contact": contact}


def lambda_handler(event, context):
    now = time.time()
    method = event.get("requestContext", {}).get("http", {}).get("method", "")
    path = event.get("rawPath", "")
    headers = {k.lower(): v for k, v in (event.get("headers") or {}).items()}

    try:
        guard.flood_check(now)
        if method != "POST" or path not in ROUTES:
            return respond(404, {"error": "not_found"})
        if headers.get("origin", "") not in config.ORIGINS:
            return respond(403, {"error": "forbidden"})
        body = parse_body(event)
        h = guard.ip_hash(client_ip(event, headers))
        return ROUTES[path](body, h, now)
    except guard.Limited as err:
        return respond(err.status, {"error": err.code})
    except (assistant.BadInput, mailer.BadForm) as err:
        return respond(400, {"error": "bad_request", "field": str(err)})
    except Exception as err:
        log(event="server_error", path=path, error=str(err)[:300])
        return respond(500, {"error": "server_error"})
