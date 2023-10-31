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
package dk.kb.present;

import dk.kb.present.transform.DSTransformer;
import dk.kb.present.transform.TransformerController;
import dk.kb.storage.model.v1.DsRecordDto;
import dk.kb.util.webservice.exception.InternalServiceException;
import dk.kb.util.yaml.YAML;
import org.apache.commons.lang3.function.TriFunction;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.ws.rs.core.MediaType;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;
import java.util.function.BiFunction;
import java.util.function.Function;


/**
 * A view is at the core a list of {@link dk.kb.present.transform.DSTransformer}s.
 * It takes three values of {@code recordID, recordContent, childRecord} and return transformed recordContent.
 */
public class View extends ArrayList<DSTransformer> implements Function<DsRecordDto, String> {
    private static final Logger log = LoggerFactory.getLogger(View.class);

    private static final String MIME_KEY = "mime";
    private static final String TRANSFORMERS_KEY = "transformers";

    private final String id;
    private final String origin;
    private final MediaType mime;

    /**
     * Creates a view from the given YAML. Expects the YAML to contain a single entry,
     * where the key is the ID for the view and the value is the configuration of the view.
     * @param conf the configuration for this specific view.
     * @param originOfCollection the origin of the collection specified in the CONF yaml.
     */
    public View(YAML conf, String originOfCollection) {
        super();
        if (conf.size() != 1) {
            throw new IllegalArgumentException
                    ("Expected a single entry in the configuration but there was " + conf.size() +
                     ". Maybe indenting was not correct in the config file?");
        }
        id = conf.keySet().stream().findFirst().orElseThrow();
        origin = originOfCollection;
        //TODO: Set origin injection here and also do renaming of base to origin in DSCollection
        conf = conf.getSubMap(id);
        String[] mimeTokens = conf.getString(MIME_KEY).split("/", 2);
        mime = new MediaType(mimeTokens[0], mimeTokens[1]);
        if (conf.isEmpty()) {
            throw new IllegalArgumentException("No transformer specified for view '" + id + "'");
        }
        for (YAML transformerConf: conf.getYAMLList(TRANSFORMERS_KEY)) {
            try {
                add(TransformerController.createTransformer(transformerConf));
            } catch (Exception e) {
                throw new RuntimeException(e); // Wrap for stream use
            }
        }
        log.info("Created " + this);
    }

    public String getId() {
        return id;
    }

    public MediaType getMime() {
        return mime;
    }

    @Override
    public String apply(DsRecordDto record) {
        String recordID = record.getId();
        String content = record.getData();
        String child = getFirstChild(record);


        final Map<String, String> metadata = new HashMap<>();
        metadata.put("recordID", recordID);
        metadata.put("origin", origin);

        if (child != null ) {
            metadata.put("childRecord", child);
        }


        for (DSTransformer transformer: this) {
            try {
                content = transformer.apply(content, metadata);
            } catch (Exception e) {
                String message = String.format(
                        Locale.ROOT, "Exception in View '%s' while calling %s with recordID '%s' and metadata %s",
                        getId(), transformer, recordID, metadata);
                log.warn(message, e);
                throw new InternalServiceException(message);
            }
        }
        return content;
    }

    @Override
    public String toString() {
        return "View(" +
               "id='" + id + '\'' +
               ", mime=" + mime +
               ", origin=" + origin +
               ", transformers=" + super.toString() +
               ')';
    }

    /**
     * If record has children, the first child is returned.
     * @param record to extract the newest child from.
     * @return  the data from the first child related to the input record.
     */
    private String getFirstChild(DsRecordDto record) {
        // TODO: Figure how to choose correct manifestation for record, if more than one is present
        // Return first child record, but if there are multiple presentation manifestations,
        // the rest are currently not added to the transformation
        return record.getChildren() == null ? "" :
                record.getChildren().stream()
                        .map(this::getNonNullChild)
                        .findFirst().orElse("");
    }

    /**
     * Check for child being null.
     * @param child record to check for data in.
     * @return the data from child if child is not null. Otherwise, return an empty string.
     */
    private String getNonNullChild(DsRecordDto child) {
        if (child.getData() == null){
            return "";
        }
        return child.getData();
    }
}
