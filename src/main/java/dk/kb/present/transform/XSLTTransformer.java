/*
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 *
 */
package dk.kb.present.transform;

import dk.kb.util.Resolver;
import dk.kb.util.yaml.YAML;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.xml.transform.Transformer;
import javax.xml.transform.TransformerConfigurationException;
import javax.xml.transform.TransformerException;
import javax.xml.transform.TransformerFactory;
import javax.xml.transform.stream.StreamResult;
import javax.xml.transform.stream.StreamSource;
import java.io.ByteArrayOutputStream;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.InputStream;
import java.io.Reader;
import java.io.StringReader;
import java.net.URL;
import java.nio.charset.StandardCharsets;

/**
 * XSLT transformer using Saxon HE 3.
 *
 */
public class XSLTTransformer extends DSTransformer {
    private static final Logger log = LoggerFactory.getLogger(XSLTTransformer.class);
    public static final String ID = "xslt";

    public static final TransformerFactory transformerFactory;

    static {
        System.setProperty("javax.xml.transform.TransformerFactory", "net.sf.saxon.TransformerFactoryImpl");
        transformerFactory = TransformerFactory.newInstance();
    }
    public final String stylesheet;
    public final Transformer transformer;

    /**
     * Construct a transformer that uses Saxon to perform an XSLT transformation on its input.
     * @param stylesheet the stylesheet for the transformation. This can be be a file resolved relatively to the current
     *                   folder, under the user.home or on the classpath.
     * @throws IOException if the stylesheet could not be resolved.
     */
    public XSLTTransformer(String stylesheet) throws IOException {
        this.stylesheet = stylesheet;
        URL stylesheetURL = Resolver.resolveURL(stylesheet);
        if (stylesheetURL == null) {
            throw new FileNotFoundException("Unable to resolve stylesheet '" + stylesheet + "'");
        }
        try (InputStream is = stylesheetURL.openStream()) {
            transformer = transformerFactory.newTransformer(new StreamSource(is));
        } catch (IOException e) {
            throw new IOException("Unable to retrieve stylesheet from '" + stylesheet + "'", e);
        } catch (TransformerConfigurationException e) {
            throw new IllegalStateException("Unable to parse stylesheet at '" + stylesheet + "'", e);
        }
        log.debug("Constructed " + this);
    }

    @Override
    public String getID() {
        return ID;
    }

    @Override
    public synchronized String apply(String s) {
        try (ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            try (Reader in = new StringReader(s)) {
                transformer.transform(new StreamSource(in), new StreamResult(out));
            }
            return out.toString(StandardCharsets.UTF_8);
        } catch (IOException | TransformerException e) {
            throw new RuntimeTransformerException("Excaption transforming with stylesheet '" + stylesheet + "'", e);
        }
    }

    @Override
    public String toString() {
        return "XSLTTransformer(stylesheet='" + stylesheet + "')";
    }

}
