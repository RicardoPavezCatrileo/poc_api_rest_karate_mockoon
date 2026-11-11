package soporte;

import com.atlassian.oai.validator.OpenApiInteractionValidator;
import com.atlassian.oai.validator.model.Request;
import com.atlassian.oai.validator.model.SimpleResponse;
import com.atlassian.oai.validator.report.ValidationReport;
import io.swagger.parser.OpenAPIParser;
import io.swagger.v3.parser.core.models.ParseOptions;
import io.swagger.v3.parser.core.models.SwaggerParseResult;

import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Map;

/**
 * Valida respuestas HTTP contra src/test/resources/contracts/openapi.yaml.
 *
 * No hace solicitudes: Karate envía la solicitud y pasa aquí el status, las cabeceras y el cuerpo
 * recibidos. Devuelve la lista de errores de contrato, vacía si la respuesta cumple.
 */
public final class OpenApiContrato {

    private static final String ESPECIFICACION = "contracts/openapi.yaml";
    private static final OpenApiInteractionValidator VALIDADOR =
            OpenApiInteractionValidator.createForSpecificationUrl(url()).build();

    private OpenApiContrato() {
    }

    /** Errores de sintaxis o estructura de la propia especificación OpenAPI. */
    public static List<String> erroresDeLaEspecificacion() {
        ParseOptions opciones = new ParseOptions();
        opciones.setResolve(true);
        SwaggerParseResult resultado = new OpenAPIParser().readLocation(url(), null, opciones);
        List<String> errores = new ArrayList<>();
        if (resultado.getMessages() != null) {
            errores.addAll(resultado.getMessages());
        }
        if (resultado.getOpenAPI() == null) {
            errores.add("No se pudo leer la especificación");
        }
        return errores;
    }

    /**
     * Valida la respuesta real que recibió Karate.
     * Uso desde Karate: validarRespuesta('GET', '/api/usuarios/1', responseStatus, responseHeaders, responseBytes)
     */
    public static List<String> validarRespuesta(String metodo, String ruta, int status,
                                                Map<String, Object> cabeceras, byte[] cuerpo) {
        SimpleResponse.Builder respuesta = SimpleResponse.Builder.status(status);
        if (cabeceras != null) {
            cabeceras.forEach((nombre, valor) -> respuesta.withHeader(nombre, valores(valor)));
        }
        if (cuerpo != null && cuerpo.length > 0) {
            respuesta.withBody(new String(cuerpo, StandardCharsets.UTF_8));
        }
        return errores(metodo, ruta, respuesta.build());
    }

    /** Valida una respuesta construida a mano; sirve para comprobar que el validador detecta incumplimientos. */
    public static List<String> validarEjemplo(String metodo, String ruta, int status, String contentType, String cuerpo) {
        SimpleResponse.Builder respuesta = SimpleResponse.Builder.status(status);
        if (contentType != null) {
            respuesta.withContentType(contentType);
        }
        if (cuerpo != null) {
            respuesta.withBody(cuerpo);
        }
        return errores(metodo, ruta, respuesta.build());
    }

    private static List<String> errores(String metodo, String ruta, SimpleResponse respuesta) {
        Request.Method metodoHttp = Request.Method.valueOf(metodo.toUpperCase(Locale.ROOT));
        ValidationReport reporte = VALIDADOR.validateResponse(ruta, metodoHttp, respuesta);
        List<String> errores = new ArrayList<>();
        for (ValidationReport.Message mensaje : reporte.getMessages()) {
            if (mensaje.getLevel() == ValidationReport.Level.ERROR) {
                errores.add(mensaje.getKey() + ": " + mensaje.getMessage());
            }
        }
        return errores;
    }

    private static String[] valores(Object valor) {
        if (valor instanceof List<?> lista) {
            return lista.stream().map(String::valueOf).toArray(String[]::new);
        }
        return new String[] {String.valueOf(valor)};
    }

    private static String url() {
        return OpenApiContrato.class.getClassLoader().getResource(ESPECIFICACION).toString();
    }
}
