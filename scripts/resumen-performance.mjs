// Resume la última ejecución de Gatling: TPS, latencias por endpoint, aserciones, recursos y hallazgos.
//
//   node scripts/resumen-performance.mjs
//
// Lee target/gatling/<última ejecución>/js/stats.json y assertions.xml, más target/gatling-recursos/resumen.json
// (MonitorRecursos). Escribe target/gatling-recursos/resumen-performance.md y lo agrega al resumen del job en
// GitHub Actions (GITHUB_STEP_SUMMARY) o en Azure DevOps (##vso[task.uploadsummary]).
// No decide si la prueba pasa: eso lo hacen las aserciones de Gatling, que fallan el build.

import { appendFileSync, existsSync, readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { resolve } from 'node:path';

// Umbrales de los hallazgos (no del acuerdo de nivel de servicio, que está en UsuariosSimulation)
const CPU_MOCK_SATURACION_PCT = 80; // Porcentaje de un núcleo: Node atiende en un solo hilo
const CPU_HOST_SATURACION_PCT = 80;
const COLA_P99_SOBRE_P50 = 3; // p99 más de 3 veces la mediana indica latencia de cola...
const COLA_DIFERENCIA_MINIMA_MS = 50; // ...siempre que la diferencia sea relevante (no 10 ms contra 33 ms)

const raiz = process.cwd();
const dirGatling = resolve(raiz, 'target', 'gatling');
const lastRun = resolve(dirGatling, 'lastRun.txt');
if (!existsSync(lastRun)) {
  console.error('No hay ejecuciones de Gatling: ejecute antes .\\mvnw.cmd test-compile gatling:test');
  process.exit(1);
}
const ejecucion = readFileSync(lastRun, 'utf8').trim().split(/\r?\n/).pop();
const dirEjecucion = resolve(dirGatling, ejecucion);
const stats = JSON.parse(readFileSync(resolve(dirEjecucion, 'js', 'stats.json'), 'utf8'));
const xmlAserciones = readFileSync(resolve(dirEjecucion, 'js', 'assertions.xml'), 'utf8');
const archivoRecursos = resolve(raiz, 'target', 'gatling-recursos', 'resumen.json');
const recursos = existsSync(archivoRecursos) ? JSON.parse(readFileSync(archivoRecursos, 'utf8')) : null;

// Gatling escribe los percentiles configurados en gatling.conf; por defecto 50, 75, 95 y 99
const fila = (nombre, s) => ({
  nombre,
  total: s.numberOfRequests.total,
  ko: s.numberOfRequests.ko,
  tps: s.meanNumberOfRequestsPerSecond.total,
  p50: s.percentiles1.total,
  p95: s.percentiles3.total,
  p99: s.percentiles4.total,
  max: s.maxResponseTime.total,
});
const global = fila('Global', stats.stats);
const endpoints = Object.values(stats.contents)
  .filter((c) => c.type === 'REQUEST')
  .map((c) => fila(c.name, c.stats))
  .sort((a, b) => b.p95 - a.p95);

const aserciones = [...xmlAserciones.matchAll(/<testcase name="([^"]+)" status="(true|false)"/g)]
  .map(([, nombre, estado]) => ({ nombre: decodificar(nombre), ok: estado === 'true' }));

const numero = (v, decimales = 0) =>
  v === null || v === undefined ? '-' : Number(v).toLocaleString('es-CL', { maximumFractionDigits: decimales });
const metrica = (clave) => recursos?.metricas?.[clave] ?? { promedio: null, maximo: null };

const lineas = [];
lineas.push(`## Performance: ${ejecucion}`, '');
lineas.push(`Perfil: **${recursos?.perfil ?? 'desconocido'}**. Tiempos en ms; TPS = solicitudes por segundo de media.`, '');
lineas.push('| Solicitud | Total | KO | TPS | p50 | p95 | p99 | Máx |', '|---|---:|---:|---:|---:|---:|---:|---:|');
for (const f of [global, ...endpoints]) {
  const n = f === global ? `**${f.nombre}**` : f.nombre;
  lineas.push(`| ${n} | ${numero(f.total)} | ${numero(f.ko)} | ${numero(f.tps, 2)} | ${f.p50} | ${f.p95} | ${f.p99} | ${f.max} |`);
}

lineas.push('', '### Aserciones', '');
for (const a of aserciones) {
  lineas.push(`- ${a.ok ? '✅' : '❌'} ${a.nombre}`);
}

lineas.push('', '### Recursos', '');
if (recursos) {
  lineas.push(`${recursos.muestras} muestras cada ${recursos.intervaloMs} ms; host con ${recursos.nucleos} núcleos y ` +
    `${numero(recursos.memHostTotalMb)} MB. PID del mock: ${recursos.mockPid ?? 'no encontrado'}.`, '');
  lineas.push('| Recurso | Promedio | Máximo |', '|---|---:|---:|');
  const filasRecursos = [
    ['CPU host (%)', 'cpu_host_pct'],
    ['Memoria host usada (MB)', 'mem_host_mb'],
    ['CPU inyector Gatling (% del host)', 'cpu_inyector_pct'],
    ['Heap inyector (MB)', 'heap_inyector_mb'],
    ['CPU mock (% de un núcleo)', 'cpu_mock_pct'],
    ['Memoria mock (MB)', 'mem_mock_mb'],
  ];
  for (const [nombre, clave] of filasRecursos) {
    const m = metrica(clave);
    lineas.push(`| ${nombre} | ${numero(m.promedio, 1)} | ${numero(m.maximo, 1)} |`);
  }
} else {
  lineas.push('Sin datos: no se encontró target/gatling-recursos/resumen.json.');
}

lineas.push('', '### Hallazgos', '');
const hallazgos = [];
const conErrores = endpoints.filter((f) => f.ko > 0);
if (conErrores.length) {
  hallazgos.push(`Errores en: ${conErrores.map((f) => `${f.nombre} (${f.ko})`).join(', ')}. Revisar simulation.log.`);
}
if (endpoints.length) {
  const lento = endpoints[0];
  hallazgos.push(`Endpoint con mayor p95: ${lento.nombre} (${lento.p95} ms; p99 ${lento.p99} ms).`);
}
const conCola = endpoints.filter(
  (f) => f.p50 > 0 && f.p99 / f.p50 > COLA_P99_SOBRE_P50 && f.p99 - f.p50 >= COLA_DIFERENCIA_MINIMA_MS,
);
if (conCola.length) {
  hallazgos.push(`Latencia de cola (p99 > ${COLA_P99_SOBRE_P50} x p50 y ${COLA_DIFERENCIA_MINIMA_MS} ms más) en: ${conCola.map((f) => f.nombre).join(', ')}.`);
}
const cpuMock = metrica('cpu_mock_pct').maximo;
if (cpuMock !== null && cpuMock >= CPU_MOCK_SATURACION_PCT) {
  hallazgos.push(`El mock tuvo picos de ${numero(cpuMock, 1)} % de un núcleo (promedio ` +
    `${numero(metrica('cpu_mock_pct').promedio, 1)} %): con más carga, su hilo de eventos sería el primer recurso ` +
    'en saturarse. Revisar en recursos.csv si el consumo crece con cada escalón.');
}
const cpuHost = metrica('cpu_host_pct').maximo;
if (cpuHost !== null && cpuHost >= CPU_HOST_SATURACION_PCT) {
  hallazgos.push(`El host llegó a ${numero(cpuHost, 1)} % de CPU: el inyector y el mock compiten por la máquina ` +
    'y los tiempos pueden estar inflados por el generador de carga.');
}
if (!conErrores.length && (cpuMock ?? 0) < CPU_MOCK_SATURACION_PCT && (cpuHost ?? 0) < CPU_HOST_SATURACION_PCT) {
  hallazgos.push('Sin errores ni saturación de CPU: el servicio tiene margen para la carga aplicada.');
}
lineas.push(...hallazgos.map((h) => `- ${h}`));

const markdown = lineas.join('\n') + '\n';
const dirSalida = resolve(raiz, 'target', 'gatling-recursos');
mkdirSync(dirSalida, { recursive: true });
const salida = resolve(dirSalida, 'resumen-performance.md');
writeFileSync(salida, markdown, 'utf8');
console.log(markdown);

if (process.env.GITHUB_STEP_SUMMARY) {
  appendFileSync(process.env.GITHUB_STEP_SUMMARY, markdown, 'utf8');
}
if (process.env.TF_BUILD) {
  console.log(`##vso[task.uploadsummary]${salida}`);
}

function decodificar(texto) {
  return texto.replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&amp;/g, '&');
}
