"""Entrypoint del mock-validator: `python -m mock_validator`."""

from __future__ import annotations

import logging
import signal

from mezquite_contract.broker import make_broker

from .config import Config
from .worker import MockValidator


def main() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s %(message)s",
    )
    cfg = Config.from_env()
    broker = make_broker(cfg.broker_kind, url=cfg.redis_url)
    validator = MockValidator(broker, cfg)

    stop = {"flag": False}

    def _handle(signum, _frame):  # noqa: ANN001
        logging.getLogger("mock_validator").info("señal %s recibida; deteniendo…", signum)
        stop["flag"] = True

    signal.signal(signal.SIGINT, _handle)
    try:
        signal.signal(signal.SIGTERM, _handle)
    except (AttributeError, ValueError):  # SIGTERM no siempre disponible (p.ej. Windows)
        pass

    try:
        validator.run_forever(should_stop=lambda: stop["flag"])
    finally:
        broker.close()


if __name__ == "__main__":
    main()
