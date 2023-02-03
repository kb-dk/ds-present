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
import com.google.common.reflect.TypeToken;
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.JsonElement;
import com.google.gson.JsonParser;



import dk.kb.present.TestUtil;
import dk.kb.present.copyright.XsltCopyrightMapper;
import dk.kb.util.Resolver;

public class EmbeddedSolrTest {

	private static final Logger log = LoggerFactory.getLogger(EmbeddedSolrTest.class);
	private static String solr_home = "target/test-classes/solr";

	private static CoreContainer coreContainer = null;
	private static EmbeddedSolrServer embeddedServer = null;

	public static final String MODS2SOLR = "xslt/mods2solr.xsl";
	public static final String RECORD_000332 = "xml/copyright_extraction/000332.tif.xml"; //Updated version
	
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
	}
	
	@AfterAll
	public static void tearDown() throws Exception {
		coreContainer.shutdown();
		embeddedServer.close();
	}

	@BeforeEach
	public void deleteDocs() throws Exception {
		embeddedServer.deleteByQuery("*:*");
	}

	/*
	 * Basic test. Add 10 documents with ID only
	 * 
	 */
	/*
	@Test
	public void testSolrServerIsRunning() throws Exception {

		try {
			for (int i = 0; i < 10; i++) {
				SolrInputDocument document = new SolrInputDocument();
				String id = "id" + i;
				document.addField("id", id);
				embeddedServer.add(document);

			}
			embeddedServer.commit();

			assertEquals(10L, getNumberOfTotalDocuments());

		} catch (Exception e) {
			e.printStackTrace();
			fail("Error indexing 10 test documents only with id field");
		}

	}
	*/
	 
   
    @Test
    void testRecord000332() throws Exception {
            
    	String solrString = TestUtil.getTransformedWithAccessFieldsAdded(MODS2SOLR, RECORD_000332);
        
        Gson gson = new GsonBuilder().setPrettyPrinting().create();
        JsonElement je = JsonParser.parseString(solrString);
        String prettyJsonString = gson.toJson(je);
         //System.out.println(prettyJsonString);
        
        SolrInputDocument document = convertJsonToSolrJavaDoc(prettyJsonString);
        embeddedServer.add(document);
        embeddedServer.commit();                
        assertEquals(1, getNumberOfTotalDocuments());
        
        
        //Full life cycle test
        //Hej Victor. Her kan du teste at felterne også er kommet korrekt ud af Solr. 
         SolrDocument record = getRecordById("urn:uuid:05fea810-7181-11e0-82d7-002185371280");
         
         //Single value field
         assertEquals("000332.tif",record.getFieldValue("identifier_local"));
    
         //multivalue field
         Collection<Object> typeResources = record.getFieldValues("type_of_resource");
         assertEquals(2,typeResources.size());
         assertTrue(typeResources.contains("Billede, Todimensionalt billedmateriale"));
         assertTrue(typeResources.contains("Grafik"));
         
    }
    
    /*
     * Embedded solr does not have a http listener, so we can not add call and add documents as JSON.
     * They needs to be converted to SolrInputDocument. This seems to be the simplest way to do it... 
     * Correct me if I am wrong.
     * 
     */
    private  SolrInputDocument convertJsonToSolrJavaDoc(String json) throws Exception{
        
        //Object is string or String[] for multivalued
        Map<String, Object> map = new ObjectMapper().readValue(json, new TypeReference<Map<String, Object>>(){});
        
        SolrInputDocument document = new SolrInputDocument();
        
        for (String key : map.keySet()) {
            //Object can be String or String[]
            Object  value = map.get(key);
            if (value instanceof String) {
                System.out.println("Adding:"+key +"="+map.get(key));
            	document.addField(key, map.get(key));
                                
            }
            else if (value instanceof ArrayList) {
            	for (Object o : (ArrayList<Object>) value) {
                    System.out.println("Adding:"+key +"="+o.toString());
            		document.addField(key, o.toString());
            	}            	
            }            
            else {//sanity check, should not happen         
            	log.error("Unknown json type"+value.getClass());               
            	throw new Exception("Unknown json type"+value.getClass());
            }                                      
        }        
        return document;
    }
    
    
    private SolrDocument getRecordById(String id) throws Exception{	    
           SolrQuery solrQuery = new SolrQuery();
           solrQuery.setQuery("id:\""+id +"\"");
           solrQuery.setRows(10);           
           QueryResponse rsp = embeddedServer.query(solrQuery, METHOD.POST); 
           return rsp.getResults().get(0);           
   	}
    
    
	private long getNumberOfTotalDocuments() throws Exception{
	    
	 // Test number of documents
        SolrQuery solrQuery = new SolrQuery();
        solrQuery.setQuery("*:*");
        solrQuery.setRows(10);
        solrQuery.add("fl", "id");

        QueryResponse rsp = embeddedServer.query(solrQuery, METHOD.POST); 
        return rsp.getResults().getNumFound();
        
	}
    
	

}
