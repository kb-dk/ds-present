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
import dk.kb.present.transform.RuntimeTransformerException;
import dk.kb.storage.model.v1.DsRecordDto;

import dk.kb.util.webservice.exception.InternalServiceException;
import dk.kb.util.webservice.exception.InvalidArgumentServiceException;
import dk.kb.util.webservice.exception.ServiceException;

import dk.kb.util.yaml.NotFoundException;
import dk.kb.util.yaml.YAML;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.stream.Collectors;
import java.util.stream.Stream;

/**
 * A collection encapsulates access to a logical collection ("samling"). It uses the same collections as ds-storage and
 * is typically backed by a ds-storage instance.
 *
 * Access is read-only and always with an explicit export format. The format can be {@code raw} for direct proxying to
 * the connected ds-storage, but common use case is to request MODS, JSON-LD (schema.org) or SolrJSON representations.
 */
public class DSCollection {
    private static final Logger log = LoggerFactory.getLogger(DSCollection.class);
    private static final String PREFIX_KEY = "prefix"; // IDs for this collection starts with <prefix>_ (note the underscore)
    private static final String DESCRIPTION_KEY = "description";
    private static final String STORAGE_KEY = "storage";
    private static final String ORIGIN_KEY = "origin";
    private static final String VIEWS_KEY = "views";
    private static final String GET_RECORD_ENDPOINT_KEY = "getrecordendpoint";

    /**
     * The ID of the collection, primarily used for debugging and configuration.
     */
    private final String id;

    /**
     * recordIDs always starts with the collection followed by underscore, e.g. {@code images-dsfl_internalid1234}.
     * The prefix must be present for all recordIDs used for lookup.
     * This might be the same as the {@link #id} but it is not a requirement.
     */
    private final String prefix;

    /**
     * Human readable description of the collection.
     */
    private final String description;

    /**
     * Encapsulation of the backing storage for the collection. This will typically be a ds-storage service.
     */
    private final Storage storage;

    /**
     * Optional origin, with fallback to the default origin for {@link Storage}.
     * Used when {@link #getDSRecords(Long, Long, String)} is called.
     */
    private final String origin;

    /**
     * Map from format -> view. A view is at the core an array of transformations and responsible for transforming
     * metadata to the requested format.
     */
    private final Map<String, View> views; // keys are lowercase

    private String getRecordEndpoint;

    /**
     * Create a collection based on the given conf. The storageHandler is expected to be initialized and should contain
     * the storage specified for the collection.
     * @param conf configuration for the collection, should contain a single key:value with the key being the
     *             collection ID and the value being the configuration for the collection.
     * @param storageHandler previously initialized pool of storages.
     */
    public DSCollection(YAML conf, StorageHandler storageHandler) {
        id = conf.keySet().stream().findFirst().orElseThrow();
        try {
            origin = conf.getSubMap(id).getString("origin");
            conf = conf.getSubMap(id); // There must be some properties for a storage
            prefix = conf.getString(PREFIX_KEY);
            description = conf.getString(DESCRIPTION_KEY, null);
            storage = storageHandler.getStorage(conf.getString(STORAGE_KEY, null)); // null means default storage

            if (conf.containsKey(GET_RECORD_ENDPOINT_KEY)){
                getRecordEndpoint = conf.getString(GET_RECORD_ENDPOINT_KEY);

            }

            views = conf.getYAMLList(VIEWS_KEY)
                    .stream()
                    .map(yaml -> new View(yaml, origin))
                    .collect(Collectors.toMap(view -> view.getId().toLowerCase(Locale.ROOT), view -> view));
        } catch (NotFoundException e) {
            throw new IllegalArgumentException(
                    "Mandatory property '" + e.getPath() + "' not present for Collection '" + id + "'");
        }
        log.info("Created " + this);
    }

    /**
     * Retrieve the record with the given id and transform it to the given format before delivery.
     * @param recordID an ID for a record.
     * @param format the format of the record. See {@link #getViews()} for available formats.
     * @return the record with the given id in the given format.
     * @throws ServiceException if the record could not be retrieved or transformed.
     */
    public String getRecord(String recordID, String format) throws ServiceException {
        View view = getView(format);
        DsRecordDto record = storage.getDSRecord(recordID);
        String child = getChildRecord(record);
        String recordData = record.getData();
        return view.apply(recordID, recordData, child);
    }

