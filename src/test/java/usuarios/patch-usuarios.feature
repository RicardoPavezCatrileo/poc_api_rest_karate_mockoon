@regression
Feature: PATCH /api/usuarios/{id}

  Background:
    * call read('classpath:common/reset.feature')
    * url baseUrl
    * def datos = read('classpath:data/usuarios.json')
    * def esquemaUsuario = read('classpath:common/schemas/usuario.json')

  @smoke
  Scenario: Actualizar parcialmente conserva los demás campos
    Given path 'api', 'usuarios', 1
    And request { nombre: 'Ana T.' }
    When method patch
    Then status 200
    And match header Content-Type contains 'application/json'
    And match response == esquemaUsuario
    And match response == karate.merge(datos.usuario1, { nombre: 'Ana T.' })

  Scenario Outline: La actualización parcial de <campo> persiste
    Given path 'api', 'usuarios', 1
    And request cambios
    When method patch
    Then status 200

    Given path 'api', 'usuarios', 1
    When method get
    Then status 200
    And match response == karate.merge(datos.usuario1, cambios)

    Examples:
      | campo  | cambios!                         |
      | email  | { email: 'nuevo@example.com' }   |
      | rol    | { rol: 'supervisor' }            |
      | activo | { activo: false }                |

  @negative
  Scenario Outline: Actualizar parcialmente el usuario inexistente <usuarioId> responde 404
    Given path 'api', 'usuarios', usuarioId
    And request { nombre: 'Nadie' }
    When method patch
    Then status 404
    And match header Content-Type contains 'application/json'
    And match response == read('classpath:common/schemas/usuario-no-encontrado.json')

    Examples:
      | usuarioId! |
      | 999        |
      | 12345      |

  @negative
  Scenario Outline: Actualizar parcialmente con datos inválidos no altera los datos: <caso>
    Given path 'api', 'usuarios', 1
    And request payload
    When method patch
    Then status 422
    And match header Content-Type contains 'application/json'
    And match response == read('classpath:common/schemas/datos-invalidos.json')

    Given path 'api', 'usuarios', 1
    When method get
    Then match response == datos.usuario1

    Examples:
      | read('classpath:data/patch-invalidos.json') |

  @negative
  Scenario Outline: Actualizar parcialmente con payload malformado no altera los datos: <caso>
    Given path 'api', 'usuarios', 1
    And header Content-Type = 'application/json'
    And request cuerpo
    When method patch
    Then status 400
    And match header Content-Type contains 'application/json'
    And match response == read('classpath:common/schemas/payload-malformado.json')

    Given path 'api', 'usuarios', 1
    When method get
    Then match response == datos.usuario1

    Examples:
      | read('classpath:data/payloads-malformados.json') |
