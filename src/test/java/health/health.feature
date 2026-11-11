@regression @smoke
Feature: Estado del servicio

  Background:
    * url baseUrl

  Scenario: GET /api/health responde que el servicio está disponible
    Given path 'api', 'health'
    When method get
    Then status 200
    And match header Content-Type contains 'application/json'
    And match response == { status: 'ok' }
    And assert responseTime < maxResponseTimeMs
