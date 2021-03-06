package dk.kb.present;

import dk.kb.util.yaml.YAML;
import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import static org.junit.jupiter.api.Assertions.*;

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
class CollectionHandlerTest {

    @Test
    void idPattern() {
        final Pattern recordIDPattern = Pattern.compile("([a-z0-9.]+):([a-zA-Z0-9:._-]+)");
        for (String TEST: new String[]{
                "1::", // Degenerate example
                ".::_..-", // Degenerate example
                "images.dsfl:luftfoto-sample.xml",
                "images:luftfoto:sample.xml",
                "oai:kb.dk:images:luftfo:2011:maj:luftfoto:object967062"
        }) {
            assertTrue(recordIDPattern.matcher(TEST).matches());
        }

    }

    @Test
    void demoPattern() {
        final Pattern recordIDPattern = Pattern.compile("([a-z0-9.]+):([a-zA-Z0-9:._-]+)");
        String id = "images.dsfl:luftfoto-sample.xml";
        Matcher matcher = recordIDPattern.matcher(id);
        if (matcher.matches()) {
            System.out.println("Collection=" + matcher.group(1) + ", material-id=" + matcher.group(2));
        } else {
            throw new IllegalArgumentException("Unsupported ID format '" + id + "'");
        }
    }

    @Test
    void normaliseID() {
        final Pattern NO_GO = Pattern.compile("[^a-zA-Z0-9:._-]");

        // Note: Not a proper id as the collection is not added
        String id = "himmel/luftfoto-sample?????? .xml";
        for (String[] subst: new String[][]{
                {"??", "ae"}, {"??", "ae"}, {"??", "Ae"}, {"??", "Ae"},
                {"??", "oe"}, {"??", "oe"}, {"??", "Oe"}, {"??", "Oe"},
                {"??", "aa"}, {"??", "Aa"},
                {" ", "-"}, {"/", "-"}, {"~", "-"}
        }) {
            id = id.replace(subst[0], subst[1]);
        }
        id = NO_GO.matcher(id).replaceAll(".");

        System.out.println("Prepend collection and colon to this: " + id);
    }


    @Test
    void localCorpusMODS() throws IOException {
        YAML conf = YAML.resolveLayeredConfigs("test_setup.yaml");
        CollectionHandler ch = new CollectionHandler(conf);
        String record = ch.getRecord("local:albert-einstein.xml", "mods");
        assertTrue(record.contains("<md:title>Letter from Einstein, Albert to Simonsen, David</md:title>"));
    }

    @Test
    void localCorpusFail() throws IOException {
        YAML conf = YAML.resolveLayeredConfigs("test_setup.yaml");
        CollectionHandler ch = new CollectionHandler(conf);
        try {
            ch.getRecord("local_albert-einstein.xml", "raw");
            fail("Requesting record in raw format should fail");
        } catch (Exception e) {
            // Expected
        }
    }
}