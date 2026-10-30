# Waypoints

A shared list of interesting and useful spots (anchorages, fuel, dog-friendly
shore access, etc.) that shows up as an overlay in [AvNav](https://www.wellenvogel.net/software/avnav/docs/beschreibung.html?lang=en)
on OpenPlotter.

`waypoints.csv` is converted to an overlay and sync'd on the hour - so whatever waypoints are in here show up on your plotter.

![Anchor icon on the AvNav chart](readme-images/icon-on-map.png)

Tap a waypoint to see its name and description:

![Waypoint info in AvNav](readme-images/waypoint-info.png)

## How it works

- `csv_to_gpx.py` converts `waypoints.csv` to `waypoints.gpx`, turning
  coordinates into decimal degrees and downloading an icon for each emoji
  symbol into `waypoints-icons.zip`.
- `sync.sh` fetches `main` and, if anything changed, rebuilds both files into
  `/home/pi/avnav/data/overlays/`. If the boat is offline it keeps the
  existing files and tries again next hour.
- `bob423.sh` (optional) downloads the latest Bob423 ICW tracks into the same
  overlays directory once a day. See [Bob423 tracks](#bob423-tracks-optional).
- `install.sh` sets the above up on the Pi.

## Install (on an OpenPlotter Pi)

1. On the Pi, run the installer as any user with `sudo`:

   ```sh
   curl -fsSL https://raw.githubusercontent.com/pirate-baby/Waypoints/main/install.sh | bash
   ```

   This clones the repo to `/home/pi/Waypoints`, adds an hourly cron job for
   the `pi` user (the user AvNav runs as), and builds the overlay. It's safe
   to re-run. If AvNav runs as a different user, end the command with
   `| AVNAV_USER=<user> bash` instead.
   
2. Add the waypoints layer in AvNav:
   go to layers (the sideways squares icon) -> "Edit" -> "Insert Before" -> click on the "Overlay Name" line -> select "Waypoints.gpx" -> check the box to make it visible -> "Save"
3. Set the waypoints layer **icon file** to `waypoints-icons.zip`:
   go to layers (the sideways squares icon) -> "Edit" -> select the pencil icon next to "waypoints.gpx" -> click the line next to "Icon File" -> select "waypoints-icons.zip" -> "Ok" -> "Save"

### Troubleshooting
To force a rebuild when nothing has changed, delete the build stamp first:

```sh
sudo -u pi rm -f /home/pi/Waypoints/.last-built && sudo -u pi /home/pi/Waypoints/sync.sh
```

Problems (bad coordinates, failed icon downloads) are logged to
`/home/pi/Waypoints/sync.log`; the previous overlay stays in place until the
next good build.

## Bob423 tracks (optional)

[Bob423](https://bobicw.blogspot.com/p/bob423-long-tracks.html) publishes free
GPX tracks that follow the deepest water on the Atlantic ICW from Norfolk to
Miami, updated as shoaling changes. Install with `--bob` to add them to AvNav:

```sh
curl -fsSL https://raw.githubusercontent.com/pirate-baby/Waypoints/main/install.sh | bash -s -- --bob
```

This adds a daily cron job that downloads the current tracks into your AvNav
overlays directory as `bob423-norfolk-southport.gpx`,
`bob423-southport-savannah.gpx`, `bob423-savannah-titusville.gpx`,
`bob423-titusville-miami.gpx` and `bob423-side-tracks.gpx`. The filenames stay
the same across updates, so add the ones you want as layers once (same steps
as the waypoints layer) and they stay current. Re-running the installer
without `--bob` removes the cron job; the downloaded tracks stay until you
delete them. Logs go to `/home/pi/Waypoints/bob423.log`.

The tracks are Bob's work, for personal use only. Don't commit or redistribute
them, and read his [Rules of the Road](https://bob423.com/fb/RulesofRoad.pdf)
before relying on them.

## Symbols

Put an emoji in the `symbol` column and it's drawn on the chart as that icon.
Any emoji in [Twemoji 15.1](https://github.com/jdecked/twemoji) works. Some
handy ones:

| Emoji | Use for |
|-------|---------|
| ⚓ | Anchorage |
| ⛽ | Fuel |
| 🐕 | Dog-friendly shore access |
| 🍺 | Bar / restaurant |
| 🛒 | Groceries |
| 🔧 | Marine repair / chandlery |
| ⚠️ | Hazard / shoaling |
| 🏊 | Swimming |

Leave `symbol` blank to use AvNav's default point marker.

## Contributing

Add or edit rows in `waypoints.csv` and open a pull request.

| Column | Required | Example |
|--------|----------|---------|
| `name` | yes | `Wye River Anchorage` |
| `lat` | yes | `38°52.62'N` |
| `lon` | yes | `076°09.99'W` |
| `desc` | no | Notes shown when you tap the waypoint. Wrap in quotes if it contains commas. |
| `symbol` | no | `⚓` |
| `link` | no | `https://…` |

Coordinates can be degrees and decimal minutes (`38°52.62'N`), degrees,
minutes and seconds (`38°52'37"N`), space separated (`38 52.62 N`), or decimal
degrees (`38.877`, `-76.1665`).

Check your changes convert cleanly before opening the PR (Python 3, no extra
packages):

```sh
./csv_to_gpx.py
```

It prints the GPX, or lists every bad row with its line number. The same check
runs on every pull request, and the CSV is sanitized during conversion.
