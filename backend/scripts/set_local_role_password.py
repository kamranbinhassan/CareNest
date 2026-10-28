"""Set the local development role password from backend/.env safely.

Run as the normal project user. sudo is used only for read-only local cluster
diagnostics and a fixed SQL operation as the postgres OS account. The password
is sent over stdin and safely quoted by psycopg; it never appears in arguments
or output.
"""

from pathlib import Path
import re
import shutil
import subprocess
import sys

from dotenv import dotenv_values
from sqlalchemy import create_engine, text
from sqlalchemy.engine import URL, make_url


BACKEND_DIR = Path(__file__).resolve().parents[1]
ENV_FILE = BACKEND_DIR / ".env"
SYSTEM_PYTHON = "/usr/bin/python3"
PASSWORD_WORKER_CODE = r'''
import sys

try:
    import psycopg
    from psycopg import sql
    password = sys.stdin.readline().rstrip("\n")
    if not password or any(ord(char) < 32 or ord(char) == 127 for char in password):
        raise ValueError("invalid password input")
    statement = sql.SQL("ALTER ROLE {} PASSWORD {}").format(
        sql.Identifier("medicine_app"), sql.Literal(password)
    )
    with psycopg.connect("dbname=postgres host=/var/run/postgresql user=postgres") as conn:
        with conn.cursor() as cursor:
            cursor.execute(statement)
except Exception:
    print("Could not update the medicine_app role password; details hidden.", file=sys.stderr)
    raise SystemExit(1)
'''
SOCKET_IDENTITY_SQL = (
    "SELECT current_setting('data_directory'), current_setting('port'), "
    "(SELECT system_identifier::text FROM pg_control_system()), "
    "current_setting('listen_addresses')"
)


def validate_password(password: str | None) -> str:
    if not password or len(password) > 1024:
        raise ValueError("DATABASE_URL must contain a nonempty role password")
    if any(ord(character) < 32 or ord(character) == 127 for character in password):
        raise ValueError("Role password cannot contain control characters")
    return password


def classify_tcp_error(error: Exception) -> str:
    """Map DBAPI errors to sanitized diagnostic labels."""
    original = getattr(error, "orig", error)
    message = str(original).lower()
    if isinstance(error, ValueError):
        return "SQLAlchemy rejected the parsed DATABASE_URL configuration; credential details hidden"
    if getattr(original, "sqlstate", None) == "28P01" or "password authentication failed" in message:
        return "TCP server reachable, but the medicine_app password was rejected"
    if "connection refused" in message or "actively refused" in message:
        return "TCP connection refused at the configured address"
    if "timed out" in message or "timeout" in message:
        return "TCP connection timed out at the configured address"
    return f"TCP connection failed ({type(error).__name__}); details hidden"


def update_role_password(password: str) -> int:
    """Set only medicine_app's password, transmitting it only through stdin."""
    validate_password(password)
    # Run a small worker with system Python, avoiding execution of the venv
    # under sudo. The worker uses psycopg SQL composition and reads the password
    # only from stdin; no secret is placed in argv or the environment.
    result = subprocess.run(
        ["sudo", "-u", "postgres", SYSTEM_PYTHON, "-c", PASSWORD_WORKER_CODE],
        input=f"{password}\n",
        text=True,
        check=False,
    )
    if result.returncode != 0:
        print("The medicine_app password update command failed; details hidden.", file=sys.stderr)
    return result.returncode


def check_tcp_login(url, password: str) -> tuple[bool, str]:
    """Check the exact SQLAlchemy URL credentials and return a sanitized result."""
    # Compose with SQLAlchemy's URL API so reserved password characters are
    # encoded correctly exactly as they are for the app and Alembic.
    connection_url = URL.create(
        drivername=url.drivername,
        username=url.username,
        password=password,
        host=url.host,
        port=url.port,
        database=url.database,
        query=url.query,
    )
    engine = None
    try:
        engine = create_engine(connection_url, connect_args={"connect_timeout": 5})
        with engine.connect() as connection:
            username, database = connection.execute(
                text("SELECT current_user, current_database()")
            ).one()
    except Exception as exc:
        return False, classify_tcp_error(exc)
    finally:
        if engine is not None:
            engine.dispose()
    if (username, database) != ("medicine_app", "medicine_adherence"):
        return False, "TCP login returned an unexpected role or database"
    return True, "TCP login verified for medicine_app on medicine_adherence"


def verify_tcp_login(url, password: str) -> bool:
    """Print a sanitized TCP result and return whether the credentials work."""
    success, diagnosis = check_tcp_login(url, password)
    stream = sys.stdout if success else sys.stderr
    print(f"TCP login diagnosis: {diagnosis}.", file=stream)
    return success


def _cluster_configured_for_port(port: int) -> tuple[str, str, str] | None:
    """Return (status, version, data_directory) from Debian pg_lsclusters."""
    try:
        result = subprocess.run(
            ["pg_lsclusters", "--no-header"],
            capture_output=True,
            text=True,
            check=False,
        )
    except OSError:
        return None
    if result.returncode != 0:
        return None
    for line in result.stdout.splitlines():
        fields = line.split()
        if len(fields) >= 6 and fields[2] == str(port):
            return fields[3], fields[0], fields[5]
    return None


