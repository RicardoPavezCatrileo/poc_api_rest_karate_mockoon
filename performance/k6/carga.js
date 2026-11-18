// Prueba de carga con k6, equivalente al perfil "carga" de performance/UsuariosSimulation.java (Gatling).
//
// Misma inyección (modelo abierto: llegan N iteraciones por segundo, respondan o no las anteriores):
//   consultas: rampa de 1 a 20 por segundo en 10 s y 20 por segundo durante 30 s (2 solicitudes cada una)
//   login:     rampa de 1 a 5 por segundo en 10 s y 5 por segundo durante 30 s (2 solicitudes)
//   soap:      rampa de 1 a 5 por segundo en 10 s y 5 por segundo durante 30 s (1 solicitud)
// y los mismos umbrales del SLA. Si un umbral no se cumple, k6 termina con código de salida distinto de 0.
//
// Con Podman o Docker (k6 no necesita instalarse):
//   podman run --rm -e BASE_URL=http://host.containers.internal:3001 -v "${PWD}\performance\k6:/scripts:ro" `
//     -v "${PWD}\target\k6:/resultados" docker.io/grafana/k6:2.3.0 run /scripts/carga.js
// En Linux (CI): docker run --rm --network host -e BASE_URL=http://localhost:3001 ...

import http from 'k6/http';
import { check } from 'k6';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3001';
const RESULTADOS = __ENV.RESULTADOS || '/resultados';

const rampaYMeseta = (objetivo) => ({
  executor: 'ramping-arrival-rate',
  startRate: 1,
  timeUnit: '1s',
  preAllocatedVUs: objetivo,
  maxVUs: objetivo * 5,
  stages: [
    { target: objetivo, duration: '10s' },
    { target: objetivo, duration: '30s' },
  ],
});

// Nombres de solicitud iguales a los de Gatling, para comparar los reportes fila por fila
const NOMBRES = [
  'GET /api/usuarios',
  'GET /api/usuarios/{id}',
  'POST /api/auth/login',
  'GET /api/secure/usuarios',
  'POST /soap/usuarios',
];

export const options = {
  scenarios: {
    consultas: { ...rampaYMeseta(20), exec: 'consultas' },
    login: { ...rampaYMeseta(5), exec: 'loginYRecursoSeguro' },
    soap: { ...rampaYMeseta(5), exec: 'soap' },
  },
  thresholds: {
    'http_req_duration{fase:carga}': ['p(95)<500', 'p(99)<800', 'max<2000'],
    'http_req_failed{fase:carga}': ['rate<0.01'],
    'http_reqs{fase:carga}': ['rate>=45'],
    checks: ['rate==1.0'],
    'http_req_duration{name:POST /api/auth/login}': ['p(95)<500'],
    'http_req_duration{name:POST /soap/usuarios}': ['p(95)<500'],
    // Sin umbral propio: solo para que el resumen muestre los percentiles de cada solicitud
    'http_req_duration{name:GET /api/usuarios}': ['max>=0'],
    'http_req_duration{name:GET /api/usuarios/{id}}': ['max>=0'],
    'http_req_duration{name:GET /api/secure/usuarios}': ['max>=0'],
  },
  summaryTrendStats: ['avg', 'min', 'med', 'p(95)', 'p(99)', 'max'],
  // SIN_KEEPALIVE=1: una conexión nueva por solicitud, para comparar con Gatling + Karate (ver docs/k6-vs-gatling.md)
  noConnectionReuse: __ENV.SIN_KEEPALIVE === '1',
};

// Igual que preparar-datos.feature: parte de los datos iniciales; durante la carga solo se lee
export function setup() {
  const r = http.post(`${BASE_URL}/api/test/reset`, null, { tags: { name: 'POST /api/test/reset' } });
  if (r.status !== 200) {
    throw new Error(`No se pudieron preparar los datos: HTTP ${r.status}`);
  }
}

const carga = (name) => ({ tags: { name, fase: 'carga' } });
const idAlAzar = () => 1 + Math.floor(Math.random() * 3);

