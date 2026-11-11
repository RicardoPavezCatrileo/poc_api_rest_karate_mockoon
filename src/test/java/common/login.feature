@ignore
Feature: Login reutilizable

  Obtiene un token Bearer con un login real. Por defecto usa qa_user; para otro usuario:
    * def sesion = call read('classpath:common/login.feature') { credencialesLogin: '#(auth.credencialesSinPermisos)' }
  Devuelve la variable token. Los tokens del mock son cadenas fijas de laboratorio, no JWT.

  Scenario: Iniciar sesión
    * def credencialesLogin = karate.get('credencialesLogin', read('classpath:data/auth.json').credencialesValidas)
    Given url baseUrl
    And path 'api', 'auth', 'login'
    And request credencialesLogin
    When method post
    Then status 200
    And match response == { access_token: '#string', token_type: 'Bearer' }
    * def token = response.access_token
