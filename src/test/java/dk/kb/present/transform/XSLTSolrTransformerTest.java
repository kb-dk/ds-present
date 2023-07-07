package dk.kb.present.transform;

import dk.kb.present.TestUtil;

import org.junit.jupiter.api.Test;

import com.google.gson.*;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

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
class XSLTSolrTransformerTest{

	public static final String MODS2SOLR = "xslt/mods2solr.xsl";
	public static final String RECORD_05fea810 = "xml/copyright_extraction/05fea810-7181-11e0-82d7-002185371280.xml";
	public static final String RECORD_3956d820 = "xml/copyright_extraction/3956d820-7b7d-11e6-b2b3-0016357f605f.xml";
	public static final String RECORD_096c9090 = "xml/copyright_extraction/096c9090-717f-11e0-82d7-002185371280.xml";
	public static final String RECORD_aaf3b130 = "xml/copyright_extraction/aaf3b130-e6e7-11e6-bdbe-00505688346e.xml";
	public static final String RECORD_54b34b50 = "xml/copyright_extraction/54b34b50-2ce6-11ed-81b4-005056882ec3.xml";
	public static final String RECORD_8e608940 = "xml/copyright_extraction/8e608940-d6db-11e3-8d2e-0016357f605f.xml";
	public static final String RECORD_45dd4830 = "xml/copyright_extraction/45dd4830-717f-11e0-82d7-002185371280.xml";
	public static final String RECORD_DNF = "xml/copyright_extraction/DNF_1951-00352_00052.tif.xml";
	public static final String RECORD_ANSK = "xml/copyright_extraction/ANSK_11614.tif.xml";
	public static final String RECORD_FM = "xml/copyright_extraction/FM103703H.tif.xml";
	public static final String RECORD_5cc1bea0 = "xml/copyright_extraction/5cc1bea0-71fa-11e2-b31c-0016357f605f.xml";
	public static final String RECORD_Elf = "xml/copyright_extraction/09222b40-dba1-11e5-9785-0016357f605f.xml";
	public static final String RECORD_e2519ce0 = "xml/copyright_extraction/e2519ce0-9fb0-11e8-8891-00505688346e.xml";
	public static final String RECORD_26d4dd60 ="xml/copyright_extraction/26d4dd60-6708-11e2-b40f-0016357f605f.xml";
	public static final String RECORD_9C = "xml/copyright_extraction/9c17a440-fe1a-11e8-9044-00505688346e.xml";
	public static final String RECORD_3B03 = "xml/copyright_extraction/3b03aa00-fee2-11e8-ab76-00505688346e.xml";
	public static final String RECORD_DB_hans = "xml/copyright_extraction/25461fb0-f664-11e0-9d29-0016357f605f.xml";
	public static final String RECORD_770379f0 = "xml/copyright_extraction/770379f0-8a0d-11e1-805f-0016357f605f.xml";
	public static final String RECORD_40221e30 = "xml/copyright_extraction/40221e30-1414-11e9-8fb8-00505688346e.xml";
	@Test
	void testSolrNew() throws Exception {
		String solrString = TestUtil.getTransformedWithAccessFieldsAdded(MODS2SOLR, RECORD_05fea810);
		assertTrue(solrString.contains("\"id\":\"05fea810-7181-11e0-82d7-002185371280\""));
	}

	/**
	 * This record is tested thoroughly in EmbeddedSolrTest.testRecordDPK()
	 */
	@Test
	void testXsltNewDpkItem() throws Exception {
		String solrString = TestUtil.getTransformedWithAccessFieldsAdded(MODS2SOLR, RECORD_3956d820);
		assertTrue(solrString.contains("\"shelf_location\":\"Billedsamlingen. Postkortsamlingen, Vestindien, Sankt Thomas, Charlotte Amalie, Det gamle fort\\/politistation\""));
	}

	@Test
	void testXslt45dd() throws Exception {
		String solrString = TestUtil.getTransformedWithAccessFieldsAdded(MODS2SOLR, RECORD_45dd4830);
		assertTrue(solrString.contains("\"catalog_name\":\"Samlingsbilleder\",\"collection\":\"Billedsamlingen\""));
	}

	/**
	 * This record is fully tested in EmbeddedSolrTest.testRecord096c9090()
	 */
	@Test
	void testXslt096() throws Exception {
		String solrString = TestUtil.getTransformedWithAccessFieldsAdded(MODS2SOLR, RECORD_096c9090);
		assertTrue(solrString.contains("\"id\":\"096c9090-717f-11e0-82d7-002185371280\""));
	}

