# k6 frente a Gatling

La misma prueba de carga escrita en las dos herramientas: `performance/UsuariosSimulation.java` (Gatling con karate-gatling, perfil `carga`) y `performance/k6/carga.js` (k6 2.3.0).

## Qué hace cada una

| | Gatling (karate-gatling) | k6 |
|---|---|---|
| Inyección | Modelo abierto: `rampUsersPerSec(1).to(20).during(10)` y `constantUsersPerSec(20).during(30)` | Modelo abierto: ejecutor `ramping-arrival-rate`, 1 → 20 en 10 s y 20 durante 30 s |
| Escenarios | Consultas (20/s), login + recurso seguro (5/s), SOAP (5/s) | Los mismos, con los mismos nombres de solicitud |
| Preparación | `preparar-datos.feature` antes de la simulación | `setup()` con `POST /api/test/reset` |
| Validación de cada respuesta | Los `match` de los features de Karate | `check()` sobre status, cuerpo e id |
| SLA | Aserciones: p95 < 500 ms, p99 < 800 ms, máx < 2 s, errores < 1 %, TPS ≥ 45, p95 de login y SOAP < 500 ms | Thresholds con los mismos valores, más `checks == 100 %` |
| Si no se cumple | El build de Maven falla | k6 termina con código de salida distinto de 0 |
| Lenguaje | Java (simulación) y Gherkin de Karate (pasos) | JavaScript |
| Reporte | HTML por ejecución en `target/gatling/` | Resumen en consola y JSON completo en `target/k6/resumen-k6.json` |
| Ejecución en la POC | Maven (`gatling:test`), en una JVM aparte | Contenedor `grafana/k6:2.3.0`; no hay que instalar k6 |

## Resultados

Ejecuciones del 2026-11-11, con el **mismo mock** (Mockoon 9.10.0 en contenedor, Podman 5.8.3) y la misma carga:

| Herramienta | Solicitudes | TPS medio | Fallidas | p50 | p95 | p99 | Máx | Umbrales |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| Gatling | 1.950 | 48,75 | 0 % | 10 | 32 | 70 | 261 | 7 de 7 |
| k6 | 1.950 | 48,71 | 0 % | 6 | 13 | 18 | 58 | 8 de 8 |
| k6 sin reutilizar conexiones | 1.945 | 48,61 | 0 % | 6 | 14 | 21 | 47 | 8 de 8 |

Tiempos en ms.

**Lo que sí se puede afirmar:**

- Las dos generan la misma carga (mismo volumen y mismo TPS) y las dos dan el SLA por cumplido.
- k6 falla cuando debe. Con el mock inaccesible, `setup()` lanzó un error y k6 terminó con código de salida 107, sin un resultado en verde.

**Lo que no se puede afirmar:** que una herramienta mida tiempos más bajos que la otra. Las latencias de Gatling fueron mayores, pero las dos corrieron en lugares distintos:

- **Keep-alive: descartado.** Gatling a través de Karate abre conexiones nuevas en cada iteración. Para probarlo, k6 se ejecutó sin reutilizar conexiones (`SIN_KEEPALIVE=1`) y su p95 pasó de 13 a 14 ms. Abrir la conexión costó en promedio 0,5 ms (`http_req_connecting`).
- **Ruta de red: hipótesis sin verificar.** k6 corre dentro de la máquina de Podman, en la misma red que el contenedor de Mockoon. Gatling corre en Windows y llega al mock por el reenvío de puertos de Podman. Para compararlas de verdad hay que ejecutarlas desde el mismo lugar: las dos en Linux en CI, o k6 instalado en Windows.

## Cuándo usar cada una

| Situación | Conviene |
|---|---|
| El equipo ya escribe pruebas funcionales en Karate y quiere reutilizarlas como carga | Gatling con karate-gatling |
| Escenarios de carga en Java, Scala o Kotlin, con reportes HTML detallados | Gatling |
| Scripts de carga livianos en JavaScript, un solo binario y umbrales que cortan el pipeline | k6 |
| Dashboards en tiempo real (Grafana) | k6, que se integra de forma nativa |

## Cómo ejecutar k6

```powershell
podman run --rm -e BASE_URL=http://host.containers.internal:3001 `
  -v "${PWD}\performance\k6:/scripts:ro" -v "${PWD}\target\k6:/resultados" `
  docker.io/grafana/k6:2.3.0 run --quiet /scripts/carga.js
```

`BASE_URL` debe apuntar a un mock alcanzable desde el contenedor. En la verificación local se usó el Mockoon en contenedor (`compose.yaml`); un Mockoon CLI nativo de Windows no fue alcanzable desde el contenedor (`connection refused`). En CI (Linux) se usa `--network host` y `BASE_URL=http://localhost:3001`.
