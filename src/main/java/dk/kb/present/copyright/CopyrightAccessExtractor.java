package dk.kb.present.copyright;

import dk.kb.present.copyright.CopyrightAccessDto.AccessCondition;
import dk.kb.present.copyright.CopyrightAccessDto.CreatorCorporate;
import dk.kb.present.copyright.CopyrightAccessDto.CreatorPerson;
import dk.kb.util.webservice.exception.InvalidArgumentServiceException;
import dk.kb.util.xml.XMLEscapeSanitiser;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.Node;
import org.w3c.dom.NodeList;
import org.xml.sax.InputSource;

import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import java.io.StringReader;
import java.util.ArrayList;
import java.util.Locale;
import java.util.Set;

/**
 * CopyrightAccessExtractor reads the XML (Mods/Meds) in the preservation format at kb.dk for the Cumulus records.
 * Originally all information for copyright logic was supposed to be in the AccessCondition tags of the record. 
 * But this has shown not to be sufficient information and too hard to make sufficient. So now this class
 * also reads other XML fields required to deduce the various copyright statuses of the records.
 * 
 * The output of this class in used to enrich the solr-documents with additional fields about copyright statuses.
 *  
 * This document is the bible for what is going on:
 * https://kbintern.sharepoint.com/:w:/r/sites/Proj-KULA-186-Digitale-samlinger-Amanda-Britta/_layouts/15/Doc.aspx?action=edit&sourcedoc=%7B915b7ba6-eeae-4636-b04c-472b83aa81f6%7D&wdOrigin=TEAMS-ELECTRON.teamsSdk.openFilePreview&wdExp=TEAMS-CONTROL&web=1&cid=5b8502b8-d6cc-4d97-8191-7f3abe6e3c5b
 * This should be the newest version and is stil not finished. (materiel type logic missing)
 * The version used to implement this class can be found in the /doc folder in the project
 * 
 */
public class CopyrightAccessExtractor {

	private static final Logger log = LoggerFactory.getLogger(CopyrightAccessExtractor.class);


	
	//Lowercase important    
    private static final Set<String> FOTOGRAFI_AFTALE = Set.of("dia", "digital optagelse", "fotografi", "fotogravure", "negativ");
 
	//Lowercase important
	private static final Set<String> BILLEDE_AFTALE = Set.of("akvarel", "grafik", "postkort", "plakats","tegning","tryk","silhuet",
                                              "arkitekturfotografi","arkitekturtegning","anskuelsesbillede","genstand",
                                              "bladtegning","kort","atlas","prospekt");
                                              

	
	public static CopyrightAccessDto buildCopyrightFields(String xml) throws Exception {

		if (xml == null) {
			throw new Exception("XML is null");
		}


		CopyrightAccessDto copyrightDto= new CopyrightAccessDto();

		Document document = createDocFromXml(xml);

		String fileName = getFileName(document); //used as parameter to methods for log statement        
        copyrightDto.setFilNavn(fileName);
		
        
        String materialeType=getMaterialType(document);
		copyrightDto.setMaterialeType(getMaterialType(document));
		
		copyrightDto.setBilledeAftale(isBilledeAftale(materialeType));
		copyrightDto.setFotoAftale(isFotoAftale(materialeType));
		
		
		//TEMORARY SOLUTION TO SET IMAGE LINK!
		copyrightDto.setImageUrl(getImageLink(document));

		NodeList nList = document.getElementsByTagName("mets:rightsMD");
		if (nList.getLength()==0) {
			//log.info("No rightsMD found"); //This is not an error anymore
			copyrightDto.setAccessConditionsList(new ArrayList<AccessCondition>()); //Set empty list
			return copyrightDto;
		}

		String version=nList.item(0).getAttributes().getNamedItem("ID").getNodeValue();
		if (!"ModsRights1".equals(version)) { //Failed hard if we are not parsing the implemented version
			throw new InvalidArgumentServiceException("'Mets:rightsMD' Version not supported:"+version);          
		}

		Element rightsMD = (Element) nList.item(0);

		NodeList accessConditions = rightsMD.getElementsByTagName("mods:accessCondition");        
		ArrayList<AccessCondition> accessConditionList = buildAccessConditions(accessConditions);
		copyrightDto.setAccessConditionsList(accessConditionList);        


		Integer lastDeathYearForPerson = getLastDeathYearForPerson(accessConditionList,fileName);
		if (lastDeathYearForPerson !=  null) {
			copyrightDto.setOphavsPersonDoedsAar(lastDeathYearForPerson);;
		}
		
					
		Integer skabelsesAar = getSkabelsesAar(document,fileName);
		if (skabelsesAar != null) {
			 copyrightDto.setSkabelsesAar(skabelsesAar);
		}
		 
		
		return  copyrightDto;
	}


