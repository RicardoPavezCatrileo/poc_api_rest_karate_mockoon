@ignore
Feature: Restablece los usuarios del mock a los datos iniciales

  Solo para laboratorio: POST /api/test/reset copia el data bucket usuarios-iniciales sobre usuarios.
  Se invoca con call desde el Background de los features que modifican datos.

  Scenario: Restablecer los usuarios
    Given url baseUrl
    And path 'api', 'test', 'reset'
    When method post
    Then status 200
    And match response == { status: 'restablecido' }
