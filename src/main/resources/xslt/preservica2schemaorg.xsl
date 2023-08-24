<?xml version="1.0" encoding="UTF-8" ?>
<xsl:transform xmlns:f="http://www.w3.org/2005/xpath-functions"
               xmlns:h="http://www.w3.org/1999/xhtml"
               xmlns:xs="http://www.w3.org/2001/XMLSchema"
               xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
               xmlns:my="urn:my"
               xmlns:xip="http://example.com/"
               xmlns:pbc="http://www.pbcore.org/PBCore/PBCoreNamespace.html"
               version="3.0">


  <xsl:output method="text"/>

  <xsl:param name="recordID"/>

  <xsl:template match="/">

    <xsl:variable name="json">
      <f:map>
        <!-- TODO: Add logic for selecting more specific type -->
        <f:string key="@type">BroadcastEvent</f:string>
        <f:string key="id">
          <xsl:value-of select="/xip:DeliverableUnit/DeliverableUnitRef"/>
        </f:string>

        <xsl:for-each select="/xip:DeliverableUnit/Metadata/pbc:PBCoreDescriptionDocument">
          <xsl:call-template name="pbc-metadata"/>
        </xsl:for-each>

      </f:map>
    </xsl:variable>
    <xsl:value-of select="f:xml-to-json($json)"/>
  </xsl:template>

  <xsl:template name="pbc-metadata">


    <!-- TODO: Investigate relation between titel and originaltitel. Some logic related to metadata delivery type exists. -->
    <!-- Create fields headline and alternativeHeadline if needed.
         Determine if title and original title are alike. Both fields should always be in metadata -->
    <xsl:variable name="title">
      <xsl:value-of select="pbcoreTitle[1]/title"/>
    </xsl:variable>
    <xsl:variable name="original-title">
      <xsl:value-of select="pbcoreTitle[2]/title"/>
    </xsl:variable>
    <xsl:choose>
      <xsl:when test="$title = $original-title">
        <f:array key="name">
          <f:map>
            <f:string key="value">
              <xsl:value-of select="$title"/>
            </f:string>
            <!-- TODO: Figure how to determine language for the string "@language"-->
          </f:map>
        </f:array>
      </xsl:when>
      <xsl:otherwise>
        <f:array key="name">
          <f:map>
            <f:string key="value">
              <xsl:value-of select="$title"/>
            </f:string>
            <!-- TODO: Figure how to determine language for the string "@language"-->
          </f:map>
        </f:array>
        <f:array key="alternateName">
          <f:map>
            <f:string key="value">
              <xsl:value-of select="$original-title"/>
            </f:string>
            <!-- TODO: Figure how to determine language for the string "@language"-->
          </f:map>
        </f:array>
      </xsl:otherwise>
    </xsl:choose>


    <!-- TODO: Ellaborate this as specified in https://schema.org/BroadcastEvent -->
    <!-- Publisher extraction. Some metadata has two pbcorePublisher/publisher/publisherRole.
         We use the one with the value "kanalnavn" as this should be present in all metadata files.-->
    <xsl:for-each select="pbcorePublisher">
      <xsl:if test="./publisherRole = 'kanalnavn'">
        <f:map key="publishedOn">
          <f:string key="@type">BroadcastService</f:string>
          <f:string key="broadcastDisplayName">
            <xsl:value-of select="./publisher"/>
          </f:string>
        </f:map>
      </xsl:if>
    </xsl:for-each>




  </xsl:template>

</xsl:transform>