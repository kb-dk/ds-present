package dk.kb.present.api.v1.impl;

import dk.kb.present.Stats;
import dk.kb.present.api.v1.ServiceApi;
import dk.kb.present.model.v1.StatusDto;
import dk.kb.present.model.v1.WhoamiDto;
import dk.kb.present.model.v1.WhoamiTokenDto;
import dk.kb.present.webservice.KBAuthorizationInterceptor;
import dk.kb.util.BuildInfoManager;
import dk.kb.util.Timing;
import dk.kb.util.webservice.ImplBase;
import dk.kb.util.webservice.exception.ServiceException;

import org.apache.cxf.jaxrs.utils.JAXRSUtils;
import org.apache.cxf.message.Message;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.net.InetAddress;
import java.net.UnknownHostException;
import java.util.ArrayList;
import java.util.Set;

/**
 * ds-present
 *
 * <p>Metadata delivery for the Royal Danish Library.  This API delivers metadata from collections at the Royal Danish Library. These metadata can be delivered in different formats. The `/record/{id}`-endpoint can deliver metadata as [JSON-LD](https://json-ld.org/), [MODS](http://www.loc.gov/standards/mods/) and [SolrJSON](https://solr.apache.org/guide/8_8/uploading-data-with-index-handlers.html#json-formatted-index-updates).  Furthermore metadata can be delivered as IIIF Presentation manifests through the `/IIIF/{identifier}/manifest`-endpoint.  For information on the IIIF Presentation API see the following [link](https://iiif.io/api/presentation/3.0/). This API supports version 3.0 and should be backwards compatible with version 2.1.1 
 *
 */
public class ServiceApiServiceImpl extends ImplBase implements ServiceApi {
    private static final Logger log = LoggerFactory.getLogger(ServiceApiServiceImpl.class);



    /**
     * Ping the server to check if the server is reachable.
     * 
     * @return <ul>
      *   <li>code = 200, message = "OK", response = String.class</li>
      *   </ul>
      * @throws ServiceException when other http codes should be returned
      *
      * @implNote return will always produce a HTTP 200 code. Throw ServiceException if you need to return other codes
     */
    @Override
    public String ping() throws ServiceException {
        try {
            log.debug("ping() called with call details: {}", getCallDetails());
            return "Pong";
        } catch (Exception e){
            throw handleException(e);
        }
    }

    /**
     * Detailed status / health check for the service
     * 
     * @return <ul>
      *   <li>code = 200, message = "OK", response = StatusDto.class</li>
      *   <li>code = 500, message = "Internal Error", response = String.class</li>
      *   </ul>
      * @throws ServiceException when other http codes should be returned
      *
      * @implNote return will always produce a HTTP 200 code. Throw ServiceException if you need to return other codes
     */
    @Override
    public StatusDto status() throws ServiceException {
        log.debug("status() called with call details: {}", getCallDetails());
        String host = "N/A";

        try {
            host = InetAddress.getLocalHost().getHostName();

        } catch (UnknownHostException e) {
            log.warn("Exception resolving hostname", e);
        }
        return new StatusDto()
                .application(BuildInfoManager.getName())
                .version(BuildInfoManager.getVersion())
                .build(BuildInfoManager.getBuildTime())
                .java(System.getProperty("java.version"))
                .heap(Runtime.getRuntime().maxMemory()/1048576L)
                .server(host)
                .gitCommitChecksum(BuildInfoManager.getGitCommitChecksum())
                .gitBranch(BuildInfoManager.getGitBranch())
                .gitClosestTag(BuildInfoManager.getGitClosestTag())
                .gitCommitTime(BuildInfoManager.getGitCommitTime())
                .health("ok")
                .stats(Stats.GET_RECORD.toString((Timing.STATS[])null, true));
    }

    /**
     * Extract info from OAUth2 accessTokens.
     * @return OAUth2 roles from the caller's accessToken, if present.
     */
    @SuppressWarnings("unchecked")
    @Override
    public WhoamiDto probeWhoami() {
        WhoamiDto whoami = new WhoamiDto();
        WhoamiTokenDto token = new WhoamiTokenDto();
        whoami.setToken(token);

        Message message = JAXRSUtils.getCurrentMessage();

        token.setPresent(message.containsKey(KBAuthorizationInterceptor.ACCESS_TOKEN_STRING));
        token.setValid(Boolean.TRUE.equals(message.get(KBAuthorizationInterceptor.VALID_TOKEN)));
        if (message.containsKey(KBAuthorizationInterceptor.FAILED_REASON)) {
            token.setError(message.get(KBAuthorizationInterceptor.FAILED_REASON).toString());
        }
        Object roles = message.get(KBAuthorizationInterceptor.TOKEN_ROLES);
        if (roles != null) {
            token.setRoles(new ArrayList<>((Set<String>)roles));
        }
        return whoami;
    }
}
