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
package dk.kb.present.storage;

import dk.kb.util.yaml.YAML;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Constructs {@link FailStorage}s.
 */
public class FailStorageFactory implements StorageFactory {
    private static final Logger log = LoggerFactory.getLogger(FailStorageFactory.class);
    private static final String TYPE = "fail";

    public static final String MESSAGE_KEY = "message";
    public static final String MESSAGE_DEFAULT = "No records can be delivered from this Storage";

    @Override
    public String getStorageType() {
        return TYPE;
    }

    @Override
    public Storage createStorage(String id, YAML conf, boolean isDefault) throws Exception {
        String message = conf.getString(MESSAGE_KEY, MESSAGE_DEFAULT);

        return new FailStorage(id, message, isDefault);
    }
}
