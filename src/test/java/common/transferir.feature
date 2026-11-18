@ignore
Feature: Transferencia reutilizable

  Uso: * def resultado = call read('classpath:common/transferir.feature') { cuentaOrigen: 10, cuentaDestino: 20, monto: 5, token: '#(sesion.token)' }
  No valida el status: el llamador revisa resultado.responseStatus y resultado.response.

  Scenario: Transferir
    Given url baseUrl
    And path 'api', 'transferencias'
    And header Authorization = 'Bearer ' + token
    And request { cuentaOrigen: '#(cuentaOrigen)', cuentaDestino: '#(cuentaDestino)', monto: '#(monto)' }
    When method post
