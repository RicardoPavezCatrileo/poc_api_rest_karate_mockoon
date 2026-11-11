package soporte;

import org.w3c.dom.Attr;
import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.NamedNodeMap;
import org.w3c.dom.Node;
import org.xml.sax.ErrorHandler;
import org.xml.sax.InputSource;
import org.xml.sax.SAXParseException;

import javax.xml.XMLConstants;
import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.transform.dom.DOMSource;
import javax.xml.validation.Schema;
import javax.xml.validation.SchemaFactory;
import javax.xml.validation.Validator;
import java.io.InputStream;
import java.io.StringReader;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

/**
 * Valida el contenido de soapenv:Body contra el XML Schema incluido en
 * src/test/resources/contracts/usuarios.wsdl, solo con las APIs XML del JDK.
 *
 * Devuelve la lista de errores de contrato, vacía si el mensaje cumple.
 */
public final class XmlContrato {

    private static final String WSDL = "contracts/usuarios.wsdl";
    private static final String SOAP_ENVELOPE_NS = "http://schemas.xmlsoap.org/soap/envelope/";
    private static final String XMLNS_NS = XMLConstants.XMLNS_ATTRIBUTE_NS_URI;
    private static final Schema ESQUEMA = cargarEsquema();

    private XmlContrato() {
    }

    public static List<String> validar(byte[] mensajeSoap) {
        return validar(new String(mensajeSoap, StandardCharsets.UTF_8));
    }

    public static List<String> validar(String mensajeSoap) {
        List<String> errores = new ArrayList<>();
        Element contenido;
        try {
            Document documento = constructor().parse(new InputSource(new StringReader(mensajeSoap)));
            contenido = primerHijo(documento.getElementsByTagNameNS(SOAP_ENVELOPE_NS, "Body").item(0));
        } catch (Exception e) {
            errores.add("XML mal formado: " + e.getMessage());
            return errores;
        }
        if (contenido == null) {
            errores.add("El mensaje no tiene contenido en soapenv:Body");
            return errores;
        }
        Validator validador = ESQUEMA.newValidator();
        validador.setErrorHandler(new ErrorHandler() {
            @Override
            public void warning(SAXParseException e) {
                errores.add(e.getMessage());
            }

            @Override
            public void error(SAXParseException e) {
                errores.add(e.getMessage());
            }

            @Override
            public void fatalError(SAXParseException e) {
                errores.add(e.getMessage());
            }
        });
        try {
            validador.validate(new DOMSource(contenido));
        } catch (Exception e) {
            if (errores.isEmpty()) {
                errores.add(e.getMessage());
            }
        }
        return errores;
    }

    private static Schema cargarEsquema() {
        try (InputStream entrada = XmlContrato.class.getClassLoader().getResourceAsStream(WSDL)) {
            Document wsdl = constructor().parse(entrada);
            Element esquema = (Element) wsdl.getElementsByTagNameNS(XMLConstants.W3C_XML_SCHEMA_NS_URI, "schema").item(0);
            // El esquema usa prefijos declarados en wsdl:definitions; se copian para compilarlo por separado
            NamedNodeMap atributos = wsdl.getDocumentElement().getAttributes();
            for (int i = 0; i < atributos.getLength(); i++) {
                Attr atributo = (Attr) atributos.item(i);
                if (XMLNS_NS.equals(atributo.getNamespaceURI()) && !esquema.hasAttributeNS(XMLNS_NS, atributo.getLocalName())) {
                    esquema.setAttributeNS(XMLNS_NS, atributo.getName(), atributo.getValue());
                }
            }
            SchemaFactory fabrica = SchemaFactory.newInstance(XMLConstants.W3C_XML_SCHEMA_NS_URI);
            return fabrica.newSchema(new DOMSource(esquema));
        } catch (Exception e) {
            throw new IllegalStateException("No se pudo cargar el esquema de " + WSDL, e);
        }
    }

    private static DocumentBuilder constructor() throws Exception {
        DocumentBuilderFactory fabrica = DocumentBuilderFactory.newInstance();
        fabrica.setNamespaceAware(true);
        // Sin DTD ni entidades externas: evita XXE al procesar XML recibido
        fabrica.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
        fabrica.setXIncludeAware(false);
        fabrica.setExpandEntityReferences(false);
        return fabrica.newDocumentBuilder();
    }

    private static Element primerHijo(Node nodo) {
        if (nodo == null) {
            return null;
        }
        for (Node hijo = nodo.getFirstChild(); hijo != null; hijo = hijo.getNextSibling()) {
            if (hijo.getNodeType() == Node.ELEMENT_NODE) {
                return (Element) hijo;
            }
        }
        return null;
    }
}
