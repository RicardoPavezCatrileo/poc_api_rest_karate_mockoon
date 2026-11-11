@regression @timeout
Feature: Timeout del cliente frente a HTTP 504 y 524

  Tres situaciones que suelen confundirse:
  1. Timeout del cliente: no llega respuesta a tiempo y Karate corta la lectura. No hay código HTTP.
  2. HTTP 504: el servidor responde y el cliente recibe un código de estado.
  3. HTTP 524 simulado: igual que el 504; el código es propio de Cloudflare y Mockoon solo simula la respuesta.

  Ninguna prueba usa esperas fijas: la espera la produce el retardo de la ruta en Mockoon (15 s).

  Background:
    * url baseUrl
    * def errores = read('classpath:data/errores-http.json')
    * def tolerancia = 0.9

  @negative
  Scenario: El timeout del cliente corta la espera a los 5 segundos
    # karate.call dentro de try/catch: el timeout es el resultado esperado, no un fallo del escenario
    * def llamarConTimeoutCorto =
      """
      function() {
        var inicio = java.lang.System.currentTimeMillis();
        try {
          var r = karate.call('classpath:common/get-lento.feature', { timeoutMs: timeouts.shortReadMs });
          return { error: null, status: r.responseStatus, ms: java.lang.System.currentTimeMillis() - inicio };
        } catch (e) {
          return { error: '' + e, status: null, ms: java.lang.System.currentTimeMillis() - inicio };
        }
      }
      """
    * def resultado = llamarConTimeoutCorto()
    * match resultado.status == null
    * match resultado.error contains 'SocketTimeoutException: Read timed out'
    * assert resultado.ms >= timeouts.shortReadMs * tolerancia
    * assert resultado.ms < timeouts.slowDelayMs

  Scenario: El endpoint lento responde con un timeout suficiente de 20 segundos
    * configure readTimeout = timeouts.readMs
    Given path 'api', 'usuarios', 'lento'
    When method get
    Then status 200
    And match header Content-Type contains 'application/json'
    And match response == { mensaje: 'Respuesta lenta simulada.', retardo_ms: '#(timeouts.slowDelayMs)' }
    And assert responseTime >= timeouts.slowDelayMs * tolerancia
    And assert responseTime < timeouts.readMs

  @negative
  Scenario Outline: El HTTP <codigo> es una respuesta inmediata del servidor, no un timeout del cliente
    * def esperado = karate.filter(errores, function(e){ return e.codigo == codigo })[0]
    Given path 'api', 'errores', codigo
    When method get
    Then match responseStatus == codigo
    And match response == esperado
    And assert responseTime < maxResponseTimeMs

    Examples:
      | codigo! |
      | 504     |
      | 524     |

  @negative
  Scenario: 504 y 524 son respuestas distintas
    Given path 'api', 'errores', 504
    When method get
    * def gateway = response

    Given path 'api', 'errores', 524
    When method get
    * def simulada = response

    * match gateway.codigo != simulada.codigo
    * match gateway.error != simulada.error
    * match simulada.mensaje contains 'simulada'
    * match gateway.mensaje !contains 'simulada'
