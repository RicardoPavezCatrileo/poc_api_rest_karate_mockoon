@regression
Feature: PUT /api/usuarios/{id}

  Background:
    * call read('classpath:common/reset.feature')
    * url baseUrl
    * def datos = read('classpath:data/usuarios.json')
    * def esquemaUsuario = read('classpath:common/schemas/usuario.json')
    * def esperado = karate.merge(datos.actualizado, { id: 1 })

  @smoke
  Scenario: Actualizar un usuario completo
    Given path 'api', 'usuarios', 1
    And request datos.actualizado
    When method put
    Then status 200
    And match header Content-Type contains 'application/json'
    And match response == esquemaUsuario
    And match response == esperado

  Scenario: La actualización completa persiste
    Given path 'api', 'usuarios', 1
    And request datos.actualizado
    When method put
    Then status 200

    Given path 'api', 'usuarios', 1
    When method get
    Then status 200
    And match response == esperado

  Scenario: Actualizar solo afecta al usuario indicado
    * def otrosQueElUsuario1 = function(lista){ return karate.filter(lista, function(u){ return u.id != 1 }) }
    Given path 'api', 'usuarios'
    When method get
    * def otrosAntes = otrosQueElUsuario1(response)

    Given path 'api', 'usuarios', 1
    And request datos.actualizado
    When method put
    Then status 200

    Given path 'api', 'usuarios'
    When method get
    * def otrosDespues = otrosQueElUsuario1(response)
    Then match otrosDespues == otrosAntes

  @negative
  Scenario Outline: Actualizar el usuario inexistente <usuarioId> responde 404 y no altera los datos
    Given path 'api', 'usuarios', usuarioId
    And request datos.actualizado
    When method put
    Then status 404
    And match header Content-Type contains 'application/json'
    And match response == read('classpath:common/schemas/usuario-no-encontrado.json')

    Given path 'api', 'usuarios'
    When method get
    Then match response[*].id == datos.existentes

    Examples:
      | usuarioId! |
      | 999        |
      | 12345      |

  @negative
  Scenario Outline: Actualizar un usuario con datos inválidos no altera los datos: <caso>
    Given path 'api', 'usuarios', 1
    And request payload
    When method put
    Then status 422
    And match header Content-Type contains 'application/json'
    And match response == read('classpath:common/schemas/datos-invalidos.json')

    Given path 'api', 'usuarios', 1
    When method get
    Then match response == datos.usuario1

    Examples:
      | read('classpath:data/usuarios-invalidos.json') |

  @negative
  Scenario Outline: Actualizar un usuario con payload malformado no altera los datos: <caso>
    Given path 'api', 'usuarios', 1
    And header Content-Type = 'application/json'
    And request cuerpo
    When method put
    Then status 400
    And match header Content-Type contains 'application/json'
    And match response == read('classpath:common/schemas/payload-malformado.json')

    Given path 'api', 'usuarios', 1
    When method get
    Then match response == datos.usuario1

    Examples:
      | read('classpath:data/payloads-malformados.json') |
