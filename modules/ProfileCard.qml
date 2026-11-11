import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../config"
import "../components"
import "../services"

Item {
    id: root

    width: 688
    height: 320
    clip: true

    readonly property string userName: Quickshell.env("USER") || "user"

    // Calendar Navigation & Selection State
    property int viewYear: (new Date()).getFullYear()
    property int viewMonth: (new Date()).getMonth()
    property int yearBase: Math.floor(viewYear / 10) * 10
    property string selectedDateKey: formatDateKey((new Date()).getFullYear(), (new Date()).getMonth(), (new Date()).getDate())
    property bool monthPickerOpen: false
    property bool yearPickerOpen: false

    readonly property var monthNames: ["Jan", "Feb", "Mar", "Apr", "Mei", "Jun", "Jul", "Agu", "Sep", "Okt", "Nov", "Des"]
    readonly property var indoMonthsFull: ["Januari", "Februari", "Maret", "April", "Mei", "Juni", "Juli", "Agustus", "September", "Oktober", "November", "Desember"]
    readonly property var indoDaysShort: ["Min", "Sen", "Sel", "Rab", "Kam", "Jum", "Sab"]
    readonly property var indoDaysFull: ["Minggu", "Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu"]

    readonly property string todayKey: formatDateKey(sysClock.date.getFullYear(), sysClock.date.getMonth(), sysClock.date.getDate())
    readonly property bool isViewingCurrentMonth: {
        const now = sysClock.date;
        return root.viewYear === now.getFullYear() && root.viewMonth === now.getMonth();
    }

    readonly property string heroTimeText: {
        const d = sysClock.date;
        const hh = d.getHours() < 10 ? `0${d.getHours()}` : `${d.getHours()}`;
        const mm = d.getMinutes() < 10 ? `0${d.getMinutes()}` : `${d.getMinutes()}`;
        return `${hh}:${mm}`;
    }

    readonly property string heroGreetingText: {
        const h = sysClock.date.getHours();
        const greet = h < 11 ? "Selamat Pagi" : (h < 15 ? "Selamat Siang" : (h < 18 ? "Selamat Sore" : "Selamat Malam"));
        return `${greet}, ${root.userName}`;
    }

    readonly property string heroFullDateText: {
        const d = sysClock.date;
        return `${root.indoDaysFull[d.getDay()] ?? ""}, ${d.getDate()} ${root.indoMonthsFull[d.getMonth()] ?? ""} ${d.getFullYear()}`;
    }

    // Marked Dates & Events Map (Format: { "YYYY-MM-DD": "Deskripsi Acara" })
    property var markedDates: []
    property var eventsMap: ({})
    property int eventsVersion: 0
    property string lastNotifiedDate: ""

    // Active Event Editor State
    property string activeEditDateKey: ""
    property string activeEditDateLabel: ""
    property bool eventEditorOpen: false
    property string hoveredDateKey: ""
    property string storageError: ""

    readonly property int totalEventCount: {
        root.eventsVersion;
        const set = new Set(root.markedDates ?? []);
        for (const k in root.eventsMap) {
            if (root.eventsMap[k] && String(root.eventsMap[k]).trim().length > 0) set.add(k);
        }
        return set.size;
    }

    readonly property string inspectedDateKey: hoveredDateKey.length > 0 ? hoveredDateKey : selectedDateKey
    readonly property string inspectedDayNum: {
        const parts = inspectedDateKey.split("-");
        return parts.length === 3 ? String(parseInt(parts[2], 10)) : "";
    }
    readonly property string inspectedShortDate: {
        const parts = inspectedDateKey.split("-");
        if (parts.length !== 3) return "";
        const m = parseInt(parts[1], 10) - 1;
        const d = parseInt(parts[2], 10);
        return `${d} ${root.monthNames[m] ?? ""}`;
    }
    readonly property string inspectedEventNote: {
        root.eventsVersion;
        return getEvent(inspectedDateKey);
    }
    readonly property bool inspectedHasMark: {
        root.eventsVersion;
        return hasEvent(inspectedDateKey);
    }

    // Real scheduled dates under the active row (never synthetic placeholder items)
    readonly property var secondaryAgendaRows: {
        root.eventsVersion;
        const keys = [...new Set([...(root.markedDates ?? []), ...Object.keys(root.eventsMap ?? {})])]
            .filter(k => k && k !== root.inspectedDateKey && hasEvent(k))
            .sort();
        const upcoming = keys.filter(k => k >= root.todayKey);
        const past = keys.filter(k => k < root.todayKey);
        return [...upcoming, ...past].slice(0, 2).map(k => {
            const p = k.split("-");
            const y = parseInt(p[0], 10);
            const m = parseInt(p[1], 10) - 1;
            const d = parseInt(p[2], 10);
            const note = getEvent(k);
            return {
                dateKey: k,
                year: y,
                month: m,
                badge: String(d),
                title: `${d} ${root.monthNames[m] ?? ""}`,
                subtitle: note.length > 0 ? note : "Ditandai"
            };
        });
    }

    // Live Weather State (Saved Manual / GPS / GeoClue2 / IP + Open-Meteo)
    property bool weatherReady: false
    property bool weatherLoading: false
    property bool weatherError: false
    property string weatherMode: "auto" // "auto" | "manual"
    property string weatherSource: "" // "manual" | "gpsd" | "geoclue" | "ip"
    property string weatherCity: ""
    property string weatherLabel: ""
    property real weatherLat: NaN
    property real weatherLon: NaN
    property int weatherTemp: 0
    property int weatherFeelsLike: 0
    property int weatherHumidity: 0
    property int weatherWind: 0
    property int weatherCode: 3
    property bool weatherIsDay: true
    property real _weatherLastFetchMs: 0
    property bool _weatherGotPayload: false
    property int _weatherReqSeq: 0
    property int _weatherActiveReqId: 0
    property bool _weatherPendingForce: false
    property bool weatherLocEditorOpen: false
    property bool weatherLocSearching: false
    property string weatherLocError: ""
    property bool _locGotPayload: false
    readonly property string weatherLocPath: `${Quickshell.env("HOME")}/.config/quickshell/sora/config/weather_location.json`

    readonly property string weatherSourceLabel: {
        if (weatherSource === "manual" || weatherMode === "manual") return "Lokasi sendiri";
        if (weatherSource === "gpsd") return "GPS sistem (gpsd)";
        if (weatherSource === "geoclue") return "GeoClue2 (< 2 km)";
        if (weatherSource === "ip") return "Perkiraan IP (kurang akurat)";
        return "Otomatis";
    }

    function weatherIconFor(code: int, isDay: bool): string {
        if (code <= 1) return isDay ? "wb_sunny" : "dark_mode";
        if (code === 2) return isDay ? "partly_cloudy_day" : "partly_cloudy_night";
        if (code === 3) return "cloud";
        if (code === 45 || code === 48) return "foggy";
        if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) return "rainy";
        if ((code >= 71 && code <= 77) || code === 85 || code === 86) return "ac_unit";
        if (code >= 95) return "thunderstorm";
        return "cloud";
    }

    function weatherLabelFor(code: int): string {
        if (code === 0) return "Cerah";
        if (code === 1) return "Cerah berawan";
        if (code === 2) return "Berawan sebagian";
        if (code === 3) return "Mendung";
        if (code === 45 || code === 48) return "Berkabut";
        if (code >= 51 && code <= 57) return "Gerimis";
        if (code === 61 || code === 80) return "Hujan ringan";
        if (code === 63 || code === 81) return "Hujan";
        if (code === 65 || code === 67 || code === 82) return "Hujan deras";
        if ((code >= 71 && code <= 77) || code === 85 || code === 86) return "Salju";
        if (code >= 95) return "Badai petir";
        return "Berawan";
    }

    function loadWeatherLocJson(raw: string): bool {
        const trimmed = String(raw ?? "").trim();
        if (trimmed.length === 0) return false;
        try {
            const obj = JSON.parse(trimmed);
            if (!obj || typeof obj !== "object" || Array.isArray(obj)) return false;
            if (obj.mode === "manual" && typeof obj.lat === "number" && isFinite(obj.lat)
                    && typeof obj.lon === "number" && isFinite(obj.lon)) {
                const changed = weatherMode !== "manual"
                    || Math.abs(weatherLat - obj.lat) > 0.0001
                    || Math.abs(weatherLon - obj.lon) > 0.0001
                    || weatherCity !== String(obj.city ?? "");
                weatherMode = "manual";
                weatherSource = "manual";
                weatherLat = obj.lat;
                weatherLon = obj.lon;
                weatherCity = String(obj.city ?? `${obj.lat.toFixed(2)}, ${obj.lon.toFixed(2)}`);
                weatherLabel = String(obj.label ?? weatherCity);
                return changed;
            } else if (obj.mode === "auto") {
                const changed = weatherMode !== "auto";
                weatherMode = "auto";
                if (changed) {
                    weatherLat = NaN;
                    weatherLon = NaN;
                    weatherCity = "";
                    weatherLabel = "";
                    weatherSource = "";
                }
                return changed;
            }
        } catch (e) {}
        return false;
    }

    function saveWeatherLocation(mode: string, city: string, lat: real, lon: real, label: string): void {
        const payload = mode === "manual"
            ? { mode: "manual", city: city, lat: lat, lon: lon, label: label }
            : { mode: "auto" };
        Quickshell.execDetached([
            "python3", "-c",
            "import sys, pathlib; pathlib.Path(sys.argv[1]).write_text(sys.argv[2], encoding='utf-8')",
            weatherLocPath, JSON.stringify(payload)
        ]);
    }

    function openWeatherLocEditor(): void {
        monthPickerOpen = false;
        yearPickerOpen = false;
        closeEventEditor();
        weatherLocError = "";
        Config.centerPinned = true;
        Config.centerKeyboardFocus = true;
        weatherLocEditorOpen = true;
    }

    function closeWeatherLocEditor(): void {
        weatherLocEditorOpen = false;
        weatherLocSearching = false;
        weatherLocError = "";
        Config.centerKeyboardFocus = root.eventEditorOpen;
    }

    function useAutoWeatherLocation(): void {
        weatherMode = "auto";
        weatherSource = "";
        weatherLat = NaN;
        weatherLon = NaN;
        weatherCity = "";
        weatherLabel = "";
        weatherReady = false;
        weatherError = false;
        saveWeatherLocation("auto", "", NaN, NaN, "");
        closeWeatherLocEditor();
        refreshWeather(true);
    }

    function submitWeatherLocQuery(queryText: string): void {
        const trimmed = String(queryText ?? "").trim();
        if (trimmed.length === 0) {
            weatherLocError = "Masukkan nama kota/kecamatan atau koordinat lat, lon.";
            return;
        }
        if (resolveLocProc.running) return;
        weatherLocSearching = true;
        weatherLocError = "";
        _locGotPayload = false;
        resolveLocProc.command = [
            "python3", "-c",
            "import json, sys, urllib.parse, urllib.request\n" +
            "def g(u):\n" +
            "    req = urllib.request.Request(u, headers={'User-Agent': 'sora-shell/1.0'})\n" +
            "    with urllib.request.urlopen(req, timeout=5) as r:\n" +
            "        return json.loads(r.read().decode('utf-8'))\n" +
            "def rev(la, lo):\n" +
            "    try:\n" +
            "        r = g(f'https://api.bigdatacloud.net/data/reverse-geocode-client?latitude={la}&longitude={lo}&localityLanguage=id')\n" +
            "        loc = str(r.get('locality') or '').strip()\n" +
            "        ct = str(r.get('city') or '').strip()\n" +
            "        name = loc or ct or f'{la:.2f}, {lo:.2f}'\n" +
            "        lbl = f'{loc}, {ct}' if (loc and ct and loc != ct) else name\n" +
            "        return name, lbl\n" +
            "    except Exception:\n" +
            "        s = f'{la:.2f}, {lo:.2f}'\n" +
            "        return s, s\n" +
            "q = sys.argv[1].strip()\n" +
            "parts = [p for p in q.replace('°', ' ').replace(';', ' ').replace(',', ' ').split() if p]\n" +
            "if len(parts) == 2:\n" +
            "    try:\n" +
            "        la, lo = float(parts[0]), float(parts[1])\n" +
            "        if -90.0 <= la <= 90.0 and -180.0 <= lo <= 180.0:\n" +
            "            ct, lbl = rev(la, lo)\n" +
            "            print(json.dumps({'ok': True, 'lat': la, 'lon': lo, 'city': ct, 'label': lbl}))\n" +
            "            sys.exit(0)\n" +
            "    except ValueError:\n" +
            "        pass\n" +
            "try:\n" +
            "    om = g('https://geocoding-api.open-meteo.com/v1/search?name=' + urllib.parse.quote(q) + '&count=1&language=id')\n" +
            "    rs = om.get('results') or []\n" +
            "    if rs:\n" +
            "        r0 = rs[0]\n" +
            "        ct = str(r0.get('name') or q).strip()\n" +
            "        adm = str(r0.get('admin1') or '').strip()\n" +
            "        lbl = f'{ct}, {adm}' if (adm and adm != ct) else ct\n" +
            "        print(json.dumps({'ok': True, 'lat': float(r0['latitude']), 'lon': float(r0['longitude']), 'city': ct, 'label': lbl}))\n" +
            "        sys.exit(0)\n" +
            "    nom = g('https://nominatim.openstreetmap.org/search?q=' + urllib.parse.quote(q) + '&format=json&addressdetails=1&limit=5&accept-language=id')\n" +
            "    if nom:\n" +
            "        r0 = next((r for r in nom if r.get('class') in ('boundary', 'place')), nom[0])\n" +
            "        addr = r0.get('address') or {}\n" +
            "        ct = str(r0.get('name') or addr.get('city') or addr.get('town') or q).strip()\n" +
            "        st = str(addr.get('city') or addr.get('state') or '').strip()\n" +
            "        lbl = f'{ct}, {st}' if (st and st != ct) else ct\n" +
            "        print(json.dumps({'ok': True, 'lat': float(r0['lat']), 'lon': float(r0['lon']), 'city': ct, 'label': lbl}))\n" +
            "        sys.exit(0)\n" +
            "    print(json.dumps({'ok': False, 'error': 'Lokasi tidak ditemukan.'}))\n" +
            "except Exception:\n" +
            "    print(json.dumps({'ok': False, 'error': 'Gagal mencari lokasi.'}))",
            trimmed
        ];
        resolveLocProc.running = true;
    }

    function refreshWeather(force: bool): void {
        if (weatherProc.running) {
            if (force) {
                _weatherReqSeq++;
                _weatherPendingForce = true;
            }
            return;
        }
        const stale = (Date.now() - _weatherLastFetchMs) >= 900000;
        if (!force && weatherReady && !stale) return;
        weatherLoading = true;
        if (!weatherReady) weatherError = false;
        _weatherGotPayload = false;
        _weatherPendingForce = false;
        _weatherReqSeq++;
        _weatherActiveReqId = _weatherReqSeq;
        const modeArg = weatherMode === "manual" ? "manual" : "auto";
        const latArg = isNaN(weatherLat) ? "" : String(weatherLat);
        const lonArg = isNaN(weatherLon) ? "" : String(weatherLon);
        const cityArg = weatherCity ?? "";
        const labelArg = weatherLabel ?? "";
        weatherProc.command = [
            "python3", "-c",
            "import json, os, socket, subprocess, sys, urllib.request\n" +
            "def g(u, t=5):\n" +
            "    req = urllib.request.Request(u, headers={'User-Agent': 'sora-shell/1.0'})\n" +
            "    with urllib.request.urlopen(req, timeout=t) as r:\n" +
            "        return json.loads(r.read().decode('utf-8'))\n" +
            "def rev(la, lo):\n" +
            "    try:\n" +
            "        r = g(f'https://api.bigdatacloud.net/data/reverse-geocode-client?latitude={la}&longitude={lo}&localityLanguage=id', 4)\n" +
            "        loc = str(r.get('locality') or '').strip()\n" +
            "        ct = str(r.get('city') or '').strip()\n" +
            "        name = loc or ct or f'{la:.2f}, {lo:.2f}'\n" +
            "        lbl = f'{loc}, {ct}' if (loc and ct and loc != ct) else name\n" +
            "        return name, lbl\n" +
            "    except Exception:\n" +
            "        s = f'{la:.2f}, {lo:.2f}'\n" +
            "        return s, s\n" +
            "mode, lat_s, lon_s, city, lbl = sys.argv[1], sys.argv[2].strip(), sys.argv[3].strip(), sys.argv[4].strip(), sys.argv[5].strip()\n" +
            "src = 'manual' if mode == 'manual' else ''\n" +
            "lat, lon = None, None\n" +
            "if mode == 'manual' and lat_s and lon_s:\n" +
            "    lat, lon = float(lat_s), float(lon_s)\n" +
            "    if not city:\n" +
            "        city, lbl = rev(lat, lon)\n" +
            "if lat is None:\n" +
            "    try:\n" +
            "        with socket.create_connection(('127.0.0.1', 2947), timeout=0.25) as s:\n" +
            "            s.settimeout(1.2)\n" +
            "            s.sendall(b'?WATCH={\"enable\":true,\"json\":true}\\n')\n" +
            "            for _ in range(8):\n" +
            "                for line in s.recv(4096).decode('utf-8', 'ignore').splitlines():\n" +
            "                    obj = json.loads(line)\n" +
            "                    if obj.get('class') == 'TPV' and obj.get('lat') is not None and obj.get('lon') is not None:\n" +
            "                        lat, lon, src = float(obj['lat']), float(obj['lon']), 'gpsd'\n" +
            "                        city, lbl = rev(lat, lon)\n" +
            "                        break\n" +
            "                if lat is not None: break\n" +
            "    except Exception:\n" +
            "        pass\n" +
            "gc_fb = None\n" +
            "if lat is None and os.path.exists('/usr/lib/geoclue-2.0/demos/where-am-i'):\n" +
            "    try:\n" +
            "        env = dict(os.environ, LC_ALL='C')\n" +
            "        try:\n" +
            "            out = subprocess.run(['/usr/lib/geoclue-2.0/demos/where-am-i', '-t', '1'], env=env, text=True, capture_output=True, timeout=2.0).stdout or ''\n" +
            "        except subprocess.TimeoutExpired as e:\n" +
            "            out = e.stdout or ''\n" +
            "        gla = glo = gacc = None\n" +
            "        for ln in out.splitlines():\n" +
            "            if 'Latitude:' in ln: gla = float(ln.split(':')[1].strip().rstrip('°'))\n" +
            "            elif 'Longitude:' in ln: glo = float(ln.split(':')[1].strip().rstrip('°'))\n" +
            "            elif 'Accuracy:' in ln: gacc = float(ln.split(':')[1].strip().split()[0])\n" +
            "        if gla is not None and glo is not None:\n" +
            "            if gacc is not None and gacc <= 2000.0:\n" +
            "                lat, lon, src = gla, glo, 'geoclue'\n" +
            "                city, lbl = rev(lat, lon)\n" +
            "            else:\n" +
            "                gc_fb = (gla, glo)\n" +
            "    except Exception:\n" +
            "        pass\n" +
            "if lat is None:\n" +
            "    for u in ('https://ipwho.is/?fields=city,latitude,longitude', 'https://ipapi.co/json/', 'https://ipinfo.io/json'):\n" +
            "        try:\n" +
            "            d = g(u, 4)\n" +
            "            la, lo = d.get('latitude'), d.get('longitude')\n" +
            "            if (la is None or lo is None) and isinstance(d.get('loc'), str) and ',' in d['loc']:\n" +
            "                la, lo = d['loc'].split(',', 1)\n" +
            "            if la is not None and lo is not None:\n" +
            "                lat, lon, src = float(la), float(lo), 'ip'\n" +
            "                city = str(d.get('city') or 'Lokasi').strip()\n" +
            "                lbl = city\n" +
            "                break\n" +
            "        except Exception:\n" +
            "            pass\n" +
            "    if lat is None and gc_fb is not None:\n" +
            "        lat, lon, src = gc_fb[0], gc_fb[1], 'ip'\n" +
            "        city, lbl = rev(lat, lon)\n" +
            "if lat is None or lon is None:\n" +
            "    sys.exit(1)\n" +
            "w = g(f'https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&current=temperature_2m,apparent_temperature,relative_humidity_2m,is_day,weather_code,wind_speed_10m&timezone=auto')\n" +
            "c = w['current']\n" +
            "print(json.dumps({'city': city or 'Lokasi', 'label': lbl or city or 'Lokasi', 'source': src, 'lat': lat, 'lon': lon, 'temp': round(float(c['temperature_2m'])), 'feels': round(float(c.get('apparent_temperature', c['temperature_2m']))), 'hum': int(round(float(c['relative_humidity_2m']))), 'wind': round(float(c['wind_speed_10m'])), 'isDay': int(c.get('is_day', 1)) == 1, 'code': int(c.get('weather_code', 3))}))",
            modeArg, latArg, lonArg, cityArg, labelArg
        ];
        weatherProc.running = true;
    }

    FileView {
        id: weatherLocWatcher
        printErrors: false
        preload: true
        blockLoading: true
        path: root.weatherLocPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            if (root.loadWeatherLocJson(text())) {
                root.refreshWeather(true);
            }
        }
    }

    Timer {
        id: weatherTimer
        interval: 900000
        running: true
        repeat: true
        onTriggered: root.refreshWeather(true)
    }

    Process {
        id: resolveLocProc
        running: false
        stdout: SplitParser {
            onRead: data => {
                const raw = data.trim();
                if (raw.length === 0) return;
                try {
                    const obj = JSON.parse(raw);
                    root._locGotPayload = true;
                    if (obj && obj.ok) {
                        const ct = String(obj.city ?? "Lokasi");
                        const lbl = String(obj.label ?? ct);
                        const la = Number(obj.lat);
                        const lo = Number(obj.lon);
                        root.weatherMode = "manual";
                        root.weatherSource = "manual";
                        root.weatherCity = ct;
                        root.weatherLabel = lbl;
                        root.weatherLat = la;
                        root.weatherLon = lo;
                        root.saveWeatherLocation("manual", ct, la, lo, lbl);
                        root.closeWeatherLocEditor();
                        root.refreshWeather(true);
                    } else {
                        root.weatherLocError = String(obj?.error ?? "Lokasi tidak ditemukan.");
                    }
                } catch (e) {
                    root.weatherLocError = "Gagal membaca hasil lokasi.";
                }
            }
        }
        onExited: exitCode => {
            root.weatherLocSearching = false;
            if (!root._locGotPayload && root.weatherLocEditorOpen) {
                root.weatherLocError = "Gagal mencari lokasi.";
            }
        }
    }

    Process {
        id: weatherProc
        running: false
        stdout: SplitParser {
            onRead: data => {
                if (root._weatherActiveReqId !== root._weatherReqSeq) return;
                const raw = data.trim();
                if (raw.length === 0) return;
                try {
                    const obj = JSON.parse(raw);
                    if (obj && typeof obj.temp === "number") {
                        root.weatherCity = String(obj.city ?? "Lokasi");
                        root.weatherLabel = String(obj.label ?? root.weatherCity);
                        root.weatherSource = String(obj.source ?? root.weatherMode);
                        root.weatherLat = Number(obj.lat);
                        root.weatherLon = Number(obj.lon);
                        root.weatherTemp = Math.round(obj.temp);
                        root.weatherFeelsLike = Math.round(obj.feels ?? obj.temp);
                        root.weatherHumidity = Math.round(obj.hum ?? 0);
                        root.weatherWind = Math.round(obj.wind ?? 0);
                        root.weatherCode = Math.round(obj.code ?? 3);
                        root.weatherIsDay = Boolean(obj.isDay ?? true);
                        root.weatherReady = true;
                        root.weatherError = false;
                        root._weatherLastFetchMs = Date.now();
                        root._weatherGotPayload = true;
                    }
                } catch (e) {}
            }
        }
        onExited: exitCode => {
            root.weatherLoading = false;
            if (root._weatherPendingForce) {
                root._weatherPendingForce = false;
                Qt.callLater(() => root.refreshWeather(true));
                return;
            }
            if (root._weatherActiveReqId !== root._weatherReqSeq) return;
            if ((exitCode !== 0 || !root._weatherGotPayload) && !root.weatherReady) {
                root.weatherError = true;
            }
        }
    }

    Connections {
        target: Config
        function onCenterPopoverOpenChanged() {
            if (Config.centerPopoverOpen) {
                root.refreshWeather(false);
            } else {
                monthPickerOpen = false;
                yearPickerOpen = false;
                closeEventEditor();
                closeWeatherLocEditor();
            }
        }
    }

    function prevMonth(): void {
        if (viewMonth === 0) {
            viewMonth = 11;
            viewYear--;
        } else {
            viewMonth--;
        }
    }

    function nextMonth(): void {
        if (viewMonth === 11) {
            viewMonth = 0;
            viewYear++;
        } else {
            viewMonth++;
        }
    }

    function resetToToday(): void {
        const now = new Date();
        viewYear = now.getFullYear();
        viewMonth = now.getMonth();
        selectedDateKey = formatDateKey(now.getFullYear(), now.getMonth(), now.getDate());
    }

    function formatDateKey(y: int, m: int, d: int): string {
        const mm = (m + 1) < 10 ? `0${m + 1}` : `${m + 1}`;
        const dd = d < 10 ? `0${d}` : `${d}`;
        return `${y}-${mm}-${dd}`;
    }

    function selectDate(dateKey: string, cellYear: int, cellMonth: int): void {
        selectedDateKey = dateKey;
        if (cellYear !== viewYear || cellMonth !== viewMonth) {
            viewYear = cellYear;
            viewMonth = cellMonth;
        }
    }

    function jumpToNextAgenda(): void {
        root.eventsVersion;
        const all = [...new Set([...(root.markedDates ?? []), ...Object.keys(root.eventsMap ?? {})])].sort();
        if (all.length === 0) {
            openEventEditor(root.selectedDateKey);
            return;
        }
        const target = all.find(k => k >= root.todayKey) ?? all[0];
        const parts = target.split("-");
        if (parts.length === 3) {
            root.selectDate(target, parseInt(parts[0], 10), parseInt(parts[1], 10) - 1);
        }
    }

    function hasEvent(dateKey: string): bool {
        eventsVersion;
        return (eventsMap[dateKey] !== undefined && String(eventsMap[dateKey]).length > 0) || (markedDates.indexOf(dateKey) !== -1);
    }

    function getEvent(dateKey: string): string {
        eventsVersion;
        return eventsMap[dateKey] ?? "";
    }

    function setEvent(dateKey: string, note: string): void {
        const next = Object.assign({}, eventsMap);
        const trimmed = (note ?? "").trim();
        if (trimmed.length > 0) {
            next[dateKey] = trimmed;
            if (markedDates.indexOf(dateKey) === -1) {
                markedDates = [...markedDates, dateKey];
            }
            if (dateKey === root.todayKey) {
                Quickshell.execDetached(["notify-send", "-u", "critical", "Kalender KINFAEL", `Acara hari ini: ${trimmed}`]);
            }
        } else {
            delete next[dateKey];
            const idx = markedDates.indexOf(dateKey);
            if (idx !== -1) {
                const nextMarks = [...markedDates];
                nextMarks.splice(idx, 1);
                markedDates = nextMarks;
            }
        }
        eventsMap = next;
        eventsVersion++;
        storageError = "";
        saveEvents();
        saveMarkedDates();
    }

    function removeEvent(dateKey: string): void {
        setEvent(dateKey, "");
    }

    function openEventEditor(dateKey: string): void {
        closeWeatherLocEditor();
        activeEditDateKey = dateKey;
        const parts = dateKey.split("-");
        const y = parseInt(parts[0], 10);
        const m = parseInt(parts[1], 10) - 1;
        const d = parseInt(parts[2], 10);
        const dt = new Date(y, m, d);
        activeEditDateLabel = `${root.indoDaysFull[dt.getDay()] ?? ""}, ${d} ${root.indoMonthsFull[m] ?? ""} ${y}`;
        Config.centerPinned = true;
        Config.centerKeyboardFocus = true;
        eventEditorOpen = true;
    }

    function closeEventEditor(): void {
        eventEditorOpen = false;
        Config.centerKeyboardFocus = root.weatherLocEditorOpen;
    }

    function saveEvents(): void {
        const json = JSON.stringify(eventsMap);
        const path = `${Quickshell.env("HOME")}/.config/quickshell/sora/config/calendar_events.json`;
        Quickshell.execDetached(["python3", "-c", "import sys, pathlib; pathlib.Path(sys.argv[1]).write_text(sys.argv[2], encoding='utf-8')", path, json]);
    }

    function saveMarkedDates(): void {
        const json = JSON.stringify(markedDates);
        const path = `${Quickshell.env("HOME")}/.config/quickshell/sora/config/calendar_marks.json`;
        Quickshell.execDetached(["python3", "-c", "import sys, pathlib; pathlib.Path(sys.argv[1]).write_text(sys.argv[2], encoding='utf-8')", path, json]);
    }

    function checkTodayMark(): void {
        const now = new Date();
        const tKey = formatDateKey(now.getFullYear(), now.getMonth(), now.getDate());
        if (hasEvent(tKey) && lastNotifiedDate !== tKey) {
            lastNotifiedDate = tKey;
            const note = getEvent(tKey);
            const msg = note.length > 0 ? `Hari ini: ${note}` : `Hari ini (${tKey}) memiliki penanda kalender.`;
            Quickshell.execDetached(["notify-send", "-u", "critical", "Pengingat Kalender", msg]);
        }
    }

    FileView {
        id: marksWatcher
        printErrors: false
        path: `${Quickshell.env("HOME")}/.config/quickshell/sora/config/calendar_marks.json`
        watchChanges: true
        onLoaded: {
            try {
                const raw = text().trim();
                if (raw.length > 0) {
                    const arr = JSON.parse(raw);
                    if (Array.isArray(arr)) {
                        root.markedDates = arr;
                        root.storageError = "";
                        root.eventsVersion++;
                        root.checkTodayMark();
                    }
                }
            } catch (e) {
                root.storageError = "Gagal membaca penanda kalender.";
            }
        }
    }

    FileView {
        id: eventsWatcher
        printErrors: false
        path: `${Quickshell.env("HOME")}/.config/quickshell/sora/config/calendar_events.json`
        watchChanges: true
        onLoaded: {
            try {
                const raw = text().trim();
                if (raw.length > 0) {
                    const obj = JSON.parse(raw);
                    if (obj && typeof obj === "object" && !Array.isArray(obj)) {
                        root.eventsMap = obj;
                        root.storageError = "";
                        root.eventsVersion++;
                        root.checkTodayMark();
                    }
                }
            } catch (e) {
                root.storageError = "Gagal membaca catatan agenda.";
            }
        }
    }

    SystemClock {
        id: sysClock
        precision: SystemClock.Minutes
        onDateChanged: root.checkTodayMark()
    }

    readonly property var calendarCells: {
        root.eventsVersion;
        const year = root.viewYear;
        const month = root.viewMonth;
        const today = sysClock.date;
        const isCurrentMonth = (today.getFullYear() === year && today.getMonth() === month);
        const todayNum = isCurrentMonth ? today.getDate() : -1;

        const firstDayIndex = new Date(year, month, 1).getDay();
        const daysInMonth = new Date(year, month + 1, 0).getDate();
        const daysInPrevMonth = new Date(year, month, 0).getDate();

        const cells = [];
        const prevM = month === 0 ? 11 : month - 1;
        const prevY = month === 0 ? year - 1 : year;
        for (let i = firstDayIndex - 1; i >= 0; i--) {
            const d = daysInPrevMonth - i;
            cells.push({ day: d, cellYear: prevY, cellMonth: prevM, isCurrent: false, isToday: false, dateKey: formatDateKey(prevY, prevM, d) });
        }
        for (let i = 1; i <= daysInMonth; i++) {
            cells.push({ day: i, cellYear: year, cellMonth: month, isCurrent: true, isToday: (i === todayNum), dateKey: formatDateKey(year, month, i) });
        }
        const nextM = month === 11 ? 0 : month + 1;
        const nextY = month === 11 ? year + 1 : year;
        const totalSlots = cells.length > 35 ? 42 : 35;
        const remaining = totalSlots - cells.length;
        for (let i = 1; i <= remaining; i++) {
            cells.push({ day: i, cellYear: nextY, cellMonth: nextM, isCurrent: false, isToday: false, dateKey: formatDateKey(nextY, nextM, i) });
        }
        return cells;
    }

    Component.onCompleted: {
        checkTodayMark();
        loadWeatherLocJson(weatherLocWatcher.text());
        refreshWeather(true);
    }

    readonly property string activeSwatchId: {
        const ca = (Theme.customAccent ?? "").trim().toLowerCase();
        if (ca.length === 0) return "auto";
        if (["#ffffff", "#f4f4f5", "#000000", "#12151c", "#171a1c", "#e8ebeb"].includes(ca)) return "neutral";
        if (ca === Theme.wallSecondaryRaw.toString().toLowerCase()) return "secondary";
        if (ca === Theme.wallTertiaryRaw.toString().toLowerCase()) return "tertiary";
        return "custom";
    }

    Rectangle {
        id: innerMask
        anchors.fill: parent
        anchors.margins: 1
        radius: 13
        color: "#ffffff"
        visible: false
        layer.enabled: true
    }

    Item {
        id: bentoCanvas
        anchors.fill: parent
        anchors.margins: 1
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: innerMask
            maskSpreadAtMin: 1.0
            maskThresholdMin: 0.5
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            // ================================================================
            // 1. LEFT DOCK RAIL (38 x 298) - Bare icons, zero heavy chrome
            // ================================================================
            Rectangle {
                id: dockRail
                Layout.preferredWidth: 38
                Layout.fillHeight: true
                radius: 10
                color: Theme.surface

                ColumnLayout {
                    anchors.fill: parent
                    anchors.topMargin: 7
                    anchors.bottomMargin: 7
                    spacing: 5

                    // Avatar -> Dashboard
                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        width: 26
                        height: 26
                        Accessible.role: Accessible.Button
                        Accessible.name: "Buka Dashboard"

                        HoverHandler { id: railAvatarHover }

                        Item {
                            anchors.fill: parent
                            scale: railAvatarHover.hovered ? 1.06 : 1.0
                            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                            Rectangle {
                                id: railAvatarMask
                                anchors.fill: parent
                                radius: 13
                                color: "#ffffff"
                                visible: false
                                layer.enabled: true
                            }

                            Item {
                                anchors.fill: parent
                                layer.enabled: true
                                layer.effect: MultiEffect {
                                    maskEnabled: true
                                    maskSource: railAvatarMask
                                    maskSpreadAtMin: 1.0
                                    maskThresholdMin: 0.5
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: Theme.accent
                                    Text {
                                        anchors.centerIn: parent
                                        text: root.userName.slice(0, 1).toUpperCase()
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        font.weight: Font.Bold
                                        color: Theme.accentOnFill
                                    }
                                }

                                Image {
                                    anchors.fill: parent
                                    source: `file://${Quickshell.env("HOME")}/.face`
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    visible: status === Image.Ready
                                }
                            }

                            Rectangle {
                                width: 7
                                height: 7
                                radius: 3.5
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.rightMargin: -1
                                anchors.bottomMargin: -1
                                color: Theme.success
                                border.width: 1.5
                                border.color: Theme.surface
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Config.centerPopoverHovered = false;
                                Config.toggleDashboard();
                            }
                        }
                    }

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: 16
                        height: 1
                        color: Theme.outline
                    }

                    // 4 Bare Action Icons (hover pill / solid only when active)
                    Column {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 4

                        // Mode Terang / Gelap
                        Rectangle {
                            width: 26
                            height: 26
                            radius: 7
                            color: railModeHover.hovered ? Theme.surfaceContainerLow : "transparent"
                            Accessible.role: Accessible.Button
                            Accessible.name: Theme.isDarkMode ? "Aktifkan Mode Terang" : "Aktifkan Mode Gelap"

                            HoverHandler { id: railModeHover }
                            MatIcon {
                                anchors.centerIn: parent
                                icon: "contrast"
                                size: 15
                                color: railModeHover.hovered ? Theme.accentInk : Theme.text
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ThemeEngine.toggleThemeMode()
                            }
                        }

                        // Wallpaper
                        Rectangle {
                            width: 26
                            height: 26
                            radius: 7
                            color: railWpHover.hovered ? Theme.surfaceContainerLow : "transparent"
                            Accessible.role: Accessible.Button
                            Accessible.name: "Pilih Wallpaper"

                            HoverHandler { id: railWpHover }
                            MatIcon {
                                anchors.centerIn: parent
                                icon: "wallpaper"
                                size: 15
                                color: railWpHover.hovered ? Theme.accentInk : Theme.text
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Config.centerPopoverHovered = false;
                                    Config.toggleWallpaperPicker();
                                }
                            }
                        }

                        // Night Light
                        Rectangle {
                            width: 26
                            height: 26
                            radius: 7
                            color: Config.nightLightEnabled
                                ? Theme.accent
                                : (railNlHover.hovered ? Theme.surfaceContainerLow : "transparent")
                            Accessible.role: Accessible.Button
                            Accessible.name: "Toggle Night Light"

                            HoverHandler { id: railNlHover }
                            MatIcon {
                                anchors.centerIn: parent
                                icon: "nightlight"
                                size: 15
                                fill: Config.nightLightEnabled ? 1.0 : 0.0
                                color: Config.nightLightEnabled ? Theme.accentOnFill : Theme.text
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Config.toggleNightLight()
                            }
                        }

                        // Do Not Disturb
                        Rectangle {
                            width: 26
                            height: 26
                            radius: 7
                            color: Config.dndEnabled
                                ? Theme.accent
                                : (railDndHover.hovered ? Theme.surfaceContainerLow : "transparent")
                            Accessible.role: Accessible.Button
                            Accessible.name: "Toggle Jangan Ganggu"

                            HoverHandler { id: railDndHover }
                            MatIcon {
                                anchors.centerIn: parent
                                icon: Config.dndEnabled ? "notifications_off" : "notifications"
                                size: 15
                                fill: Config.dndEnabled ? 1.0 : 0.0
                                color: Config.dndEnabled ? Theme.accentOnFill : Theme.text
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Config.dndEnabled = !Config.dndEnabled
                            }
                        }
                    }

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: 16
                        height: 1
                        color: Theme.outline
                    }

                    // Lock Screen
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: 26
                        height: 26
                        radius: 7
                        color: railLockHover.hovered ? Theme.surfaceContainerLow : "transparent"
                        Accessible.role: Accessible.Button
                        Accessible.name: "Kunci Layar"

                        HoverHandler { id: railLockHover }
                        MatIcon {
                            anchors.centerIn: parent
                            icon: "lock"
                            size: 15
                            color: railLockHover.hovered ? Theme.accentInk : Theme.subtext
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Config.centerPopoverHovered = false;
                                Config.centerPopoverOpen = false;
                                Quickshell.execDetached(["hyprlock"]);
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    // Power Menu
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: 26
                        height: 26
                        radius: 13
                        color: railPowerHover.hovered ? Theme.surfaceContainerLow : "transparent"
                        Accessible.role: Accessible.Button
                        Accessible.name: "Menu Daya"

                        HoverHandler { id: railPowerHover }
                        MatIcon {
                            anchors.centerIn: parent
                            icon: "power_settings_new"
                            size: 15
                            color: railPowerHover.hovered ? Theme.urgentInk : Theme.subtext
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Config.centerPopoverHovered = false;
                                Config.togglePowerMenu();
                            }
                        }
                    }
                }
            }

            // ================================================================
            // 2. RIGHT BENTO STAGE (620 x 298)
            // ================================================================
            Item {
                id: bentoStage
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 8

                    // --------------------------------------------------------
                    // TOP BAND (140px): Hero Artwork (404) + Agenda (208)
                    // --------------------------------------------------------
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 140
                        Layout.minimumHeight: 140
                        Layout.maximumHeight: 140
                        spacing: 8

                        // CARD A: WIDE HERO WALLPAPER + USER + SWATCHES (404 x 140)
                        Rectangle {
                            id: heroCard
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 10
                            color: Theme.surfaceContainerLow
                            clip: true

                            HoverHandler { id: heroBgHover }

                            Rectangle {
                                id: heroImgMask
                                anchors.fill: parent
                                radius: 10
                                color: "#ffffff"
                                visible: false
                                layer.enabled: true
                            }

                            Item {
                                anchors.fill: parent
                                layer.enabled: true
                                layer.effect: MultiEffect {
                                    maskEnabled: true
                                    maskSource: heroImgMask
                                    maskSpreadAtMin: 1.0
                                    maskThresholdMin: 0.5
                                }

                                Image {
                                    anchors.fill: parent
                                    source: ThemeEngine.profileBannerSrc
                                    fillMode: Image.PreserveAspectCrop
                                    sourceSize.width: 640
                                    sourceSize.height: 280
                                    asynchronous: true
                                    cache: true
                                    smooth: true
                                    scale: heroBgHover.hovered ? 1.02 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                                }

                                // Top/bottom edge scrim (keeps middle artwork open while ensuring #F4F6F6 passes AA on bright skies)
                                Rectangle {
                                    anchors.fill: parent
                                    gradient: Gradient {
                                        GradientStop { position: 0.0; color: Qt.alpha("#171A1C", 0.56) }
                                        GradientStop { position: 0.18; color: Qt.alpha("#171A1C", 0.20) }
                                        GradientStop { position: 0.42; color: "transparent" }
                                        GradientStop { position: 0.62; color: Qt.alpha("#171A1C", 0.34) }
                                        GradientStop { position: 1.0; color: Qt.alpha("#171A1C", 0.82) }
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Config.centerPopoverHovered = false;
                                    Config.toggleWallpaperPicker();
                                }
                            }

                            // Bottom-Left Personal Greeting + Typographic Clock + Date
                            Column {
                                anchors.left: parent.left
                                anchors.bottom: parent.bottom
                                anchors.leftMargin: 12
                                anchors.bottomMargin: 10
                                spacing: 1
                                z: 2

                                Row {
                                    spacing: 8

                                    Text {
                                        anchors.baseline: heroClockText.baseline
                                        id: heroClockText
                                        text: root.heroTimeText
                                        font.family: Theme.fontFamily
                                        font.features: Theme.tabularFeatures
                                        font.pixelSize: 24
                                        font.weight: Font.Bold
                                        color: "#F4F6F6"
                                    }

                                    Text {
                                        anchors.verticalCenter: heroClockText.verticalCenter
                                        text: root.heroGreetingText
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                        color: "#F4F6F6"
                                    }
                                }

                                Text {
                                    text: root.heroFullDateText
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    font.weight: Font.Medium
                                    color: Qt.alpha("#F4F6F6", 0.84)
                                }
                            }

                            // Top Bar: Hover wallpaper hint (left) + 4 accent swatches (right)
                            RowLayout {
                                id: heroTopBar
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.margins: 10
                                spacing: 8
                                z: 2

                                Row {
                                    spacing: 4
                                    opacity: heroBgHover.hovered ? 0.92 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                                    MatIcon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        icon: "wallpaper"
                                        size: 11
                                        color: "#F4F6F6"
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Ganti Wallpaper"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        font.weight: Font.Medium
                                        color: "#F4F6F6"
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                Row {
                                    id: swatchRow
                                    spacing: 4

                                    Repeater {
                                        model: [
                                            { id: "auto", label: "Aksen Wallpaper", col: Theme.wallPrimaryRaw },
                                            { id: "secondary", label: "Aksen Sekunder", col: Theme.wallSecondaryRaw },
                                            { id: "tertiary", label: "Aksen Tersier", col: Theme.wallTertiaryRaw },
                                            { id: "neutral", label: "Netral", col: Theme.isDarkMode ? "#E8EBEB" : "#252C2F" }
                                        ]

                                        Rectangle {
                                            id: swPill
                                            required property var modelData
                                            readonly property bool isActive: root.activeSwatchId === modelData.id

                                            width: isActive ? 22 : 17
                                            height: 11
                                            radius: 5.5
                                            color: modelData.col
                                            border.width: isActive ? 1.5 : 1
                                            border.color: isActive ? "#F4F6F6" : Qt.alpha("#F4F6F6", 0.45)
                                            scale: swPillHover.hovered ? 1.08 : 1.0
                                            Accessible.role: Accessible.Button
                                            Accessible.name: modelData.label

                                            Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                                            Behavior on scale { NumberAnimation { duration: 100 } }
                                            HoverHandler { id: swPillHover }

                                            MouseArea {
                                                anchors.fill: parent
                                                anchors.margins: -3
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (swPill.modelData.id === "auto") ThemeEngine.useWallpaperAccent();
                                                    else if (swPill.modelData.id === "neutral") ThemeEngine.resetToWhiteTheme();
                                                    else ThemeEngine.setCustomColor(swPill.modelData.col.toString());
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                        }

                        // CARD B: TOP-RIGHT SPARSE AGENDA CARD (208 x 140)
                        Rectangle {
                            id: agendaCard
                            Layout.preferredWidth: 208
                            Layout.fillHeight: true
                            radius: 10
                            color: Theme.surface

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 4

                                // Quiet Header + Optional Jump Count + Quick Add Icon
                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 18
                                    spacing: 6

                                    Text {
                                        text: "Agenda"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                        color: Theme.text
                                    }

                                    Rectangle {
                                        visible: root.totalEventCount > 0
                                        height: 15
                                        implicitWidth: agCountText.implicitWidth + 8
                                        radius: 7.5
                                        color: Theme.accent
                                        border.width: agCountHover.hovered ? 1 : 0
                                        border.color: Theme.text
                                        Accessible.role: Accessible.Button
                                        Accessible.name: "Lompat ke agenda terdekat"
                                        HoverHandler { id: agCountHover }

                                        Text {
                                            id: agCountText
                                            anchors.centerIn: parent
                                            text: `${root.totalEventCount}`
                                            font.family: Theme.fontMono
                                            font.features: Theme.tabularFeatures
                                            font.pixelSize: 10
                                            font.weight: Font.Bold
                                            color: Theme.accentOnFill
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.jumpToNextAgenda()
                                        }
                                    }

                                    Item { Layout.fillWidth: true }

                                    Rectangle {
                                        width: 18
                                        height: 18
                                        radius: 9
                                        color: agPlusHover.hovered ? Theme.surfaceContainerLow : "transparent"
                                        Accessible.role: Accessible.Button
                                        Accessible.name: "Tambah agenda tanggal terpilih"
                                        HoverHandler { id: agPlusHover }
                                        MatIcon {
                                            anchors.centerIn: parent
                                            icon: "add"
                                            size: 14
                                            color: agPlusHover.hovered ? Theme.accentInk : Theme.subtext
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.openEventEditor(root.selectedDateKey)
                                        }
                                    }
                                }

                                // Row 0: Active / Inspected Date Row (flat on card, zero nested box border)
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 28
                                    radius: 7
                                    color: selRowHover.hovered ? Theme.surfaceContainerLow : "transparent"
                                    Accessible.role: Accessible.Button
                                    Accessible.name: "Edit agenda tanggal terpilih"

                                    HoverHandler { id: selRowHover }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 7
                                        anchors.rightMargin: 7
                                        spacing: 7

                                        Rectangle {
                                            width: 19
                                            height: 19
                                            radius: 9.5
                                            color: Theme.accent

                                            Text {
                                                anchors.centerIn: parent
                                                text: root.inspectedDayNum
                                                font.family: Theme.fontFamily
                                                font.features: Theme.tabularFeatures
                                                font.pixelSize: 10
                                                font.weight: Font.Bold
                                                color: Theme.accentOnFill
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: {
                                                if (root.storageError.length > 0) return root.storageError;
                                                if (root.inspectedEventNote.length > 0) return `${root.inspectedShortDate} · ${root.inspectedEventNote}`;
                                                if (root.inspectedHasMark) return `${root.inspectedShortDate} · Ditandai`;
                                                return `${root.inspectedShortDate} · Kosong`;
                                            }
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
                                            font.weight: root.inspectedEventNote.length > 0 ? Font.DemiBold : Font.Medium
                                            color: root.storageError.length > 0
                                                ? Theme.urgentInk
                                                : (root.inspectedEventNote.length > 0 ? Theme.text : Theme.subtext)
                                            elide: Text.ElideRight
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.openEventEditor(root.selectedDateKey)
                                    }
                                }

                                // Real Upcoming Events Only (leaves calm air when empty)
                                Repeater {
                                    model: root.secondaryAgendaRows

                                    Rectangle {
                                        id: secAgRow
                                        required property var modelData
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 22
                                        radius: 6
                                        color: secAgHover.hovered ? Theme.surfaceContainerLow : "transparent"
                                        Accessible.role: Accessible.Button
                                        Accessible.name: `${secAgRow.modelData.title}: ${secAgRow.modelData.subtitle}`

                                        HoverHandler { id: secAgHover }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 7
                                            anchors.rightMargin: 7
                                            spacing: 7

                                            Rectangle {
                                                width: 17
                                                height: 17
                                                radius: 8.5
                                                color: Theme.surfaceContainerLow
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: secAgRow.modelData.badge
                                                    font.family: Theme.fontFamily
                                                    font.features: Theme.tabularFeatures
                                                    font.pixelSize: 10
                                                    font.weight: Font.DemiBold
                                                    color: Theme.subtext
                                                }
                                            }

                                            Text {
                                                text: secAgRow.modelData.title
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 10
                                                font.weight: Font.DemiBold
                                                color: Theme.text
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: secAgRow.modelData.subtitle
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 10
                                                color: Theme.subtext
                                                elide: Text.ElideRight
                                            }

                                            Rectangle {
                                                width: 4
                                                height: 4
                                                radius: 2
                                                color: Theme.accentInk
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.selectDate(secAgRow.modelData.dateKey, secAgRow.modelData.year, secAgRow.modelData.month)
                                        }
                                    }
                                }

                                Item { Layout.fillHeight: true }

                                // Clean Flat Secondary Bottom CTA Pill
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 21
                                    radius: 6
                                    color: agCtaHover.hovered ? Theme.surfaceContainerHigh : Theme.surfaceContainer
                                    Accessible.role: Accessible.Button
                                    Accessible.name: root.hasEvent(root.selectedDateKey) ? "Edit Agenda" : "Tambah Agenda"

                                    HoverHandler { id: agCtaHover }

                                    Text {
                                        anchors.centerIn: parent
                                        text: root.hasEvent(root.selectedDateKey) ? "Edit Agenda" : "Tambah Agenda"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        font.weight: Font.DemiBold
                                        color: Theme.text
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.openEventEditor(root.selectedDateKey)
                                    }
                                }
                            }
                        }
                    }

                    // --------------------------------------------------------
                    // BOTTOM BAND (150px): Calendar (364) + Weather (248)
                    // --------------------------------------------------------
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 8

                        // CARD C: BOTTOM-LEFT CLEAN TYPOGRAPHIC CALENDAR (364 x 150)
                        Rectangle {
                            id: calendarCard
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 10
                            color: Theme.surface

                            Column {
                                anchors.fill: parent
                                anchors.margins: 9
                                spacing: 3

                                // Clean Minimal Month / Year + Arrows Header
                                Item {
                                    width: parent.width
                                    height: 18

                                    RowLayout {
                                        anchors.fill: parent
                                        spacing: 4

                                        Rectangle {
                                            width: 18
                                            height: 18
                                            radius: 5
                                            color: mPrevHover.hovered ? Theme.surfaceContainerLow : "transparent"
                                            Accessible.role: Accessible.Button
                                            Accessible.name: "Bulan sebelumnya"
                                            HoverHandler { id: mPrevHover }
                                            MatIcon {
                                                anchors.centerIn: parent
                                                icon: "chevron_left"
                                                size: 14
                                                color: mPrevHover.hovered ? Theme.accentInk : Theme.subtext
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.prevMonth()
                                            }
                                        }

                                        Item {
                                            height: 18
                                            implicitWidth: monthLabel.implicitWidth + 4
                                            Accessible.role: Accessible.Button
                                            Accessible.name: "Pilih bulan"
                                            HoverHandler { id: monthHover }
                                            WheelHandler {
                                                onWheel: event => {
                                                    if (event.angleDelta.y > 0) root.prevMonth();
                                                    else if (event.angleDelta.y < 0) root.nextMonth();
                                                }
                                            }
                                            Text {
                                                id: monthLabel
                                                anchors.centerIn: parent
                                                text: root.indoMonthsFull[root.viewMonth] ?? ""
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 11
                                                font.weight: Font.Bold
                                                color: (root.monthPickerOpen || monthHover.hovered) ? Theme.accentInk : Theme.text
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    root.yearPickerOpen = false;
                                                    root.monthPickerOpen = !root.monthPickerOpen;
                                                }
                                            }
                                        }

                                        Item {
                                            height: 18
                                            implicitWidth: yearLabel.implicitWidth + 4
                                            Accessible.role: Accessible.Button
                                            Accessible.name: "Pilih tahun"
                                            HoverHandler { id: yearHover }
                                            WheelHandler {
                                                onWheel: event => {
                                                    if (event.angleDelta.y > 0) root.viewYear--;
                                                    else if (event.angleDelta.y < 0) root.viewYear++;
                                                }
                                            }
                                            Text {
                                                id: yearLabel
                                                anchors.centerIn: parent
                                                text: `${root.viewYear}`
                                                font.family: Theme.fontFamily
                                                font.features: Theme.tabularFeatures
                                                font.pixelSize: 11
                                                font.weight: Font.Medium
                                                color: (root.yearPickerOpen || yearHover.hovered) ? Theme.accentInk : Theme.subtext
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    root.monthPickerOpen = false;
                                                    root.yearPickerOpen = !root.yearPickerOpen;
                                                    root.yearBase = Math.floor(root.viewYear / 10) * 10;
                                                }
                                            }
                                        }

                                        Rectangle {
                                            width: 18
                                            height: 18
                                            radius: 5
                                            color: mNextHover.hovered ? Theme.surfaceContainerLow : "transparent"
                                            Accessible.role: Accessible.Button
                                            Accessible.name: "Bulan berikutnya"
                                            HoverHandler { id: mNextHover }
                                            MatIcon {
                                                anchors.centerIn: parent
                                                icon: "chevron_right"
                                                size: 14
                                                color: mNextHover.hovered ? Theme.accentInk : Theme.subtext
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.nextMonth()
                                            }
                                        }

                                        Item { Layout.fillWidth: true }

                                        Rectangle {
                                            visible: !root.isViewingCurrentMonth || root.selectedDateKey !== root.todayKey
                                            height: 16
                                            implicitWidth: todayBtnText.implicitWidth + 10
                                            radius: 5
                                            color: todayBtnHover.hovered ? Theme.accent : Theme.surfaceContainer
                                            Accessible.role: Accessible.Button
                                            Accessible.name: "Kembali ke hari ini"
                                            HoverHandler { id: todayBtnHover }
                                            Text {
                                                id: todayBtnText
                                                anchors.centerIn: parent
                                                text: "Hari Ini"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 9
                                                font.weight: Font.DemiBold
                                                color: todayBtnHover.hovered ? Theme.accentOnFill : Theme.text
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.resetToToday()
                                            }
                                        }
                                    }
                                }

                                // Quiet Single-Letter Day Header
                                Row {
                                    width: parent.width
                                    spacing: 0

                                    Repeater {
                                        model: ["M", "S", "S", "R", "K", "J", "S"]
                                        Item {
                                            width: Math.floor(parent.width / 7)
                                            height: 12

                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 10
                                                font.weight: Font.DemiBold
                                                color: (index === 0 || index === 6)
                                                    ? Qt.alpha(Theme.subtext, 0.84)
                                                    : Theme.subtext
                                            }
                                        }
                                    }
                                }

                                // Open Typographic Day Grid (Circular Today & Ring Selected)
                                Grid {
                                    id: miniCalGrid
                                    width: parent.width
                                    columns: 7
                                    spacing: 0

                                    readonly property int rowCount: root.calendarCells.length > 35 ? 6 : 5
                                    readonly property int cellHeight: rowCount > 5 ? 16 : 19

                                    Repeater {
                                        model: root.calendarCells

                                        Item {
                                            id: cellItem
                                            required property var modelData
                                            width: Math.floor(parent.width / 7)
                                            height: miniCalGrid.cellHeight

                                            readonly property bool cellMarked: {
                                                root.eventsVersion;
                                                return root.hasEvent(modelData.dateKey);
                                            }
                                            readonly property bool isSelected: modelData.dateKey === root.selectedDateKey

                                            HoverHandler {
                                                id: cellHover
                                                onHoveredChanged: {
                                                    if (hovered) root.hoveredDateKey = cellItem.modelData.dateKey;
                                                    else if (root.hoveredDateKey === cellItem.modelData.dateKey) root.hoveredDateKey = "";
                                                }
                                            }

                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: miniCalGrid.cellHeight
                                                height: miniCalGrid.cellHeight
                                                radius: miniCalGrid.cellHeight / 2
                                                color: {
                                                    if (modelData.isToday) return Theme.accent;
                                                    if (cellHover.hovered) return Qt.alpha(Theme.text, 0.06);
                                                    return "transparent";
                                                }
                                                border.width: cellItem.isSelected && !modelData.isToday ? 1 : 0
                                                border.color: Theme.text

                                                Text {
                                                    anchors.centerIn: parent
                                                    anchors.verticalCenterOffset: cellItem.cellMarked ? -1 : 0
                                                    text: `${modelData.day}`
                                                    font.family: Theme.fontFamily
                                                    font.features: Theme.tabularFeatures
                                                    font.pixelSize: 10
                                                    font.weight: (modelData.isToday || cellItem.isSelected)
                                                        ? Font.Bold
                                                        : (modelData.isCurrent ? Font.Medium : Font.Normal)
                                                    color: modelData.isToday
                                                        ? Theme.accentOnFill
                                                        : (modelData.isCurrent ? Theme.text : Qt.alpha(Theme.subtext, 0.84))
                                                }

                                                Rectangle {
                                                    visible: cellItem.cellMarked
                                                    anchors.bottom: parent.bottom
                                                    anchors.bottomMargin: 1
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    width: 3
                                                    height: 3
                                                    radius: 1.5
                                                    color: modelData.isToday ? Theme.accentOnFill : Theme.accentInk
                                                }
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: mouse => {
                                                    if (mouse.button === Qt.RightButton) {
                                                        root.selectDate(cellItem.modelData.dateKey, cellItem.modelData.cellYear, cellItem.modelData.cellMonth);
                                                        root.openEventEditor(cellItem.modelData.dateKey);
                                                    } else if (cellItem.isSelected) {
                                                        root.openEventEditor(cellItem.modelData.dateKey);
                                                    } else {
                                                        root.selectDate(cellItem.modelData.dateKey, cellItem.modelData.cellYear, cellItem.modelData.cellMonth);
                                                    }
                                                }
                                                onDoubleClicked: {
                                                    root.selectDate(cellItem.modelData.dateKey, cellItem.modelData.cellYear, cellItem.modelData.cellMonth);
                                                    root.openEventEditor(cellItem.modelData.dateKey);
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // CARD D: BOTTOM-RIGHT LIVE WEATHER (248 x 150)
                        Rectangle {
                            id: weatherCard
                            Layout.preferredWidth: 248
                            Layout.fillHeight: true
                            radius: 10
                            color: Theme.surface

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 4

                                // Header: Clickable Location Chip (GPS/City) + Refresh Button
                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 20
                                    spacing: 4

                                    Rectangle {
                                        id: weatherLocBtn
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 20
                                        radius: 6
                                        activeFocusOnTab: Config.centerPopoverOpen && !root.eventEditorOpen && !root.weatherLocEditorOpen
                                        color: wLocHover.hovered ? Theme.surfaceContainerLow : "transparent"
                                        border.width: activeFocus ? 1.5 : 0
                                        border.color: Theme.accent
                                        Accessible.role: Accessible.Button
                                        Accessible.name: "Atur lokasi cuaca"

                                        HoverHandler { id: wLocHover }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 3
                                            anchors.rightMargin: 4
                                            spacing: 4

                                            MatIcon {
                                                icon: "my_location"
                                                size: 12
                                                fill: 0.0
                                                color: (wLocHover.hovered || root.weatherMode === "manual" || root.weatherSource === "gpsd" || root.weatherSource === "geoclue")
                                                    ? Theme.accentInk
                                                    : Theme.subtext
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: root.weatherCity.length > 0 ? root.weatherCity : "Cuaca"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 11
                                                font.weight: Font.Bold
                                                color: wLocHover.hovered ? Theme.accentInk : Theme.text
                                                elide: Text.ElideRight
                                            }
                                        }

                                        Keys.onReturnPressed: root.openWeatherLocEditor()
                                        Keys.onSpacePressed: root.openWeatherLocEditor()

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.openWeatherLocEditor()
                                        }
                                    }

                                    Rectangle {
                                        id: weatherRefreshBtn
                                        width: 20
                                        height: 20
                                        radius: 6
                                        activeFocusOnTab: Config.centerPopoverOpen && !root.eventEditorOpen && !root.weatherLocEditorOpen
                                        color: wRefHover.hovered && !root.weatherLoading ? Theme.surfaceContainerLow : "transparent"
                                        border.width: activeFocus ? 1.5 : 0
                                        border.color: Theme.accent
                                        Accessible.role: Accessible.Button
                                        Accessible.name: "Muat ulang cuaca"

                                        HoverHandler { id: wRefHover }

                                        MatIcon {
                                            anchors.centerIn: parent
                                            icon: "refresh"
                                            size: 13
                                            fill: 0.0
                                            color: wRefHover.hovered && !root.weatherLoading ? Theme.accentInk : Theme.subtext
                                            opacity: root.weatherLoading ? 0.45 : 1.0
                                        }

                                        Keys.onReturnPressed: root.refreshWeather(true)
                                        Keys.onSpacePressed: root.refreshWeather(true)

                                        MouseArea {
                                            anchors.fill: parent
                                            enabled: !root.weatherLoading
                                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            onClicked: root.refreshWeather(true)
                                        }
                                    }
                                }

                                // Content Zone: Ready / Loading / Error
                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    // Ready State
                                    ColumnLayout {
                                        visible: root.weatherReady
                                        anchors.fill: parent
                                        spacing: 4

                                        Item {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true

                                            RowLayout {
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 8

                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 1

                                                    Row {
                                                        spacing: 6

                                                        Text {
                                                            id: wTempMain
                                                            text: `${root.weatherTemp}°`
                                                            font.family: Theme.fontFamily
                                                            font.features: Theme.tabularFeatures
                                                            font.pixelSize: 30
                                                            font.weight: Font.Bold
                                                            color: Theme.text
                                                        }

                                                        Text {
                                                            anchors.bottom: wTempMain.bottom
                                                            anchors.bottomMargin: 5
                                                            text: root.weatherLabelFor(root.weatherCode)
                                                            font.family: Theme.fontFamily
                                                            font.pixelSize: 11
                                                            font.weight: Font.DemiBold
                                                            color: Theme.text
                                                        }
                                                    }

                                                    Text {
                                                        Layout.fillWidth: true
                                                        text: `Terasa ${root.weatherFeelsLike}° · ${root.weatherIsDay ? "Siang" : "Malam"}`
                                                        font.family: Theme.fontFamily
                                                        font.features: Theme.tabularFeatures
                                                        font.pixelSize: 10
                                                        font.weight: Font.Medium
                                                        color: Theme.subtext
                                                        elide: Text.ElideRight
                                                    }
                                                }

                                                MatIcon {
                                                    icon: root.weatherIconFor(root.weatherCode, root.weatherIsDay)
                                                    size: 32
                                                    fill: 0.0
                                                    color: Theme.accentInk
                                                }
                                            }
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: 1
                                            color: Theme.outline
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 20
                                            spacing: 8

                                            Row {
                                                spacing: 3
                                                MatIcon {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    icon: "water_drop"
                                                    size: 12
                                                    fill: 0.0
                                                    color: Theme.subtext
                                                }
                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: `${root.weatherHumidity}%`
                                                    font.family: Theme.fontFamily
                                                    font.features: Theme.tabularFeatures
                                                    font.pixelSize: 10
                                                    font.weight: Font.DemiBold
                                                    color: Theme.text
                                                }
                                            }

                                            Item { Layout.fillWidth: true }

                                            Row {
                                                spacing: 3
                                                MatIcon {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    icon: "thermostat"
                                                    size: 12
                                                    fill: 0.0
                                                    color: Theme.subtext
                                                }
                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: `${root.weatherFeelsLike}°`
                                                    font.family: Theme.fontFamily
                                                    font.features: Theme.tabularFeatures
                                                    font.pixelSize: 10
                                                    font.weight: Font.DemiBold
                                                    color: Theme.text
                                                }
                                            }

                                            Item { Layout.fillWidth: true }

                                            Row {
                                                spacing: 3
                                                MatIcon {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    icon: "air"
                                                    size: 12
                                                    fill: 0.0
                                                    color: Theme.subtext
                                                }
                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: `${root.weatherWind} km/j`
                                                    font.family: Theme.fontFamily
                                                    font.features: Theme.tabularFeatures
                                                    font.pixelSize: 10
                                                    font.weight: Font.DemiBold
                                                    color: Theme.text
                                                }
                                            }
                                        }
                                    }

                                    // Loading State
                                    ColumnLayout {
                                        visible: !root.weatherReady && root.weatherLoading
                                        anchors.centerIn: parent
                                        spacing: 4

                                        MatIcon {
                                            Layout.alignment: Qt.AlignHCenter
                                            icon: "cloud"
                                            size: 22
                                            fill: 0.0
                                            color: Theme.subtext
                                        }

                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: "Memuat cuaca..."
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
                                            color: Theme.subtext
                                        }
                                    }

                                    // Error State
                                    ColumnLayout {
                                        visible: !root.weatherReady && root.weatherError && !root.weatherLoading
                                        anchors.centerIn: parent
                                        spacing: 6

                                        MatIcon {
                                            Layout.alignment: Qt.AlignHCenter
                                            icon: "cloud_off"
                                            size: 20
                                            fill: 0.0
                                            color: Theme.urgentInk
                                        }

                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: "Cuaca gagal dimuat"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
                                            color: Theme.subtext
                                        }

                                        Rectangle {
                                            Layout.alignment: Qt.AlignHCenter
                                            height: 22
                                            implicitWidth: retryLbl.implicitWidth + 14
                                            radius: 6
                                            activeFocusOnTab: visible && Config.centerPopoverOpen && !root.eventEditorOpen && !root.weatherLocEditorOpen
                                            color: retryHover.hovered ? Theme.surfaceContainerHigh : Theme.surfaceContainer
                                            border.width: activeFocus ? 1.5 : 0
                                            border.color: Theme.accent
                                            Accessible.role: Accessible.Button
                                            Accessible.name: "Muat ulang cuaca"

                                            HoverHandler { id: retryHover }

                                            Text {
                                                id: retryLbl
                                                anchors.centerIn: parent
                                                text: "Muat ulang"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 10
                                                font.weight: Font.DemiBold
                                                color: Theme.text
                                            }

                                            Keys.onReturnPressed: root.refreshWeather(true)
                                            Keys.onSpacePressed: root.refreshWeather(true)

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.refreshWeather(true)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ============================================================
                // OVERLAYS INSIDE RIGHT BENTO STAGE (z: 40..60)
                // ============================================================

                MouseArea {
                    anchors.fill: parent
                    z: 35
                    visible: root.monthPickerOpen || root.yearPickerOpen
                    onClicked: {
                        root.monthPickerOpen = false;
                        root.yearPickerOpen = false;
                    }
                }

                // Month Selection Grid Dropdown Popup
                Rectangle {
                    id: monthPickerPopup
                    z: 45
                    visible: root.monthPickerOpen
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 158
                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    width: 196
                    height: 112
                    radius: 9
                    color: Theme.surfaceContainer
                    border.width: 1
                    border.color: Theme.outline

                    Grid {
                        anchors.fill: parent
                        anchors.margins: 6
                        columns: 4
                        rows: 3
                        spacing: 4

                        Repeater {
                            model: root.monthNames

                            Rectangle {
                                id: mDelegate
                                required property string modelData
                                required property int index
                                width: Math.floor((parent.width - 12) / 4)
                                height: Math.floor((parent.height - 8) / 3)
                                radius: 5
                                color: mDelegate.index === root.viewMonth
                                    ? Theme.accent
                                    : (mHover.hovered ? Theme.surfaceContainerHigh : "transparent")

                                HoverHandler { id: mHover }

                                Text {
                                    anchors.centerIn: parent
                                    text: mDelegate.modelData
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.weight: mDelegate.index === root.viewMonth ? Font.Bold : Font.Medium
                                    color: mDelegate.index === root.viewMonth
                                        ? Theme.accentOnFill
                                        : (mHover.hovered ? Theme.text : Theme.subtext)
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.viewMonth = mDelegate.index;
                                        root.monthPickerOpen = false;
                                    }
                                }
                            }
                        }
                    }
                }

                // Year Selection Grid Dropdown Popup
                Rectangle {
                    id: yearPickerPopup
                    z: 45
                    visible: root.yearPickerOpen
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 158
                    anchors.left: parent.left
                    anchors.leftMargin: 56
                    width: 196
                    height: 128
                    radius: 9
                    color: Theme.surfaceContainer
                    border.width: 1
                    border.color: Theme.outline

                    Column {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 4

                        Item {
                            width: parent.width
                            height: 22

                            Rectangle {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: 22
                                height: 22
                                radius: 5
                                color: yPrevHover.hovered ? Theme.surfaceContainerHigh : "transparent"

                                HoverHandler { id: yPrevHover }
                                MatIcon {
                                    anchors.centerIn: parent
                                    icon: "chevron_left"
                                    size: 14
                                    color: yPrevHover.hovered ? Theme.accentInk : Theme.subtext
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.yearBase -= 12
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: `${root.yearBase} - ${root.yearBase + 11}`
                                font.family: Theme.fontFamily
                                font.features: Theme.tabularFeatures
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                color: Theme.text
                            }

                            Rectangle {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: 22
                                height: 22
                                radius: 5
                                color: yNextHover.hovered ? Theme.surfaceContainerHigh : "transparent"

                                HoverHandler { id: yNextHover }
                                MatIcon {
                                    anchors.centerIn: parent
                                    icon: "chevron_right"
                                    size: 14
                                    color: yNextHover.hovered ? Theme.accentInk : Theme.subtext
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.yearBase += 12
                                }
                            }
                        }

                        Grid {
                            width: parent.width
                            columns: 4
                            rows: 3
                            spacing: 4

                            Repeater {
                                model: 12

                                Rectangle {
                                    id: yDelegate
                                    required property int index
                                    readonly property int yearVal: root.yearBase + index
                                    width: Math.floor((parent.width - 12) / 4)
                                    height: 27
                                    radius: 5
                                    color: yDelegate.yearVal === root.viewYear
                                        ? Theme.accent
                                        : (yHover.hovered ? Theme.surfaceContainerHigh : "transparent")

                                    HoverHandler { id: yHover }

                                    Text {
                                        anchors.centerIn: parent
                                        text: `${yDelegate.yearVal}`
                                        font.family: Theme.fontFamily
                                        font.features: Theme.tabularFeatures
                                        font.pixelSize: 11
                                        font.weight: yDelegate.yearVal === root.viewYear ? Font.Bold : Font.Medium
                                        color: yDelegate.yearVal === root.viewYear
                                            ? Theme.accentOnFill
                                            : (yHover.hovered ? Theme.text : Theme.subtext)
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.viewYear = yDelegate.yearVal;
                                            root.yearPickerOpen = false;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Event / Agenda Editor Overlay Modal (z: 60)
                Item {
                    id: eventEditorDialog
                    anchors.fill: parent
                    z: 60
                    visible: root.eventEditorOpen
                    Keys.onEscapePressed: root.closeEventEditor()

                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: Qt.alpha(Theme.background, 0.86)

                        MouseArea {
                            anchors.fill: parent
                            onClicked: mouse => {
                                const pt = mapToItem(dialogCard, mouse.x, mouse.y);
                                if (pt.x < 0 || pt.x > dialogCard.width || pt.y < 0 || pt.y > dialogCard.height) {
                                    root.closeEventEditor();
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: dialogCard
                        anchors.centerIn: parent
                        width: Math.min(416, parent.width - 36)
                        height: 176
                        radius: 10
                        color: Theme.surface
                        border.width: 1
                        border.color: Theme.outline

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 10

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                MatIcon {
                                    icon: "event"
                                    size: 16
                                    color: Theme.accentInk
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: root.activeEditDateLabel
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                    color: Theme.text
                                    elide: Text.ElideRight
                                }

                                Rectangle {
                                    id: editorCloseBtn
                                    width: 24
                                    height: 24
                                    radius: 6
                                    activeFocusOnTab: true
                                    color: closeEditHover.hovered ? Theme.surfaceContainerLow : "transparent"
                                    border.width: activeFocus ? 1.5 : 0
                                    border.color: Theme.accentInk
                                    Accessible.role: Accessible.Button
                                    Accessible.name: "Tutup editor agenda"

                                    HoverHandler { id: closeEditHover }
                                    MatIcon {
                                        anchors.centerIn: parent
                                        icon: "close"
                                        size: 14
                                        color: closeEditHover.hovered ? Theme.text : Theme.subtext
                                    }
                                    Keys.onReturnPressed: root.closeEventEditor()
                                    Keys.onSpacePressed: root.closeEventEditor()
                                    Keys.onEscapePressed: root.closeEventEditor()
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.closeEventEditor()
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: Theme.outline
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 5

                                Text {
                                    text: "Catatan"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    font.weight: Font.Medium
                                    color: Theme.subtext
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 34
                                    radius: 7
                                    color: Theme.background
                                    border.width: eventTextInput.activeFocus ? 1.5 : 1
                                    border.color: eventTextInput.activeFocus ? Theme.accentInk : Theme.outline

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.IBeamCursor
                                        onClicked: eventTextInput.forceActiveFocus()
                                    }

                                    TextInput {
                                        id: eventTextInput
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        anchors.topMargin: 7
                                        anchors.bottomMargin: 7
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        color: Theme.text
                                        clip: true
                                        selectByMouse: true
                                        focus: true
                                        activeFocusOnTab: true
                                        KeyNavigation.tab: editorDelBtn.visible ? editorDelBtn : editorCancelBtn
                                        KeyNavigation.backtab: editorCloseBtn

                                        Text {
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "Tulis agenda..."
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 12
                                            color: Qt.alpha(Theme.subtext, 0.80)
                                            visible: eventTextInput.text.length === 0 && !eventTextInput.activeFocus
                                        }

                                        Keys.onEscapePressed: root.closeEventEditor()
                                        onAccepted: {
                                            root.setEvent(root.activeEditDateKey, eventTextInput.text);
                                            root.closeEventEditor();
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Rectangle {
                                    id: editorDelBtn
                                    visible: root.hasEvent(root.activeEditDateKey)
                                    height: 26
                                    implicitWidth: delText.implicitWidth + 16
                                    radius: 6
                                    activeFocusOnTab: visible
                                    KeyNavigation.tab: editorCancelBtn
                                    KeyNavigation.backtab: eventTextInput
                                    color: delHover.hovered ? Theme.urgent : Theme.surface
                                    border.width: activeFocus ? 2 : 1
                                    border.color: delHover.hovered ? Theme.urgent : Theme.urgentInk
                                    Accessible.role: Accessible.Button
                                    Accessible.name: "Hapus agenda"

                                    HoverHandler { id: delHover }
                                    Text {
                                        id: delText
                                        anchors.centerIn: parent
                                        text: "Hapus"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                        color: delHover.hovered ? (Theme.isDarkMode ? "#171A1C" : "#F8FAFA") : Theme.urgentInk
                                    }
                                    Keys.onReturnPressed: {
                                        root.removeEvent(root.activeEditDateKey);
                                        root.closeEventEditor();
                                    }
                                    Keys.onSpacePressed: {
                                        root.removeEvent(root.activeEditDateKey);
                                        root.closeEventEditor();
                                    }
                                    Keys.onEscapePressed: root.closeEventEditor()
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.removeEvent(root.activeEditDateKey);
                                            root.closeEventEditor();
                                        }
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                Rectangle {
                                    id: editorCancelBtn
                                    height: 26
                                    implicitWidth: cancelText.implicitWidth + 18
                                    radius: 6
                                    activeFocusOnTab: true
                                    KeyNavigation.tab: editorSaveBtn
                                    KeyNavigation.backtab: editorDelBtn.visible ? editorDelBtn : eventTextInput
                                    color: cancelHover.hovered ? Theme.surfaceContainerLow : "transparent"
                                    border.width: activeFocus ? 1.5 : 0
                                    border.color: Theme.accentInk
                                    Accessible.role: Accessible.Button
                                    Accessible.name: "Batal"

                                    HoverHandler { id: cancelHover }
                                    Text {
                                        id: cancelText
                                        anchors.centerIn: parent
                                        text: "Batal"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.Medium
                                        color: Theme.subtext
                                    }
                                    Keys.onReturnPressed: root.closeEventEditor()
                                    Keys.onSpacePressed: root.closeEventEditor()
                                    Keys.onEscapePressed: root.closeEventEditor()
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.closeEventEditor()
                                    }
                                }

                                Rectangle {
                                    id: editorSaveBtn
                                    height: 26
                                    implicitWidth: saveText.implicitWidth + 20
                                    radius: 6
                                    activeFocusOnTab: true
                                    KeyNavigation.tab: editorCloseBtn
                                    KeyNavigation.backtab: editorCancelBtn
                                    color: saveHover.hovered ? Qt.lighter(Theme.accent, 1.08) : Theme.accent
                                    border.width: activeFocus ? 2 : 0
                                    border.color: Theme.text
                                    Accessible.role: Accessible.Button
                                    Accessible.name: "Simpan agenda"

                                    HoverHandler { id: saveHover }
                                    Text {
                                        id: saveText
                                        anchors.centerIn: parent
                                        text: "Simpan"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                        color: Theme.accentOnFill
                                    }
                                    Keys.onReturnPressed: {
                                        root.setEvent(root.activeEditDateKey, eventTextInput.text);
                                        root.closeEventEditor();
                                    }
                                    Keys.onSpacePressed: {
                                        root.setEvent(root.activeEditDateKey, eventTextInput.text);
                                        root.closeEventEditor();
                                    }
                                    Keys.onEscapePressed: root.closeEventEditor()
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.setEvent(root.activeEditDateKey, eventTextInput.text);
                                            root.closeEventEditor();
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Timer {
                        id: inputFocusTimer
                        interval: 60
                        repeat: false
                        onTriggered: {
                            if (root.eventEditorOpen) {
                                eventTextInput.selectAll();
                                eventTextInput.forceActiveFocus();
                            }
                        }
                    }

                    Connections {
                        target: root
                        function onActiveEditDateKeyChanged() {
                            eventTextInput.text = root.getEvent(root.activeEditDateKey);
                        }
                        function onEventEditorOpenChanged() {
                            if (root.eventEditorOpen) {
                                eventTextInput.text = root.getEvent(root.activeEditDateKey);
                                inputFocusTimer.restart();
                            }
                        }
                    }
                }

                // Weather Location / GPS Override Modal (z: 62)
                Item {
                    id: weatherLocDialog
                    anchors.fill: parent
                    z: 62
                    visible: root.weatherLocEditorOpen
                    Keys.onEscapePressed: root.closeWeatherLocEditor()

                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: Qt.alpha(Theme.background, 0.86)

                        MouseArea {
                            anchors.fill: parent
                            onClicked: mouse => {
                                const pt = mapToItem(wLocCard, mouse.x, mouse.y);
                                if (pt.x < 0 || pt.x > wLocCard.width || pt.y < 0 || pt.y > wLocCard.height) {
                                    root.closeWeatherLocEditor();
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: wLocCard
                        anchors.centerIn: parent
                        width: Math.min(416, parent.width - 36)
                        implicitHeight: wLocCol.implicitHeight + 32
                        height: Math.min(parent.height - 24, implicitHeight)
                        radius: 10
                        color: Theme.surface
                        border.width: 1
                        border.color: Theme.outline

                        ColumnLayout {
                            id: wLocCol
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 9

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                MatIcon {
                                    icon: "my_location"
                                    size: 16
                                    fill: 0.0
                                    color: Theme.accentInk
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: "Lokasi Cuaca (GPS / Kota)"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                    color: Theme.text
                                    elide: Text.ElideRight
                                }

                                Rectangle {
                                    id: wLocCloseBtn
                                    width: 24
                                    height: 24
                                    radius: 6
                                    activeFocusOnTab: true
                                    KeyNavigation.tab: weatherLocInput
                                    KeyNavigation.backtab: wLocSaveBtn
                                    color: wLocCloseHover.hovered ? Theme.surfaceContainerLow : "transparent"
                                    border.width: activeFocus ? 1.5 : 0
                                    border.color: Theme.accentInk
                                    Accessible.role: Accessible.Button
                                    Accessible.name: "Tutup pengaturan lokasi cuaca"

                                    HoverHandler { id: wLocCloseHover }
                                    MatIcon {
                                        anchors.centerIn: parent
                                        icon: "close"
                                        size: 14
                                        color: wLocCloseHover.hovered ? Theme.text : Theme.subtext
                                    }
                                    Keys.onReturnPressed: root.closeWeatherLocEditor()
                                    Keys.onSpacePressed: root.closeWeatherLocEditor()
                                    Keys.onEscapePressed: root.closeWeatherLocEditor()
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.closeWeatherLocEditor()
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: Theme.outline
                            }

                            Text {
                                Layout.fillWidth: true
                                text: {
                                    const name = root.weatherLabel.length > 0 ? root.weatherLabel : (root.weatherCity || "-");
                                    const coords = (!isNaN(root.weatherLat) && !isNaN(root.weatherLon))
                                        ? ` (${root.weatherLat.toFixed(4)}, ${root.weatherLon.toFixed(4)})`
                                        : "";
                                    return `Aktif: ${name}${coords} · ${root.weatherSourceLabel}`;
                                }
                                font.family: Theme.fontFamily
                                font.features: Theme.tabularFeatures
                                font.pixelSize: 10
                                color: Theme.subtext
                                elide: Text.ElideRight
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 5

                                Text {
                                    text: "Kota/kecamatan atau koordinat lat, lon"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    font.weight: Font.Medium
                                    color: Theme.subtext
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 34
                                    radius: 7
                                    color: Theme.background
                                    border.width: weatherLocInput.activeFocus ? 1.5 : 1
                                    border.color: root.weatherLocError.length > 0
                                        ? Theme.urgentInk
                                        : (weatherLocInput.activeFocus ? Theme.accentInk : Theme.outline)

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.IBeamCursor
                                        onClicked: weatherLocInput.forceActiveFocus()
                                    }

                                    TextInput {
                                        id: weatherLocInput
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        anchors.topMargin: 7
                                        anchors.bottomMargin: 7
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        color: Theme.text
                                        clip: true
                                        selectByMouse: true
                                        focus: true
                                        activeFocusOnTab: true
                                        KeyNavigation.tab: wLocAutoBtn
                                        KeyNavigation.backtab: wLocCloseBtn

                                        Text {
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "Contoh: Bekasi Barat atau -6.245, 106.992"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 12
                                            color: Theme.subtext
                                            visible: weatherLocInput.text.length === 0
                                        }

                                        onTextChanged: root.weatherLocError = ""
                                        Keys.onEscapePressed: root.closeWeatherLocEditor()
                                        onAccepted: root.submitWeatherLocQuery(weatherLocInput.text)
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    visible: root.weatherLocError.length > 0
                                    text: root.weatherLocError
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                    color: Theme.urgentInk
                                    elide: Text.ElideRight
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Rectangle {
                                    id: wLocAutoBtn
                                    height: 26
                                    implicitWidth: wLocAutoLbl.implicitWidth + 16
                                    radius: 6
                                    activeFocusOnTab: true
                                    KeyNavigation.tab: wLocCancelBtn
                                    KeyNavigation.backtab: weatherLocInput
                                    color: wLocAutoHover.hovered ? Theme.surfaceContainerLow : Theme.surface
                                    border.width: activeFocus ? 1.5 : 1
                                    border.color: activeFocus ? Theme.accentInk : Theme.outline
                                    Accessible.role: Accessible.Button
                                    Accessible.name: "Gunakan GPS atau lokasi otomatis"

                                    HoverHandler { id: wLocAutoHover }
                                    Text {
                                        id: wLocAutoLbl
                                        anchors.centerIn: parent
                                        text: "Otomatis GPS"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                        color: Theme.text
                                    }
                                    Keys.onReturnPressed: root.useAutoWeatherLocation()
                                    Keys.onSpacePressed: root.useAutoWeatherLocation()
                                    Keys.onEscapePressed: root.closeWeatherLocEditor()
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.useAutoWeatherLocation()
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                Rectangle {
                                    id: wLocCancelBtn
                                    height: 26
                                    implicitWidth: wLocCancelLbl.implicitWidth + 16
                                    radius: 6
                                    activeFocusOnTab: true
                                    KeyNavigation.tab: wLocSaveBtn
                                    KeyNavigation.backtab: wLocAutoBtn
                                    color: wLocCancelHover.hovered ? Theme.surfaceContainerLow : "transparent"
                                    border.width: activeFocus ? 1.5 : 0
                                    border.color: Theme.accentInk
                                    Accessible.role: Accessible.Button
                                    Accessible.name: "Batal"

                                    HoverHandler { id: wLocCancelHover }
                                    Text {
                                        id: wLocCancelLbl
                                        anchors.centerIn: parent
                                        text: "Batal"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.Medium
                                        color: Theme.subtext
                                    }
                                    Keys.onReturnPressed: root.closeWeatherLocEditor()
                                    Keys.onSpacePressed: root.closeWeatherLocEditor()
                                    Keys.onEscapePressed: root.closeWeatherLocEditor()
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.closeWeatherLocEditor()
                                    }
                                }

                                Rectangle {
                                    id: wLocSaveBtn
                                    height: 26
                                    implicitWidth: wLocSaveLbl.implicitWidth + 20
                                    radius: 6
                                    activeFocusOnTab: true
                                    KeyNavigation.tab: wLocCloseBtn
                                    KeyNavigation.backtab: wLocCancelBtn
                                    color: root.weatherLocSearching
                                        ? Theme.surfaceContainer
                                        : (wLocSaveHover.hovered ? Qt.lighter(Theme.accent, 1.08) : Theme.accent)
                                    border.width: activeFocus ? 2 : 0
                                    border.color: Theme.text
                                    Accessible.role: Accessible.Button
                                    Accessible.name: "Terapkan lokasi cuaca"

                                    HoverHandler { id: wLocSaveHover }
                                    Text {
                                        id: wLocSaveLbl
                                        anchors.centerIn: parent
                                        text: root.weatherLocSearching ? "Mencari..." : "Terapkan"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                        color: root.weatherLocSearching ? Theme.subtext : Theme.accentOnFill
                                    }
                                    Keys.onReturnPressed: root.submitWeatherLocQuery(weatherLocInput.text)
                                    Keys.onSpacePressed: root.submitWeatherLocQuery(weatherLocInput.text)
                                    Keys.onEscapePressed: root.closeWeatherLocEditor()
                                    MouseArea {
                                        anchors.fill: parent
                                        enabled: !root.weatherLocSearching
                                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: root.submitWeatherLocQuery(weatherLocInput.text)
                                    }
                                }
                            }
                        }
                    }

                    Timer {
                        id: weatherLocFocusTimer
                        interval: 60
                        repeat: false
                        onTriggered: {
                            if (root.weatherLocEditorOpen) {
                                weatherLocInput.selectAll();
                                weatherLocInput.forceActiveFocus();
                            }
                        }
                    }

                    Connections {
                        target: root
                        function onWeatherLocEditorOpenChanged() {
                            if (root.weatherLocEditorOpen) {
                                weatherLocInput.text = root.weatherMode === "manual"
                                    ? ((!isNaN(root.weatherLat) && !isNaN(root.weatherLon))
                                        ? `${root.weatherLat.toFixed(4)}, ${root.weatherLon.toFixed(4)}`
                                        : root.weatherCity)
                                    : "";
                                weatherLocFocusTimer.restart();
                            }
                        }
                    }
                }
            }
        }
    }
}
