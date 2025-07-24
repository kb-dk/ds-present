package dk.kb.present.api.v1.impl;

import dk.kb.present.PresentFacade;
import dk.kb.present.Stats;
import dk.kb.present.api.v1.DsPresentApiApi;
import dk.kb.present.model.v1.FormatDto;
import dk.kb.present.model.v1.OriginDto;
import dk.kb.present.webservice.AccessUtil;
import dk.kb.util.webservice.exception.ForbiddenServiceException;
import dk.kb.util.webservice.ImplBase;
import dk.kb.util.webservice.exception.InternalServiceException;
import dk.kb.util.webservice.exception.NotFoundServiceException;
import dk.kb.util.webservice.exception.ServiceException;

import org.apache.cxf.interceptor.InInterceptors;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.ws.rs.core.StreamingOutput;
import java.io.IOException;
import java.util.List;
import java.util.Map;

/**
 * ds-present
 * <p>
 * Metadata delivery for the Royal Danish Library
 */
@InInterceptors(interceptors = "dk.kb.present.webservice.KBAuthorizationInterceptor")
public class DsPresentApiServiceImpl extends ImplBase implements DsPresentApiApi {
    private static final Logger log = LoggerFactory.getLogger(DsPresentApiServiceImpl.class);

    // "Search" is best guess for the access type for now
    // This might be changed when we make a major evaluation of the license system
    public static final String RECORD_ACCESS_TYPE = "Search";

    /**
     * The different types of access for a given material.
     */
    public enum ACCESS {
        /**
         * Material exists and the caller is allowed to access it.
         */
        ok,
        /**
         * Material exists but the caller is not allowed to access it.
         */
        not_allowed,
        /**
         * The material does not exist in the system.
         */
        not_exists}

    /* How to access the various web contexts. See https://cxf.apache.org/docs/jax-rs-basics.html#JAX-RSBasics-Contextannotations */

    /**
     * Retrieve a formal description of a single origin
     * 
     * @param id: The ID of the origin
     * 
     * @return <ul>
      *   <li>code = 200, message = "OK: The origin was known and a description is returned", response = OriginDto.class</li>
      *   <li>code = 404, message = "Origin is unknown", response = String.class</li>
      *   </ul>
      * @throws ServiceException when other http codes should be returned
      *
      * @implNote return will always produce a HTTP 200 code. Throw ServiceException if you need to return other codes
     */
    @Override
    public OriginDto getOrigin(String id) throws ServiceException {
        try {
            // Allowed for everyone
            log.debug("() called with call details: {}", getCallDetails());
            return PresentFacade.getOrigin(id);
        } catch (Exception e){
            throw handleException(e);
        }
    }

    /**
     * Retrieve a formal description of all origins
     * 
     * @return <ul>
      *   <li>code = 200, message = "OK: Origins are returned", response = OriginDto.class, responseContainer = "List"</li>
      *   </ul>
      * @throws ServiceException when other http codes should be returned
      *
      * @implNote return will always produce a HTTP 200 code. Throw ServiceException if you need to return other codes
     */
    @Override
    public List<OriginDto> getOrigins() throws ServiceException {
        try {
            // Allowed for everyone
            log.debug("getOrigins() called with call details: {}", getCallDetails());
            return PresentFacade.getOrigins();
        } catch (Exception e){
            throw handleException(e);
        }
    }

