# Run from infra/api: python3 -m unittest discover tests
import json
import os
import sys
import unittest

os.environ.update(
    {
        "TABLE_NAME": "t",
        "MODEL_ID": "model",
        "CONTEXT_URL": "https://example.com/ai/context.json",
        "ALLOWED_ORIGINS": "https://site.example,http://localhost:4321",
        "AWS_LAMBDA_FUNCTION_NAME": "fn",
        "MAIL_TO": "me@example.com",
        "IP_SALT": "salt",
        "CHAT_PER_IP_HOUR": "3",
        "CONTACT_PER_IP_DAY": "2",
        "FLOOD_PER_MINUTE": "50",
    }
)
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))

import assistant  # noqa: E402
import aws  # noqa: E402
import guard  # noqa: E402
import handler  # noqa: E402


class AwsError(Exception):
    def __init__(self, code):
        super().__init__(code)
        self.response = {"Error": {"Code": code}}


class FakeTable:
    def __init__(self):
        self.items = {}

    def update_item(self, Key, UpdateExpression, ExpressionAttributeValues, ConditionExpression=None):
        item = self.items.setdefault(Key["pk"], {})
        v = ExpressionAttributeValues
        if ConditionExpression and "n" in item and item["n"] >= v[":limit"]:
            raise AwsError("ConditionalCheckFailedException")
        if ":one" in v:
            item["n"] = item.get("n", 0) + 1
        if ":m" in v:
            item["micro"] = item.get("micro", 0) + v[":m"]
        item.setdefault("expires", v[":exp"])

    def get_item(self, Key):
        return {"Item": self.items[Key["pk"]]} if Key["pk"] in self.items else {}


class FakeBedrock:
    def __init__(self):
        self.calls = []
        self.error = None

    def converse(self, **kw):
        self.calls.append(kw)
        if self.error:
            raise self.error
        return {
            "output": {"message": {"content": [{"text": "He has run EKS in production."}]}},
            "stopReason": "end_turn",
            "usage": {"inputTokens": 3000, "outputTokens": 100},
        }


class FakeSes:
    def __init__(self):
        self.sent = []

    def send_email(self, **kw):
        self.sent.append(kw)


class FakeLambda:
    def __init__(self):
        self.calls = []

    def put_function_concurrency(self, **kw):
        self.calls.append(kw)


def event(path="/api/chat", body=None, origin="https://site.example", method="POST", ip="203.0.113.7:4431"):
    return {
        "rawPath": path,
        "requestContext": {"http": {"method": method, "sourceIp": "10.0.0.1"}},
        "headers": {"Origin": origin, "CloudFront-Viewer-Address": ip},
        "body": json.dumps(body if body is not None else {}),
    }


def ask(text="Has he used EKS?", **kw):
    return event(body={"messages": [{"role": "assistant", "content": "Hi!"}, {"role": "user", "content": text}]}, **kw)


def contact(**fields):
    form = {"name": "Asha", "email": "asha@example.com", "topic": "question", "message": "Hello there"}
    form.update(fields)
    return event(path="/api/contact", body=form)


def call(ev):
    res = handler.lambda_handler(ev, None)
    return res["statusCode"], json.loads(res["body"])


