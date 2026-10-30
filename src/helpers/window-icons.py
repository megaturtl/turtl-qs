#!/usr/bin/env python3
"""Read XWayland window icons for the workspace widget."""

import base64
import json
import os
import struct
from io import BytesIO

from PIL import Image
from Xlib import Xatom, display, error

MAX_DIMENSION = 1024
MAX_PROPERTY_ITEMS = 2 * 1024 * 1024
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
        icons = {}
        for xid in windows:
            try:
                window = connection.create_resource_object("window", xid)
                pid = property_values(window, pid_atom, Xatom.CARDINAL, 1)
                if len(pid) != 1 or not pid[0] or str(pid[0]) in icons:
                    continue
                values = property_values(
                    window, icon_atom, Xatom.CARDINAL, MAX_PROPERTY_ITEMS
                )
                image = decode_icon_property(values)
                if image is not None:
                    png = BytesIO()
                    image.save(png, format="PNG")
                    icons[str(pid[0])] = "data:image/png;base64," + base64.b64encode(
                        png.getvalue()
                    ).decode("ascii")
            except error.BadWindow:
                # A window can close between enumeration and a property request.
                continue
        return icons
    finally:
        connection.close()


if __name__ == "__main__":
    print(json.dumps(read_window_icons(), separators=(",", ":")))
