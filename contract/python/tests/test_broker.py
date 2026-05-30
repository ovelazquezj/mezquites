"""Semantica del broker en memoria (consumer groups, pending/ack)."""

from mezquite_contract.broker import InMemoryBroker, make_broker


STREAM = "test:stream"
GROUP = "g1"


def test_publish_consume_ack():
    b = InMemoryBroker()
    b.ensure_group(STREAM, GROUP)
    id1 = b.publish(STREAM, {"n": 1})
    b.publish(STREAM, {"n": 2})

    batch = b.consume(STREAM, GROUP, "c1", count=10)
    assert [m["n"] for _, m in batch] == [1, 2]
    assert b.pending(STREAM, GROUP) == {id1, batch[1][0]}

    for msg_id, _ in batch:
        b.ack(STREAM, GROUP, msg_id)
    assert b.pending(STREAM, GROUP) == set()


def test_no_reentrega_mensajes_ya_leidos():
    b = InMemoryBroker()
    b.ensure_group(STREAM, GROUP)
    b.publish(STREAM, {"n": 1})
    first = b.consume(STREAM, GROUP, "c1")
    assert len(first) == 1
    # sin nuevos mensajes, una segunda lectura no reentrega
    assert b.consume(STREAM, GROUP, "c1") == []


def test_dos_grupos_reciben_cada_uno_su_copia():
    b = InMemoryBroker()
    b.publish(STREAM, {"n": 1})
    a = b.consume(STREAM, "ga", "c")
    z = b.consume(STREAM, "gz", "c")
    assert len(a) == 1 and len(z) == 1


def test_factory_memory():
    assert isinstance(make_broker("memory"), InMemoryBroker)