	@Test
	void testNoNameButAffiliation() throws Exception {
		String solrString = TestUtil.getTransformedWithAccessFieldsAdded(MODS2SOLR, RECORD_DNF);
		assertTrue(solrString.contains("\"creator_affiliation\":[\"Bisson frères\"],\"creator_description\":[\"fransk korporation\"]"));
		assertFalse(solrString.contains("creator_given_name"));
	}

	@Test
	void testNoNameMultipleNames() throws Exception {
		String solrString = TestUtil.getTransformedWithAccessFieldsAdded(MODS2SOLR, RECORD_5cc1bea0);
		assertTrue(solrString.contains("\"creator_given_name\":[\"Chen\"]"));
		assertTrue(solrString.contains("\"creator_date_of_birth\":[\"1945-0-0\",\"1945-0-0\"]"));
	}

	@Test
	void testEmptyCollection() throws Exception {
		String solrString = TestUtil.getTransformedWithAccessFieldsAdded(MODS2SOLR, RECORD_Elf);
		assertFalse(solrString.contains("collection"));
	}

	@Test
	void testNoTermsOfAddress() throws Exception {
		String solrString = TestUtil.getTransformedWithAccessFieldsAdded(MODS2SOLR, RECORD_ANSK);
		assertFalse(solrString.contains("creator_terms_of_address"));
	}

	@Test
	void testXsltSkfF0137() throws Exception {
		String solrString = TestUtil.getTransformedWithAccessFieldsAdded(MODS2SOLR, RECORD_54b34b50);
		assertTrue(solrString.contains("\"list_of_categories\":[\"Rytterskoler x\",\"Skolehistorie\",\"69 testfiler\"]"));
	}

	@Test
	void testUldall() throws Exception {
		String solrString = TestUtil.getTransformedWithAccessFieldsAdded(MODS2SOLR, RECORD_e2519ce0);
		assertTrue(solrString.contains("\"catalog_name\":\"Maps\""));
	}

	@Test
	void testChineseTitels() throws Exception {
		String solrString = TestUtil.getTransformedWithAccessFieldsAdded(MODS2SOLR, RECORD_26d4dd60);
		assertTrue(solrString.contains("\"creator_affiliation\":[\"Haidian Yangfang dian jiedao zhongxin xiaoxue (海淀区羊坊店街道中心小学)\"]"));
	}

	@Test
	void testMultipleAffiliations() throws Exception {
		String solrString = TestUtil.getTransformedWithAccessFieldsAdded(MODS2SOLR,  RECORD_9C);
		assertTrue(solrString.contains("\"creator_affiliation\":[\"Billedbladet\",\"Nordisk Pressefoto\"]"));
	}

	@Test
	void testMultipleDescriptions() throws Exception {
		String solrString = TestUtil.getTransformedWithAccessFieldsAdded(MODS2SOLR,  RECORD_3B03);
		assertTrue(solrString.contains("\"creator_affiliation\":[\"Aftenbladet\",\"Associated Press\"],\"creator_description\":[\"dansk avis\",\"amerikansk nyhedsbureau\"]"));
	}

	@Test
	void testDifferentRelatedItems() throws Exception {
		String solrString = TestUtil.getTransformedWithAccessFieldsAdded(MODS2SOLR, RECORD_DB_hans);
		assertTrue(solrString.contains("\"collection\":\"Bladtegnersamlingen\",\"published_in\":\"Aktuelt\""));
	}

	@Test
	void testTitleExtraction() throws Exception {
		String solrString = TestUtil.getTransformedWithAccessFieldsAdded(MODS2SOLR, RECORD_770379f0);
		assertTrue(solrString.contains("\"titles\":[\"Romeo og Julie\"]"));
	}

	@Test
	void testImageResource() throws Exception {
		String solrString = TestUtil.getTransformedWithAccessFieldsAdded(MODS2SOLR, RECORD_40221e30);
		assertTrue(solrString.contains("\"resource_id\":[\"\\/DAMJP2\\/DAM\\/Samlingsbilleder\\/0000\\/624\\/420\\/KE070592\"]"));
	}

	/**
	 * Transform the input MODS record with an XSLT and return as pretty JSON
	 */
	private void prettyPrintSolrJsonFromMods(String record) throws Exception {
		String solrString = TestUtil.getTransformedWithAccessFieldsAdded(MODS2SOLR, record);
		Gson gson = new GsonBuilder().setPrettyPrinting().create();
		JsonElement je = JsonParser.parseString(solrString);
		String prettyJsonString = gson.toJson(je);
		System.out.println(prettyJsonString);
	}


}