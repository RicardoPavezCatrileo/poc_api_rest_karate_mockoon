# Monitoreo de TPS, latencia y recursos: de esta POC a Instana

Instana es una herramienta comercial de APM (monitoreo del rendimiento de aplicaciones) de IBM. No se puede ejecutar localmente sin una licencia o una cuenta de prueba, así que esta POC mide las mismas señales con Gatling y `MonitorRecursos`. Esta guía explica qué equivale a qué y cómo se trabajaría con Instana en un proyecto real.

## Qué mide cada lado

Gatling mide **desde el cliente**: el tiempo incluye la red y la cola del generador de carga. Un APM como Instana mide **desde el servidor**, con un agente en el host y trazas de cada llamada. En una prueba de performance se usan los dos: Gatling genera la carga y define el resultado de la prueba, e Instana explica dónde se fue el tiempo.

| Señal | En esta POC | En Instana |
|---|---|---|
| TPS (solicitudes por segundo) | `mean requests/sec` de Gatling, global y por solicitud; aserción `requestsPerSec().gte(45)` | Calls por segundo del servicio o endpoint, en la Application Perspective |
| Latencia (p50, p95, p99, máximo) | Percentiles de Gatling por solicitud; aserciones de p95 y p99 | Latencia del servicio y del endpoint, con percentiles, medida en el servidor |
| Tasa de errores | `failedRequests().percent()` y la columna KO | Erroneous calls (tasa de llamadas con error) |
| CPU del host | `cpu_host_pct` (`OperatingSystemMXBean`) | Métricas del host que recoge el agente de Instana |
| Memoria del host | `mem_host_mb` | Ídem |
| CPU y memoria del servicio | `cpu_mock_pct` (`ProcessHandle`) y `mem_mock_mb` (`tasklist` o `ps`) del proceso del mock | Métricas del proceso y del runtime: JVM (heap, GC, threads) o Node.js (event loop, heap) |
| Consumo del generador de carga | `cpu_inyector_pct` y `heap_inyector_mb` | Normalmente no se monitorea con Instana; el inyector corre fuera del sistema bajo prueba |
| Dónde se va el tiempo de una solicitud | No disponible: el mock no tiene dependencias | Trazas distribuidas: servicio, base de datos y llamadas a otros servicios |

## Cómo se usa en la POC

```powershell
.\mvnw.cmd test-compile gatling:test "-Dperfil=carga"     # o estres
node scripts\resumen-performance.mjs
```

- `MonitorRecursos` muestrea cada segundo (`-Dmonitor.intervaloMs`) y escribe `target/gatling-recursos/recursos.csv`, una fila por muestra para correlacionar con el tiempo de la prueba, y `resumen.json`, con el promedio y el máximo.
- El PID del mock se busca por el puerto de `baseUrl`. Si no se encuentra o el mock está en otra máquina, se puede pasar con `-DmockPid=1234`. Si no hay PID, solo se mide el host y el inyector.
- `resumen-performance.mjs` combina las estadísticas de Gatling con los recursos y escribe `target/gatling-recursos/resumen-performance.md`. En CI lo publica en el resumen del job.

## Cómo se detecta un cuello de botella

Las reglas de `resumen-performance.mjs` siguen el mismo razonamiento que se aplica en Instana:

1. **¿Hay errores?** Primero los errores, luego los tiempos: una respuesta rápida con error no cuenta.
2. **¿Qué endpoint es el más lento?** Se ordena por p95, no por el promedio, que esconde los casos lentos.
3. **¿Hay latencia de cola?** Un p99 muy superior a la mediana indica bloqueos, GC o colas, aunque el p95 se vea bien.
4. **¿El servicio se está saturando?** Si su CPU sube con cada escalón de carga mientras el host tiene margen, el servicio será el primer recurso en saturarse. En Node.js el límite es un núcleo, porque el event loop atiende en un solo hilo.
5. **¿El problema es el generador de carga?** Si el host se satura, o fallan las conexiones mientras el servidor responde rápido, el cuello de botella está en el inyector y no en el servicio. Ya ocurrió en esta POC: con escalones de 50 a 250 consultas por segundo se agotaron los puertos efímeros de Windows (`BindException`), mientras el p99 del servidor seguía en 28 ms (ver el comentario en `UsuariosSimulation.estres()`).

## Flujo con Instana en un proyecto real

1. Antes de la prueba: confirmar que el agente de Instana monitorea el host y el servicio (para Node.js se instala además el paquete de tracing en la aplicación) y que existe una Application Perspective para el servicio.
2. Anotar la hora de inicio y fin de la prueba, o marcarla en Instana, para filtrar exactamente esa ventana.
3. Durante la prueba: observar calls por segundo, latencia y erroneous calls del servicio y de cada endpoint, y en Infrastructure la CPU y la memoria del host y del proceso.
4. Después: comparar el TPS y los percentiles de Gatling con los de Instana. Si Gatling mide mucho más que Instana, el tiempo extra está en la red o en el inyector. Si Instana también lo mide, analizar las trazas de las llamadas lentas para ubicar el componente (consulta SQL, servicio externo, GC).
5. Reportar: TPS sostenido, percentiles contra el acuerdo de nivel de servicio, recursos en el pico, el cuello de botella con su evidencia (gráfico o traza) y el riesgo para producción.

## Limitaciones de esta medición

- El inyector y el mock comparten la máquina: compiten por la CPU, y los tiempos no representan un entorno de producción.
- En Windows, la CPU de un proceso se acumula en intervalos de unos 15 ms, por lo que una muestra aislada puede marcar 0 % o un pico. Hay que mirar la tendencia en `recursos.csv`, no una muestra suelta.
- La memoria del mock se lee con `tasklist` (Windows) o `ps` (Linux) en cada muestra, lo que agrega un proceso por segundo al host.
- No hay trazas: no se puede saber qué parte de la solicitud consumió el tiempo, que es justamente lo que aporta un APM.
