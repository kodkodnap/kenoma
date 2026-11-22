"""Cliente mínimo para el addon BlenderMCP (socket JSON en localhost:9876).

Uso:
    python scripts/blender_mcp.py get_scene_info
    python scripts/blender_mcp.py execute_code "import bpy; print(len(bpy.data.objects))"

El addon espera un JSON por línea con {"type": ..., "params": {...}} y responde
otro JSON por línea.
"""

from __future__ import annotations

import json
import socket
import sys

HOST = "127.0.0.1"
PORT = 9876
TIMEOUT = 120.0


def send(payload: dict) -> dict:
    with socket.create_connection((HOST, PORT), timeout=TIMEOUT) as sock:
        sock.settimeout(TIMEOUT)
        sock.sendall((json.dumps(payload) + "\n").encode("utf-8"))
        chunks: list[bytes] = []
        while True:
            chunk = sock.recv(65536)
            if not chunk:
                break
            chunks.append(chunk)
            try:
                return json.loads(b"".join(chunks).decode("utf-8"))
            except json.JSONDecodeError:
                continue
        raw = b"".join(chunks).decode("utf-8", "replace")
        return {"status": "raw", "result": {"raw": raw}}


NO_PARAM_TYPES = {
    "get_scene_info",
    "get_polyhaven_status",
    "get_hyper3d_status",
    "get_sketchfab_status",
}


def explain(parts: list[str]) -> dict:
    """Acepta un tipo sin parámetros, un JSON completo o código Python suelto."""
    head = parts[0].strip()
    rest = " ".join(parts[1:]).strip()
    if head in NO_PARAM_TYPES and not rest:
        return {"type": head, "params": {}}
    if head == "execute_code":
        return {"type": head, "params": {"code": rest}}
    if head in {"get_object_info", "get_viewport_screenshot"}:
        return {"type": head, "params": json.loads(rest or "{}")}
    joined = " ".join(parts).strip()
    if joined.startswith("{"):
        return json.loads(joined)
    return {"type": "execute_code", "params": {"code": joined}}


def main() -> int:
    args = sys.argv[1:]
    if not args:
        print(__doc__.strip())
        return 2
    payload = explain(args)
    response = send(payload)
    print(json.dumps(response, indent=2, ensure_ascii=False))
    return 0 if response.get("status") == "success" else 1


if __name__ == "__main__":
    raise SystemExit(main())