def _socket_cluster_identity() -> tuple[str, str, str, str] | None:
    """Read local cluster identity using only the postgres OS account."""
    command = [
        "sudo", "-u", "postgres", "psql", "-X", "-A", "-t", "-F", "\t",
        "-h", "/var/run/postgresql", "-p", "5432", "-d", "postgres",
        "-v", "ON_ERROR_STOP=1", "-c", SOCKET_IDENTITY_SQL,
    ]
    try:
        result = subprocess.run(command, capture_output=True, text=True, check=False)
    except OSError:
        return None
    if result.returncode != 0:
        return None
    fields = result.stdout.strip().split("\t")
    if len(fields) != 4:
        return None
    return fields[0], fields[1], fields[2], fields[3]


def _tcp_listener_pids(port: int) -> set[int] | None:
    """Return process IDs owning TCP listeners on port, or None if unknown."""
    try:
        result = subprocess.run(
            ["sudo", "ss", "-ltnpH", f"sport = :{port}"],
            capture_output=True,
            text=True,
            check=False,
        )
    except OSError:
        return None
    if result.returncode != 0:
        return None
    pids = {int(value) for value in re.findall(r"pid=(\d+)", result.stdout)}
    return pids or None


def _postmaster_pid(data_directory: str) -> int | None:
    """Read the postmaster PID through the postgres OS account."""
    try:
        result = subprocess.run(
            ["sudo", "-u", "postgres", "head", "-n", "1", f"{data_directory}/postmaster.pid"],
            capture_output=True,
            text=True,
            check=False,
        )
    except OSError:
        return None
    if result.returncode != 0:
        return None
    try:
        return int(result.stdout.strip())
    except ValueError:
        return None


def compare_socket_and_tcp_cluster(port: int = 5432) -> tuple[bool | None, str]:
    """Compare socket identity with the cluster registered for the TCP port."""
    cluster = _cluster_configured_for_port(port)
    if cluster is None:
        return None, "pg_lsclusters has no identifiable cluster for TCP port 5432"
    state, version, cluster_directory = cluster
    if state.lower() != "online":
        return False, f"pg_lsclusters reports the port-5432 cluster as {state}"

    socket = _socket_cluster_identity()
    if socket is None:
        return None, "could not query the local PostgreSQL socket cluster identity"
    socket_directory, socket_port, socket_system_id, listen_addresses = socket
    if socket_port != str(port):
        return False, "local socket psql connected to a different PostgreSQL port"
    if Path(socket_directory).resolve() != Path(cluster_directory).resolve():
        return False, "local socket and the cluster registered on TCP port 5432 use different data directories"
    if not any(address.strip() in {"*", "localhost", "127.0.0.1"} for address in listen_addresses.split(",")):
        return False, "port-5432 cluster is not configured to listen on 127.0.0.1"

    listener_pids = _tcp_listener_pids(port)
    postmaster_pid = _postmaster_pid(cluster_directory)
    if listener_pids is None or postmaster_pid is None:
        return None, "could not identify the process owning TCP port 5432 and compare it with the socket cluster"
    if postmaster_pid not in listener_pids:
        return False, "TCP port 5432 is owned by a different process than the local socket PostgreSQL cluster"

    controldata = Path(f"/usr/lib/postgresql/{version}/bin/pg_controldata")
    if not controldata.is_file():
        found = shutil.which("pg_controldata")
        if found:
            controldata = Path(found)
    if not controldata.is_file():
        return None, "pg_controldata is unavailable for a system-identifier comparison"
    try:
        control = subprocess.run(
            ["sudo", "-u", "postgres", str(controldata), cluster_directory],
            capture_output=True,
            text=True,
            check=False,
        )
    except OSError:
        return None, "could not read the cluster registered for TCP port 5432"
    match = re.search(r"^Database system identifier:\s*(\d+)\s*$", control.stdout, re.M)
    if control.returncode != 0 or not match:
        return None, "could not read the TCP cluster system identifier"
    if match.group(1) != socket_system_id:
        return False, "local socket and TCP port 5432 have different PostgreSQL system identifiers"
    return True, "local socket and TCP port 5432 identify the same PostgreSQL cluster"


def main() -> int:
    values = dotenv_values(ENV_FILE)
    raw_url = values.get("DATABASE_URL")
    if not raw_url:
        print("backend/.env has no DATABASE_URL", file=sys.stderr)
        return 2
    try:
        url = make_url(raw_url)
    except Exception:
        print("DATABASE_URL parsing failed; credential values are hidden", file=sys.stderr)
        return 2
    if (url.username, url.database, url.host) != (
        "medicine_app",
        "medicine_adherence",
        "127.0.0.1",
    ):
        print("Refusing to alter a role outside the expected local development target", file=sys.stderr)
        return 2
    try:
        password = validate_password(url.password)
    except ValueError as exc:
        print(str(exc), file=sys.stderr)
        return 2

    tcp_ok, tcp_diagnosis = check_tcp_login(url, password)
    if tcp_ok:
        print(f"{tcp_diagnosis}; no password change was needed.")
        return 0
    print(f"Initial TCP check: {tcp_diagnosis}.")
    if "password was rejected" not in tcp_diagnosis:
        print("No role password was changed because the configured TCP endpoint is unavailable or unexpected.", file=sys.stderr)
        return 5

    same_cluster, diagnosis = compare_socket_and_tcp_cluster(url.port or 5432)
    print(f"Cluster check: {diagnosis}.")
    if same_cluster is not True:
        print("No role password was changed; resolve the cluster mismatch or unavailable identity check first.", file=sys.stderr)
        return 4

    return_code = update_role_password(password)
    if return_code != 0:
        return return_code
    if not verify_tcp_login(url, password):
        print(
            "The role update command completed on the verified socket cluster, "
            "but TCP still rejected the .env credential; migrations were not run.",
            file=sys.stderr,
        )
        return 3
    print("Local medicine_app role password updated and verified from backend/.env.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
