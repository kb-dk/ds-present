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

import dk.kb.present.storage.Storage;
import dk.kb.present.webservice.exception.InvalidArgumentServiceException;
import dk.kb.present.webservice.exception.NotFoundServiceException;
import dk.kb.util.yaml.YAML;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Collectors;

/**
 * Creates {@link DSCollection}s from a given configuration and provides access to them based on ID-prefix.
 */
public class CollectionHandler {
    private static final Logger log = LoggerFactory.getLogger(CollectionHandler.class);
    private static final String COLLECTIONS_KEY = ".config.collections";
    private static final String RECORD_ID_PATTERN_KEY = ".config.record.id.pattern";
    private static final String COLLECTION_ID_PATTERN_KEY = ".config.collection.prefix.pattern";

    private final StorageHandler storageHandler;
    private final Map<String, DSCollection> collectionsByPrefix; // prefix, collection
    private final Map<String, DSCollection> collectionsByID; // id, collection
    private final Pattern recordIDPattern;
    private final Pattern collectionPrefixPattern;

    /**
     * Creates a {@link StorageHandler} and a set of {@link Storage}s based on the given configuration.
     * @param conf top-level configuration. The parts for this handler is expected to be found at
     * {@code .config.collections} and {@code .config.record.id.pattern}
     */
    public CollectionHandler(YAML conf) {
        try {
            collectionPrefixPattern = Pattern.compile(conf.getString(COLLECTION_ID_PATTERN_KEY));
        } catch (Exception e) {
            String message = "Unable to create pattern from configuration, expected key " + RECORD_ID_PATTERN_KEY;
            log.warn(message, e);
            throw new RuntimeException(e);
        }

        storageHandler = new StorageHandler(conf);
        collectionsByPrefix = conf.getYAMLList(COLLECTIONS_KEY).stream()
                .map(collectionConf -> new DSCollection(collectionConf, storageHandler))
                .peek(collection -> {
                    if (!collectionPrefixPattern.matcher(collection.getPrefix()).matches()) {
                        throw new IllegalStateException(
                                "The configured collection prefix '" + collection.getPrefix() + "' for collection '" +
                                collection.getId() + "' does not match the collection prefix pattern '" +
                                collectionPrefixPattern.pattern() + "'");
                    }})
                .collect(Collectors.toMap(DSCollection::getPrefix, storage -> storage));
        collectionsByID = collectionsByPrefix.values().stream()
                .collect(Collectors.toMap(DSCollection::getId, storage -> storage));
        try {
            recordIDPattern = Pattern.compile(conf.getString(RECORD_ID_PATTERN_KEY));
        } catch (Exception e) {
            String message = "Unable to create pattern from configuration, expected key " + RECORD_ID_PATTERN_KEY;
            log.warn(message, e);
            throw new RuntimeException(e);
        }
        log.info("Created " + this);
    }

    public String getRecord(String id, String format) throws NotFoundServiceException {
        Matcher matcher = recordIDPattern.matcher(id);
        if (!matcher.matches()) {
            throw new InvalidArgumentServiceException(
                    "ID '" + id + "' should conform to pattern '" + recordIDPattern + "'");
        }
        DSCollection collection = collectionsByPrefix.get(matcher.group(1));
        if (collection == null) {
            throw new NotFoundServiceException(
                    "A collection for IDs with prefix '" + matcher.group(1) + "' is not available. " +
                    "Full ID was '" + id + "'. Available collection-prefixess are " + collectionsByPrefix.keySet());
        }
        return collection.getRecord(id, format);
    }

    /**
     * @param collectionID an ID for a collection.
     * @return a collection with the given ID or null if it does not exist.
     */
    public DSCollection getCollection(String collectionID) {
        return collectionsByID.get(collectionID);
    }

    /**
     * @return a complete list of supported collections.
     */
    public List<String> getCollectionIDs() {
        return new ArrayList<>(collectionsByID.keySet());
    }

    /**
     * @return all collections.
     */
    public Collection<DSCollection> getCollections() {
        return collectionsByPrefix.values();
    }

    @Override
    public String toString() {
        return "CollectionHandler(" +
               "collections=" + collectionsByPrefix.values() +
               "recordIDPattern: '" + recordIDPattern + "'" +
               ')';
    }
}
