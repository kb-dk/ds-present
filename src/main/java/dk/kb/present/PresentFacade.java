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

import dk.kb.present.backend.model.v1.DsRecordDto;
import dk.kb.present.config.ServiceConfig;
import dk.kb.present.model.v1.CollectionDto;
import dk.kb.present.model.v1.ViewDto;
import dk.kb.present.webservice.ExportWriter;
import dk.kb.present.webservice.ExportWriterFactory;
import dk.kb.present.webservice.exception.InvalidArgumentServiceException;
import dk.kb.present.webservice.exception.NotFoundServiceException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.servlet.http.HttpServletResponse;
import javax.ws.rs.core.StreamingOutput;
import java.util.List;
import java.util.Locale;
import java.util.stream.Collectors;

/**
 *
 */
public class PresentFacade {
    private static final Logger log = LoggerFactory.getLogger(PresentFacade.class);

    private static CollectionHandler collectionHandler;

    /**
     * Optional warmUp (initialization) for fail early.
     */
    public static void warmUp() {
        getCollectionHandler();
    }

    private static CollectionHandler getCollectionHandler() {
        if (collectionHandler == null) {
            collectionHandler = new CollectionHandler(ServiceConfig.getConfig());
        }
        return collectionHandler;
    }

    // TODO: What about setting the MIME type?

    /**
     * Derived a collection from the recordID and requests the record from that, with the specified format.
     * @param recordID an ID for a record in any known collection.
     * @param format the wanted format (collection specific).
     * @return the record in the given format.
     * @throws NotFoundServiceException if the record or the format was unknown.
     */
    public static String getRecord(String recordID, String format) {
        return getCollectionHandler().getRecord(recordID, format);
    }

    /**
     * @param id ID for a collection.
     * @return the collection with the given ID.
     * @throws NotFoundServiceException if the collection was not known.
     */
    public static CollectionDto getCollection(String id) {
        DSCollection collection = getCollectionHandler().getCollection(id);
        if (collection == null) {
            throw new NotFoundServiceException("A collection with the id '" + id + "' could not be located. " +
                                               "Supported collections are " + collectionHandler.getCollectionNames());
        }
        return toDto(collection);
    }

    /**
     * @return all known collections.
     */
    public static List<CollectionDto> getCollections() {
        return getCollectionHandler().getCollections().stream()
                .map(PresentFacade::toDto)
                .collect(Collectors.toList());
    }

    // TODO: storage is not returned as that is internal information. With elevated privileges this might be added?
    private static CollectionDto toDto(DSCollection collection) {
        return new CollectionDto()
                .id(collection.getId())
                .description(collection.getDescription())
                .views(collection.getViews().values().stream()
                               .map(PresentFacade::toDto)
                               .collect(Collectors.toList()));
    }

    private static ViewDto toDto(View view) {
        return new ViewDto().id(view.getId()).mime(view.getMime().toString());
    }

    public static StreamingOutput getRecords(
            HttpServletResponse httpServletResponse, String collectionID, Long mTime, Long maxRecords, String format) {
        DSCollection collection = collectionHandler.getCollection(collectionID);
        if (collection == null) {
            throw new InvalidArgumentServiceException(String.format(
                    Locale.ROOT, "The collection '%s' was unknown. Known collections are %s",
                    collectionID, collectionHandler.getCollections()));
        }

        // enum:  ['JSON-LD', 'JSON-LD-Lines', 'MODS', 'SolrJSON', "StorageRecord"]
        switch (format.toUpperCase(Locale.ROOT)) {
            case "JSON-LD": return getRecordsData(
                    collection, mTime, maxRecords,
                    httpServletResponse, "JSON-LD", ExportWriterFactory.FORMAT.json);
            case "JSON-LD-LINES": return getRecordsData(
                    collection, mTime, maxRecords,
                    httpServletResponse, "JSON-LD", ExportWriterFactory.FORMAT.jsonl);
            case "MODS": return getRecordsData(
                    collection, mTime, maxRecords,
                    httpServletResponse, "MODS", ExportWriterFactory.FORMAT.xml);
            case "STORAGERECORD": return getRecordsFull(
                    collection, mTime, maxRecords,
                    httpServletResponse, ExportWriterFactory.FORMAT.json);
            case "STORAGERECORD-LINES": return getRecordsFull(
                    collection, mTime, maxRecords,
                    httpServletResponse, ExportWriterFactory.FORMAT.jsonl);
            case "SOLRJSON": return getRecordsSolr(collection, mTime, maxRecords, httpServletResponse);
            default: throw new InvalidArgumentServiceException("The format '" + format + "' is not supported");
        }
    }

