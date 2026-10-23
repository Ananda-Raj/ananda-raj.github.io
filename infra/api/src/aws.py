# AWS clients, created on first use so tests can swap them out.
import config

_clients = {}


def _get(name, make):
    if name not in _clients:
        _clients[name] = make()
    return _clients[name]


def _boto():
    import boto3
    from botocore.config import Config

    return boto3, Config


def table():
    def make():
        boto3, _ = _boto()
        return boto3.resource("dynamodb").Table(config.TABLE)

    return _get("table", make)


def bedrock():
    def make():
        boto3, Config = _boto()
        cfg = Config(connect_timeout=3, read_timeout=20, retries={"max_attempts": 2, "mode": "standard"})
        return boto3.client("bedrock-runtime", config=cfg)

    return _get("bedrock", make)


def ses():
    return _get("ses", lambda: _boto()[0].client("sesv2"))


def lambda_client():
    return _get("lambda", lambda: _boto()[0].client("lambda"))


def error_code(err):
    return getattr(err, "response", {}).get("Error", {}).get("Code", "")
