function fn() {
  // Entorno: -Dkarate.env=local (por defecto) o -Dkarate.env=ci
  var env = karate.env || 'local';
  if (env != 'local' && env != 'ci') {
    karate.fail('karate.env no soportado: ' + env + ' (use local o ci)');
  }

  var config = {
    env: env,
    // Se puede sobrescribir con -DbaseUrl=http://host:puerto
    baseUrl: karate.properties['baseUrl'] || 'http://localhost:3001',
    timeouts: {
      connectMs: 5000,
      // Timeout general; también es el "timeout suficiente" para /api/usuarios/lento
      readMs: 20000,
      // Timeout corto del cliente, menor que el retardo de la ruta lenta
      shortReadMs: 5000,
      // Debe coincidir con latency y retardo_ms de api/usuarios/lento en el mock
      slowDelayMs: 15000
    },
    maxResponseTimeMs: 2000
  };

  karate.configure('connectTimeout', config.timeouts.connectMs);
  karate.configure('readTimeout', config.timeouts.readMs);

  if (env == 'ci') {
    // En CI el log de Mockoon (--log-transaction) ya registra cada solicitud
    karate.configure('logPrettyRequest', false);
    karate.configure('logPrettyResponse', false);
  }

  return config;
}