    private static StreamingOutput getRecordsData(
            DSCollection collection, Long mTime, Long maxRecords,
            HttpServletResponse httpServletResponse, String recordFormat, ExportWriterFactory.FORMAT deliveryFormat) {
        setFilename(httpServletResponse, mTime, maxRecords, deliveryFormat);
        return output -> {
            try (ExportWriter writer = ExportWriterFactory.wrap(
                    output, httpServletResponse, deliveryFormat, false, "records")) {
                collection.getDSRecords(mTime, maxRecords, recordFormat)
                        .map(DsRecordDto::getData)
                        .forEach(writer::write);
            }
        };
    }

    // Only deliver the data-part of the Records
    private static StreamingOutput getRecordsFull(
            DSCollection collection, Long mTime, Long maxRecords,
            HttpServletResponse httpServletResponse, ExportWriterFactory.FORMAT deliveryFormat) {
        return output -> {
            try (ExportWriter writer = ExportWriterFactory.wrap(
                    output, httpServletResponse, deliveryFormat, false, "records")) {
                collection.getDSRecords(mTime, maxRecords, "raw") // Does not contain deleted records
                        .forEach(writer::write);
            }
        };
    }

    // Direct ds-storage record JSON
    private static StreamingOutput getRecordsSolr(DSCollection collection, Long mTime, Long maxRecords,
                                                  HttpServletResponse httpServletResponse) {
        return output -> {
            try (ExportWriter writer = ExportWriterFactory.wrap(
                    output, httpServletResponse, ExportWriterFactory.FORMAT.json, false, "records")) {
                collection.getDSRecords(mTime, maxRecords, "SolrJSON")
                        .map(PresentFacade::wrapSolrJSON)
                        .forEach(writer::write);
            }
        };
    }

    // https://solr.apache.org/guide/8_8/uploading-data-with-index-handlers.html#json-formatted-index-updates
    private static String wrapSolrJSON(DsRecordDto record) {
        return Boolean.TRUE.equals(record.getDeleted()) ?
                "\"delete\": { \"id\": \"" + record.getId() + "\" }" :
                "\"add\": \n{ \"doc\" : " + record.getData() + "\n}\n}";

    }

    private static void setFilename(
            HttpServletResponse httpServletResponse,
            Long mTime, Long maxRecords, ExportWriterFactory.FORMAT deliveryFormat) {
        if (httpServletResponse == null) {
            log.debug("setFilename: No HttpServletResponse, so no filename stated");
            return;
        }
        String filename = "records_" + mTime + ".json";
        if (maxRecords <= 2) { // The Swagger GUI is extremely sluggish for inline rendering
            // A few records is ok to show inline in the Swagger GUI:
            // Show inline in Swagger UI, inline when opened directly in browser
            httpServletResponse.setHeader("Content-Disposition", "inline; filename=\"" + filename + "\"");
        } else {
            // When there are a lot of records, they should not be displayed inline in the OpenAPI GUI:
            // Show download link in Swagger UI, inline when opened directly in browser
            // https://github.com/swagger-api/swagger-ui/issues/3832
            httpServletResponse.setHeader("Content-Disposition", "inline; swaggerDownload=\"attachment\"; filename=\"" + filename + "\"");
        }
    }

}
