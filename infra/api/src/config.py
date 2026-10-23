import os


def _int(name, default):
    return int(os.environ.get(name, default))


def _float(name, default):
    return float(os.environ.get(name, default))


TABLE = os.environ.get("TABLE_NAME", "")
MODEL_ID = os.environ.get("MODEL_ID", "")
CONTEXT_URL = os.environ.get("CONTEXT_URL", "")
ORIGINS = [o.strip() for o in os.environ.get("ALLOWED_ORIGINS", "").split(",") if o.strip()]
FUNCTION_NAME = os.environ.get("AWS_LAMBDA_FUNCTION_NAME", "")
MAIL_TO = os.environ.get("MAIL_TO", "")
MAIL_FROM = os.environ.get("MAIL_FROM", MAIL_TO)
IP_SALT = os.environ.get("IP_SALT", "")

# Cost cap for the assistant, from the token counts Bedrock reports.
MONTHLY_BUDGET_USD = _float("MONTHLY_BUDGET_USD", 1)
PRICE_IN = _float("PRICE_INPUT_PER_MTOK", 1.0)
PRICE_OUT = _float("PRICE_OUTPUT_PER_MTOK", 5.0)
MAX_TOKENS = _int("MAX_TOKENS", 450)

CHAT_PER_IP_HOUR = _int("CHAT_PER_IP_HOUR", 10)
CHAT_PER_IP_DAY = _int("CHAT_PER_IP_DAY", 30)
CHAT_PER_DAY = _int("CHAT_PER_DAY", 150)
CONTACT_PER_IP_DAY = _int("CONTACT_PER_IP_DAY", 3)
CONTACT_PER_DAY = _int("CONTACT_PER_DAY", 20)
FLOOD_PER_MINUTE = _int("FLOOD_PER_MINUTE", 120)
