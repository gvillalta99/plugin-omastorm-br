pragma Singleton
import QtQuick

QtObject {
    id: ws

    property real currentLat: 0
    property real currentLon: 0

    property bool loading: false
    property string error: ""

    // Current weather
    property real temperature: NaN
    property real apparentTemperature: NaN
    property real humidity: NaN
    property real precipitation: NaN
    property real rain: NaN
    property int weatherCode: -1
    property real windSpeed: NaN
    property real windGusts: NaN
    property real windDirection: NaN

    // Wind grid points for vector overlay on the map: array of { lat, lon, speed, dir, gusts }
    property var windGrid: []
    property bool windGridLoading: false

    // Daily summary
    property real tempMax: NaN
    property real tempMin: NaN
    property int precipProb: 0
    property real precipSum: 0

    // Beaufort scale color helper for wind speeds (km/h)
    function windColor(speedKmH) {
        if (isNaN(speedKmH) || speedKmH <= 0) return "#708090";
        if (speedKmH < 12) return "#5dade2"; // Leve / calmo (azul claro)
        if (speedKmH < 25) return "#48c9b0"; // Moderado (verde-água)
        if (speedKmH < 40) return "#f4d03f"; // Vento fresco/forte (amarelo)
        if (speedKmH < 60) return "#e67e22"; // Muito forte (laranja)
        return "#e74c3c";                    // Vendaval / tempestade (vermelho)
    }

    readonly property string conditionText: {
        switch (weatherCode) {
            case 0: return "Céu limpo";
            case 1: return "Principalmente limpo";
            case 2: return "Parcialmente nublado";
            case 3: return "Nublado";
            case 45: case 48: return "Nevoeiro";
            case 51: case 53: case 55: return "Garoa";
            case 61: return "Chuva fraca";
            case 63: return "Chuva moderada";
            case 65: return "Chuva forte";
            case 71: case 73: case 75: return "Neve";
            case 80: return "Pancadas fracas";
            case 81: return "Pancadas de chuva";
            case 82: return "Pancadas violentas";
            case 95: return "Trovoada / Tempestade";
            case 96: case 99: return "Tempestade c/ granizo";
            default: return weatherCode >= 0 ? "Chuva / Tempo instável" : "—";
        }
    }

    readonly property string windDirectionText: {
        if (isNaN(windDirection)) return "";
        var dirs = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"];
        var idx = Math.round(windDirection / 22.5) % 16;
        return dirs[idx];
    }

    function fetch(lat, lon) {
        if (isNaN(lat) || isNaN(lon) || (lat === 0 && lon === 0)) return;
        currentLat = lat;
        currentLon = lon;
        loading = true;

        var url = "https://api.open-meteo.com/v1/forecast?latitude=" + lat.toFixed(4)
            + "&longitude=" + lon.toFixed(4)
            + "&current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,rain,weather_code,wind_speed_10m,wind_direction_10m,wind_gusts_10m"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,precipitation_sum&forecast_days=1"
            + "&timezone=auto";

        var xhr = new XMLHttpRequest();
        xhr.open("GET", url);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                loading = false;
                if (xhr.status === 200) {
                    try {
                        var data = JSON.parse(xhr.responseText);
                        if (data.current) {
                            ws.temperature = data.current.temperature_2m;
                            ws.apparentTemperature = data.current.apparent_temperature;
                            ws.humidity = data.current.relative_humidity_2m;
                            ws.precipitation = data.current.precipitation;
                            ws.rain = data.current.rain;
                            ws.weatherCode = data.current.weather_code;
                            ws.windSpeed = data.current.wind_speed_10m;
                            ws.windDirection = data.current.wind_direction_10m;
                            ws.windGusts = data.current.wind_gusts_10m;
                        }
                        if (data.daily) {
                            if (data.daily.temperature_2m_max && data.daily.temperature_2m_max.length)
                                ws.tempMax = data.daily.temperature_2m_max[0];
                            if (data.daily.temperature_2m_min && data.daily.temperature_2m_min.length)
                                ws.tempMin = data.daily.temperature_2m_min[0];
                            if (data.daily.precipitation_probability_max && data.daily.precipitation_probability_max.length)
                                ws.precipProb = data.daily.precipitation_probability_max[0];
                            if (data.daily.precipitation_sum && data.daily.precipitation_sum.length)
                                ws.precipSum = data.daily.precipitation_sum[0];
                        }
                        ws.error = "";
                    } catch (e) {
                        ws.error = "Open-Meteo parse error: " + e;
                    }
                }
            }
        };
        xhr.send();
    }

    // Fetch wind grid for current viewport region (e.g. 5x5 sample points around viewCenter)
    function fetchWindGrid(lat, lon, spanKm) {
        if (isNaN(lat) || isNaN(lon) || (lat === 0 && lon === 0)) return;
        var r = spanKm || 200;
        // ~111 km per degree latitude
        var dLat = (r / 111) * 0.85;
        var cosLat = Math.cos(lat * Math.PI / 180);
        var dLon = (r / (111 * Math.max(0.2, cosLat))) * 0.85;

        // Generate 5x5 grid coordinates
        var lats = [];
        var lons = [];
        var rows = 5;
        var cols = 5;
        for (var i = 0; i < rows; i++) {
            var currLat = lat - dLat + (2 * dLat * i / (rows - 1));
            for (var j = 0; j < cols; j++) {
                var currLon = lon - dLon + (2 * dLon * j / (cols - 1));
                lats.push(currLat.toFixed(3));
                lons.push(currLon.toFixed(3));
            }
        }

        windGridLoading = true;
        var url = "https://api.open-meteo.com/v1/forecast?latitude=" + lats.join(",")
            + "&longitude=" + lons.join(",")
            + "&current=wind_speed_10m,wind_direction_10m,wind_gusts_10m";

        var xhr = new XMLHttpRequest();
        xhr.open("GET", url);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                windGridLoading = false;
                if (xhr.status === 200) {
                    try {
                        var res = JSON.parse(xhr.responseText);
                        var points = [];
                        if (Array.isArray(res)) {
                            for (var k = 0; k < res.length; k++) {
                                var item = res[k];
                                if (item.current) {
                                    points.push({
                                        lat: item.latitude,
                                        lon: item.longitude,
                                        speed: item.current.wind_speed_10m,
                                        dir: item.current.wind_direction_10m,
                                        gusts: item.current.wind_gusts_10m
                                    });
                                }
                            }
                        } else if (res.current) {
                            points.push({
                                lat: res.latitude,
                                lon: res.longitude,
                                speed: res.current.wind_speed_10m,
                                dir: res.current.wind_direction_10m,
                                gusts: res.current.wind_gusts_10m
                            });
                        }
                        ws.windGrid = points;
                    } catch (err) {
                        console.log("Wind grid error:", err);
                    }
                }
            }
        };
        xhr.send();
    }

    function fetchWeather(lat, lon) {
        fetch(lat, lon);
    }

    property Timer pollTimer: Timer {
        interval: 600000 // 10 minutes
        running: true
        repeat: true
        onTriggered: {
            if (ws.currentLat !== 0 && ws.currentLon !== 0) {
                ws.fetch(ws.currentLat, ws.currentLon);
            }
        }
    }
}
