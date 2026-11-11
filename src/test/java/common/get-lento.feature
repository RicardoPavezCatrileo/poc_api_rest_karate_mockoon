@ignore
Feature: GET /api/usuarios/lento con un timeout de lectura propio

  Lo invoca timeouts.feature con karate.call dentro de un try/catch, para que el timeout del cliente
  sea un resultado esperado y no una prueba fallida. Parámetro: timeoutMs.
  Karate registra el timeout como ERROR en el log aunque el escenario que llama pase.

  Scenario: Llamar al endpoint lento
    * configure readTimeout = timeoutMs
    Given url baseUrl
    And path 'api', 'usuarios', 'lento'
    When method get