export function consultas() {
  const lista = http.get(`${BASE_URL}/api/usuarios`, carga('GET /api/usuarios'));
  check(lista, {
    'lista: status 200': (r) => r.status === 200,
    'lista: tiene usuarios': (r) => r.status === 200 && r.json().length > 0,
  });

  const id = idAlAzar();
  const usuario = http.get(`${BASE_URL}/api/usuarios/${id}`, carga('GET /api/usuarios/{id}'));
  check(usuario, {
    'usuario: status 200': (r) => r.status === 200,
    'usuario: es el pedido': (r) => r.status === 200 && r.json().id === id,
  });
}

export function loginYRecursoSeguro() {
  const login = http.post(`${BASE_URL}/api/auth/login`,
    JSON.stringify({ username: 'qa_user', password: 'demo123' }),
    { headers: { 'Content-Type': 'application/json' }, ...carga('POST /api/auth/login') });
  const ok = check(login, {
    'login: status 200': (r) => r.status === 200,
    'login: entrega token': (r) => r.status === 200 && typeof r.json().access_token === 'string',
  });
  if (!ok) {
    return;
  }

  const seguro = http.get(`${BASE_URL}/api/secure/usuarios`,
    { headers: { Authorization: `Bearer ${login.json().access_token}` }, ...carga('GET /api/secure/usuarios') });
  check(seguro, { 'recurso seguro: status 200': (r) => r.status === 200 });
}

export function soap() {
  const id = idAlAzar();
  const sobre =
    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:usu="http://poc.qa/usuarios">' +
    `<soapenv:Body><usu:ObtenerUsuario><usu:id>${id}</usu:id></usu:ObtenerUsuario></soapenv:Body></soapenv:Envelope>`;
  const r = http.post(`${BASE_URL}/soap/usuarios`, sobre, {
    headers: { 'Content-Type': 'text/xml; charset=utf-8', SOAPAction: 'http://poc.qa/usuarios/ObtenerUsuario' },
    ...carga('POST /soap/usuarios'),
  });
  check(r, {
    'soap: status 200': (res) => res.status === 200,
    'soap: es el usuario pedido': (res) => res.status === 200 && res.body.includes(`<usu:id>${id}</usu:id>`),
  });
}

// Resumen propio: una tabla comparable con la de Gatling y el JSON completo para el análisis
export function handleSummary(data) {
  const m = data.metrics;
  const ms = (v) => (v === undefined ? '-' : String(Math.round(v)));
  const fila = (nombre, clave) => {
    const t = m[clave] && m[clave].values;
    return t ? `| ${nombre} | ${ms(t.med)} | ${ms(t['p(95)'])} | ${ms(t['p(99)'])} | ${ms(t.max)} |` : `| ${nombre} | - | - | - | - |`;
  };
  const total = m['http_reqs{fase:carga}'].values;
  const fallidas = m['http_req_failed{fase:carga}'].values;
  const umbrales = [];
  for (const [metrica, def] of Object.entries(m)) {
    for (const [regla, r] of Object.entries(def.thresholds || {})) {
      if (regla !== 'max>=0') {
        umbrales.push(`- ${r.ok ? 'OK   ' : 'FALLA'} ${metrica}: ${regla}`);
      }
    }
  }
  const lineas = [
    '',
    `Solicitudes: ${total.count} · TPS medio: ${total.rate.toFixed(2)} · Fallidas: ${(fallidas.rate * 100).toFixed(2)} %`,
    '',
    '| Solicitud | p50 | p95 | p99 | Máx |',
    '|---|---:|---:|---:|---:|',
    fila('**Global**', 'http_req_duration{fase:carga}'),
    ...NOMBRES.map((n) => fila(n, `http_req_duration{name:${n}}`)),
    '',
    'Umbrales:',
    ...umbrales,
    '',
  ];
  return {
    stdout: lineas.join('\n'),
    [`${RESULTADOS}/resumen-k6.json`]: JSON.stringify(data, null, 2),
  };
}
