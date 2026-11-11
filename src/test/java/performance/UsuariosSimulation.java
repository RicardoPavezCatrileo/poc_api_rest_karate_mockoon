package performance;

import com.intuit.karate.Results;
import com.intuit.karate.Runner;
import com.intuit.karate.gatling.javaapi.KarateProtocolBuilder;
import io.gatling.javaapi.core.Assertion;
import io.gatling.javaapi.core.PopulationBuilder;
import io.gatling.javaapi.core.ScenarioBuilder;
import io.gatling.javaapi.core.Simulation;

import java.util.List;

import static com.intuit.karate.gatling.javaapi.KarateDsl.karateFeature;
import static com.intuit.karate.gatling.javaapi.KarateDsl.karateProtocol;
import static com.intuit.karate.gatling.javaapi.KarateDsl.uri;
import static io.gatling.javaapi.core.CoreDsl.constantUsersPerSec;
import static io.gatling.javaapi.core.CoreDsl.details;
import static io.gatling.javaapi.core.CoreDsl.global;
import static io.gatling.javaapi.core.CoreDsl.incrementUsersPerSec;
import static io.gatling.javaapi.core.CoreDsl.rampUsersPerSec;
import static io.gatling.javaapi.core.CoreDsl.scenario;

/**
 * Pruebas de carga y estrés que reutilizan features de Karate (performance/*.feature).
 *
 * Perfil con -Dperfil (por defecto carga):
 *   carga  - tráfico esperado sostenido; las aserciones definen el acuerdo de nivel de servicio.
 *   estres - escalones crecientes de usuarios por segundo para encontrar dónde se degrada el servicio.
 *
 * .\mvnw.cmd test-compile gatling:test "-Dperfil=estres"
 */
public class UsuariosSimulation extends Simulation {

    private static final String PERFIL = System.getProperty("perfil", "carga");

    // Agrupa en el reporte las URIs con id variable, en vez de una fila por cada id
    private final KarateProtocolBuilder protocolo = karateProtocol(
            uri("/api/usuarios/{id}").nil()
    );

    private final ScenarioBuilder consultas = scenario("Consultas REST")
            .exec(karateFeature("classpath:performance/consultas-rest.feature"));

    private final ScenarioBuilder login = scenario("Login y recurso seguro")
            .exec(karateFeature("classpath:performance/login-y-recurso-seguro.feature"));

    private final ScenarioBuilder soap = scenario("SOAP ObtenerUsuario")
            .exec(karateFeature("classpath:performance/soap.feature"));

    public UsuariosSimulation() {
        // Parte de los datos iniciales; durante la carga los features solo leen
        Results preparacion = Runner.path("classpath:performance/preparar-datos.feature")
                .reportDir("target/karate-reports-preparacion")
                .parallel(1);
        if (preparacion.getFailCount() > 0) {
            throw new IllegalStateException("No se pudieron preparar los datos: " + preparacion.getErrorMessages());
        }

        List<PopulationBuilder> poblacion = "estres".equals(PERFIL) ? estres() : carga();
        setUp(poblacion)
                .protocols(protocolo)
                .assertions(aserciones());
    }

    /** Sube durante 10 s y sostiene 30 s: 20 consultas, 5 logins y 5 SOAP por segundo. */
    private List<PopulationBuilder> carga() {
        return List.of(
                consultas.injectOpen(rampUsersPerSec(1).to(20).during(10), constantUsersPerSec(20).during(30)),
                login.injectOpen(rampUsersPerSec(1).to(5).during(10), constantUsersPerSec(5).during(30)),
                soap.injectOpen(rampUsersPerSec(1).to(5).during(10), constantUsersPerSec(5).during(30))
        );
    }

    /**
     * Cinco escalones de 10 s, de 20 a 100 consultas por segundo, más login y SOAP proporcionales
     * (pico cercano a 275 solicitudes por segundo).
     *
     * Límite del inyector: cada iteración abre conexiones nuevas, que quedan unos 120 s en TIME_WAIT.
     * En Windows hay 16.384 puertos efímeros; con escalones de 50 a 250 consultas por segundo
     * (unas 18.500 solicitudes en 60 s) se agotaron y el 25,8 % falló con
     * java.net.BindException: Address already in use, mientras el p99 del servidor seguía en 28 ms.
     * El cuello de botella era el generador de carga, no el servicio. Ver README, sección Performance.
     */
    private List<PopulationBuilder> estres() {
        return List.of(
                consultas.injectOpen(incrementUsersPerSec(20).times(5).eachLevelLasting(10)
                        .separatedByRampsLasting(2).startingFrom(20)),
                login.injectOpen(incrementUsersPerSec(5).times(5).eachLevelLasting(10)
                        .separatedByRampsLasting(2).startingFrom(5)),
                soap.injectOpen(incrementUsersPerSec(5).times(5).eachLevelLasting(10)
                        .separatedByRampsLasting(2).startingFrom(5))
        );
    }

    /**
     * Carga: el p95 global bajo 500 ms, el máximo bajo 2 s y menos de 1 % de errores.
     * Estrés: solo se exige menos de 5 % de errores; los tiempos se analizan en el reporte.
     */
    private List<Assertion> aserciones() {
        if ("estres".equals(PERFIL)) {
            return List.of(global().failedRequests().percent().lt(5.0));
        }
        return List.of(
                global().responseTime().percentile(95.0).lt(500),
                global().responseTime().max().lt(2000),
                global().failedRequests().percent().lt(1.0),
                details("POST /api/auth/login").responseTime().percentile(95.0).lt(500)
        );
    }
}
