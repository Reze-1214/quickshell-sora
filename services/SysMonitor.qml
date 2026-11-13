pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

Singleton {
    id: root

    // 1. Suhu & CPU
    property int cpuPercent: 18
    property int tempC: 54
    property string cpuFreqGhz: "2.4"
    readonly property string tempStatus: tempC >= 82 ? "HOT" : (tempC >= 70 ? "WARM" : "GOOD")
    property var cpuHistory: [16, 24, 18, 32, 26, 42, 28, 20, 35, 26, 30, 22, 38, 28]
    property var cpuCorePercents: [18, 24, 14, 28, 20, 16, 22, 12]
    property var prevCoresTot: []
    property var prevCoresIdl: []

    // Hardware Identity (Automatically detected for any machine)
    property string cpuModel: "CPU"
    readonly property string cpuShortName: cpuModel.replace("Intel(R) Core(TM) ", "").replace("Intel Core ", "").replace("AMD Ryzen ", "Ryzen ").trim()
    property string cpuCores: ""
    property string igpuName: "GPU"
    readonly property string igpuShort: igpuName.replace("Intel ", "").replace("AMD ", "").trim()
    property string dgpuName: ""
    readonly property string dgpuShort: dgpuName.replace("AMD ", "").replace("NVIDIA ", "").trim()
    property bool hasDualGpu: false

    // Discrete GPU (dGPU) Telemetry
    property string dgpuStatus: "ACTIVE"
    property int dgpuPercent: 0
    property int dgpuTempC: 46
    property int dgpuVramUsedMb: 0
    property int dgpuVramTotalMb: 2048
    property string dgpuVramText: "0.5 / 2.0 GiB"

    // 2. RAM
    property int ramPercent: 78
    property string ramUsedGb: "6.0"
    property string ramTotalGb: "7.6"
    property string ramFreeGb: "1.6"
    property string ramAppsGb: "4.2"
    property string ramCacheGb: "1.8"
    property int ramAppsPercent: 55
    property int ramCachePercent: 23
    property int ramFreePercent: 22
    property var ramHistory: [68, 72, 70, 75, 74, 78, 76, 79, 80, 78]

    // 3. SSD
    property int ssdPercent: 81
    property string ssdUsedGb: "359"
    property string ssdTotalGb: "443"
    property string ssdFreeGb: "84"

    // 4. GPU (Kartu Grafis)
    property int gpuPercent: 18
    property int gpuFreqMhz: 300
    property int gpuMaxMhz: 1100
    readonly property string gpuStatus: gpuPercent >= 75 ? "BOOST" : (gpuPercent >= 35 ? "ACTIVE" : "GOOD")

    // 5. Jaringan (Network)
    property string netDownText: "0.0 KB/s"
    property string netUpText: "0.0 KB/s"
    property int netPercent: 0
    property var netHistory: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property var netDownHistory: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property var netUpHistory: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

    function scaleNetLog(bytesPerSec: double): int {
        const kb = Math.max(0.0, bytesPerSec / 1024.0);
        if (kb <= 0.1) return 0;
        return Math.min(100, Math.max(4, Math.round(Math.log10(kb + 1) * 28)));
    }

    // 6. Cooling Fan & ZRAM Swap
    property int fanRpm: 0
    property string zramUsedGb: "0.0"
    property string zramTotalGb: "7.6"
    property int zramPercent: 0

    // Revision counter to trigger Canvas repaints smoothly
    property int tickCount: 0

    // Internal delta state for CPU & Network
    property double prevCpuTotal: 0
    property double prevCpuIdle: 0
    property double prevNetRx: 0
    property double prevNetTx: 0
    property double prevTimestamp: 0

    function formatSpeed(bytesPerSec: double): string {
        if (bytesPerSec < 1024) return `${Math.max(0, Math.round(bytesPerSec))} B/s`;
        const kb = bytesPerSec / 1024.0;
        if (kb < 1024) return `${kb.toFixed(kb >= 100 ? 0 : 1)} KB/s`;
        const mb = kb / 1024.0;
        return `${mb.toFixed(1)} MB/s`;
    }

    function refresh(): void {
        if (!probeProc.running) probeProc.running = true;
    }

    Component.onCompleted: {
        hwDetectProc.running = true;
        refresh();
    }

    // True when any UI surface is actively displaying telemetry data
    readonly property bool hasActiveConsumer: Config.perfPopoverOpen
        || (Config.activeCenterPage === 2 && (Config.centerPopoverOpen || Config.centerBarHovered))
        || (Config.showDesktopWidgets && (Config.showWidgetBauhausDial || Config.showWidgetNetTelemetry || Config.showWidgetPulseHealth))

    Timer {
        id: pollTimer
        interval: Config.perfPopoverOpen ? 1800 : (root.hasActiveConsumer ? 4500 : 18000)
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Connections {
        target: Config
        function onPerfPopoverOpenChanged() { if (Config.perfPopoverOpen) root.refresh(); }
        function onActiveCenterPageChanged() { if (Config.activeCenterPage === 2) root.refresh(); }
        function onShowDesktopWidgetsChanged() { if (Config.showDesktopWidgets) root.refresh(); }
    }

    // Static Hardware Identity Auto-Detection (Runs once at startup)
    Process {
        id: hwDetectProc
        command: [
            "sh", "-c",
            "cpu=$(awk -F': ' '/model name/ {print $2; exit}' /proc/cpuinfo | sed -E 's/\\(R\\)|\\(TM\\)//g; s/ CPU @.*//; s/^[ \\t]*//; s/[ \\t]*$//; s/[ ]+/ /g'); " +
            "cores=$(grep -c '^processor' /proc/cpuinfo); " +
            "gpus=$(lspci | grep -E 'VGA|3D|Display'); " +
            "igpu=''; dgpu=''; " +
            "while IFS= read -r line; do " +
            "  if echo \"$line\" | grep -iq 'Intel'; then " +
            "    igpu=$(echo \"$line\" | sed -E 's/.*: (Intel Corporation )?//; s/ \\[//g; s/\\]//g; s/ \\(rev .*//'); " +
            "    if echo \"$igpu\" | grep -iq 'UHD Graphics'; then igpu=\"Intel UHD $(echo \"$igpu\" | grep -oE 'Graphics [0-9]+' | awk '{print $2}')\"; " +
            "    elif echo \"$igpu\" | grep -iq 'Iris'; then igpu=\"Intel Iris $(echo \"$igpu\" | grep -oE 'Xe|Plus|[0-9]+')\"; fi; " +
            "  elif echo \"$line\" | grep -iq 'Advanced Micro Devices\\|AMD\\|ATI'; then " +
            "    clean=$(echo \"$line\" | sed -E 's/.*: //; s/Advanced Micro Devices, Inc. //; s/\\[AMD\\/ATI\\] //; s/ \\(rev .*//'); " +
            "    if echo \"$clean\" | grep -iq '580'; then dgpu='AMD Radeon RX 580'; " +
            "    elif echo \"$clean\" | grep -iq '570'; then dgpu='AMD Radeon RX 570'; " +
            "    elif echo \"$clean\" | grep -iq '590'; then dgpu='AMD Radeon RX 590'; " +
            "    elif echo \"$clean\" | grep -iq '520'; then dgpu='AMD Radeon 520'; " +
            "    else " +
            "      rx=$(echo \"$clean\" | grep -oE 'RX [0-9]+[A-Z]*' | head -n1); " +
            "      if [ -n \"$rx\" ]; then dgpu=\"AMD Radeon $rx\"; " +
            "      else rad=$(echo \"$clean\" | grep -oE 'Radeon (Pro |R[0-9] )?[0-9]+[A-Za-z]*' | head -n1); [ -n \"$rad\" ] && dgpu=\"AMD $rad\" || dgpu='AMD Radeon'; fi; " +
            "    fi; " +
            "  elif echo \"$line\" | grep -iq 'NVIDIA'; then " +
            "    dgpu=\"NVIDIA $(echo \"$line\" | grep -oE '(RTX|GTX|MX) [0-9]+[A-Z]*' | head -n1 || echo 'GeForce')\"; " +
            "  fi; " +
            "done <<< \"$gpus\"; " +
            "printf '%s|%s|%s|%s\\n' \"${cpu:-Unknown CPU}\" \"${cores:-4} Threads\" \"${igpu:-Intel UHD}\" \"${dgpu}\""
        ]
        running: false
        stdout: SplitParser {
            onRead: data => {
                const line = data.trim();
                if (!line) return;
                const p = line.split("|");
                if (p.length >= 4) {
                    root.cpuModel = p[0] || root.cpuModel;
                    root.cpuCores = p[1] || root.cpuCores;
                    root.igpuName = p[2] || root.igpuName;
                    root.dgpuName = p[3] || "";
                    root.hasDualGpu = (root.dgpuName.length > 0);
                }
            }
        }
    }

    Process {
        id: probeProc
        command: [
            "sh", "-c",
            "awk '/^cpu / {t=$2+$3+$4+$5+$6+$7+$8+$9; i=$5+$6; printf \"%s|%s|\", t, i}' /proc/stat; " +
            "printf '%s|' \"$(cat /sys/class/thermal/thermal_zone7/temp 2>/dev/null || cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo 50000)\"; " +
            "awk '/^MemTotal:/ {t=$2} /^MemAvailable:/ {a=$2} /^Buffers:/ {b=$2} /^Cached:/ {c=$2} END {printf \"%s|%s|%s|\", t, a, b+c}' /proc/meminfo; " +
            "df -B1 / | awk 'NR==2 {printf \"%s|%s|\", $2, $3}'; " +
            "awk 'NR>2 && $1 !~ /^(lo|docker|veth|br-|virbr)/ {rx+=$2; tx+=$10} END {printf \"%s|%s|\", rx+0, tx+0}' /proc/net/dev; " +
            "printf '%s|' \"$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null || echo 2400000)\"; " +
            "printf '%s|%s|' \"$(cat /sys/class/drm/card1/gt_act_freq_mhz 2>/dev/null || cat /sys/class/drm/card0/gt_act_freq_mhz 2>/dev/null || echo 300)\" \"$(cat /sys/class/drm/card1/gt_max_freq_mhz 2>/dev/null || cat /sys/class/drm/card0/gt_max_freq_mhz 2>/dev/null || echo 1100)\"; " +
            "printf '%s|%s|%s|%s|' " +
            "\"$(cat /sys/class/drm/card0/device/power/runtime_status 2>/dev/null || cat /sys/class/drm/card1/device/power/runtime_status 2>/dev/null || echo active)\" " +
            "\"$(cat /sys/class/drm/card0/device/hwmon/hwmon*/temp1_input 2>/dev/null || cat /sys/class/drm/card1/device/hwmon/hwmon*/temp1_input 2>/dev/null || echo 0)\" " +
            "\"$(cat /sys/class/drm/card0/device/mem_info_vram_used 2>/dev/null || echo 0)\" " +
            "\"$(cat /sys/class/drm/card0/device/gpu_busy_percent 2>/dev/null || cat /sys/class/drm/card1/device/gpu_busy_percent 2>/dev/null || echo -1)\"; " +
            "printf '%s|' \"$(cat /sys/class/hwmon/hwmon*/fan1_input 2>/dev/null | head -n1 || echo 0)\"; " +
            "awk '/zram0/ {u=$4; s=$3} END {printf \"%s|%s|\", u+0, s+0}' /proc/swaps; " +
            "awk '/^cpu[0-9]+/ {ct=$2+$3+$4+$5+$6+$7+$8+$9; ci=$5+$6; cores=(cores ? cores \",\" : \"\") ct \":\" ci} END {printf \"%s\\n\", cores}' /proc/stat"
        ]
        running: false
        stdout: SplitParser {
            onRead: data => {
                const line = data.trim();
                if (!line) return;
                const p = line.split("|");
                if (p.length < 15) return;

                const now = Date.now();
                const dtSec = root.prevTimestamp > 0 ? Math.max(0.5, (now - root.prevTimestamp) / 1000.0) : 1.8;
                root.prevTimestamp = now;

                // 1. CPU Usage % & GHz
                const cpuTot = parseFloat(p[0]) || 0;
                const cpuIdl = parseFloat(p[1]) || 0;
                if (root.prevCpuTotal > 0 && cpuTot > root.prevCpuTotal) {
                    const dTot = cpuTot - root.prevCpuTotal;
                    const dIdl = cpuIdl - root.prevCpuIdle;
                    root.cpuPercent = Math.max(2, Math.min(100, Math.round(((dTot - dIdl) / dTot) * 100)));
                    root.cpuHistory = [...root.cpuHistory.slice(1), root.cpuPercent];
                }
                root.prevCpuTotal = cpuTot;
                root.prevCpuIdle = cpuIdl;

                const cpuKhz = parseFloat(p[10]) || 2400000;
                root.cpuFreqGhz = (cpuKhz / 1000000.0).toFixed(1);

                // 2. Temperature (Suhu °C)
                const rawTemp = parseFloat(p[2]) || 50000;
                root.tempC = Math.round(rawTemp > 1000 ? rawTemp / 1000.0 : rawTemp);

                // 3. RAM (Total, Available, Apps, Cache)
                const memTotKb = parseFloat(p[3]) || 1;
                const memAvailKb = parseFloat(p[4]) || 0;
                const memCacheRawKb = parseFloat(p[5]) || 0;
                const memUsedKb = Math.max(0, memTotKb - memAvailKb);
                const memCacheKb = Math.min(memUsedKb * 0.45, memCacheRawKb * 0.65);
                const memAppsKb = Math.max(0, memUsedKb - memCacheKb);

                root.ramPercent = Math.max(0, Math.min(100, Math.round((memUsedKb / memTotKb) * 100)));
                root.ramUsedGb = (memUsedKb / 1048576.0).toFixed(1);
                root.ramTotalGb = (memTotKb / 1048576.0).toFixed(1);
                root.ramFreeGb = (memAvailKb / 1048576.0).toFixed(1);
                root.ramAppsGb = (memAppsKb / 1048576.0).toFixed(1);
                root.ramCacheGb = (memCacheKb / 1048576.0).toFixed(1);
                root.ramAppsPercent = Math.max(5, Math.round((memAppsKb / memTotKb) * 100));
                root.ramCachePercent = Math.max(3, Math.round((memCacheKb / memTotKb) * 100));
                root.ramFreePercent = Math.max(2, 100 - root.ramPercent);
                root.ramHistory = [...root.ramHistory.slice(1), root.ramPercent];

                // 4. SSD (Root /)
                const ssdTotB = parseFloat(p[6]) || 1;
                const ssdUsedB = parseFloat(p[7]) || 0;
                const ssdFreeB = Math.max(0, ssdTotB - ssdUsedB);
                root.ssdPercent = Math.max(0, Math.min(100, Math.round((ssdUsedB / ssdTotB) * 100)));
                root.ssdUsedGb = Math.round(ssdUsedB / 1073741824.0).toString();
                root.ssdTotalGb = Math.round(ssdTotB / 1073741824.0).toString();
                root.ssdFreeGb = Math.round(ssdFreeB / 1073741824.0).toString();

                // 5. Network (Jaringan)
                const netRx = parseFloat(p[8]) || 0;
                const netTx = parseFloat(p[9]) || 0;
                if (root.prevNetRx > 0 && netRx >= root.prevNetRx) {
                    const rxRate = (netRx - root.prevNetRx) / dtSec;
                    const txRate = Math.max(0, (netTx - root.prevNetTx) / dtSec);
                    root.netDownText = root.formatSpeed(rxRate);
                    root.netUpText = root.formatSpeed(txRate);
                    const rxVal = root.scaleNetLog(rxRate);
                    const txVal = root.scaleNetLog(txRate);
                    const waveVal = root.scaleNetLog(rxRate + txRate);
                    root.netPercent = waveVal;
                    root.netHistory = [...root.netHistory.slice(1), waveVal];
                    root.netDownHistory = [...root.netDownHistory.slice(1), rxVal];
                    root.netUpHistory = [...root.netUpHistory.slice(1), txVal];
                }
                root.prevNetRx = netRx;
                root.prevNetTx = netTx;

                // 6. GPU (Kartu Grafis - iGPU)
                const intelAct = parseInt(p[11]) || 300;
                const intelMax = Math.max(301, parseInt(p[12]) || 1100);
                root.gpuFreqMhz = intelAct;
                root.gpuMaxMhz = intelMax;
                const intelScaled = Math.round(((intelAct - 300) / (intelMax - 300)) * 100);
                const intelBaseline = Math.min(100, Math.max(intelScaled, Math.round(root.cpuPercent * 0.55)));
                root.gpuPercent = Math.max(8, intelBaseline);

                // 7. Discrete GPU (dGPU) Telemetry
                const dgpuStatusRaw = (p[13] || "active").toLowerCase();
                root.dgpuStatus = dgpuStatusRaw === "suspended" ? "SLEEP" : "ACTIVE";
                const dgpuRawTemp = parseFloat(p[14]) || 0;
                root.dgpuTempC = Math.round(dgpuRawTemp > 1000 ? dgpuRawTemp / 1000.0 : dgpuRawTemp);
                const dgpuVramBytes = parseFloat(p[15]) || 0;
                root.dgpuVramUsedMb = Math.round(dgpuVramBytes / 1048576.0);
                const vramUsedGb = (dgpuVramBytes / 1073741824.0).toFixed(1);
                root.dgpuVramText = `${vramUsedGb} / 2.0 GiB`;

                const rawBusy = parseInt(p[16]);
                if (!isNaN(rawBusy) && rawBusy >= 0) {
                    root.dgpuPercent = rawBusy;
                } else if (root.dgpuStatus === "SLEEP") {
                    root.dgpuPercent = 0;
                } else {
                    root.dgpuPercent = root.dgpuVramUsedMb > 12 ? Math.min(100, Math.round((root.dgpuVramUsedMb / 2048.0) * 100) + 5) : 0;
                }

                // 8. Cooling Fan RPM
                root.fanRpm = parseInt(p[17]) || 0;

                // 9. ZRAM Swap
                const zUsedKb = parseFloat(p[18]) || 0;
                const zTotKb = parseFloat(p[19]) || 0;
                if (zTotKb > 0) {
                    root.zramUsedGb = (zUsedKb / 1048576.0).toFixed(1);
                    root.zramTotalGb = (zTotKb / 1048576.0).toFixed(1);
                    root.zramPercent = Math.round((zUsedKb / zTotKb) * 100);
                }

                // 10. Per-Core CPU Load Percentages
                const rawCores = p[20] ? p[20].trim() : "";
                if (rawCores) {
                    const corePairs = rawCores.split(",");
                    const curPcts = [];
                    const newTot = [];
                    const newIdl = [];
                    for (let c = 0; c < corePairs.length; c++) {
                        const parts = corePairs[c].split(":");
                        const cTot = parseFloat(parts[0]) || 0;
                        const cIdl = parseFloat(parts[1]) || 0;
                        newTot.push(cTot);
                        newIdl.push(cIdl);
                        if (root.prevCoresTot.length > c && root.prevCoresTot[c] > 0) {
                            const dTot = cTot - root.prevCoresTot[c];
                            const dIdl = cIdl - root.prevCoresIdl[c];
                            const pct = (dTot > 0) ? Math.max(0, Math.min(100, Math.round(((dTot - dIdl) / dTot) * 100))) : 0;
                            curPcts.push(pct);
                        } else {
                            curPcts.push(root.cpuPercent);
                        }
                    }
                    root.prevCoresTot = newTot;
                    root.prevCoresIdl = newIdl;
                    if (curPcts.length > 0) {
                        root.cpuCorePercents = curPcts;
                    }
                }

                root.tickCount = root.tickCount + 1;
            }
        }
    }
}
