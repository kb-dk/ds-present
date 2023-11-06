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
               version="3.0">
  
  <xsl:output method="text" />
  <xsl:param name="schemaorgjson"/>

  <!--Saves the input JSON as an XDM object. -->
  <xsl:variable name="schemaorg-xml" as="item()*">
    <xsl:copy-of select="f:parse-json($schemaorgjson)"/>
  </xsl:variable>

  <xsl:template match="/">
    <xsl:variable name="solrjson">
      <f:map>
        <f:string key="resource_description">
          <xsl:value-of select="$schemaorg-xml('@type')"/>
        </f:string>
        <!--Simple ID extraction -->
        <f:string key="id">
          <xsl:value-of select="$schemaorg-xml('id')"/>
        </f:string>

        <!-- THIS IS THE BIGGEST AND BADDEST HACK IN TOWN! TO MAKE TEST METHODS AND XSLTS PRETTY AND MANAGEABLE,
             WE SHOULD REALLY IMPLEMENT THIS SCHEMA2SOLR TRANSFORMATION FOR MODS RESOURCES AS WELL. CURRENTLY, THIS
             BRANCH CAN'T GENERATE ANY SOLR-DOCUMENTS FOR MODS RECORDS, WHICH SHOULD BE DO-ABLE. -->
        <xsl:if test="contains(map:get($schemaorg-xml,'@type'), 'VideoObject') or
                      contains(map:get($schemaorg-xml,'@type'), 'AudioObject') ">

          <f:string key="name">
            <xsl:value-of select="$schemaorg-xml('name')"/>
          </f:string>

          <xsl:if test="f:exists($schemaorg-xml('keywords'))">
            <!--Save categories to a variable as a sequence. -->
            <xsl:variable name="categories" as="item()*" select="tokenize($schemaorg-xml('keywords'), ',')"/>
            <!--Create array of categories, which fits with the multivalued solr field -->
            <f:array key="categories">
              <xsl:for-each select="$categories">
                <f:string><xsl:value-of select="normalize-space(.)"/></f:string>
              </xsl:for-each>
            </f:array>
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
            <f:string key="title">
              <xsl:value-of select="$schemaorg-xml('name')"/>
            </f:string>
          </xsl:if>

          <!-- extract alternate title-->
          <xsl:if test="$schemaorg-xml('alternateName')">
            <f:string key="original_title">
              <xsl:value-of select="$schemaorg-xml('alternateName')"/>
            </f:string>
          </xsl:if>

          <!-- Extract the creater affiliation -->
          <!-- map:find() can be used, because we know that only one key in the complete JSON file is named
               broadcastDisplayName -->
          <xsl:if test="f:exists(map:find($schemaorg-xml,'broadcastDisplayName'))">
            <f:string key="creator_affiliation">
              <xsl:value-of select="map:find($schemaorg-xml,'broadcastDisplayName')"/>
            </f:string>
          </xsl:if>

          <!-- Creates the notes field, which originates from the mods2solr XSLT and acts as a catch all field for metadata
               The values in this field are also present in the specific abstract and description fields.-->
          <xsl:if test="$schemaorg-xml('abstract') or $schemaorg-xml('description')">
            <f:array key="notes">
              <xsl:if test="$schemaorg-xml('abstract')">
                <f:string>
                  <xsl:value-of select="$schemaorg-xml('abstract')"/>
                </f:string>
              </xsl:if>
              <xsl:if test="$schemaorg-xml('description')">
                <f:string>
                  <xsl:value-of select="$schemaorg-xml('description')"/>
                </f:string>
              </xsl:if>
            </f:array>
          </xsl:if>

          <!-- Extract content url-->
          <!-- TODO: What about resourceID?-->
          <xsl:if test="$schemaorg-xml('contentUrl')">
            <f:string key="streaming_url">
              <xsl:value-of select="$schemaorg-xml('contentUrl')"/>
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

          <!-- extract start time-->
          <xsl:if test="$schemaorg-xml('startTime')">
            <f:string key="startTime">
              <xsl:value-of select="$schemaorg-xml('startTime')"/>
            </f:string>
          </xsl:if>

          <!-- extract end time-->
          <xsl:if test="$schemaorg-xml('endTime')">
            <f:string key="endTime">
              <xsl:value-of select="$schemaorg-xml('endTime')"/>
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
          <xsl:if test="f:exists(map:get($schemaorg-xml('kb:internal'),'kb:color'))">
            <f:string key="color">
              <xsl:value-of select="map:get($schemaorg-xml('kb:internal'),'kb:color')"/>
            </f:string>
          </xsl:if>

          <!-- Extract videoQuality -->
          <xsl:if test="$schemaorg-xml('videoQuality')">
            <f:string key="video_quality">
              <xsl:value-of select="$schemaorg-xml('videoQuality')"/>
            </f:string>
          </xsl:if>

          <!-- Extract surround sound-->
          <xsl:if test="f:exists(map:get($schemaorg-xml('kb:internal'),'kb:surround_sound'))">
            <f:string key="surround_sound">
              <xsl:value-of select="map:get($schemaorg-xml('kb:internal'),'kb:surround_sound')"/>
            </f:string>
          </xsl:if>

          <!-- Extract premiere-->
          <xsl:if test="f:exists(map:get($schemaorg-xml('kb:internal'), 'kb:premiere'))">
            <f:string key="premiere">
              <xsl:value-of select="$schemaorg-xml('kb:internal')('kb:premiere')"/>
            </f:string>
          </xsl:if>

          <!-- Extract aspect ratio-->
          <xsl:if test="f:exists(map:get($schemaorg-xml('kb:internal'), 'kb:aspect_ratio'))">
            <f:string key="aspect_ratio">
              <xsl:value-of select="$schemaorg-xml('kb:internal')('kb:aspect_ratio')"/>
            </f:string>
          </xsl:if>

          <!-- Extract boolean for live broadcast -->
          <xsl:if test="f:exists($schemaorg-xml('publication')('isLiveBroadcast'))">
            <f:string key="live_broadcast">
              <xsl:value-of select="$schemaorg-xml('publication')('isLiveBroadcast')"/>
            </f:string>
          </xsl:if>

          <!-- Extract boolean for retransmission -->
          <xsl:if test="f:exists($schemaorg-xml('kb:internal')('kb:retransmission'))">
            <f:string key="retransmission">
              <xsl:value-of select="($schemaorg-xml('kb:internal')('kb:retransmission'))"/>
            </f:string>
          </xsl:if>

          <!-- Extract abstract -->
          <xsl:if test="f:exists($schemaorg-xml('abstract'))">
            <f:string key="abstract">
              <xsl:value-of select="$schemaorg-xml('abstract')"/>
            </f:string>
          </xsl:if>

          <!-- Extract description -->
          <xsl:if test="f:exists($schemaorg-xml('description'))">
            <f:string key="description">
              <xsl:value-of select="$schemaorg-xml('description')"/>
            </f:string>
          </xsl:if>

          <!-- Extract sub genre -->
          <xsl:if test="f:exists($schemaorg-xml('kb:internal')('kb:genre_sub'))">
            <f:string key="genre_sub">
              <xsl:value-of select="$schemaorg-xml('kb:internal')('kb:genre_sub')"/>
            </f:string>
          </xsl:if>

          <!-- Extract boolean for subtitles -->
          <xsl:if test="f:exists($schemaorg-xml('kb:internal')('kb:has_subtitles'))">
            <f:string key="has_subtitles">
              <xsl:value-of select="$schemaorg-xml('kb:internal')('kb:has_subtitles')"/>
            </f:string>
          </xsl:if>

          <!-- Extract boolean for subtitles for hearing impaired  -->
          <xsl:if test="f:exists($schemaorg-xml('kb:internal')('kb:has_subtitles_for_hearing_impaired'))">
            <f:string key="has_subtitles_for_hearing_impaired">
              <xsl:value-of select="$schemaorg-xml('kb:internal')('kb:has_subtitles_for_hearing_impaired')"/>
            </f:string>
          </xsl:if>

          <!--Extract the array of identifiers to a variable, where the individual maps can be accessed. -->
          <xsl:variable name="identifers" as="item()*">
            <xsl:copy-of select="array:flatten($schemaorg-xml('identifier'))"/>
          </xsl:variable>
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

      </f:map>
    </xsl:variable>

    <xsl:value-of select="f:xml-to-json($solrjson)"/>
  </xsl:template>

  <!-- EXTRACT IDENTIFIERS FROM THE SCHEMA.ORG ARRAY OF IDENTIFIERS. -->
  <xsl:template name="identifierExtractor">
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
  </xsl:template>

  <!-- TEMPLATE WHICH EXTRACTS VALUES FROM THE KB INTERNAL MAP, THAT HAVE STATUS AS INTERNAL FIELDS IN SOLR AS WELL. -->
  <xsl:template name="kbInternal">
    <xsl:param name="internalMap"/>

    <xsl:if test="f:exists($internalMap('kb:format_identifier_ritzau'))">
      <f:string key="internal_format_identifier_ritzau">
        <xsl:value-of select="$internalMap('kb:format_identifier_ritzau')"/>
      </f:string>
    </xsl:if>

    <xsl:if test="f:exists($internalMap('kb:format_identifier_nielsen'))">
      <f:string key="internal_format_identifier_nielsen">
        <xsl:value-of select="$internalMap('kb:format_identifier_nielsen')"/>
      </f:string>
    </xsl:if>

    <xsl:if test="f:exists($internalMap('kb:maingenre_id'))">
      <f:string key="internal_maingenre_id">
        <xsl:value-of select="$internalMap('kb:maingenre_id')"/>
      </f:string>
    </xsl:if>

    <xsl:if test="f:exists($internalMap('kb:channel_id'))">
      <f:string key="internal_channel_id">
        <xsl:value-of select="$internalMap('kb:channel_id')"/>
      </f:string>
    </xsl:if>

    <xsl:if test="f:exists($internalMap('kb:country_of_origin_id'))">
      <f:string key="internal_country_of_origin_id">
        <xsl:value-of select="$internalMap('kb:country_of_origin_id')"/>
      </f:string>
    </xsl:if>

    <xsl:if test="f:exists($internalMap('kb:ritzau_program_id'))">
      <f:string key="internal_ritzau_program_id">
        <xsl:value-of select="$internalMap('kb:ritzau_program_id')"/>
      </f:string>
    </xsl:if>

    <xsl:if test="f:exists($internalMap('kb:subgenre_id'))">
      <f:string key="internal_subgenre_id">
        <xsl:value-of select="$internalMap('kb:subgenre_id')"/>
      </f:string>
    </xsl:if>

    <xsl:if test="f:exists($internalMap('kb:episode_id'))">
      <f:string key="internal_episode_id">
        <xsl:value-of select="$internalMap('kb:episode_id')"/>
      </f:string>
    </xsl:if>

    <xsl:if test="f:exists($internalMap('kb:season_id'))">
      <f:string key="internal_season_id">
        <xsl:value-of select="$internalMap('kb:season_id')"/>
      </f:string>
    </xsl:if>

    <xsl:if test="f:exists($internalMap('kb:series_id'))">
      <f:string key="internal_series_id">
        <xsl:value-of select="$internalMap('kb:series_id')"/>
      </f:string>
    </xsl:if>

    <xsl:if test="f:exists($internalMap('kb:program_ophold'))">
      <f:string key="internal_program_ophold">
        <xsl:value-of select="$internalMap('kb:program_ophold')"/>
      </f:string>
    </xsl:if>

    <xsl:if test="f:exists($internalMap('kb:is_teletext'))">
      <f:string key="internal_is_teletext">
        <xsl:value-of select="$internalMap('kb:is_teletext')"/>
      </f:string>
    </xsl:if>

    <xsl:if test="f:exists($internalMap('kb:showviewcode'))">
      <f:string key="internal_showviewcode">
        <xsl:value-of select="$internalMap('kb:showviewcode')"/>
      </f:string>
    </xsl:if>

    <xsl:if test="f:exists($internalMap('kb:padding_seconds'))">
      <f:string key="internal_padding_seconds">
        <xsl:value-of select="$internalMap('kb:padding_seconds')"/>
      </f:string>
    </xsl:if>

    <xsl:if test="f:exists($internalMap('kb:access_individual_prohibition'))">
      <f:string key="internal_access_individual_prohibition">
        <xsl:value-of select="$internalMap('kb:access_individual_prohibition')"/>
      </f:string>
    </xsl:if>

    <xsl:if test="f:exists($internalMap('kb:access_claused'))">
      <f:string key="internal_access_claused">
        <xsl:value-of select="$internalMap('kb:access_claused')"/>
      </f:string>
    </xsl:if>

    <xsl:if test="f:exists($internalMap('kb:access_malfunction'))">
      <f:string key="internal_access_malfunction">
        <xsl:value-of select="$internalMap('kb:access_malfunction')"/>
      </f:string>
    </xsl:if>

    <xsl:if test="f:exists($internalMap('kb:access_comments'))">
      <f:string key="internal_access_comments">
        <xsl:value-of select="$internalMap('kb:access_comments')"/>
      </f:string>
    </xsl:if>

    <xsl:if test="f:exists($internalMap('kb:program_structure_missing_seconds_start'))">
      <f:string key="internal_program_structure_missing_seconds_start">
        <xsl:value-of select="$internalMap('kb:program_structure_missing_seconds_start')"/>
      </f:string>
    </xsl:if>

    <xsl:if test="f:exists($internalMap('kb:program_structure_missing_seconds_end'))">
      <f:string key="internal_program_structure_missing_seconds_end">
        <xsl:value-of select="$internalMap('kb:program_structure_missing_seconds_end')"/>
      </f:string>
    </xsl:if>

    <xsl:if test="f:exists($internalMap('kb:program_structure_holes'))">
      <f:string key="internal_program_structure_holes">
        <xsl:value-of select="$internalMap('kb:program_structure_holes')"/>
      </f:string>
    </xsl:if>

    <xsl:if test="f:exists($internalMap('kb:program_structure_overlaps'))">
      <f:string key="internal_program_structure_overlaps">
        <xsl:value-of select="$internalMap('kb:program_structure_overlaps')"/>
      </f:string>
    </xsl:if>
  </xsl:template>


  <!-- FUNCTIONS -->
  <!-- Get milliseconds between two datetimes. -->
  <xsl:function name="my:toMilliseconds" as="xs:integer">
    <xsl:param name="startDate" as="xs:dateTime"/>
    <xsl:param name="endDate" as="xs:dateTime"/>
    <xsl:value-of select="($endDate - $startDate) div xs:dayTimeDuration('PT0.001S')"/>
  </xsl:function>
</xsl:transform>
