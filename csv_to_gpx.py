#!/usr/bin/env python3
"""Convert waypoints.csv into a GPX file for use as an AvNav overlay.

CSV columns: name, lat, lon, desc, symbol, link (desc/symbol/link optional).

Coordinates may be written as:
  37°49.40'N        degrees + decimal minutes
  37°49'24.0"N      degrees, minutes, seconds
  37 49.40 N        same, space separated
  37.8233 / -76.31  plain decimal degrees
A trailing (or leading) N/S/E/W sets the sign; S and W are negative.
"""

import argparse
import csv
import os
import re
import sys
import tempfile
from xml.etree import ElementTree as ET

GPX_NS = "http://www.topografix.com/GPX/1/1"

# Pulls out up to three numbers (deg, min, sec) and an optional hemisphere.
COORD_RE = re.compile(
    r"""^\s*
    (?P<hemi1>[NSEW])?\s*
    (?P<sign>[-+])?
    (?P<deg>\d+(?:\.\d+)?)\s*[°º:d ]?\s*
    (?:(?P<min>\d+(?:\.\d+)?)\s*['′m:]?\s*)?
    (?:(?P<sec>\d+(?:\.\d+)?)\s*(?:["″]|'')?\s*)?
    (?P<hemi2>[NSEW])?
    \s*$""",
    re.VERBOSE | re.IGNORECASE,
)


def to_decimal(value, axis):
    """Convert a coordinate string to decimal degrees.

    axis is "lat" or "lon"; used to validate the hemisphere and range.
    """
    m = COORD_RE.match(value)
    if not m:
        raise ValueError(f"unrecognised {axis} {value!r}")
    hemi1, hemi2 = m.group("hemi1"), m.group("hemi2")
    if hemi1 and hemi2:
        raise ValueError(f"{axis} {value!r} has two hemisphere letters")
    hemi = (hemi1 or hemi2 or "").upper()
    if hemi and m.group("sign"):
        raise ValueError(f"{axis} {value!r} has both a sign and a hemisphere")

    deg = float(m.group("deg"))
    minutes = float(m.group("min") or 0)
    seconds = float(m.group("sec") or 0)
    if minutes >= 60 or seconds >= 60:
        raise ValueError(f"{axis} {value!r} has minutes/seconds >= 60")
    decimal = deg + minutes / 60 + seconds / 3600

    allowed = "NS" if axis == "lat" else "EW"
    if hemi and hemi not in allowed:
        raise ValueError(f"{axis} {value!r} has hemisphere {hemi}, expected {allowed}")
    if hemi in ("S", "W") or m.group("sign") == "-":
        decimal = -decimal

    limit = 90 if axis == "lat" else 180
    if abs(decimal) > limit:
        raise ValueError(f"{axis} {value!r} is out of range")
    return round(decimal, 6)


def read_waypoints(csv_path):
    waypoints = []
    errors = []
    with open(csv_path, newline="", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f, skipinitialspace=True)
        reader.fieldnames = [h.strip().lower() for h in reader.fieldnames or []]
        missing = {"name", "lat", "lon"} - set(reader.fieldnames)
        if missing:
            raise SystemExit(f"{csv_path}: missing column(s): {', '.join(sorted(missing))}")
        # Line 1 is the header, so data starts on line 2.
        for line, row in enumerate(reader, start=2):
            row = {k: (v or "").strip() for k, v in row.items() if k}
            if not any(row.values()):
                continue
            try:
                if not row["name"]:
                    raise ValueError("empty name")
                waypoints.append(
                    {
                        "name": row["name"],
                        "lat": to_decimal(row["lat"], "lat"),
                        "lon": to_decimal(row["lon"], "lon"),
                        "desc": row.get("desc", ""),
                        "sym": row.get("symbol", ""),
                        "link": row.get("link", ""),
                    }
                )
            except ValueError as e:
                errors.append(f"{csv_path}:{line}: {e}")
    if errors:
        raise SystemExit("\n".join(errors))
    return waypoints


def build_gpx(waypoints):
    ET.register_namespace("", GPX_NS)
    gpx = ET.Element(f"{{{GPX_NS}}}gpx", version="1.1", creator="Waypoints csv_to_gpx.py")
    for wp in waypoints:
        wpt = ET.SubElement(gpx, f"{{{GPX_NS}}}wpt", lat=f"{wp['lat']:.6f}", lon=f"{wp['lon']:.6f}")
        ET.SubElement(wpt, f"{{{GPX_NS}}}name").text = wp["name"]
        if wp["desc"]:
            ET.SubElement(wpt, f"{{{GPX_NS}}}desc").text = wp["desc"]
        if wp["link"]:
            ET.SubElement(wpt, f"{{{GPX_NS}}}link", href=wp["link"])
        if wp["sym"]:
            ET.SubElement(wpt, f"{{{GPX_NS}}}sym").text = wp["sym"]
    ET.indent(gpx)
    return ET.ElementTree(gpx)


def write_atomic(tree, out_path):
    """Write to a temp file in the same directory, then rename over the target
    so AvNav never sees a half-written file."""
    out_dir = os.path.dirname(os.path.abspath(out_path))
    fd, tmp = tempfile.mkstemp(dir=out_dir, prefix=".waypoints-", suffix=".gpx")
    try:
        with os.fdopen(fd, "wb") as f:
            tree.write(f, encoding="utf-8", xml_declaration=True)
        os.chmod(tmp, 0o644)
        os.replace(tmp, out_path)
    except BaseException:
        os.unlink(tmp)
        raise


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("csv", nargs="?", default=os.path.join(here, "waypoints.csv"))
    p.add_argument("-o", "--output", default="-", help="output .gpx path (default: stdout)")
    args = p.parse_args()

    tree = build_gpx(read_waypoints(args.csv))
    if args.output == "-":
        tree.write(sys.stdout.buffer, encoding="utf-8", xml_declaration=True)
        sys.stdout.buffer.write(b"\n")
    else:
        write_atomic(tree, args.output)
        print(f"wrote {len(tree.getroot())} waypoints to {args.output}", file=sys.stderr)


if __name__ == "__main__":
    main()
