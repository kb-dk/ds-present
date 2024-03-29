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

import dk.kb.util.yaml.YAML;

import java.util.Arrays;

/**
 * Factory for creating a specific type of {@link DSTransformer}s.
 *
 * The class primarily exists as a mechanism for the ServiceLoader to discover transformers.
 *
 * IMPORTANT:
 * Implementations of AbstractTransformerFactory cannot be inner classes due to the way ServiceLoader works.
 * Implementations must be registered in src/main/resources/META-INF/services/dk.kb.present.transformer.AbstractTransformerFactory.
 */
public interface DSTransformerFactory {

    /**
     * @return the ID for the transformer that this factory creates, e.g. {@code mods2solr}.
     */
    String getTransformerID();

    /**
     * Create a new transformer of the supported type and return it.
     * @param conf configuration for the {@link DSTransformer} to create.
     * @return a {@link DSTransformer} of the supported type with the given configuration;
     * @throws Exception if the transformer could not be created.
     */
    DSTransformer createTransformer(YAML conf) throws Exception;

    /**
     * Helper for verifying existence of keys in the config.
     * @param config configuration for the concrete transformer.
     * @param requiredKeys 0 or more keys that must be present in the configuration.
     */
    default void assertConfigKeys(YAML config, String... requiredKeys) {
        for (String requiredKey: requiredKeys) {
            if (!config.containsKey(requiredKey)) {
                throw new IllegalArgumentException(
                        "Expected the property '" + requiredKey + "' to be present in the config. " +
                                "The complete list of mandatory properties is " + Arrays.toString(requiredKeys));
            }
        }

    }
}