class HandlerTest(unittest.TestCase):
    def setUp(self):
        self.table, self.bedrock, self.ses, self.lam = FakeTable(), FakeBedrock(), FakeSes(), FakeLambda()
        aws._clients.update(table=self.table, bedrock=self.bedrock, ses=self.ses, **{"lambda": self.lam})
        guard._recent.clear()
        guard._local.clear()
        assistant._cache.update(
            data={"name": "V Ananda Raj", "firstName": "Ananda Raj", "role": "Senior DevOps Engineer", "location": "Kochi", "text": "Skills: EKS {x}"},
            at=1e12,
        )

    def test_chat_answers_and_records_spend(self):
        status, body = call(ask())
        self.assertEqual(status, 200)
        self.assertIn("EKS", body["reply"])
        sent = self.bedrock.calls[0]
        self.assertEqual(sent["messages"][0]["role"], "user")
        self.assertIn("Skills: EKS {x}", sent["system"][0]["text"])
        spend = [v for k, v in self.table.items.items() if k.startswith("spend:")][0]
        self.assertEqual(spend["micro"], 3500)

    def test_wrong_origin_and_method(self):
        self.assertEqual(call(ask(origin="https://evil.example"))[0], 403)
        self.assertEqual(call(event(method="GET"))[0], 404)
        self.assertEqual(call(event(path="/other"))[0], 404)

    def test_bad_messages(self):
        self.assertEqual(call(event(body={"messages": []}))[0], 400)
        self.assertEqual(call(ask("x" * 1001))[0], 400)
        last_assistant = {"messages": [{"role": "user", "content": "hi"}, {"role": "assistant", "content": "yo"}]}
        self.assertEqual(call(event(body=last_assistant))[0], 400)
        bad = event()
        bad["body"] = "not json"
        self.assertEqual(call(bad)[0], 400)

    def test_rate_limit_per_ip(self):
        for _ in range(3):
            self.assertEqual(call(ask())[0], 200)
        status, body = call(ask())
        self.assertEqual((status, body["error"]), (429, "rate_limited"))
        self.assertEqual(call(ask(ip="198.51.100.9:1"))[0], 200)

    def test_budget_rests_assistant(self):
        guard_key = "spend:" + __import__("time").strftime("%Y%m", __import__("time").gmtime())
        self.table.items[guard_key] = {"micro": 1_000_000}
        status, body = call(ask())
        self.assertEqual((status, body["error"]), (503, "resting"))
        self.assertEqual(self.bedrock.calls, [])

    def test_model_errors(self):
        self.bedrock.error = AwsError("ThrottlingException")
        self.assertEqual(call(ask())[1]["error"], "busy")
        self.bedrock.error = AwsError("AccessDeniedException")
        self.assertEqual(call(ask(ip="198.51.100.2:1"))[1]["error"], "unavailable")

    def test_contact_sends_email_with_reply_to(self):
        status, _ = call(contact(transcript="Visitor: hi"))
        self.assertEqual(status, 200)
        mail = self.ses.sent[0]
        self.assertEqual(mail["ReplyToAddresses"], ["asha@example.com"])
        self.assertIn("Visitor: hi", mail["Content"]["Simple"]["Body"]["Text"]["Data"])

    def test_contact_validation_and_honeypot(self):
        self.assertEqual(call(contact(email="nope"))[0], 400)
        self.assertEqual(call(contact(topic="spam"))[0], 400)
        self.assertEqual(call(contact(website="http://bot"))[0], 200)
        self.assertEqual(self.ses.sent, [])

    def test_contact_rate_limit(self):
        self.assertEqual(call(contact())[0], 200)
        self.assertEqual(call(contact())[0], 200)
        self.assertEqual(call(contact())[0], 429)

    def test_flood_trips_breaker(self):
        for _ in range(50):
            call(event(path="/nothing"))
        status, body = call(ask())
        self.assertEqual((status, body["error"]), (503, "busy"))
        self.assertEqual(self.lam.calls[0], {"FunctionName": "fn", "ReservedConcurrentExecutions": 0})

    def test_client_ip(self):
        self.assertEqual(handler.client_ip({}, {"cloudfront-viewer-address": "203.0.113.7:443"}), "203.0.113.7")
        self.assertEqual(handler.client_ip({}, {"cloudfront-viewer-address": "2001:db8::1:443"}), "2001:db8::1")
        self.assertEqual(handler.client_ip({}, {"x-forwarded-for": "198.51.100.1, 10.0.0.1"}), "198.51.100.1")


if __name__ == "__main__":
    unittest.main()
