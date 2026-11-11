import com.intuit.karate.Results;
import com.intuit.karate.Runner;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;

/**
 * Punto de entrada único de la suite.
 *
 * Se ejecuta con un solo hilo porque Mockoon guarda los usuarios en un único
 * data bucket compartido: dos escenarios en paralelo podrían restablecer o
 * modificar los datos que el otro está validando.
 *
 * Los tags se filtran con -Dkarate.options, que Karate aplica sobre este Runner:
 *   .\mvnw.cmd test "-Dkarate.options=--tags @smoke"
 *
 * Los features de common/ llevan @ignore: solo se ejecutan cuando otro los llama.
 * performance/ no se incluye: esos features los ejecuta Gatling (UsuariosSimulation).
 */
class ApiTestRunner {

    private static final String[] FEATURES_FUNCIONALES = {
            "classpath:health",
            "classpath:usuarios",
            "classpath:auth",
            "classpath:errores",
            "classpath:contratos",
            "classpath:soap",
            "classpath:sql",
            "classpath:transferencias",
    };

    @Test
    void ejecutarSuite() {
        Results results = Runner.path(FEATURES_FUNCIONALES)
                .outputCucumberJson(true)
                .outputJunitXml(true)
                .parallel(1);
        assertEquals(0, results.getFailCount(), results.getErrorMessages());
    }
}
