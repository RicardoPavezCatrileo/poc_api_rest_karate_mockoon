@regression @security
Feature: GET /api/apikey/usuarios con X-API-Key

  Background:
    * call read('classpath:common/reset.feature')
    * url baseUrl
    * def auth = read('classpath:data/auth.json')
    * def datos = read('classpath:data/usuarios.json')
    * def esquemaUsuario = read('classpath:common/schemas/usuario.json')
    * def camposSensibles = read('classpath:common/campos-sensibles.js')
    * def apiKeyRechazada = { codigo: 401, error: 'Unauthorized', mensaje: '#regex .*API Key.*' }

  @smoke
  Scenario: Una API Key válida accede al recurso
    Given path 'api', 'apikey', 'usuarios'
    And header X-API-Key = auth.apiKeyValida
    When method get
    Then status 200
    And match header Content-Type contains 'application/json'
    And match each response == esquemaUsuario
    And match camposSensibles(response) == []
    And match response[*].id == datos.existentes

  @negative
  Scenario: Sin API Key responde 401
    # La ausencia va en un escenario propio: header X-API-Key = null enviaría el texto "null"
    Given path 'api', 'apikey', 'usuarios'
    When method get
    Then status 401
    And match header Content-Type contains 'application/json'
    And match response == apiKeyRechazada

  @negative
  Scenario Outline: Una API Key rechazada responde 401: <caso>
    # Con apiKey '' Karate envía la cabecera vacía
    Given path 'api', 'apikey', 'usuarios'
    And header X-API-Key = apiKey
    When method get
    Then status 401
    And match header Content-Type contains 'application/json'
    And match response == apiKeyRechazada

    Examples:
      | read('classpath:data/api-keys-rechazadas.json') |

  @negative
  Scenario: El token Bearer no sustituye a la API Key
    Given path 'api', 'apikey', 'usuarios'
    And header X-API-Key = auth.tokenValido
    When method get
    Then status 401
    And match response == apiKeyRechazada
