<?xml version="1.0" encoding="UTF-8" ?>
<!-- When changes are made to this XSLT, please update the general description of the mapping which is available
     in the file: src/main/webapp/mappings_radiotv.html  -->
<xsl:transform xmlns:f="http://www.w3.org/2005/xpath-functions"
               xmlns:map="http://www.w3.org/2005/xpath-functions/map"
               xmlns:array="http://www.w3.org/2005/xpath-functions/array"
               xmlns:h="http://www.w3.org/1999/xhtml"
               xmlns:xs="http://www.w3.org/2001/XMLSchema"
               xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
               xmlns:my="urn:my"
               xmlns:err="http://www.w3.org/2005/xqt-errors"
               version="3.0">
  
  <xsl:output method="text" />
  <xsl:param name="schemaorgjson"/>
  <xsl:include href="xslt/utils.xsl"/>

  <!--Saves the input JSON as an XDM object. -->
  <xsl:variable name="schemaorg-xml" as="item()*">
    <xsl:copy-of select="f:parse-json($schemaorgjson)"/>
  </xsl:variable>

  <!--Extract the array of identifiers to a variable, where the individual maps can be accessed. -->
  <xsl:variable name="identifers" as="item()*">
    <xsl:copy-of select="array:flatten($schemaorg-xml('identifier'))"/>
  </xsl:variable>

  <xsl:template name="initial-template" match="/">
    <xsl:variable name="solrjson">


      <f:map>
        <f:string key="resource_description">
          <xsl:value-of select="$schemaorg-xml('@type')"/>
        </f:string>
        <!--Simple ID extraction -->
        <f:string key="id">
          <xsl:value-of select="$schemaorg-xml('id')"/>
        </f:string>

        <xsl:choose>
          <!--Check if an error has occurred in hte previous transformer. Otherwise, continue with this transformation -->
          <xsl:when test="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:transformation_error') = 'true'">
            <xsl:for-each select="$identifers">
              <xsl:if test="map:get(., 'PropertyID') = 'Origin'">
                <f:string key="origin">
                  <xsl:value-of select="map:get(., 'value')"/>
                </f:string>
              </xsl:if>
            </xsl:for-each>

            <f:string key="internal_transformation_error">
              <xsl:value-of select="f:true()"/>
            </f:string>
            <f:string key="internal_transformation_error_description">
              <xsl:value-of select="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal',
                                                                'kb:transformation_error_description')"/>
            </f:string>
          </xsl:when>
          <xsl:otherwise>
            <xsl:try>
              <!-- Calls the main template which handles transformation between schemaorg and solr -->
              <xsl:call-template name="schemaorgToSolr"/>

              <!-- Handles all types of errors.-->
              <xsl:catch errors="*">
                <xsl:for-each select="$identifers">
                  <xsl:if test="map:get(., 'PropertyID') = 'Origin'">
                    <f:string key="origin">
                      <xsl:value-of select="map:get(., 'value')"/>
                    </f:string>
                  </xsl:if>
                </xsl:for-each>
                <f:string key="internal_transformation_error">
                  <xsl:value-of select="f:true()"/>
                </f:string>
                <f:string key="internal_transformation_error_description">
                  <xsl:value-of select="concat($err:code, ': ', $err:description)"/>
                </f:string>
              </xsl:catch>
            </xsl:try>
          </xsl:otherwise>
        </xsl:choose>
      </f:map>
    </xsl:variable>

    <xsl:value-of select="f:xml-to-json($solrjson)"/>
  </xsl:template>

  <!--TEMPLATE FOR CONVERTING SCHEMAORG JSON TO SOLR DOCUMENTS.-->
  <xsl:template name="schemaorgToSolr">
    <!-- THIS IS THE BIGGEST AND BADDEST HACK IN TOWN! TO MAKE TEST METHODS AND XSLTS PRETTY AND MANAGEABLE,
                 WE SHOULD REALLY IMPLEMENT THIS SCHEMA2SOLR TRANSFORMATION FOR MODS RESOURCES AS WELL. CURRENTLY, THIS
                 BRANCH CAN'T GENERATE ANY SOLR-DOCUMENTS FOR MODS RECORDS, WHICH SHOULD BE DO-ABLE. -->
    <xsl:if test="contains(map:get($schemaorg-xml,'@type'), 'VideoObject') or
                          contains(map:get($schemaorg-xml,'@type'), 'AudioObject') or
                          contains(map:get($schemaorg-xml,'@type'), 'MediaObject')">

      <xsl:if test="f:exists($schemaorg-xml('keywords'))">
        <!--Save categories to a variable as a sequence. -->
        <xsl:variable name="categories" as="item()*" select="tokenize($schemaorg-xml('keywords'), ',')"/>
        <!--Create array of categories, which fits with the multivalued solr field -->
        <f:array key="categories">
          <xsl:for-each select="$categories">
            <f:string><xsl:value-of select="normalize-space(.)"/></f:string>
          </xsl:for-each>
        </f:array>

        <f:string key="categories_count">
          <xsl:value-of select="f:count($categories)"/>
        </f:string>
      </xsl:if>

      <!-- Extract collection-->
      <xsl:if test="exists($schemaorg-xml('isPartOf'))">
        <!-- Variable to find collections in. -->
        <xsl:variable name="isPartOf" as="item()*">
          <xsl:copy-of select="array:flatten($schemaorg-xml('isPartOf'))"/>
        </xsl:variable>

        <xsl:for-each select="$isPartOf">
          <xsl:if test="map:get(., '@type') = 'Collection'">
            <f:string key="collection">
              <xsl:value-of select="map:get(., 'name')"/>
            </f:string>
          </xsl:if>
        </xsl:for-each>

      </xsl:if>

      <!-- Extract main genre -->
      <xsl:if test="$schemaorg-xml('genre')">
        <f:string key="genre">
          <xsl:value-of select="$schemaorg-xml('genre')"/>
        </f:string>
      </xsl:if>

      <!-- extract title-->
      <xsl:if test="$schemaorg-xml('name')">
        <xsl:variable name="title">
          <xsl:value-of select="$schemaorg-xml('name')"/>
        </xsl:variable>
        <f:string key="title">
          <xsl:value-of select="$title"/>
        </f:string>

        <f:string key="title_sort_da">
          <xsl:value-of select="$title"/>
        </f:string>
        <f:string key="title_length">
          <xsl:value-of select="f:string-length($title)"/>
        </f:string>
      </xsl:if>

      <!-- extract alternate title-->
      <xsl:if test="$schemaorg-xml('alternateName')">
        <f:string key="original_title">
          <xsl:value-of select="$schemaorg-xml('alternateName')"/>
        </f:string>
      </xsl:if>

      <!-- Extract actors and characters is present.-->
      <xsl:if test="f:exists($schemaorg-xml('actor'))">
        <xsl:variable name="actors" as="item()*">
          <xsl:copy-of select="array:flatten($schemaorg-xml('actor'))"/>
        </xsl:variable>

        <!-- Extract actor names from nested map-->
        <f:array key="actor">
          <xsl:for-each select="$actors">
            <f:string><xsl:value-of select="my:getNestedMapValue2Levels(., 'actor', 'name')"/></f:string>
          </xsl:for-each>
        </f:array>

        <f:string key="actor_count">
          <xsl:value-of select="f:count($actors)"/>
        </f:string>

        <!-- Here we need to know if the value 'characterName' is present somewhere in the nested map. I dont know of anyway else of checking this than through a variable
        getting populated true strings that we then can do an if-lookup on. -->
        <xsl:variable name="characters" as="item()*">
          <xsl:for-each select="$actors">
            <xsl:if test="map:get(., 'characterName')">
              <xsl:value-of select="map:get(., 'characterName')"/>
            </xsl:if>
          </xsl:for-each>
        </xsl:variable>

        <!-- Get character names from map if they are present.-->
        <xsl:if test="not(f:empty($characters))">
          <f:array key="character">
            <xsl:for-each select="$characters">
                <f:string>
                  <xsl:value-of select="."/>
                </f:string>
            </xsl:for-each>
          </f:array>

          <f:string key="character_count">
            <xsl:value-of select="f:count($characters)"/>
          </f:string>
        </xsl:if>
      </xsl:if>

      <!-- Extract contributors from schema.org json -->
      <xsl:if test="f:exists($schemaorg-xml('contributor'))">
        <xsl:variable name="contributors" as="item()*">
          <xsl:copy-of select="array:flatten($schemaorg-xml('contributor'))"/>
        </xsl:variable>

        <f:array key="contributor">
          <xsl:for-each select="$contributors">
            <f:string>
              <xsl:value-of select="map:get(., 'name')"/>
            </f:string>
          </xsl:for-each>
        </f:array>

        <f:string key="contributor_count">
          <xsl:value-of select="f:count($contributors)"/>
        </f:string>
      </xsl:if>

      <!-- Extract director from schema.org json -->
      <xsl:if test="f:exists($schemaorg-xml('director'))">
        <xsl:variable name="directors" as="item()*">
          <xsl:copy-of select="array:flatten($schemaorg-xml('director'))"/>
        </xsl:variable>

        <f:array key="director">
          <xsl:for-each select="$directors">
            <f:string>
              <xsl:value-of select="map:get(., 'name')"/>
            </f:string>
          </xsl:for-each>
        </f:array>

        <f:string key="director_count">
          <xsl:value-of select="f:count($directors)"/>
        </f:string>
      </xsl:if>

     <!-- Extracts creators from the array of creators present in the creator value from schema.org-->
      <xsl:if test="f:exists($schemaorg-xml('creator'))">
        <xsl:variable name="creators" as="item()*">
          <xsl:copy-of select="array:flatten($schemaorg-xml('creator'))"/>
        </xsl:variable>

        <!-- Reusing the field 'creator' here as us used for images as well. -->
        <f:array key="creator">
          <xsl:for-each select="$creators">
            <f:string>
              <xsl:value-of select="map:get(., 'name')"/>
            </f:string>
          </xsl:for-each>
        </f:array>

        <!-- Creator_count field -->
        <f:string key="creator_count">
          <xsl:value-of select="f:count($creators)"/>
        </f:string>
      </xsl:if>

      <!-- Extract the creater affiliation. Two fields are required here as creator_affiliation can change over time.
           Therefore, we are also extracting the creator_affiliation_generic which contains the same value for e.g.
           DR P1 from 1960 'program 1' and 2000's 'P1'. Here the value would be drp1. -->
      <xsl:if test="f:exists(map:get($schemaorg-xml, 'publication'))">
        <xsl:if test="f:exists(my:getNestedMapValue2Levels($schemaorg-xml, 'publication','publishedOn'))">

          <xsl:if test="not(f:empty(my:getNestedMapValue3Levels($schemaorg-xml, 'publication', 'publishedOn',  'broadcastDisplayName'))) and
                        my:getNestedMapValue3Levels($schemaorg-xml, 'publication', 'publishedOn',  'broadcastDisplayName') != ''">

            <xsl:variable name="creatorAffiliation">
              <xsl:value-of select="my:getNestedMapValue3Levels($schemaorg-xml, 'publication', 'publishedOn',  'broadcastDisplayName')"/>
            </xsl:variable>
            <f:string key="creator_affiliation">
              <xsl:value-of select="$creatorAffiliation"/>
            </f:string>
            <f:string key="creator_affiliation_length">
              <xsl:value-of select="f:string-length($creatorAffiliation)"/>
            </f:string>
          </xsl:if>

          <xsl:if test="not(empty(my:getNestedMapValue3Levels($schemaorg-xml, 'publication', 'publishedOn', 'alternateName'))) and
                        my:getNestedMapValue3Levels($schemaorg-xml, 'publication', 'publishedOn', 'alternateName') != ''">
            <xsl:variable name="genericAffiliation">
              <xsl:value-of select="my:getNestedMapValue3Levels($schemaorg-xml, 'publication', 'publishedOn', 'alternateName')"/>
            </xsl:variable>
            <f:string key="creator_affiliation_facet">
              <xsl:value-of select="upper-case($genericAffiliation)"/>
            </f:string>
            <f:string key="creator_affiliation_generic">
              <xsl:value-of select="$genericAffiliation"/>
            </f:string>
            <f:string key="creator_affiliation_generic_length">
              <xsl:value-of select="f:string-length($genericAffiliation)"/>
            </f:string>
            <f:string key="creator_affiliation_generic_count">
              <xsl:value-of select="f:count($genericAffiliation)"/>
            </f:string>
          </xsl:if>

          <xsl:if test="my:getNestedMapValue4Levels($schemaorg-xml, 'publication',
                                                    'publishedOn', 'broadcaster', 'legalName') != ''">
            <f:string key="broadcaster">
              <xsl:value-of select="my:getNestedMapValue4Levels($schemaorg-xml, 'publication',
                                                              'publishedOn', 'broadcaster', 'legalName')"/>
            </f:string>
          </xsl:if>
        </xsl:if>
      </xsl:if>

      <!-- Extract file_id -->
      <xsl:if test="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:file_id') != ''">
        <f:string key="file_id">
          <xsl:value-of select="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:file_id') "/>
        </f:string>
      </xsl:if>

      <xsl:if test="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:file_path') != ''">
        <f:string key="file_path">
          <xsl:value-of select="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:file_path') "/>
        </f:string>
      </xsl:if>


      <!-- Extract data on the encoded creative work, if present-->
      <xsl:if test="map:contains($schemaorg-xml, 'encodesCreativeWork')">
        <!-- extract episode titel -->
        <xsl:if test="exists($schemaorg-xml('encodesCreativeWork')('name'))">
          <f:string key="episode_title">
            <xsl:value-of select="$schemaorg-xml('encodesCreativeWork')('name')"/>
          </f:string>
        </xsl:if>

        <!-- Extract episode number -->
        <xsl:if test="$schemaorg-xml('encodesCreativeWork')('episodeNumber')">
          <f:string key="episode">
            <xsl:value-of select="$schemaorg-xml('encodesCreativeWork')('episodeNumber')"/>
          </f:string>
        </xsl:if>

        <!-- Quite nested structure here. We already know that the map encodesCreativeWork exists, now we are checking
             for the submap partOfSeason and when that exists, we know that the numberOfEpisodes is present, as this
             field is creating the map partOfSeason. -->
        <!-- Extract number of episodes-->
        <xsl:if test="map:contains($schemaorg-xml('encodesCreativeWork'), 'partOfSeason')">
          <f:string key="number_of_episodes">
            <xsl:value-of select="$schemaorg-xml('encodesCreativeWork')('partOfSeason')('numberOfEpisodes')"/>
          </f:string>
        </xsl:if>
      </xsl:if>

      <!-- Extraction of ownprocution related fields. -->
      <xsl:if test="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:production_code_allowed') != ''">
        <f:string key="production_code_allowed">
          <xsl:value-of select="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:production_code_allowed')"/>
        </f:string>
      </xsl:if>
      <xsl:if test="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:production_code_value') != ''">
        <f:string key="production_code_value">
          <xsl:value-of select="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:production_code_value')"/>
        </f:string>
      </xsl:if>

      <!-- Extraction of holdback related fields. -->
      <xsl:if test="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:holdback_name') != ''">
        <f:string key="holdback_name">
          <xsl:value-of select="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:holdback_name')"/>
        </f:string>
      </xsl:if>
      <xsl:if test="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:holdback_date') != ''">
        <f:string key="holdback_expired_date">
          <xsl:value-of select="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:holdback_date')"/>
        </f:string>
      </xsl:if>
      <xsl:if test="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:holdback_form_value') != ''">
        <f:string key="holdback_form_value">
          <xsl:value-of select="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:holdback_form_value')"/>
        </f:string>
      </xsl:if>
      <xsl:if test="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:holdback_content_value') != ''">
        <f:string key="holdback_content_value">
          <xsl:value-of select="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:holdback_content_value')"/>
        </f:string>
      </xsl:if>


      <!-- If statement creating all fields related to the schema.org value startTime -->
      <xsl:if test="$schemaorg-xml('startTime')">
        <xsl:variable name="startTimeZulu" as="xs:dateTime">
          <xsl:value-of select="$schemaorg-xml('startTime')"/>
        </xsl:variable>

        <!-- Using danish "normal time" which is the european winter time for timezone GMT+1 -->
        <xsl:variable name="startTimeDK" as="xs:dateTime">
          <!--<xsl:value-of select="f:adjust-dateTime-to-timezone($startTimeZulu, xs:dayTimeDuration('PT1H'))"/>-->
          <xsl:value-of select="format-dateTime($startTimeZulu, '[Y0001]-[M01]-[D01]T[H01]:[m01]:[s01]', (), (), 'Europe/Copenhagen')"/>
        </xsl:variable>
        
        <f:string key="startTime">
          <xsl:value-of select="$schemaorg-xml('startTime')"/>
        </f:string>

        <!-- Extracts the time from the datetime variable in danish normal time. -->
        <xsl:variable name="temporal_start_time_da_string">
          <xsl:value-of select="xs:string(xs:time($startTimeDK))"/>
        </xsl:variable>

        <!-- The string value of the danish time. -->
        <f:string key="temporal_start_time_da_string">
          <xsl:value-of select="$temporal_start_time_da_string"/>
        </f:string>

        <!-- The int value of the danish start hour. -->
        <f:string key="temporal_start_hour_da">
          <xsl:value-of select="hours-from-dateTime($startTimeDK)"/>
        </f:string>

        <!-- The string value of the danish date. -->
        <f:string key="temporal_start_date_da_string">
          <xsl:value-of select="xs:string(xs:date($startTimeDK))"/>
        </f:string>

        <!-- Get year from datetime-->
        <f:string key="temporal_start_year">
          <xsl:value-of select="xs:string(f:year-from-dateTime($startTimeDK))"/>
        </f:string>

        <f:string key="temporal_start_month">
          <xsl:value-of select="xs:string(f:month-from-dateTime($startTimeDK))"/>
        </f:string>

        <f:string key="temporal_start_time_da_date">
          <xsl:value-of select="xs:dateTime(concat('9999-01-01T', $temporal_start_time_da_string, 'Z'))"/>
        </f:string>

        <f:string key="temporal_start_day_da">
          <xsl:value-of select="format-dateTime($startTimeDK, '[F]')"/>
        </f:string>
      </xsl:if>

      <!-- If statement creating all fields related to the schema.org value endTime -->
      <xsl:if test="$schemaorg-xml('endTime')">
        <xsl:variable name="endTimeZulu" as="xs:dateTime">
          <xsl:value-of select="$schemaorg-xml('endTime')"/>
        </xsl:variable>

        <!-- Using danish "normal time" which is the european winter time for timezone GMT+1 -->
        <xsl:variable name="endTimeDK" as="xs:dateTime">
          <!--<xsl:value-of select="f:adjust-dateTime-to-timezone($endTimeZulu, xs:dayTimeDuration('PT1H'))"/>-->
          <xsl:value-of select="format-dateTime($endTimeZulu, '[Y0001]-[M01]-[D01]T[H01]:[m01]:[s01]', (), (), 'Europe/Copenhagen')"/>
        </xsl:variable>

        <f:string key="endTime">
          <xsl:value-of select="$schemaorg-xml('endTime')"/>
        </f:string>

        <!-- Extracts the time from the datetime variable in danish normal time. -->
        <xsl:variable name="temporal_end_time_da_string">
          <xsl:value-of select="xs:string(xs:time($endTimeDK))"/>
        </xsl:variable>

        <!-- The string value of the danish time. -->
        <f:string key="temporal_end_time_da_string">
          <xsl:value-of select="$temporal_end_time_da_string"/>
        </f:string>
        <!-- The string value of the danish date. -->
        <f:string key="temporal_end_date_da_string">
          <xsl:value-of select="xs:string(xs:date($endTimeDK))"/>
        </f:string>

        <f:string key="temporal_end_time_da_date">
          <xsl:value-of select="xs:dateTime(concat('9999-01-01T', $temporal_end_time_da_string, 'Z'))"/>
        </f:string>

        <f:string key="temporal_end_day_da">
          <xsl:value-of select="format-dateTime($endTimeDK, '[F]')"/>
        </f:string>
      </xsl:if>

      <!-- Calculate duration from start and end times-->
      <xsl:if test="$schemaorg-xml('duration')">
        <xsl:variable name="startTime">
          <xsl:value-of select="$schemaorg-xml('startTime')"/>
        </xsl:variable>
        <xsl:variable name="endTime">
          <xsl:value-of select="$schemaorg-xml('endTime')"/>
        </xsl:variable>
        <xsl:variable name="durationInMilliseconds">
          <xsl:value-of select="my:toMilliseconds($startTime, $endTime)"/>
        </xsl:variable>
        <f:string key="duration_ms">
          <xsl:value-of select="$durationInMilliseconds"/>
        </f:string>
      </xsl:if>

      <!-- Extract color boolean-->
      <xsl:if test="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:color') != ''">
        <f:string key="color">
          <xsl:value-of select="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:color') "/>
        </f:string>
      </xsl:if>

      <!-- Extract videoQuality -->
      <xsl:if test="$schemaorg-xml('videoQuality')">
        <f:string key="video_quality">
          <xsl:value-of select="$schemaorg-xml('videoQuality')"/>
        </f:string>
      </xsl:if>

      <!-- Extract surround sound-->
      <xsl:if test="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:surround_sound') != ''">
        <f:string key="surround_sound">
          <xsl:value-of select="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:surround_sound')"/>
        </f:string>
      </xsl:if>

      <!-- Extract premiere-->
      <xsl:if test="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:premiere') != ''">
        <f:string key="premiere">
          <xsl:value-of select="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:premiere')"/>
        </f:string>
      </xsl:if>

      <!-- Extract aspect ratio-->
      <xsl:if test="$schemaorg-xml('videoFrameSize')">
        <f:string key="aspect_ratio">
          <xsl:value-of select="$schemaorg-xml('videoFrameSize')"/>
        </f:string>
      </xsl:if>

      <!-- Extract boolean for live broadcast -->
      <xsl:if test="f:exists($schemaorg-xml('publication'))">
        <xsl:if test="f:exists($schemaorg-xml('publication')('isLiveBroadcast'))">
          <f:string key="live_broadcast">
            <xsl:value-of select="$schemaorg-xml('publication')('isLiveBroadcast')"/>
          </f:string>
        </xsl:if>
      </xsl:if>

      <!-- Extract boolean for retransmission -->
      <xsl:if test="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:retransmission') != ''">
        <f:string key="retransmission">
          <xsl:value-of select="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:retransmission')"/>
        </f:string>
      </xsl:if>

      <!-- Extract abstract -->
      <xsl:if test="f:exists($schemaorg-xml('abstract'))">
        <xsl:variable name="abstract">
          <xsl:value-of select="$schemaorg-xml('abstract')"/>
        </xsl:variable>
        <f:string key="abstract">
          <xsl:value-of select="$abstract"/>
        </f:string>
        <f:string key="abstract_length">
          <xsl:value-of select="f:string-length($abstract)"/>
        </f:string>

      </xsl:if>

      <!-- Extract description -->
      <xsl:if test="f:exists($schemaorg-xml('description'))">
        <xsl:variable name="description">
          <xsl:value-of select="$schemaorg-xml('description')"/>
        </xsl:variable>
        <f:string key="description">
          <xsl:value-of select="$description"/>
        </f:string>
        <f:string key="description_length">
          <xsl:value-of select="f:string-length($description)"/>
        </f:string>
      </xsl:if>

      <!-- Extract sub genre -->
      <xsl:if test="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:genre_sub') != '' ">
        <f:string key="genre_sub">
          <xsl:value-of select="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:genre_sub')"/>
        </f:string>
      </xsl:if>

      <!-- Extract boolean for subtitles -->
      <xsl:if test="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:has_subtitles') != ''">
        <f:string key="has_subtitles">
          <xsl:value-of select="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:has_subtitles')"/>
        </f:string>
      </xsl:if>

      <!-- Extract boolean for subtitles for hearing impaired  -->
      <xsl:if test="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal',
                                                        'kb:has_subtitles_for_hearing_impaired') != ''">
        <f:string key="has_subtitles_for_hearing_impaired">
          <xsl:value-of select="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal',
                                                                    'kb:has_subtitles_for_hearing_impaired')"/>
        </f:string>
      </xsl:if>

      <!--For each identifier in the variable $identifiers check for specific properties and map them to their
          respective solr counterpart.-->
      <xsl:for-each select="$identifers">
        <xsl:call-template name="identifierExtractor"/>
      </xsl:for-each>

      <!-- Extract internal fields -->
      <xsl:call-template name="kbInternal">
        <xsl:with-param name="internalMap" select="$schemaorg-xml('kb:internal')"/>
      </xsl:call-template>
    </xsl:if>
  </xsl:template>

  <!-- EXTRACT IDENTIFIERS FROM THE SCHEMA.ORG ARRAY OF IDENTIFIERS. -->
  <xsl:template name="identifierExtractor">
    <!-- Finds KalturaID -->
    <xsl:if test="map:get(., 'PropertyID') = 'KalturaID'">
      <f:string key="kaltura_id">
        <xsl:value-of select="map:get(., 'value')"/>
      </f:string>
    </xsl:if>
    <!-- Finds origin -->
    <xsl:if test="map:get(., 'PropertyID') = 'Origin'">
      <f:string key="origin">
        <xsl:value-of select="map:get(., 'value')"/>
      </f:string>
    </xsl:if>
    <!--Finds Ritzau ID -->
    <xsl:if test="map:get(., 'PropertyID') = 'ritzauId'">
      <f:string key="ritzau_id">
        <xsl:value-of select="map:get(., 'value')"/>
      </f:string>
    </xsl:if>
    <!-- Finds tvmeter id-->
    <xsl:if test="map:get(., 'PropertyID') = 'tvmeterId'">
      <f:string key="tvmeter_id">
        <xsl:value-of select="map:get(., 'value')"/>
      </f:string>
    </xsl:if>
    <!-- Finds PID -->
    <xsl:if test="map:get(., 'PropertyID') = 'PID'">
      <f:string key="pid">
        <xsl:value-of select="map:get(., 'value')"/>
      </f:string>
    </xsl:if>
    <!-- Finds internal accession ref -->
    <xsl:if test="map:get(., 'PropertyID') = 'InternalAccessionRef'">
      <f:string key="internal_accession_ref">
        <xsl:value-of select="map:get(., 'value')"/>
      </f:string>
    </xsl:if>
    <!-- Finds productionId (in danish: 'Produktions ID') for DR records.-->
    <xsl:if test="map:get(., 'PropertyID') = 'ProductionID'">
      <f:string key="dr_production_id">
        <xsl:value-of select="map:get(., 'value')"/>
      </f:string>
    </xsl:if>
  </xsl:template>

  <!-- TEMPLATE WHICH EXTRACTS VALUES FROM THE KB INTERNAL MAP. -->
  <xsl:template name="kbInternal">
    <xsl:param name="internalMap"/>

    <xsl:if test="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:originates_from') != ''">
      <f:string key="originates_from">
        <xsl:value-of select="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:originates_from')"/>
      </f:string>
    </xsl:if>

    <xsl:if test="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:dr_id_restricted') != ''">
      <f:string key="dr_id_restricted">
        <xsl:value-of select="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:dr_id_restricted')"/>
      </f:string>
    </xsl:if>

    <xsl:if test="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:ds_id_restricted') != ''">
      <f:string key="ds_id_restricted">
        <xsl:value-of select="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:ds_id_restricted')"/>
      </f:string>
    </xsl:if>

    <xsl:if test="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:has_kaltura_id') != ''">
      <f:string key="has_kaltura_id">
        <xsl:value-of select="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:has_kaltura_id')"/>
      </f:string>
    </xsl:if>

    <xsl:if test="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:storage_mTime') != ''">
      <f:string key="internal_storage_mTime">
        <xsl:value-of select="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:storage_mTime')"/>
      </f:string>
    </xsl:if>

    <xsl:if test="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:format_identifier_ritzau') != ''">
      <f:string key="internal_format_identifier_ritzau">
        <xsl:value-of select="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:format_identifier_ritzau')"/>
      </f:string>
    </xsl:if>

    <xsl:if test="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:format_identifier_nielsen') != ''">
      <f:string key="internal_format_identifier_nielsen">
        <xsl:value-of select="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:format_identifier_nielsen')"/>
      </f:string>
    </xsl:if>

    <xsl:if test="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:maingenre_id') != ''">
      <f:string key="internal_maingenre_id">
        <xsl:value-of select="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:maingenre_id')"/>
      </f:string>
    </xsl:if>

    <xsl:if test="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:ritzau_channel_id') != ''">
      <f:string key="ritzau_channel_id">
        <xsl:value-of select="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:ritzau_channel_id')"/>
      </f:string>
    </xsl:if>
    <xsl:if test="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:nielsen_channel_id') != ''">
      <f:string key="nielsen_channel_id">
        <xsl:value-of select="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:nielsen_channel_id')"/>
      </f:string>
    </xsl:if>

    <xsl:if test="my:getNestedMapValue2Levels($schemaorg-xml, 'countryOfOrigin', 'name') != ''">
      <f:string key="country_of_origin">
        <xsl:value-of select="my:getNestedMapValue2Levels($schemaorg-xml, 'countryOfOrigin', 'name')"/>
      </f:string>
    </xsl:if>

    <xsl:if test="my:getNestedMapValue2Levels($schemaorg-xml, 'countryOfOrigin', 'identifier') != ''">
      <f:string key="country_of_origin_id">
        <xsl:value-of select="my:getNestedMapValue2Levels($schemaorg-xml, 'countryOfOrigin', 'identifier')"/>
      </f:string>
    </xsl:if>

    <xsl:if test="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:ritzau_program_id') != ''">
      <f:string key="internal_ritzau_program_id">
        <xsl:value-of select="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:ritzau_program_id')"/>
      </f:string>
    </xsl:if>

    <xsl:if test="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:subgenre_id') != ''">
      <f:string key="internal_subgenre_id">
        <xsl:value-of select="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:subgenre_id')"/>
      </f:string>
    </xsl:if>

    <xsl:if test="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:episode_id') != ''">
      <f:string key="internal_episode_id">
        <xsl:value-of select="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:episode_id')"/>
      </f:string>
    </xsl:if>

    <xsl:if test="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:season_id') != ''">
      <f:string key="internal_season_id">
        <xsl:value-of select="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:season_id')"/>
      </f:string>
    </xsl:if>

    <xsl:if test="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:series_id') != ''">
      <f:string key="internal_series_id">
        <xsl:value-of select="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:series_id')"/>
      </f:string>
    </xsl:if>

    <xsl:if test="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:program_ophold') != ''">
      <f:string key="internal_program_ophold">
        <xsl:value-of select="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:program_ophold')"/>
      </f:string>
    </xsl:if>

    <xsl:if test="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:is_teletext') != ''">
      <f:string key="internal_is_teletext">
        <xsl:value-of select="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:is_teletext')"/>
      </f:string>
    </xsl:if>

    <xsl:if test="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:showviewcode') != ''">
      <f:string key="internal_showviewcode">
        <xsl:value-of select="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:showviewcode')"/>
      </f:string>
    </xsl:if>

    <xsl:if test="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:padding_seconds') != ''">
      <f:string key="internal_padding_seconds">
        <xsl:value-of select="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:padding_seconds')"/>
      </f:string>
    </xsl:if>

    <!-- Access field from preservica, historically these values have been used to clause access to material in mediestream. These clauses and prohibitions should also be made
    in DR Archive. Here we are converting it to an actual boolean. -->
    <xsl:variable name="individual_prohibition">
      <xsl:value-of select="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:access_individual_prohibition') != ''"/>
    </xsl:variable>
    <xsl:if test="$individual_prohibition != ''">
      <f:string key="access_individual_prohibition">
        <xsl:choose>
          <xsl:when test="f:lower-case($individual_prohibition) = 'ja'">true</xsl:when>
          <xsl:otherwise>false</xsl:otherwise>
        </xsl:choose>
      </f:string>
    </xsl:if>

  <!-- Access field from preservica, historically these values have been used to clause access to material in mediestream. These clauses and prohibitions should also be made
    in DR Archive. Here we are converting it to an actual boolean. -->
    <xsl:variable name="claused">
      <xsl:value-of select="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:access_claused')"/>
    </xsl:variable>
    <xsl:if test="$claused != ''">
      <f:string key="access_claused">
        <xsl:choose>
          <xsl:when test="lower-case($claused) = 'ja'">true</xsl:when>
          <xsl:otherwise>false</xsl:otherwise>
        </xsl:choose>
      </f:string>
    </xsl:if>

  <!-- Access field from preservica, historically these values have been used to clause access to material in mediestream. These clauses and prohibitions should also be made
    in DR Archive. Here we are converting it to an actual boolean. -->
    <xsl:variable name="malfunction">
      <xsl:value-of select="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:access_malfunction')"/>
    </xsl:variable>
    <xsl:variable name="hasAccessCopyFromDoms">
      <xsl:value-of select="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:has_doms_access_copy')"/>
    </xsl:variable>
    <xsl:variable name="originates_from">
      <xsl:value-of select="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:originates_from')"/>
    </xsl:variable>

    <f:string key="access_malfunction">
      <xsl:choose>
        <xsl:when test="$malfunction != ''">
          <xsl:choose>
            <xsl:when test="lower-case($malfunction) = 'ja'">true</xsl:when>
            <xsl:when test="$originates_from = 'DOMS' and $hasAccessCopyFromDoms = false()">true</xsl:when>
            <xsl:otherwise>false</xsl:otherwise>
          </xsl:choose>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="false"/>
        </xsl:otherwise>
      </xsl:choose>
    </f:string>


    <xsl:if test="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:access_comments') != ''">
      <f:string key="access_comments">
        <xsl:value-of select="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:access_comments')"/>
      </f:string>
    </xsl:if>

    <!-- The following three fields should always be available in the schema.org document for radio and tv records, so no need to encapsulate in if-statements. -->
    <f:string key="contains_tvmeter">
      <xsl:value-of select="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:contains_tvmeter')"/>
    </f:string>
    <f:string key="contains_nielsen">
      <xsl:value-of select="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:contains_nielsen')"/>
    </f:string>
    <f:string key="contains_ritzau">
      <xsl:value-of select="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:contains_ritzau')"/>
    </f:string>

    <xsl:if test="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:program_structure_missing_seconds_start') != ''">
      <f:string key="internal_program_structure_missing_seconds_start">
        <xsl:value-of select="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:program_structure_missing_seconds_start')"/>
      </f:string>
    </xsl:if>

    <xsl:if test="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:program_structure_missing_seconds_end') != ''">
      <f:string key="internal_program_structure_missing_seconds_end">
        <xsl:value-of select="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:program_structure_missing_seconds_end')"/>
      </f:string>
    </xsl:if>

    <xsl:if test="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:program_structure_holes') != ''">
      <f:string key="internal_program_structure_holes">
        <xsl:value-of select="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:program_structure_holes')"/>
      </f:string>
    </xsl:if>

    <xsl:if test="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:program_structure_overlaps') != ''">
      <f:string key="internal_program_structure_overlaps">
        <xsl:value-of select="my:getNestedMapValue2Levels($schemaorg-xml, 'kb:internal', 'kb:program_structure_overlaps')"/>
      </f:string>
    </xsl:if>


    <xsl:variable name="overlapsArray" select="my:getArrayFromNestedMap($schemaorg-xml, 'kb:internal', 'kb:program_structure_overlap')" as="item()*"/>
    <!-- Overlaps are hard to extract to solr as they are tricky to represent in a flat JSON structure where each key
         has a unique name. -->
    <xsl:if test="f:exists($overlapsArray[1]) and not(map:contains($overlapsArray[1], 'empty')) ">
      <f:array key="internal_overlapping_files">
        <xsl:for-each select="$overlapsArray">
          <f:string>
            <xsl:value-of select="concat(map:get(., 'file1UUID'), ',', map:get(., 'file2UUID'))"/>
          </f:string>
        </xsl:for-each>
      </f:array>

      <!-- This counts the amount of overlaps, not the amount of overlapping files. -->
      <f:string key="internal_overlapping_files_count">
        <xsl:value-of select="f:count($overlapsArray)"/>
      </f:string>
    </xsl:if>
    <!--
    INTERNAL STRUCTURE HAS BEEN TEMPORARILY REMOVED FROM TRANSFORMATION AS IT'S HARD TO REPRESENT IT FLAT.

    &lt;!&ndash; Extracting overlaps sorted by type of overlap as that is the only value to distinguish overlaps by. &ndash;&gt;
    <xsl:if test="f:exists($internalMap('kb:program_structure_overlap'))">
      <xsl:variable name="overlaps" as="item()*">
        <xsl:copy-of select="array:flatten($internalMap('kb:program_structure_overlap'))"/>
      </xsl:variable>

      &lt;!&ndash; Defines fields for overlaps of type 1 and 2. Currently, I don't know if more than two types exists, '
           then they would have to be added. &ndash;&gt;
      <xsl:for-each select="$overlaps">
        <xsl:choose>
          <xsl:when test="map:get(. , 'overlap_type') = '1'">
            <f:string key="internal_program_structure_overlap_type_one_length_ms">
              <xsl:value-of select="map:get(. , 'overlap_length')"/>
            </f:string>
            <f:string key="internal_program_structure_overlap_type_one_file1UUID">
              <xsl:value-of select="map:get(. , 'file1UUID')"/>
            </f:string>
            <f:string key="internal_program_structure_overlap_type_one_file2UUID">
              <xsl:value-of select="map:get(. , 'file2UUID')"/>
            </f:string>
          </xsl:when>
        </xsl:choose>
        <xsl:choose>
          <xsl:when test="map:get(. , 'overlap_type') = '2'">
            <f:string key="internal_program_structure_overlap_type_two_length_ms">
              <xsl:value-of select="map:get(. , 'overlap_length')"/>
            </f:string>
            <f:string key="internal_program_structure_overlap_type_two_file1UUID">
              <xsl:value-of select="map:get(. , 'file1UUID')"/>
            </f:string>
            <f:string key="internal_program_structure_overlap_type_two_file2UUID">
              <xsl:value-of select="map:get(. , 'file2UUID')"/>
            </f:string>
          </xsl:when>
        </xsl:choose>
      </xsl:for-each>
    </xsl:if>-->

  </xsl:template>
</xsl:transform>