	/**
	 * Maps the accessConditions tags (there can be multiple) to a java DTO.
	 * There is much cross-logic involved and having them as a java DTO makes code easier.
	 * It also makes unittests easier so you can construct them an test the business logic,
	 * instead of your XML-writing skills.   
	 *   
	 */
	public static ArrayList<AccessCondition> buildAccessConditions(  NodeList accessCondititions){       
		ArrayList<AccessCondition> accessConditionList = new  ArrayList<AccessCondition>();
		for (int i =0;i<accessCondititions.getLength();i++) {

			AccessCondition accessCondition = new CopyrightAccessDto().new AccessCondition();
			Element accessConditionElement = (Element) accessCondititions.item(i);

			Node typeNode = accessConditionElement.getAttributes().getNamedItem("type");
			if (typeNode != null) {
				accessCondition.setType(typeNode.getNodeValue());     
			}

			Node displayNode = accessConditionElement.getAttributes().getNamedItem("displayLabel");
			if (displayNode != null) {
				accessCondition.setDisplayLabel(displayNode.getNodeValue());                
			}

			NodeList copyrightList = accessConditionElement.getElementsByTagName("cdl:copyright");  


			if (copyrightList.getLength()==0) { //Text!               
				String accessContentText= accessConditionElement.getTextContent();
				if (accessContentText != null) {
					accessContentText=accessContentText.trim();
				}
				accessCondition.setValue(accessContentText);                
			}            
			if (copyrightList.getLength() ==1) { //XML      
				String publication_status = copyrightList.item(0).getAttributes().getNamedItem("publication.status").getNodeValue();
				String copyright_status = copyrightList.item(0).getAttributes().getNamedItem("copyright.status").getNodeValue();
				accessCondition.setCopyrightPublicationStatus(publication_status);
				accessCondition.setCopyrightStatus(copyright_status);
			}
			else if (copyrightList.getLength() >1) { //TODO deleted later. Just sanity check for new
				throw new InvalidArgumentServiceException("UPS... Need to handle multiple elements for 'cdl:copyright'");
			}


			//Can be empty list
			ArrayList<CreatorPerson> creatorPersons = buildPersons(accessConditionElement);
			accessCondition.setCreatorPersonList(creatorPersons);

			//Can be empty list
			ArrayList<CreatorCorporate> creatorCorporate = buildCooperate(accessConditionElement);

			accessCondition.setCreatorCorporateList(creatorCorporate);

			accessConditionList.add(accessCondition);                     
		}

		return accessConditionList ;
	}

	/*
   <cdl:creator.person>
     <cdl:name>Clemens, Johann Friderich</cdl:name>
     <cdl:year.birth>1748-11-29</cdl:year.birth>
     <cdl:year.death>1831-11-5</cdl:year.death>
   </cdl:creator.person>        
	 */     
	public static ArrayList<CreatorPerson> buildPersons( Element accessConditionElement){       
		ArrayList<CreatorPerson> personList = new  ArrayList<CreatorPerson>();

		NodeList creatorPerson = accessConditionElement.getElementsByTagName("cdl:creator.person");
		if (creatorPerson == null) {
			return personList;
		}

		for (int i =0;i<creatorPerson.getLength();i++) {
			CreatorPerson person=new CopyrightAccessDto().new CreatorPerson();

			Element creatorElement = (Element) creatorPerson.item(i);

			if (creatorElement.getElementsByTagName("cdl:name").getLength() >0) {
				String personName= creatorElement.getElementsByTagName("cdl:name").item(0).getTextContent();                    
				person.setName(personName);                    
			}

			if (creatorElement.getElementsByTagName("cdl:year.birth").getLength() >0) {
				String personYearBirth= creatorElement.getElementsByTagName("cdl:year.birth").item(0).getTextContent();
				person.setYearBirth(personYearBirth);                    

			}

			if (creatorElement.getElementsByTagName("cdl:year.death").getLength() >0) {
				String personYearDeath= creatorElement.getElementsByTagName("cdl:year.death").item(0).getTextContent();                    
				person.setYearDeath(personYearDeath);
			}
			personList.add(person);

		}
		return personList;
	}

