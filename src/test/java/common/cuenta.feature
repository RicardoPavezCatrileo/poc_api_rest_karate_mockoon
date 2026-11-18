@ignore
Feature: Consulta reutilizable de una cuenta

  Uso: * def cuenta = call read('classpath:common/cuenta.feature') { cuentaId: 10, token: '#(sesion.token)' }
  Devuelve la variable saldo y la cuenta completa en response.

  Scenario: Obtener la cuenta
    Given url baseUrl
    And path 'api', 'cuentas', cuentaId
    And header Authorization = 'Bearer ' + token
    When method get
    Then status 200
    * def saldo = response.saldo
