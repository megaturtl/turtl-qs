#!/usr/bin/env python3
"""Read XWayland window icons for the workspace widget."""

import base64
import json
import os
import signal
import struct
from io import BytesIO

from PIL import Image
from Xlib import Xatom, display, error

MAX_DIMENSION = 1024
MAX_PROPERTY_ITEMS = 2 * 1024 * 1024
MAX_TOTAL_PROPERTY_ITEMS = 8 * MAX_PROPERTY_ITEMS
MAX_ICONS = 128
MAX_WINDOWS = 16384


def decode_icon_property(values):
    """Select the smallest icon large enough for the 32px workspace preview."""
    if len(values) > MAX_PROPERTY_ITEMS:
        return None
    best = None
    best_rank = None
    offset = 0
    while offset < len(values):
        if len(values) - offset < 2:
            return None
        width, height = values[offset], values[offset + 1]
        if not (0 < width <= MAX_DIMENSION and 0 < height <= MAX_DIMENSION):
            return None
        offset += 2
        size = width * height
        if size > len(values) - offset:
            return None
        if width >= 32 and height >= 32:
            rank = (0, width * height, max(width, height))
        else:
            rank = (1, -width * height, -max(width, height))
        if best_rank is None or rank < best_rank:
            best = (width, height, offset)
            best_rank = rank
        offset += size
    if best is None:
        return None
    width, height, offset = best
    pixels = struct.pack(
        f"<{width * height}I", *values[offset : offset + width * height]
    )
    return Image.frombytes("RGBA", (width, height), pixels, "raw", "BGRA")


def property_values(window, atom, expected_type, limit):
    prop = window.get_property(atom, expected_type, 0, limit)
    if (
        prop is None
        or prop.property_type != expected_type
        or prop.format != 32
        or prop.bytes_after
    ):
        return []
    return prop.value


def read_window_icons():
    if not os.environ.get("DISPLAY"):
        return {}
    try:
        connection = display.Display()
    except (error.DisplayConnectionError, error.DisplayNameError):
        return {}

    try:
        clients_atom, pid_atom, icon_atom = (
            connection.intern_atom(name, only_if_exists=True)
            for name in ("_NET_CLIENT_LIST", "_NET_WM_PID", "_NET_WM_ICON")
        )
        if not all((clients_atom, pid_atom, icon_atom)):
            return {}
        windows = property_values(
            connection.screen().root, clients_atom, Xatom.WINDOW, MAX_WINDOWS
        )
        candidates = {}
        for xid in windows:
            try:
                window = connection.create_resource_object("window", xid)
                pid = property_values(window, pid_atom, Xatom.CARDINAL, 1)
                if len(pid) == 1 and pid[0]:
                    candidates[pid[0]] = None if pid[0] in candidates else window
            except error.BadWindow:
                continue

        icons = {}
        remaining = MAX_TOTAL_PROPERTY_ITEMS
        for pid, window in candidates.items():
            if not remaining or len(icons) == MAX_ICONS:
                break
            if window is None:
                continue
            try:
                wm_class = window.get_property(Xatom.WM_CLASS, Xatom.STRING, 0, 256)
                if wm_class is None or wm_class.format != 8 or wm_class.bytes_after:
                    continue
                parts = wm_class.value.split(b"\0")
                if len(parts) != 3 or not parts[1] or parts[2]:
                    continue
                prop = window.get_property(
                    icon_atom, Xatom.CARDINAL, 0, min(MAX_PROPERTY_ITEMS, remaining)
                )
                if prop is None or prop.property_type != Xatom.CARDINAL:
                    continue
                remaining -= (len(prop.value) * prop.format + 31) // 32
                if prop.format != 32 or prop.bytes_after:
                    continue
                image = decode_icon_property(prop.value)
                if image is not None:
                    image.thumbnail((32, 32), Image.Resampling.LANCZOS)
                    png = BytesIO()
                    image.save(png, format="PNG")
                    icons[str(pid)] = {
                        "wmClass": parts[1].decode("utf-8", errors="replace"),
                        "source": "data:image/png;base64,"
                        + base64.b64encode(png.getvalue()).decode("ascii"),
                    }
            except error.BadWindow:
                # A window can close between enumeration and a property request.
                continue
        return icons
    finally:
        connection.close()


if __name__ == "__main__":
    # Death of the launching shell must not remove the scan deadline.
    signal.alarm(2)
    print(json.dumps(read_window_icons(), separators=(",", ":")))
