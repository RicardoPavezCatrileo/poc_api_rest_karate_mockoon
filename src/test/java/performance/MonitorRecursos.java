package performance;

import com.sun.management.OperatingSystemMXBean;

import java.io.IOException;
import java.lang.management.ManagementFactory;
import java.lang.management.MemoryMXBean;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Locale;
import java.util.Optional;
import java.util.OptionalLong;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Stream;

/**
 * Muestrea recursos mientras corre la simulación, como haría un agente de APM (Instana) en el host.
 *
 * Por muestra registra: CPU y memoria del host, CPU y heap de la JVM que genera la carga (inyector)
 * y CPU y memoria del proceso del mock. El PID del mock se toma de -DmockPid o se busca por el puerto
 * de baseUrl (netstat en Windows, ss en Linux); si no se encuentra, esas columnas quedan vacías.
 *
 * Escribe target/gatling-recursos/recursos.csv (una fila por muestra) y resumen.json (promedio y máximo),
 * que scripts/resumen-performance.mjs combina con las estadísticas de Gatling.
 */
final class MonitorRecursos {

    private static final Path DIRECTORIO = Path.of("target", "gatling-recursos");
    private static final String CABECERA =
            "segundo,cpu_host_pct,mem_host_mb,cpu_inyector_pct,heap_inyector_mb,cpu_mock_pct,mem_mock_mb";

    private final OperatingSystemMXBean so =
            (OperatingSystemMXBean) ManagementFactory.getOperatingSystemMXBean();
    private final MemoryMXBean memoria = ManagementFactory.getMemoryMXBean();
    private final boolean windows = System.getProperty("os.name", "").toLowerCase(Locale.ROOT).contains("win");
    private final ScheduledExecutorService programador = Executors.newSingleThreadScheduledExecutor(tarea -> {
        Thread hilo = new Thread(tarea, "monitor-recursos");
        hilo.setDaemon(true);
        return hilo;
    });
    private final List<double[]> muestras = new ArrayList<>();
    private final long intervaloMs;
    private final OptionalLong mockPid;

    private long inicioNanos;
    private long anteriorNanos;
    private Duration anteriorCpuMock;

    MonitorRecursos(String baseUrl, long intervaloMs) {
        this.intervaloMs = intervaloMs;
        this.mockPid = buscarPidMock(baseUrl);
    }

    void iniciar() {
        so.getCpuLoad(); // La primera lectura de carga de CPU no es significativa
        inicioNanos = System.nanoTime();
        anteriorNanos = inicioNanos;
        anteriorCpuMock = cpuMock().orElse(null);
        programador.scheduleAtFixedRate(this::muestrear, intervaloMs, intervaloMs, TimeUnit.MILLISECONDS);
        System.out.printf("[monitor] Muestreo cada %d ms; PID del mock: %s%n", intervaloMs,
                mockPid.isPresent() ? mockPid.getAsLong() : "no encontrado (solo host e inyector)");
    }

    /** Detiene el muestreo y escribe el CSV y el resumen. */
    void detener(String perfil) {
        programador.shutdownNow();
        try {
            programador.awaitTermination(intervaloMs, TimeUnit.MILLISECONDS);
            escribir(perfil);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        } catch (IOException e) {
            System.err.println("[monitor] No se pudieron escribir los resultados: " + e.getMessage());
        }
    }

    private void muestrear() {
        long ahora = System.nanoTime();
        double cpuMockPct = Double.NaN;
        Optional<Duration> cpu = cpuMock();
        if (cpu.isPresent() && anteriorCpuMock != null) {
            // Porcentaje de un núcleo: Node atiende las solicitudes en un solo hilo, así que 100 % es saturación
            cpuMockPct = 100.0 * cpu.get().minus(anteriorCpuMock).toNanos() / (ahora - anteriorNanos);
        }
        anteriorCpuMock = cpu.orElse(null);
        anteriorNanos = ahora;

        double[] muestra = {
                (ahora - inicioNanos) / 1e9,
                100.0 * so.getCpuLoad(),
                (so.getTotalMemorySize() - so.getFreeMemorySize()) / 1048576.0,
                100.0 * so.getProcessCpuLoad(),
                memoria.getHeapMemoryUsage().getUsed() / 1048576.0,
                cpuMockPct,
                memoriaMockMb()
        };
        synchronized (muestras) {
            muestras.add(muestra);
        }
    }

