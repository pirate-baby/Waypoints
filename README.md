# Waypoints

A shared list of interesting and useful spots (anchorages, fuel, dog-friendly
shore access…) that shows up as an overlay in [AvNav](https://www.wellenvogel.net/software/avnav/docs/beschreibung.html?lang=en)
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

## Install (on an OpenPlotter Pi)

1. Clone the repo:

   ```sh
   sudo -u pi git clone https://github.com/pirate-baby/Waypoints.git /home/pi/Waypoints
   ```

2. Add the hourly job to `pi`'s crontab (`sudo -u pi crontab -e`):

   ```
   0 * * * * /home/pi/Waypoints/sync.sh >> /home/pi/Waypoints/sync.log 2>&1
   ```

3. Run it once to generate the overlay now:

   ```sh
   sudo -u pi /home/pi/Waypoints/sync.sh
   ```

4. In AvNav, open the chart's overlay settings, add `waypoints.gpx`, and set
   **icon file** to `waypoints-icons.zip`.

To force a rebuild when nothing has changed, delete the build stamp first:

```sh
sudo -u pi rm -f /home/pi/Waypoints/.last-built && sudo -u pi /home/pi/Waypoints/sync.sh
```

Problems (bad coordinates, failed icon downloads) are logged to
`/home/pi/Waypoints/sync.log`; the previous overlay stays in place until the
next good build.

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

It prints the GPX, or lists every bad row with its line number.
