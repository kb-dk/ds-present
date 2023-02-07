package dk.kb.present.solr;

import java.io.File;
import java.io.IOException;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.Map;
import java.util.Properties;

import org.apache.solr.client.solrj.SolrQuery;
import org.apache.solr.client.solrj.SolrRequest.METHOD;
import org.apache.solr.client.solrj.embedded.EmbeddedSolrServer;
import org.apache.solr.client.solrj.response.QueryResponse;
import org.apache.solr.common.SolrDocument;
import org.apache.solr.common.SolrInputDocument;

import org.apache.solr.core.*;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assertions.fail;

import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;


import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.JsonElement;
import com.google.gson.JsonParser;



import dk.kb.present.TestUtil;

public class EmbeddedSolrFieldAnalyseTest {

	private static final Logger log = LoggerFactory.getLogger(EmbeddedSolrTest.class);
	private static String solr_home = "target/test-classes/solr";

	private static CoreContainer coreContainer = null;
	private static EmbeddedSolrServer embeddedServer = null;

	public static final String MODS2SOLR = "xslt/mods2solr.xsl";
	public static final String RECORD_000332 = "xml/copyright_extraction/000332.tif.xml"; 
	public static final String RECORD_DPK = "xml/copyright_extraction/DPK000107.tif.xml";
	public static final String RECORD_096c9090 = "xml/copyright_extraction/096c9090-717f-11e0-82d7-002185371280.xml";

	/*
	 * Start Solr server and index test documents with method addTestDocuments
	 * 
	 */	
	@BeforeAll
	public static void startEmbeddedSolrServer() throws Exception {

		File solrHomeDir = new File(solr_home);		
		String solrHomeAbsoluteDir= solrHomeDir.getAbsolutePath();	
		Path solrHome =  Paths.get(solrHomeAbsoluteDir);
		System.setProperty("solr.install.dir", solrHomeAbsoluteDir);
		Properties props = new Properties();
		// props.put("solr.install.dir", solrHomeDir.getAbsolutePath()); //Does not
		// work. Use system property above for now
		coreContainer = new CoreContainer(solrHome, props);
		coreContainer.load();
		embeddedServer = new EmbeddedSolrServer(coreContainer, "dssolr");
		
		addTestDocuments();
		
	}

	@AfterAll
	public static void tearDown() throws Exception {
		coreContainer.shutdown();
		embeddedServer.close();
	}
	
	
	/*
	 * Even diacritics must match for text_strict field 
	 */
	@Test
    void testStrictTextField() throws Exception {
        assertEquals(0,getCreatorNameResultsForQuery("Thomas XEgenseX")); //Make sure default operator is AND and not OR.
        assertEquals(1,getCreatorNameResultsForQuery("Thomas Egense"));
        assertEquals(1,getCreatorNameResultsForQuery("Thomas"));
        assertEquals(1,getCreatorNameResultsForQuery("thomas egense")); //lower case        
        assertEquals(0,getCreatorNameResultsForQuery("Thomas Gunter Grass")); //No match, different multivalue fields.      
        assertEquals(1,getCreatorNameResultsForQuery("Antoine de Saint-Exupéry")); //Excact match
        assertEquals(0,getCreatorNameResultsForQuery("Antoine de Saint Exupéry")); //Even a character '-' must match
        assertEquals(0,getCreatorNameResultsForQuery("Antoine de Saint-Exupery")); //No match without diacritics
    
    }
        
        
    
	/*
	 * Test normalized field match with and without diacriticts
	 */
	@Test
	void testDiacriticsStripping() throws Exception {
		
		// Test match with diacritic stripping in 'freetext' field
		assertEquals(1,getFreeTextResultsForQuery("Thomas Grass")); // Combine names, should still match
		//Diacritics
		assertEquals(1,getFreeTextResultsForQuery("Thomas Egense"));
		assertEquals(1,getFreeTextResultsForQuery("thomas egense")); //lower case
		assertEquals(1,getFreeTextResultsForQuery("Antoine de Saint-Exupéry")); //with diacritics
		assertEquals(1,getFreeTextResultsForQuery("Saint-Exupery")); //without diacritics
		assertEquals(1,getFreeTextResultsForQuery("Saint Exupery")); // '-' removed
		assertEquals(1,getFreeTextResultsForQuery("Honoré de Balzac")); 
		assertEquals(1,getFreeTextResultsForQuery("Honore de Balzac"));		
		assertEquals(1,getFreeTextResultsForQuery("Søren Kierkegaard"));
		assertEquals(1,getFreeTextResultsForQuery("soren kierkegaard")); //Do we want OE match?		
		assertEquals(1,getFreeTextResultsForQuery("Juliusz Słowacki"));
		assertEquals(1,getFreeTextResultsForQuery("Juliusz Slowacki"));		
		assertEquals(1,getFreeTextResultsForQuery("Maria Dąbrowska"));
		assertEquals(1,getFreeTextResultsForQuery("maria dabrowska"));		
		assertEquals(1,getFreeTextResultsForQuery("Gabriel García Márquez"));
		assertEquals(1,getFreeTextResultsForQuery("Gabriel Garcia Marquez"));
		assertEquals(1,getFreeTextResultsForQuery("Günter Grass"));
		assertEquals(1,getFreeTextResultsForQuery("Gunter Grass"));
		
		
		
	}
	
	

	private long getCreatorNameResultsForQuery(String query) throws Exception{	    
		SolrQuery solrQuery = new SolrQuery();
		solrQuery.setQuery("creator_full_name:("+query +")");
		solrQuery.setRows(10);           
		QueryResponse rsp = embeddedServer.query(solrQuery, METHOD.POST); 		
		return rsp.getResults().getNumFound();
	}

	

	private long getFreeTextResultsForQuery(String query) throws Exception{	    
		SolrQuery solrQuery = new SolrQuery();
		solrQuery.setQuery("freetext:("+query +")");
		solrQuery.setRows(10);           
		QueryResponse rsp = embeddedServer.query(solrQuery, METHOD.POST); 		
		return rsp.getResults().getNumFound();
	}


	
	
	private static void addTestDocuments() throws Exception {

	try {
				SolrInputDocument document = new SolrInputDocument();
				document.addField("id", 1);
				document.addField("creator_full_name", "Thomas Egense");
				document.addField("creator_full_name", "Antoine de Saint-Exupéry");
				document.addField("creator_full_name", "Honoré de Balzac"); 
				document.addField("creator_full_name", "Søren Kierkegaard");
				document.addField("creator_full_name", "Juliusz Słowacki");
				document.addField("creator_full_name", "Maria Dąbrowska");
				document.addField("creator_full_name", "Gabriel García Márquez");
				document.addField("creator_full_name", "Günter Grass");
								
				embeddedServer.add(document);
				embeddedServer.commit();



		} catch (Exception e) {
			e.printStackTrace();
			fail("Error indexing test documents");
		}

	}



}
