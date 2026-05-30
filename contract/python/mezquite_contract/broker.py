"""Transporte conmutable de la frontera §6.1 (paridad de entornos, T6 / gate #6).

Un ``MessageBroker`` abstrae el canal entre backend y validador. Dos implementaciones,
seleccionables por configuración, sin tocar el código de aplicación:

- :class:`RedisStreamsBroker` — Redis Streams + *consumer groups* (staging/producción y
  cualquier entorno con Redis). Entrega *at-least-once*: los mensajes quedan *pending* hasta
  el ``ack``, habilitando reintentos y *dead-letter* (§6.4).
- :class:`InMemoryBroker` — mismo contrato, en proceso, sin dependencias externas. Para dev/QA
  sin nube y para pruebas deterministas.

Ambas usan los nombres de ``channels`` y un único campo de cable ``data`` con el mensaje
serializado en JSON, de modo que el protocolo es idéntico entre entornos. El cambio
**mock → validador real** no toca este archivo: solo cambia qué proceso consume ``JOBS_STREAM``.

La **idempotencia** de aplicación (aplicar un resultado una sola vez por ``observation_id``,
§6.4) es responsabilidad del backend consumidor; el broker garantiza entrega, no unicidad.
"""

from __future__ import annotations

import itertools
import json
import threading
import time
from abc import ABC, abstractmethod
from typing import Iterable

Message = dict
Delivery = tuple[str, Message]  # (message_id, message)

_DATA_FIELD = "data"


class MessageBroker(ABC):
    """Contrato de transporte. Las implementaciones no interpretan el contenido del mensaje."""

    @abstractmethod
    def ensure_group(self, stream: str, group: str) -> None:
        """Crea el *consumer group* (idempotente). Lee desde el inicio del stream."""

    @abstractmethod
    def publish(self, stream: str, message: Message) -> str:
        """Publica un mensaje. Devuelve su id."""

    @abstractmethod
    def consume(
        self, stream: str, group: str, consumer: str, *, count: int = 10, block_ms: int = 0
    ) -> list[Delivery]:
        """Lee hasta ``count`` mensajes nuevos para el grupo. Quedan *pending* hasta el ``ack``."""

    @abstractmethod
    def ack(self, stream: str, group: str, message_id: str) -> None:
        """Confirma el procesamiento de un mensaje (lo saca de *pending*)."""

    def close(self) -> None:  # pragma: no cover - opcional
        pass


# --------------------------------------------------------------------------------------------
# Implementación en memoria (dev/QA sin nube, pruebas)
# --------------------------------------------------------------------------------------------
class InMemoryBroker(MessageBroker):
    """Broker en proceso, *thread-safe*, con semántica de *consumer groups* simplificada."""

    def __init__(self) -> None:
        self._lock = threading.RLock()
        self._ids = itertools.count(1)
        # stream -> list[(id, message)]
        self._streams: dict[str, list[Delivery]] = {}
        # (stream, group) -> set[id] pendientes (entregados, sin ack)
        self._pending: dict[tuple[str, str], set[str]] = {}
        # (stream, group) -> último id entregado (entero)
        self._cursor: dict[tuple[str, str], int] = {}

    def ensure_group(self, stream: str, group: str) -> None:
        with self._lock:
            self._streams.setdefault(stream, [])
            self._pending.setdefault((stream, group), set())
            self._cursor.setdefault((stream, group), 0)

    def publish(self, stream: str, message: Message) -> str:
        with self._lock:
            msg_id = str(next(self._ids))
            self._streams.setdefault(stream, []).append((msg_id, dict(message)))
            return msg_id

    def consume(
        self, stream: str, group: str, consumer: str, *, count: int = 10, block_ms: int = 0
    ) -> list[Delivery]:
        deadline = time.monotonic() + (block_ms / 1000.0)
        while True:
            with self._lock:
                self.ensure_group(stream, group)
                cursor = self._cursor[(stream, group)]
                out: list[Delivery] = []
                for msg_id, message in self._streams[stream]:
                    if int(msg_id) > cursor and len(out) < count:
                        out.append((msg_id, dict(message)))
                if out:
                    last = int(out[-1][0])
                    self._cursor[(stream, group)] = last
                    self._pending[(stream, group)].update(mid for mid, _ in out)
                    return out
            if block_ms <= 0 or time.monotonic() >= deadline:
                return []
            time.sleep(min(0.02, max(0.0, deadline - time.monotonic())))

    def ack(self, stream: str, group: str, message_id: str) -> None:
        with self._lock:
            self._pending.get((stream, group), set()).discard(message_id)

    def pending(self, stream: str, group: str) -> set[str]:
        """Ids entregados sin ack (para pruebas/observabilidad)."""
        with self._lock:
            return set(self._pending.get((stream, group), set()))


# --------------------------------------------------------------------------------------------
# Implementación Redis Streams (staging/producción)
# --------------------------------------------------------------------------------------------
class RedisStreamsBroker(MessageBroker):
    """Broker sobre Redis Streams. ``redis`` se importa de forma perezosa (dependencia opcional)."""

    def __init__(self, url: str = "redis://localhost:6379/0", *, client=None) -> None:
        if client is not None:
            self._r = client
        else:
            try:
                import redis  # type: ignore
            except ModuleNotFoundError as exc:  # pragma: no cover
                raise RuntimeError(
                    "RedisStreamsBroker requiere el paquete 'redis' (pip install redis)."
                ) from exc
            self._r = redis.Redis.from_url(url, decode_responses=True)

    def ensure_group(self, stream: str, group: str) -> None:
        try:
            self._r.xgroup_create(name=stream, groupname=group, id="0", mkstream=True)
        except Exception as exc:  # BUSYGROUP: el grupo ya existe → idempotente
            if "BUSYGROUP" not in str(exc):
                raise

    def publish(self, stream: str, message: Message) -> str:
        return self._r.xadd(stream, {_DATA_FIELD: json.dumps(message)})

    def consume(
        self, stream: str, group: str, consumer: str, *, count: int = 10, block_ms: int = 0
    ) -> list[Delivery]:
        resp = self._r.xreadgroup(
            groupname=group,
            consumername=consumer,
            streams={stream: ">"},
            count=count,
            block=block_ms or None,
        )
        if not resp:
            return []
        out: list[Delivery] = []
        for _stream_name, entries in resp:
            for msg_id, fields in entries:
                out.append((msg_id, json.loads(fields[_DATA_FIELD])))
        return out

    def ack(self, stream: str, group: str, message_id: str) -> None:
        self._r.xack(stream, group, message_id)

    def close(self) -> None:  # pragma: no cover
        try:
            self._r.close()
        except Exception:
            pass


def make_broker(kind: str = "memory", *, url: str | None = None, client=None) -> MessageBroker:
    """Fábrica conmutable por configuración.

    ``kind="memory"`` → :class:`InMemoryBroker`; ``kind="redis"`` → :class:`RedisStreamsBroker`.
    """
    kind = (kind or "memory").lower()
    if kind == "memory":
        return InMemoryBroker()
    if kind == "redis":
        return RedisStreamsBroker(url or "redis://localhost:6379/0", client=client)
    raise ValueError(f"broker desconocido: {kind!r} (use 'memory' o 'redis')")


def drain(broker: MessageBroker, stream: str, group: str, consumer: str = "test") -> Iterable[Delivery]:
    """Utilidad de pruebas: consume y ackea todo lo disponible, devolviéndolo."""
    broker.ensure_group(stream, group)
    batch = broker.consume(stream, group, consumer, count=1000, block_ms=0)
    for msg_id, _ in batch:
        broker.ack(stream, group, msg_id)
    return batch
