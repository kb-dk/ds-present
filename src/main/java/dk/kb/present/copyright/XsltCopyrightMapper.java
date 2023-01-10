package dk.kb.present.copyright;

import java.util.HashMap;

public class XsltCopyrightMapper {
    
    
    public static final String ACCESS_BLOKKERET_FIELD="access_blokkeret";
    public static final String ACCESS_NOTE_FIELD="access_note";
    public static final String ACCESS_SKABELSESAAR_FIELD="access_skabelsesaar";
    public static final String ACCESS_OPHAVSPERSON_DOEDSAAR_FIELD="access_ophavsperson_doedsaar";
    public static final String ACCESS_SEARLIGE_VISNINGSVILKAAR_FIELD="access_searlige_visningsvilkaar";
    public static final String ACCESS_MATERIALE_TYPE="access_materiale_type";
    
    public static HashMap<String,String> xsltCopyrightTransformer(String modMedsXML) throws Exception{
                        
        HashMap<String,String> solrFieldsMap = new HashMap<String,String>(); 
        
        CopyrightAccessDto copyrightAccessDto = CopyrightAccessExtractor.extractCopyrightFields(modMedsXML);
        CopyrightAccessDto2SolrFieldsMapper mapper= new CopyrightAccessDto2SolrFieldsMapper(copyrightAccessDto);
        
        //Above has all as a DTO with setter and getter. But the XSLT wants a map
        solrFieldsMap.put(ACCESS_BLOKKERET_FIELD,""+mapper.isBlokeret());
        solrFieldsMap.put(ACCESS_NOTE_FIELD,mapper.getAccessNote());                               
        
        if (copyrightAccessDto.getOphavsPersonDoedsAar() != null) {
            solrFieldsMap.put(ACCESS_OPHAVSPERSON_DOEDSAAR_FIELD,copyrightAccessDto.getOphavsPersonDoedsAar());    
        }
        
        solrFieldsMap.put(ACCESS_SKABELSESAAR_FIELD,""+copyrightAccessDto.getSkabelsesAar());        
        
        solrFieldsMap.put(ACCESS_SEARLIGE_VISNINGSVILKAAR_FIELD,""); //TODO boooleans
        solrFieldsMap.put(ACCESS_MATERIALE_TYPE,mapper.getMaterialeType());
        
        if (copyrightAccessDto.getImageUrl() != null) {
          solrFieldsMap.put("imageurl",mapper.getImageUrl());
        }
        
        return solrFieldsMap;
    }

}
