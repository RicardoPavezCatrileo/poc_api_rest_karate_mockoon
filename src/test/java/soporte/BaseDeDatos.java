package soporte;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Acceso JDBC para preparar y validar datos de prueba con SQL desde Karate.
 *
 * Por defecto usa H2 en memoria en modo PostgreSQL. Con -Ddb.url, -Ddb.usuario y -Ddb.clave se puede
 * apuntar a otra base, agregando su driver JDBC al pom.xml.
 *
 * Todas las consultas usan PreparedStatement: los parámetros nunca se concatenan al SQL.
 */
public final class BaseDeDatos {

    private static final String URL = System.getProperty("db.url",
            "jdbc:h2:mem:poc;MODE=PostgreSQL;DATABASE_TO_LOWER=TRUE;DEFAULT_NULL_ORDERING=HIGH;DB_CLOSE_DELAY=-1");
    private static final String USUARIO = System.getProperty("db.usuario", "sa");
    private static final String CLAVE = System.getProperty("db.clave", "");

    private BaseDeDatos() {
    }

    /** Recrea el esquema y carga los datos semilla de src/test/resources/sql. */
    public static void inicializar() {
        ejecutarScript("sql/schema.sql");
        ejecutarScript("sql/datos.sql");
    }

    /** SELECT con parámetros posicionales (?). Devuelve una lista de filas; cada fila es columna -> valor. */
    public static List<Map<String, Object>> consultar(String sql, Object... parametros) {
        try (Connection conexion = conectar(); PreparedStatement sentencia = preparar(conexion, sql, parametros);
             ResultSet resultado = sentencia.executeQuery()) {
            ResultSetMetaData columnas = resultado.getMetaData();
            List<Map<String, Object>> filas = new ArrayList<>();
            while (resultado.next()) {
                Map<String, Object> fila = new LinkedHashMap<>();
                for (int i = 1; i <= columnas.getColumnCount(); i++) {
                    fila.put(columnas.getColumnLabel(i), resultado.getObject(i));
                }
                filas.add(fila);
            }
            return filas;
        } catch (SQLException e) {
            throw new IllegalStateException(e.getMessage(), e);
        }
    }

    /** Valor de la primera columna de la primera fila, o null si no hay filas. */
    public static Object valor(String sql, Object... parametros) {
        List<Map<String, Object>> filas = consultar(sql, parametros);
        return filas.isEmpty() ? null : filas.get(0).values().iterator().next();
    }

    /** INSERT, UPDATE o DELETE con parámetros. Devuelve las filas afectadas. */
    public static int ejecutar(String sql, Object... parametros) {
        try (Connection conexion = conectar(); PreparedStatement sentencia = preparar(conexion, sql, parametros)) {
            return sentencia.executeUpdate();
        } catch (SQLException e) {
            throw new IllegalStateException(e.getMessage(), e);
        }
    }

    /**
     * Ejecuta una sentencia que debe fallar y devuelve el SQLState del error, o null si no falló.
     * La clase 23 corresponde a violaciones de integridad (FK, CHECK, UNIQUE, NOT NULL).
     */
    public static String sqlStateDelError(String sql, Object... parametros) {
        try (Connection conexion = conectar(); PreparedStatement sentencia = preparar(conexion, sql, parametros)) {
            sentencia.executeUpdate();
            return null;
        } catch (SQLException e) {
            return e.getSQLState();
        }
    }

    /**
     * Transfiere un monto entre dos cuentas activas en una sola transacción: descuenta del origen, abona al
     * destino y registra un retiro y un depósito. Si algo falla (cuenta inexistente o no activa, saldo
     * insuficiente por el CHECK saldo >= 0), hace rollback y nada cambia.
     *
     * Devuelve null si se confirmó, o el SQLState del error si se revirtió.
     */
    public static String transferir(int origen, int destino, Number monto) {
        BigDecimal importe = new BigDecimal(monto.toString()).setScale(2, RoundingMode.UNNECESSARY);
        try (Connection conexion = conectar()) {
            conexion.setAutoCommit(false);
            try {
                actualizarSaldo(conexion, origen, importe.negate());
                actualizarSaldo(conexion, destino, importe);
                registrarMovimiento(conexion, origen, "retiro", importe);
                registrarMovimiento(conexion, destino, "deposito", importe);
                conexion.commit();
                return null;
            } catch (SQLException e) {
                conexion.rollback();
                return e.getSQLState();
            }
        } catch (SQLException e) {
            throw new IllegalStateException(e.getMessage(), e);
        }
    }

    private static void actualizarSaldo(Connection conexion, int cuenta, BigDecimal diferencia) throws SQLException {
        try (PreparedStatement sentencia = preparar(conexion,
                "UPDATE cuentas SET saldo = saldo + ? WHERE id = ? AND estado = 'activa'", diferencia, cuenta)) {
            if (sentencia.executeUpdate() != 1) {
                // 02000: sin datos. La cuenta no existe o no está activa.
                throw new SQLException("La cuenta " + cuenta + " no existe o no está activa", "02000");
            }
        }
    }

    private static void registrarMovimiento(Connection conexion, int cuenta, String tipo, BigDecimal monto) throws SQLException {
        try (PreparedStatement sentencia = preparar(conexion,
                "INSERT INTO movimientos (id, cuenta_id, tipo, monto, fecha) "
                        + "SELECT COALESCE(MAX(id), 0) + 1, ?, ?, ?, CURRENT_DATE FROM movimientos",
                cuenta, tipo, monto)) {
            sentencia.executeUpdate();
        }
    }

    private static void ejecutarScript(String recurso) {
        try (Connection conexion = conectar(); Statement sentencia = conexion.createStatement()) {
            sentencia.execute("RUNSCRIPT FROM 'classpath:" + recurso + "' CHARSET 'UTF-8'");
        } catch (SQLException e) {
            throw new IllegalStateException("No se pudo ejecutar " + recurso + ": " + e.getMessage(), e);
        }
    }

    private static Connection conectar() throws SQLException {
        return DriverManager.getConnection(URL, USUARIO, CLAVE);
    }

    private static PreparedStatement preparar(Connection conexion, String sql, Object... parametros) throws SQLException {
        PreparedStatement sentencia = conexion.prepareStatement(sql);
        if (parametros != null) {
            for (int i = 0; i < parametros.length; i++) {
                sentencia.setObject(i + 1, parametros[i]);
            }
        }
        return sentencia;
    }
}
