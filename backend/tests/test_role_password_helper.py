from types import SimpleNamespace
from io import StringIO
from unittest.mock import MagicMock, patch

import pytest
from psycopg import sql as psycopg_sql
from sqlalchemy import exc as sqlalchemy_exc
from sqlalchemy.engine import URL, make_url

from scripts import set_local_role_password as helper


def test_password_prompt_accepts_letters_digits_and_special_characters():
    password = "Alpha9!@#$%^&*()_+-=[]{};:,.?/\\safe"
    encoded_url = URL.create(
        "postgresql+psycopg",
        username="medicine_app",
        password=password,
        host="127.0.0.1",
        database="medicine_adherence",
    ).render_as_string(hide_password=False)
    assert make_url(encoded_url).password == password
    assert helper.validate_password(password) == password


def test_update_sends_password_only_to_privileged_workers_stdin():
    password = r"Letters9!$'\;[]{}"
    completed = SimpleNamespace(returncode=0)
    with patch.object(helper.subprocess, "run", return_value=completed) as run:
        assert helper.update_role_password(password) == 0

    command = run.call_args.args[0]
    input_text = run.call_args.kwargs["input"]
    assert command == [
        "sudo", "-u", "postgres", helper.SYSTEM_PYTHON, "-c",
        helper.PASSWORD_WORKER_CODE,
    ]
    assert password not in " ".join(command)
    assert input_text == f"{password}\n"


def test_system_worker_uses_fixed_role_and_psycopg_quoted_password_literal(capsys):
    password = "Safe!9'%;[]\\"
    connection = MagicMock()
    connection.__enter__.return_value = connection
    cursor_context = connection.cursor.return_value
    cursor_context.__enter__.return_value = cursor_context
    fake_psycopg = SimpleNamespace(
        sql=psycopg_sql, connect=MagicMock(return_value=connection)
    )
    with (
        patch.object(helper.sys, "stdin", StringIO(password + "\n")),
        patch.dict("sys.modules", {"psycopg": fake_psycopg}),
    ):
        exec(compile(helper.PASSWORD_WORKER_CODE, "password-worker", "exec"), {})

    assert fake_psycopg.connect.call_args.args == (
        "dbname=postgres host=/var/run/postgresql user=postgres",
    )
    statement = cursor_context.execute.call_args.args[0]
    assert isinstance(statement, psycopg_sql.Composed)
    assert statement._obj[1]._obj == ("medicine_app",)
    assert statement._obj[3]._obj == password
    assert password not in capsys.readouterr().out


def test_listener_diagnostic_extracts_only_process_ids():
    result = SimpleNamespace(
        returncode=0,
        stdout='LISTEN 0 128 127.0.0.1:5432 0.0.0.0:* users:(("postgres",pid=321,fd=7))\n',
    )
    with patch.object(helper.subprocess, "run", return_value=result):
        assert helper._tcp_listener_pids(5432) == {321}


def test_listener_diagnostic_returns_unknown_when_process_is_not_visible():
    result = SimpleNamespace(returncode=0, stdout="LISTEN 0 128 127.0.0.1:5432 *:*\n")
    with patch.object(helper.subprocess, "run", return_value=result):
        assert helper._tcp_listener_pids(5432) is None


def test_tcp_verification_does_not_print_password(capsys):
    password = "Letters9!$'\\;[]{}"
    url = make_url(URL.create(
        "postgresql+psycopg", username="medicine_app", password=password,
        host="127.0.0.1", database="medicine_adherence",
    ).render_as_string(hide_password=False))
    engine = MagicMock()
    connection = engine.connect.return_value
    connection.__enter__.return_value = connection
    connection.execute.return_value.one.return_value = (
        "medicine_app", "medicine_adherence"
    )
    with patch.object(helper, "create_engine", return_value=engine) as create_engine:
        assert helper.verify_tcp_login(url, password)
    checked_url = create_engine.call_args.args[0]
    assert checked_url.password == password
    assert create_engine.call_args.kwargs["connect_args"] == {"connect_timeout": 5}
    output = capsys.readouterr().out
    assert password not in output
    assert "medicine_app" in output


@pytest.mark.parametrize(
    ("error", "expected"),
    [
        (RuntimeError("FATAL: password authentication failed for user medicine_app"), "password was rejected"),
        (RuntimeError("connection refused"), "connection refused"),
        (RuntimeError("connection timed out"), "timed out"),
    ],
)
def test_tcp_error_diagnosis_is_specific_and_sanitized(error, expected):
    message = helper.classify_tcp_error(error)
    assert expected in message
    assert "secret" not in message.lower()


def test_sqlalchemy_password_authentication_error_is_classified():
    original = RuntimeError('FATAL: password authentication failed for user "medicine_app"')
    wrapped = sqlalchemy_exc.OperationalError("connect", {}, original)
    assert "password was rejected" in helper.classify_tcp_error(wrapped)


def test_url_parsing_with_reserved_password_characters_round_trips():
    password = "Ab9!@:$%?#/[]\\;=+"
    url = URL.create(
        "postgresql+psycopg", username="medicine_app", password=password,
        host="127.0.0.1", port=5432, database="medicine_adherence",
    )
    parsed = make_url(url.render_as_string(hide_password=False))
    assert parsed.password == password
    # SQLAlchemy receives a structured URL, not manually concatenated URL text.
    rebuilt = URL.create(
        parsed.drivername, username=parsed.username, password=parsed.password,
        host=parsed.host, port=parsed.port, database=parsed.database,
        query=parsed.query,
    )
    assert rebuilt.password == password


def test_main_updates_and_verifies_the_decoded_env_password(tmp_path, capsys):
    password = "Exact9!%:@/[]\\;#?"
    raw_url = URL.create(
        "postgresql+psycopg", username="medicine_app", password=password,
        host="127.0.0.1", port=5432, database="medicine_adherence",
    ).render_as_string(hide_password=False)
    env_path = tmp_path / ".env"
    env_path.write_text(f'DATABASE_URL="{raw_url}"\nJWT_SECRET_KEY="unchanged"\n')

    with (
        patch.object(helper, "ENV_FILE", env_path),
        patch.object(helper, "check_tcp_login", return_value=(False, "TCP server reachable, but the medicine_app password was rejected")) as check,
        patch.object(helper, "compare_socket_and_tcp_cluster", return_value=(True, "same cluster")),
        patch.object(helper, "update_role_password", return_value=0) as update,
        patch.object(helper, "verify_tcp_login", return_value=True) as verify,
    ):
        assert helper.main() == 0

    assert update.call_args.args[0] == password
    assert check.call_args.args[1] == password
    assert verify.call_args.args[1] == password
    assert password not in capsys.readouterr().out


@pytest.mark.parametrize("password", [None, "", "line\nbreak", "nul\x00byte"])
def test_password_validation_rejects_empty_or_control_characters(password):
    with pytest.raises(ValueError):
        helper.validate_password(password)
