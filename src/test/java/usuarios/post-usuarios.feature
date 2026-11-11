@regression
Feature: POST /api/usuarios

  Background:
    * call read('classpath:common/reset.feature')
    * url baseUrl
    * def datos = read('classpath:data/usuarios.json')
    * def esquemaUsuario = read('classpath:common/schemas/usuario.json')

  @smoke
  Scenario: Crear un usuario válido
    Given path 'api', 'usuarios'
    And request datos.nuevo
    When method post
    Then status 201
    And match header Content-Type contains 'application/json'
    And match response == esquemaUsuario
    And match response == karate.merge(datos.nuevo, { id: datos.siguienteId })

  Scenario: El usuario creado persiste
    Given path 'api', 'usuarios'
    And request datos.nuevo
    When method post
    Then status 201
    * def creado = response

    Given path 'api', 'usuarios', creado.id
    When method get
    Then status 200
    And match response == creado

    Given path 'api', 'usuarios'
    When method get
    Then status 200
    And match response[*].id == karate.append(datos.existentes, creado.id)

  Scenario Outline: Crear un usuario con caracteres especiales: <caso>
    Given path 'api', 'usuarios'
    And request karate.merge(datos.nuevo, { nombre: nombre })
    When method post
    Then status 201
    And match response == esquemaUsuario
    And match response.nombre == nombre

    Examples:
      | read('classpath:data/nombres-validos.json') |

  @negative
  Scenario Outline: Crear un usuario con datos inválidos: <caso>
    Given path 'api', 'usuarios'
    And request payload
    When method post
    Then status 422
    And match header Content-Type contains 'application/json'
    And match response == read('classpath:common/schemas/datos-invalidos.json')

    Examples:
      | read('classpath:data/usuarios-invalidos.json') |

  @negative
  Scenario Outline: Crear un usuario con email inválido: <caso>
    Given path 'api', 'usuarios'
    And request karate.merge(datos.nuevo, { email: email })
    When method post
    Then status 422
    And match response == read('classpath:common/schemas/datos-invalidos.json')

    Examples:
      | read('classpath:data/emails-invalidos.csv') |

  @negative
  Scenario Outline: Crear un usuario con payload malformado no altera los datos: <caso>
    Given path 'api', 'usuarios'
    And header Content-Type = 'application/json'
    And request cuerpo
    When method post
    Then status 400
    And match header Content-Type contains 'application/json'
    And match response == read('classpath:common/schemas/payload-malformado.json')

    Given path 'api', 'usuarios'
    When method get
    Then match response[*].id == datos.existentes

    Examples:
      | read('classpath:data/payloads-malformados.json') |

  @negative
  Scenario: Una creación rechazada no persiste
    Given path 'api', 'usuarios'
    And request karate.merge(datos.nuevo, { email: 'invalido' })
    When method post
    Then status 422

    Given path 'api', 'usuarios'
    When method get
    Then match response[*].id == datos.existentes
