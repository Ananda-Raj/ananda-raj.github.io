# Abuse and cost limits.
import hashlib
import json
import time
from collections import deque

import aws
import config

_recent = deque()
_local = {}


class Limited(Exception):
    def __init__(self, status, code):
        super().__init__(code)
        self.status = status
        self.code = code


def ip_hash(ip):
    return hashlib.sha256((config.IP_SALT + ip).encode()).hexdigest()[:16]


def flood_check(now):
    # Per-container view of traffic. A flood switches the function off;
    # an hourly schedule switches it back on.
    _recent.append(now)
    while _recent and now - _recent[0] > 60:
        _recent.popleft()
    if len(_recent) > config.FLOOD_PER_MINUTE:
        try:
            aws.lambda_client().put_function_concurrency(
                FunctionName=config.FUNCTION_NAME, ReservedConcurrentExecutions=0
            )
            print(json.dumps({"event": "breaker_tripped", "per_minute": len(_recent)}))
        except Exception as err:
            print(json.dumps({"event": "breaker_failed", "error": str(err)}))
        raise Limited(503, "busy")


def _bump(key, limit, expires):
    # Cheap in-memory check first, so repeat offenders don't cost a write.
    if len(_local) > 5000:
        _local.clear()
    if _local.get(key, 0) >= limit:
        return False
    try:
        aws.table().update_item(
            Key={"pk": key},
            UpdateExpression="ADD n :one SET expires = if_not_exists(expires, :exp)",
            ConditionExpression="attribute_not_exists(n) OR n < :limit",
            ExpressionAttributeValues={":one": 1, ":limit": limit, ":exp": int(expires)},
        )
    except Exception as err:
        if aws.error_code(err) == "ConditionalCheckFailedException":
            _local[key] = limit
            return False
        raise
    _local[key] = _local.get(key, 0) + 1
    return True


def _stamp(now, fmt):
    return time.strftime(fmt, time.gmtime(now))


def check_chat(h, now):
    hour, day = _stamp(now, "%Y%m%d%H"), _stamp(now, "%Y%m%d")
    if not _bump(f"chat:ip:{h}:{hour}", config.CHAT_PER_IP_HOUR, now + 7200):
        raise Limited(429, "rate_limited")
    if not _bump(f"chat:ip:{h}:{day}", config.CHAT_PER_IP_DAY, now + 172800):
        raise Limited(429, "rate_limited")
    if not _bump(f"chat:all:{day}", config.CHAT_PER_DAY, now + 172800):
        raise Limited(503, "busy")


def check_contact(h, now):
    day = _stamp(now, "%Y%m%d")
    if not _bump(f"contact:ip:{h}:{day}", config.CONTACT_PER_IP_DAY, now + 172800):
        raise Limited(429, "rate_limited")
    if not _bump(f"contact:all:{day}", config.CONTACT_PER_DAY, now + 172800):
        raise Limited(503, "busy")


def _spend_key(now):
    return "spend:" + _stamp(now, "%Y%m")


def check_budget(now):
    item = aws.table().get_item(Key={"pk": _spend_key(now)}).get("Item") or {}
    if int(item.get("micro", 0)) >= config.MONTHLY_BUDGET_USD * 1_000_000:
        raise Limited(503, "resting")


def record_spend(tokens_in, tokens_out, now):
    # Price per million tokens times tokens equals micro-dollars.
    micro = round(tokens_in * config.PRICE_IN + tokens_out * config.PRICE_OUT)
    aws.table().update_item(
        Key={"pk": _spend_key(now)},
        UpdateExpression="ADD micro :m, tokens_in :i, tokens_out :o SET expires = if_not_exists(expires, :exp)",
        ExpressionAttributeValues={":m": micro, ":i": tokens_in, ":o": tokens_out, ":exp": int(now + 400 * 86400)},
    )