	/*
  <cdl:creator>
    <dk:creator.corporate>
      <cdl:name>Em. Bærentzen &amp; Co. lith. Inst.</cdl:name>
      <dk:year.started>1837</dk:year.started>
      <dk:year.ended>1874</dk:year.ended>
    </dk:creator.corporate>
  </cdl:creator>
	 */     
	public static ArrayList<CreatorCorporate> buildCooperate( Element accessConditionElement){       
		ArrayList<CreatorCorporate> cooperateList = new  ArrayList<CreatorCorporate>();

		NodeList creatorCorporate = accessConditionElement.getElementsByTagName("dk:creator.corporate");

		if (creatorCorporate == null) {
			return cooperateList;
		}

		for (int i =0;i<creatorCorporate.getLength();i++) {
			CreatorCorporate coorporate=new CopyrightAccessDto().new CreatorCorporate();
			Element creatorElement = (Element) creatorCorporate.item(i);

			String name= creatorElement.getElementsByTagName("cdl:name").item(0).getTextContent();
			coorporate.setName(name);

			NodeList yearStartedNode = creatorElement.getElementsByTagName("dk:year.started");
			NodeList yearEndedNode = creatorElement.getElementsByTagName("dk:year.ended");

			if (yearStartedNode.getLength() >0  ){
				String yearStarted= yearStartedNode.item(0).getTextContent();                         
				coorporate.setYearStarted(yearStarted);
			}
			if (yearEndedNode.getLength() > 0){
				String yearEnded= yearEndedNode.item(0).getTextContent();                         
				coorporate.setYearEnded(yearEnded);
			}                                  

			cooperateList.add(coorporate);
		}        
		return cooperateList;
	}

	public static  Document createDocFromXml(String xml) throws Exception{

		//System.out.println(response);
		DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
		DocumentBuilder builder = factory.newDocumentBuilder();

		XMLEscapeSanitiser sanitiser = new XMLEscapeSanitiser(""); //Do not replace with anything
		String responseSanitized  =  sanitiser.apply(xml);

		Document document = null;
		try {
			document = builder.parse(new InputSource(new StringReader(responseSanitized)));
			document.getDocumentElement().normalize();
		}
		catch(Exception e) {                       
			log.error("Invalid XML",e);                                                
			throw new Exception("invalid xml",e);            

		}

		return document;
	}

	

    private static boolean isFotoAftale(String materialeType) {
        return FOTOGRAFI_AFTALE.contains(materialeType.toLowerCase(Locale.getDefault()));      
    }
    
    private static boolean isBilledeAftale(String materialeType) {
        return BILLEDE_AFTALE.contains(materialeType.toLowerCase(Locale.getDefault()));        
    }

	/**
	 *  This is a temporary fix to enrich copyright data with image link also.
	 *  It is not even sure this is the right way to extract the image link.
	 *  The long term solution would be to have the XSLT do this, though it is not a simple mapping.
	 *  Even better have the meds/mod have a field that makes it easy to get the image link (presentation copy of link)
	 * 
	 * 
	 */    
	private static String getImageLink(Document doc) {
		NodeList identifiers = doc.getElementsByTagName("mods:identifier");
		for (int i =0;i<identifiers.getLength();i++) {

			Element e = (Element) identifiers.item(i);        
			String type= e.getAttribute("type");

			if ("Asset Reference".equals(type)) {
				String ref = e.getTextContent();

				ref = ref.replaceAll("cumulus-core-01:/Depot", "");
				ref = ref.replaceAll(".tif", "");

				//http://kb-images.kb.dk/?FIF=/DAMJP2/DAM/Samlingsbilleder/0000/388/116/DT005031
				//Add last parameters such as size and format: 
				//http://kb-images.kb.dk/?FIF=/DAMJP2/DAM/Samlingsbilleder/0000/388/116/DT005031&CVT=jpeg
				//String link = "http://kb-images.kb.dk/?FIF=/DAMJP2"+ref;   //Direct call             
				String link = "http://devel11:10001/ds-image/v1/IIP/?FIF=/DAMJP2/"+ref;   //ds-image searcher                              
				return link;                
			}
		}
		return null;
	}


	// See documentation. Can be these different fields, one MUST always be there IF person.death was not found	
	
