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
package dk.kb.present.util;

import dk.kb.present.client.v1.DsPresentApi;
import dk.kb.present.client.v1.IiifPresentationApi;
import dk.kb.present.invoker.v1.ApiClient;
import dk.kb.present.invoker.v1.Configuration;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.net.URI;

/**
 * Client for the service. Intended for use by other projects that calls this service.
 * See the {@code README.md} for details on usage.
 * <p/>
 * This class is not used internally.
 * <p/>
 * The client is Thread safe and handles parallel requests independently.
 * It is recommended to persist the client and to re-use it between calls.
 * <p/>
 * In order to call the IIIF endpoints, use {@link DsPresentClient#iiif}.
 */
public class DsPresentClient extends DsPresentApi {
    private static final Logger log = LoggerFactory.getLogger(DsPresentClient.class);

    /**
     * Sub-client for the IIIF endpoints.
     */
    public final IiifPresentationApi iiif;

    /**
     * Creates a client for the service.
     * @param serviceURI the URI for the service, e.g. {@code https://example.com/ds-present/v1}.
     */
    public DsPresentClient(String serviceURI) {
        super(createClient(serviceURI));
        iiif = new IiifPresentationApi(createClient(serviceURI));
        log.info("Created OpenAPI client for '" + serviceURI + "'");
    }

    /**
     * Deconstruct the given URI and use the components to create an ApiClient.
     * @param serviceURIString an URI to a service.
     * @return an ApiClient constructed from the serviceURIString.
     */
    private static ApiClient createClient(String serviceURIString) {
        log.debug("Creating OpenAPI client with URI '{}'", serviceURIString);

        URI serviceURI = URI.create(serviceURIString);
        // No mechanism for just providing the full URI. We have to deconstruct it
        return Configuration.getDefaultApiClient().
                setScheme(serviceURI.getScheme()).
                setHost(serviceURI.getHost()).
                setPort(serviceURI.getPort()).
                setBasePath(serviceURI.getRawPath());
    }
}
