@regression @negative
Feature: GET /api/errores/{codigo}

  El 524 es un código propio de Cloudflare, no un código HTTP estándar.
  Mockoon solo simula la respuesta, no la infraestructura de Cloudflare.

  Background:
    * url baseUrl
    * def esquemaError = read('classpath:common/schemas/error.json')

  Scenario Outline: El error HTTP <codigo> responde con su código, estructura y mensaje
    Given path 'api', 'errores', codigo
    When method get
    Then match responseStatus == codigo
    And match header Content-Type contains 'application/json'
    And match response == esquemaError
    And match response == { codigo: '#(codigo)', error: '#(error)', mensaje: '#(mensaje)' }

    Examples:
      | read('classpath:data/errores-http.json') |

  Scenario Outline: El error <codigo> incluye la cabecera <encabezado>
    Given path 'api', 'errores', codigo
    When method get
    Then match responseStatus == codigo
    And match karate.response.header(encabezado) == valor

    Examples:
      | codigo! | encabezado       | valor  |
      | 401     | WWW-Authenticate | Bearer |
      | 429     | Retry-After      | 60     |
      | 503     | Retry-After      | 30     |