	//<mods:dateCreated>1868</mods:dateCreated>  (notice no point attibute)
	//<mods:dateCreated point="end">1900</mods:dateCreated> 
	//<mods:dateCaptured>2014-04-04T11:52:16.000+02:00</mods:dateCaptured> 

	private static Integer getSkabelsesAar(Document doc,String fileName) throws Exception{

		NodeList dateCreated= doc.getElementsByTagName("mods:dateCreated");

		for (int i =0;i<dateCreated.getLength();i++) {

			Element e = (Element) dateCreated.item(i);        
			String point= e.getAttribute("point");
			if (point == null || "".equals(point)){
				String unknownDateFormat=e.getTextContent();
				//Skabelsesår (dataformat: YYYY, YYYY-MM eller YYYY-MM-DD (til nøds YYYY.MM.DD)), men læser kun de YYYY.                
				//bemærk der altid tages de 4 første
				// 
				if (unknownDateFormat.toLowerCase(Locale.getDefault()).indexOf("ubekendt") == -1) { //can be "Ubekendt" or a dato. Skip if "Ubekendt"
					try {
						return Integer.parseInt(unknownDateFormat.substring(0,4));
					}
					catch(Exception ex) {
						log.error("Error pasing dateCreated:"+unknownDateFormat +" for fileName:"+fileName);
					}

				}
			}
			else if ("end".equals(point)) {
			    try {
			        int year=Integer.parseInt(e.getTextContent());
			        return year;
			    }
			    catch(Exception ex) {
			        log.debug("Error parsing year from dateCreated:"+e.getTextContent() +" for record:"+fileName);
			        return 9999;
			    }
				
			}                                        

		}

		NodeList dateCaptured = doc.getElementsByTagName("mods:dateCaptured");                                

		Element e = (Element)  dateCaptured .item(0);               
		if (e == null) {           
			return null;
		}
		return Integer.parseInt(e.getTextContent().substring(0,4));                                               
	}

	/* Find person with most recent death year. Return null if just one person  is not dead.   
	 * Also return null if no persons is found
	 * Notice last name logic is no longer in use!
	 */       
	private static Integer getLastDeathYearForPerson(ArrayList<AccessCondition> accessConditionList, String fileName) {

		Integer highestYear = null;
		for (AccessCondition ac: accessConditionList) {

			for (CreatorPerson p : ac.getCreatorPersonList()) {
				Integer year= extractYear(p.getYearDeath(),fileName);
				//System.out.println("parsed year:"+year);
				if (year == null) {
					return null;// I am not quite dead yet!
				}

				if  (highestYear==null || year > highestYear) {
					highestYear=year;
				}
			}
		}                
		return highestYear;
	}


	/*
	 * Always assume first 4 letters are year.
	 *       
	 * Format can me 
	 * YYYY or YYYY-M-DD or  YYYY-MM-DD or...
	 * 
	 */
	private static  Integer extractYear(String yearString, String fileName) {
		if (yearString==null || yearString.length() <4) {            
			return null;
		}

		try {
			int year = Integer.parseInt(yearString.substring(0,4));
			return year;
		}
		catch(Exception e) {
			log.warn("Could not parse year from:"+yearString +" from record:"+fileName);
			return 9999; // Set a default that is safe when there is a date field, but it can not be parsed.
		}                        
	}


	private static String getMaterialType(Document doc) {
		NodeList types = doc.getElementsByTagName("mods:typeOfResource");
		for (int i =0;i<types.getLength();i++) {

			Element e = (Element) types.item(i);        
			String type= e.getAttribute("displayLabel");    
			if ("Resource Description".equals(type)) { 
				String ref = e.getTextContent();                
				return ref;                
			}
		}		
		
	   String fileName = getFileName(doc);
	   log.warn("No material type found for file:"+fileName);			
		
		
		return "Ukendt";         
	}    

	//           <mods:identifier type="local">DT006526.tif</mods:identifier>
	private static String getFileName(Document doc) {

		NodeList identifiers = doc.getElementsByTagName("mods:identifier");
		for (int i =0;i<identifiers.getLength();i++) {

			Element e = (Element) identifiers.item(i);        
			String type= e.getAttribute("type");

			if ("local".equals(type)) {
				String id = e.getTextContent();
				return id;
			}
		}
		log.error("No identificer with attribute type='local' found");            	
		return null;
	}

	
}