    private void escribir(String perfil) throws IOException {
        List<double[]> copia;
        synchronized (muestras) {
            copia = new ArrayList<>(muestras);
        }
        Files.createDirectories(DIRECTORIO);

        List<String> lineas = new ArrayList<>();
        lineas.add(CABECERA);
        for (double[] m : copia) {
            List<String> valores = new ArrayList<>();
            for (double v : m) {
                valores.add(Double.isNaN(v) ? "" : String.format(Locale.ROOT, "%.1f", v));
            }
            lineas.add(String.join(",", valores));
        }
        Files.write(DIRECTORIO.resolve("recursos.csv"), lineas, StandardCharsets.UTF_8);

        String[] columnas = CABECERA.split(",");
        StringBuilder json = new StringBuilder("{\n");
        json.append(String.format(Locale.ROOT, "  \"perfil\": \"%s\",%n  \"muestras\": %d,%n  \"intervaloMs\": %d,%n",
                perfil, copia.size(), intervaloMs));
        json.append(String.format(Locale.ROOT, "  \"nucleos\": %d,%n  \"memHostTotalMb\": %.0f,%n  \"mockPid\": %s,%n",
                so.getAvailableProcessors(), so.getTotalMemorySize() / 1048576.0,
                mockPid.isPresent() ? String.valueOf(mockPid.getAsLong()) : "null"));
        json.append("  \"metricas\": {\n");
        for (int c = 1; c < columnas.length; c++) {
            final int indice = c;
            double[] valores = copia.stream().mapToDouble(m -> m[indice]).filter(v -> !Double.isNaN(v)).toArray();
            String promedio = valores.length == 0 ? "null"
                    : String.format(Locale.ROOT, "%.1f", Arrays.stream(valores).average().orElse(0));
            String maximo = valores.length == 0 ? "null"
                    : String.format(Locale.ROOT, "%.1f", Arrays.stream(valores).max().orElse(0));
            json.append(String.format("    \"%s\": { \"promedio\": %s, \"maximo\": %s }%s%n",
                    columnas[c], promedio, maximo, c < columnas.length - 1 ? "," : ""));
        }
        json.append("  }\n}\n");
        Files.writeString(DIRECTORIO.resolve("resumen.json"), json.toString(), StandardCharsets.UTF_8);
        System.out.printf("[monitor] %d muestras en %s%n", copia.size(), DIRECTORIO.toAbsolutePath());
    }

    /** CPU acumulada del proceso del mock y sus descendientes (npx puede lanzar node como hijo). */
    private Optional<Duration> cpuMock() {
        if (mockPid.isEmpty()) {
            return Optional.empty();
        }
        return ProcessHandle.of(mockPid.getAsLong()).map(raiz -> Stream.concat(Stream.of(raiz), raiz.descendants())
                .map(p -> p.info().totalCpuDuration().orElse(Duration.ZERO))
                .reduce(Duration.ZERO, Duration::plus));
    }

    /** Memoria residente del mock en MB. ProcessHandle no la expone, así que se consulta al sistema operativo. */
    private double memoriaMockMb() {
        if (mockPid.isEmpty()) {
            return Double.NaN;
        }
        String pid = String.valueOf(mockPid.getAsLong());
        // tasklist: "node.exe","19476","Console","1","229,176 KB" (unidad y separador de miles dependen del idioma)
        // ps: 64400
        Matcher m = windows
                ? Pattern.compile("\"" + pid + "\".*\"([\\d.,\\s ]+?)\\s*KB?\"")
                        .matcher(ejecutar("tasklist", "/FI", "PID eq " + pid, "/FO", "CSV", "/NH"))
                : Pattern.compile("^\\s*(\\d+)\\s*$").matcher(ejecutar("ps", "-o", "rss=", "-p", pid));
        if (!m.find()) {
            return Double.NaN;
        }
        return Long.parseLong(m.group(1).replaceAll("\\D", "")) / 1024.0;
    }

    private OptionalLong buscarPidMock(String baseUrl) {
        String propiedad = System.getProperty("mockPid", "").trim();
        if (!propiedad.isEmpty()) {
            return OptionalLong.of(Long.parseLong(propiedad));
        }
        URI uri = URI.create(baseUrl);
        String host = uri.getHost();
        if (!"localhost".equals(host) && !"127.0.0.1".equals(host)) {
            return OptionalLong.empty(); // El mock está en otra máquina: solo se mide el inyector
        }
        int puerto = uri.getPort() == -1 ? 80 : uri.getPort();
        Matcher m;
        if (windows) {
            // TCP    0.0.0.0:3001    0.0.0.0:0    LISTENING    19476
            m = Pattern.compile("(?m)^\\s*TCP\\s+\\S+:" + puerto + "\\s+\\S+\\s+\\S+\\s+(\\d+)\\s*$")
                    .matcher(ejecutar("netstat", "-ano", "-p", "TCP"));
        } else {
            // LISTEN 0 511 *:3001 *:* users:(("node",pid=1234,fd=21))
            m = Pattern.compile("pid=(\\d+)").matcher(ejecutar("ss", "-ltnpH", "sport", "=", ":" + puerto));
        }
        return m.find() ? OptionalLong.of(Long.parseLong(m.group(1))) : OptionalLong.empty();
    }

    private static String ejecutar(String... comando) {
        try {
            Process proceso = new ProcessBuilder(comando).redirectErrorStream(true).start();
            String salida = new String(proceso.getInputStream().readAllBytes(), StandardCharsets.UTF_8).trim();
            proceso.waitFor(5, TimeUnit.SECONDS);
            return salida;
        } catch (IOException e) {
            return "";
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            return "";
        }
    }
}
