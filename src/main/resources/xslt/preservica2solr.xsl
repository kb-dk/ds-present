<?xml version="1.0" encoding="UTF-8" ?>
<xsl:transform xmlns:t="http://www.test.com/"
               xmlns:f="http://www.w3.org/2005/xpath-functions"
               xmlns:h="http://www.w3.org/1999/xhtml"
               xmlns:xs="http://www.w3.org/2001/XMLSchema"
               xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
               xmlns:my="urn:my"
               xmlns:pbc="http://www.pbcore.org/PBCore/PBCoreNamespace.html"
               xmlns:xip="http://example.com/"
               version="3.0">

  <xsl:output method="text" />
  <!-- Declare all externally provided parameters here -->
  <!-- Provided by the Java code that calls the Transformer. (Key,Value) pairs are given in a map -->
  <xsl:param name="streamingserver"/>
  <xsl:param name="recordID"/>

  <xsl:template match="/" >
    <xsl:variable name="solrjson">
      <f:map>

        <f:string key="id">
          <xsl:value-of select="$recordID"/>
        </f:string>
        <!-- TODO: Not sure if this accession ref is correctly understood-->
        <f:string key="accession_number">
          <xsl:value-of select="/xip:DeliverableUnit/AccessionRef"/>
        </f:string>

        <xsl:for-each select="/xip:DeliverableUnit/Metadata/pbc:PBCoreDescriptionDocument">
          <xsl:call-template name="pbc-metadata"/>
        </xsl:for-each>
      </f:map>
    </xsl:variable>

    <xsl:value-of select="f:xml-to-json($solrjson)"/>
  </xsl:template>

  <!-- TEMPLATE FOR ACCESSING PBC METADATA. CALLED ABOVE-->
  <xsl:template name="pbc-metadata">
    <f:string key="collection">
      <xsl:value-of select="pbcoreInstantiation/formatLocation"/>
    </f:string>

    <!-- TODO: Check how genre is specified in mods2solr transformation  -->
    <xsl:if test="pbcoreGenre">
      <f:array key="genre">
        <xsl:for-each select="pbcoreGenre">
          <f:string>
            <xsl:value-of select="normalize-space(.)"/>
          </f:string>
        </xsl:for-each>
      </f:array>
    </xsl:if>

    <f:string key="resource_description">
      <xsl:value-of select="pbcoreInstantiation/formatMediaType"/>
    </f:string>


    <xsl:for-each select="pbcoreTitle">
      <xsl:if test="titleType = 'titel'">
        <f:string key="title">
          <xsl:value-of select="title"/>
        </f:string>
      </xsl:if>
      <xsl:if test="titleType = 'originaltitel' and title != ''">
        <f:string key="original_title">
          <xsl:value-of select="title"/>
        </f:string>
      </xsl:if>
    </xsl:for-each>

    <!--TODO: Figure out what the difference is between kanalnavn and channel_name in the metadata. -->
    <xsl:for-each select="pbcorePublisher">
      <xsl:if test="publisherRole = 'kanalnavn'">
        <f:string key="creator_affiliation">
          <xsl:value-of select="publisher"/>
        </f:string>
      </xsl:if>
    </xsl:for-each>

    <xsl:if test="pbcoreDescription/description != ''">
    <f:string key="notes">
      <xsl:value-of select="normalize-space(pbcoreDescription/description)"/>
    </f:string>
    </xsl:if>

    <!-- Video specific transformations -->
    <xsl:for-each select="pbcoreIdentifier">
      <xsl:if test="identifierSource = 'ritzauId'">
        <f:string key="ritzau_id">
          <xsl:value-of select="identifier"/>
        </f:string>
      </xsl:if>
      <xsl:if test="identifierSource = 'tvmeterId'">
        <f:string key="tvmeter_id">
          <xsl:value-of select="identifier"/>
        </f:string>
      </xsl:if>
    </xsl:for-each>

    <!--Some docs have this duration field. Others doesn't. Then we need to extract the duration from pbcoreDateAvailable-->
    <xsl:choose>
      <xsl:when test="pbcoreInstantiation/formatDuration">
        <f:string key="duration_ms">
          <xsl:value-of select="pbcoreInstantiation/formatDuration"/>
        </f:string>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="startTime">
          <xsl:value-of select="pbcoreInstantiation/pbcoreDateAvailable/dateAvailableStart"/>
        </xsl:variable>
        <xsl:variable name="endTime">
          <xsl:value-of select="pbcoreInstantiation/pbcoreDateAvailable/dateAvailableEnd"/>
        </xsl:variable>
        <xsl:variable name="durationInMilliseconds">
          <xsl:value-of select="my:toMilliseconds($startTime, $endTime)"/>
        </xsl:variable>
        <f:string key="duration_ms">
          <xsl:value-of select="$durationInMilliseconds"/>
        </f:string>
      </xsl:otherwise>
    </xsl:choose>

    <xsl:choose>
      <xsl:when test="pbcoreInstantiation/formatColors = 'farve'">
        <f:string key="color">true</f:string>
      </xsl:when>
      <xsl:otherwise>
        <f:string key="color">false</f:string>
      </xsl:otherwise>
    </xsl:choose>

    <xsl:for-each select="pbcoreExtension/extension">
      <xsl:choose>
        <xsl:when test="f:starts-with(., 'premiere:') and f:contains(., 'ikke premiere')">
          <f:string key="premiere">
            <xsl:value-of select="false()"/>
          </f:string>
        </xsl:when>
        <xsl:when test="f:starts-with(., 'premiere:') and f:contains(., ':premiere')">
          <f:string key="premiere">
            <xsl:value-of select="true()"/>
          </f:string>
        </xsl:when>
      </xsl:choose>
    </xsl:for-each>

    <xsl:if test="pbcoreInstantiation/formatAspectRatio">
      <f:string key="aspect_ratio">
        <xsl:value-of select="/xip:DeliverableUnit/Metadata/pbc:PBCoreDescriptionDocument/pbcoreInstantiation/formatAspectRatio"/>
      </f:string>
    </xsl:if>
  </xsl:template>

  <!-- FUNCTIONS -->
  <!-- Get milliseconds between two dates. -->
  <xsl:function name="my:toMilliseconds" as="xs:integer">
    <xsl:param name="startDate" as="xs:dateTime"/>
    <xsl:param name="endDate" as="xs:dateTime"/>
    <xsl:value-of select="($endDate - $startDate) div xs:dayTimeDuration('PT0.001S')"/>
  </xsl:function>
</xsl:transform>