    /**
     * Retrieve a record with the given ID in ds-storage record format.
     * Storages that are not {@link dk.kb.present.storage.DSStorage} will deliver best-effort {@link DsRecordDto}s,
     * but full representation is not guaranteed.
     * @param recordID an ID for a record.
     * @return the record in ds-storage record format.
     * @throws ServiceException if the record could not be retrieved.
     */
    public DsRecordDto getDSRecord(String recordID) throws ServiceException {
        return storage.getDSRecord(recordID);
    }

    /**
     * Returns a stream of records where the data are transformed to the given format.
     * @param mTime point in time (epoch * 1000) for the records to deliver, exclusive.
     * @param maxRecords the maximum number of records to deliver. -1 means no limit.
     * @param format the format of the record. See {@link #getViews()} for available formats.
     * @return a stream of records in the requested format.
     * @throws ServiceException if anything went wrong during construction of the stream.
     */
    public Stream<DsRecordDto> getDSRecords(Long mTime, Long maxRecords, String format) {
        View view = getView(format);
        log.debug("Calling storage.getDSRecords(origin='{}', mTime={}, maxRecords={})",
                origin, mTime, maxRecords);
        try {
            return storage.getDSRecords(origin, mTime, maxRecords)
                    .peek(record -> {
                        try {
                            String relation = getChildRecord(record);
                            record.data(view.apply(record.getId(), record.getData(), relation));
                        } catch (Exception e) {
                            throw new RuntimeTransformerException(
                                    "Exception transforming record '" + record.getId() + "' to format '" + format + "'");

                        }
                    });
        } catch (Exception e) {
            log.warn("Exception calling getDSRecords with collection='{}', mTime={}, maxRecords={}",
                     getId(), mTime, maxRecords, e);
            throw new InternalServiceException(
                    "Internal exception requesting records from collection '" + getId() + "' in format " + format);
        }
    }

    /**
     * Extract the first child record from storage if present in input record.
     * @param record     to extract children for.
     * @return the URI value of the related raw record for the input record.
     */
    private String getChildRecord(DsRecordDto record) {

        // TODO: Figure how to choose correct manifestation for record, if more than one is present
        // Return first child record, but if there are multiple presentation manifestations,
        // the rest are currently not added to the transformation
        return record.getChildrenIds() == null ? "" :
                record.getChildrenIds().stream()
                        .map(id -> getRawUri(id, getRecordEndpoint))
                        .findFirst().orElse("");
    }

    /**
     * Construct a URI for child records pointing towards the raw representation of the child record in ds-present.
     * @param id id of record to construct URI for.
     * @return   the URI for the input record.
     */
    private static String getRawUri(String id, String getRecordEndpoint) {
        String encodedId = URLEncoder.encode(id, StandardCharsets.UTF_8);
        String rawRecordUri = getRecordEndpoint + encodedId + "?format=raw";
        return rawRecordUri;
    }

    /**
     * @return the ID of the collection, primarily used for debugging and configuration.
     */
    public String getId() {
        return id;
    }

    /**
     * recordIDs always starts with the collection followed by underscore, e.g. {@code images-dsfl_internalid1234}.
     * The prefix must be present for all recordIDs used for lookup.
     * This might be the same as the {@link #id} but it is not a requirement.
     * @return the prefix for recordIDs in the collection.
     */
    public String getPrefix() {
        return prefix;
    }

    /**
     * @return human readable description of the collection.
     */
    public String getDescription() {
        return description;
    }

    /**
     * Map from format -> view. A view is at the core an array of transformations and responsible for transforming
     * metadata to the requested format.
     * @return the available views (aka formats) for this collection. Keys are lowercase.
     */
    public Map<String, View> getViews() {
        return views;
    }

    /**
     * Locate the View which matches the given format (View ID == format.toLowerCase()).
     * @param format the ID of the View.
     * @return a View matching the given format aka ID.
     * @throws InvalidArgumentServiceException if no View could be located.
     */
    public View getView(String format) {
        View view = views.get(format.toLowerCase(Locale.ROOT));
        if (view == null) {
            throw new InvalidArgumentServiceException(
                    "The format '" + format + "' is not supported for collection '" + id + "'");
        }
        return view;
    }

    /**
     * @param view any given view, e.g. {@code DOMS} or {@code raw}.
     * @return true if the collection supports the view.
     */
    public boolean supportsView(String view) {
        return views.containsKey(view.toLowerCase(Locale.ROOT));
    }

    @Override
    public String toString() {
        return "DSCollection(" +
               "id='" + id + '\'' +
               ", prefix='" + prefix + '\'' +
               ", description='" + description + '\'' +
               ", storage=" + storage +
               ", origin=" + origin +
               ", views=" + views +
               ')';
    }

}