    /**
     * Retrieve metadata for the record with the given ID and in the given format
     * 
     * @param id: The ID of the record
     * 
     * @param format: The delivery format for the record: * JSON-LD: [Linked Data in JSON](https://json-ld.org/) (default) * MODS: [Metadata Object Description Schema[(http://www.loc.gov/standards/mods/) * SolrXML: [Solr XML Formatted Index Updates)(https://solr.apache.org/guide/8_8/uploading-data-with-index-handlers.html#xml-formatted-index-updates) * raw: Metadata unchanged from the source. 
     * 
     * @return <ul>
      *   <li>code = 200, message = "OK: The record was available in the requested format", response = String.class</li>
      *   <li>code = 404, message = "Record ID is unknown", response = ErrorDto.class</li>
      *   </ul>
      * @throws ServiceException when other http codes should be returned
      *
      * @implNote return will always produce a HTTP 200 code. Throw ServiceException if you need to return other codes
     */
    @Override
    public String getRecord(String id, FormatDto format) throws ServiceException {
        long startNS = System.nanoTime();
        try {
            log.debug("getRecord(id='{}', format='{}') called with groups {} and call details: {}",
                    id, format, AccessUtil.getGroups(httpHeaders), getCallDetails());
            ACCESS access = Stats.RECORD_ACCESS.measure(() ->
                    AccessUtil.createAccessChecker(AccessUtil.getGroups(httpHeaders), RECORD_ACCESS_TYPE).apply(id));
            switch (access) {
                case ok:
                    return PresentFacade.getRecord(id, format);
                case not_allowed:
                    // TODO: Log access tokens or roles when available
                    log.debug("getRecord(id='{}', format='{}'): User access not allowed", id, format);
                    throw new ForbiddenServiceException("User not allowed to retrieve metadata for '" + id + "'");
                case not_exists:
                    log.debug("getRecord(id='{}', format='{}'): Not found", id, format);
                    throw new NotFoundServiceException("The material '" + id + "' could not be found");
                default:
                    throw new UnsupportedOperationException("The access condition '" + access + "' is unsupported");
            }
        } catch (Exception e){
            throw handleException(e);
        } finally {
            Stats.GET_RECORD.addNS(System.nanoTime()-startNS);
            log.debug("getRecord(id='{}', format='{}') finished with stats {}",
                    id, format, Stats.GET_RECORD);
        }
    }

    @Override
    public StreamingOutput getRecords(String origin, Long mTime, Long maxRecords, FormatDto format) {
        log.debug("getRecords(origin='{}', mTime={}, maxRecords={}, format='{}') called with groups {} " +
                        "and call details: {}",
                  origin, mTime, maxRecords, format, AccessUtil.getGroups(httpHeaders), getCallDetails());
        if (origin == null) {
            throw new InternalServiceException("origin must be specified but was not");
        }
        try {
            long finalMTime = mTime == null ? 0L : mTime;
            long finalMaxRecords = maxRecords == null ? 1000L : maxRecords;
            return PresentFacade.getRecords(
                    httpServletResponse, origin, finalMTime, finalMaxRecords, format,
                    AccessUtil.createAccessFilter(AccessUtil.getGroups(httpHeaders), RECORD_ACCESS_TYPE));
        } catch (Exception e){
            throw handleException(e);
        }
    }

    @Override
    public StreamingOutput getRecordsRaw(String origin, Long mTime, Long maxRecords, Boolean asJsonLines) {
        log.debug("getRawRecords(origin='{}', mTime={}, maxRecords={}, asJsonLines={}) called with groups {} " +
                        "and call details: {}",
                origin, mTime, maxRecords, asJsonLines, AccessUtil.getGroups(httpHeaders), getCallDetails());
        if (origin == null) {
            throw new InternalServiceException("origin must be specified but was not");
        }
        if (asJsonLines == null){
            asJsonLines = false;
        }

        try {
            long finalMTime = mTime == null ? 0L : mTime;
            long finalMaxRecords = maxRecords == null ? 1000L : maxRecords;
            return PresentFacade.getRecordsRaw(
                    httpServletResponse, origin, finalMTime, finalMaxRecords,
                    AccessUtil.createAccessFilter(AccessUtil.getGroups(httpHeaders), RECORD_ACCESS_TYPE),
                    asJsonLines);
        } catch (Exception e){
            throw handleException(e);
        }
    }

    @Override
    public String transformsolrschemaPost(String format, String rawSchema) {
        try {
            return PresentFacade.transformSolrSchema(rawSchema, format);
        } catch (IOException e) {
            throw handleException(e);
        }
    }
}
