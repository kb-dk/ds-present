<?xml version="1.0" encoding="UTF-8" ?>
<xsl:transform xmlns:m="http://www.loc.gov/mods/v3"
               xmlns:mets="http://www.loc.gov/METS/"
               xmlns:t="http://www.tei-c.org/ns/1.0"
               xmlns:f="http://www.w3.org/2005/xpath-functions"
               xmlns:h="http://www.w3.org/1999/xhtml"
               xmlns:xs="http://www.w3.org/2001/XMLSchema"
               xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
               xmlns:my="urn:my"
               xmlns:premis="http://www.loc.gov/premis/v3"
               xmlns:mix="http://www.loc.gov/mix/v20"
               version="3.0">


    <xsl:output method="text"/>
    <xsl:param name="sep_string" select="'/'"/>
    <!--Properties injected from config -->
    <xsl:param name="imageserver"/>
    <xsl:param name="origin"/>
    <xsl:param name="recordID"/> <!-- Guaranteed to be set -->

    <!--Used to escape single quotes from config-->
    <xsl:variable name="singlequote"><xsl:text>'</xsl:text></xsl:variable>
    <xsl:variable name="roles">
        <roles>
            <role key="act" href="https://schema.org/actor">actor</role>
            <role key="art" href="https://schema.org/artist ">artist</role>
            <role key="aut" href="https://schema.org/author">author</role>
            <role key="cre" href="https://schema.org/creator">creator</role>
            <role key="creator" href="https://schema.org/creator">creator</role>
            <role key="ctb" href="https://schema.org/contributor">contributor</role>
            <role key="rcp" href="https://schema.org/recipient">recipient</role>
            <role key="scr" href="http://id.loc.gov/vocabulary/relators/art">relator:scr</role>
            <role key="src" href="http://id.loc.gov/vocabulary/relators/art">relator:scr</role>
            <role key="trl" href="https://schema.org/translator">translator</role>
            <role key="pat" href="https://schema.org/funder">funder</role>
            <role key="prt" href="http://id.loc.gov/vocabulary/relators/art">relator:prt</role>
        </roles>
    </xsl:variable>

    <xsl:variable name="types">
        <types>
            <type key="Fotografi" href="https://schema.org/Photograph">Photograph</type>
            <type key="Anskuelsesbillede" href="https://schema.org/Poster">Poster</type>
            <type key="Postkort" href="https://schema.org/Message">Message</type>
            <type key="Grafik" href="https://schema.org/Photograph">Photograph</type>
            <type key="Negativ" href="https://schema.org/Photograph">Photograph</type>
            <type key="Plakat" href="https://schema.org/Poster">Poster</type>
            <type key="Bladtegning" href="https://schema.org/Drawing">Drawing</type>
            <type key="Tegning" href="https://schema.org/Drawing">Drawing</type>
            <type key="Arkitekturfotografi" href="https://schema.org/Photograph">Photograph</type>
            <type key="Genstand" href="https://schema.org/Thing">Thing</type> <!-- Product, CreativeArtwork, Thing??????-->
        </types>
    </xsl:variable>
    <xsl:template match="/">

        <xsl:variable name="json">
            <f:map>
                <xsl:for-each select="//mets:dmdSec[@ID='Mods1']//m:mods">
                    <!-- TODO: Add genre, where it fits-->

                    <xsl:variable name="cataloging_language">
                        <xsl:for-each select="m:recordInfo/m:languageOfCataloging/m:languageTerm[1]">
                            <xsl:value-of select="."/>
                        </xsl:for-each>
                    </xsl:variable>

                    <!-- TODO: We should store the original ID in some field, e.g. origin_id or source_id -->
<!--                    <xsl:variable name="record-id">
                        <xsl:value-of select="substring-after(m:identifier[@type='uri'], 'urn:uuid:')"/>
                    </xsl:variable>-->
                    <!-- save the entire mods in a variable -->
                    <xsl:variable name="mods" select="."/>


                    <f:array key="@context">
                        <f:string>http://schema.org/</f:string>
                        <f:map>
                            <f:string key="kb">http://kb.dk/vocabs/</f:string>
                            <f:string key="relator">https://id.loc.gov/vocabulary/relators/</f:string>
                        </f:map>
                    </f:array>
                    <f:string key="@type">
                        <!-- Mapping from resourcetypes in new MODS -->
                        <!-- TODO: Maybe sanitycheck this mapping with Sigge. -->
                        <xsl:choose>
                            <xsl:when test="m:typeOfResource[@displayLabel='Resource Description']='Fotografi'">Photograph</xsl:when>
                            <xsl:when test="m:typeOfResource[@displayLabel='Resource Description']='Anskuelsesbillede'">Poster</xsl:when>
                            <xsl:when test="m:typeOfResource[@displayLabel='Resource Description']='Postkort'">Message</xsl:when>
                            <xsl:when test="m:typeOfResource[@displayLabel='Resource Description']='Grafik'">Photograph</xsl:when>
                            <xsl:when test="m:typeOfResource[@displayLabel='Resource Description']='Negativ'">Photograph</xsl:when>
                            <xsl:when test="m:typeOfResource[@displayLabel='Resource Description']='Plakat'">Poster</xsl:when>
                            <xsl:when test="m:typeOfResource[@displayLabel='Resource Description']='Bladtegning'">Drawing</xsl:when>
                            <xsl:when test="m:typeOfResource[@displayLabel='Resource Description']='Tegning'">Drawing</xsl:when>
                            <xsl:when test="m:typeOfResource[@displayLabel='Resource Description']='Arkitekturfotografi'">Photograph</xsl:when>
                            <xsl:when test="m:typeOfResource[@displayLabel='Resource Description']='Genstand'">Thing</xsl:when>
                            <xsl:otherwise>CreativeWork</xsl:otherwise>
                        </xsl:choose>
                    </f:string>
                    <f:string key="id">
                        <xsl:value-of select="$recordID"/>
                    </f:string>

                    <xsl:variable name="imageIdentifierNoExtension">
                        <xsl:value-of select="substring-before(substring-after(
                                              m:relatedItem[@type='otherFormat']/m:identifier[@displayLabel='image'][@type='uri'],
                                              'http://kb-images.kb.dk/'), '.jp')"/>
                    </xsl:variable>
                    <xsl:variable name="imageIdentifierEncoded">
                        <xsl:value-of select="f:encode-for-uri($imageIdentifierNoExtension)"/>
                    </xsl:variable>
                    <xsl:variable name="imageUrl">
                        <xsl:value-of select="concat($imageserver, $imageIdentifierEncoded, '/full/', f:encode-for-uri('!150,150'), '/0/default.jpg')"/>
                    </xsl:variable>

                    <f:string key="url">
                        <xsl:value-of select="$imageUrl"/>
                    </f:string>
                    <f:map key="kb:admin_data">
                        <!-- NOTE: Everything in this comment was available in old data, not present in new.ff
                        <f:array>
                            <xsl:attribute name="key">kb:last_modified_by</xsl:attribute>
                             NOTE: this data is not available in preservation mods
                            <xsl:for-each select="m:name[@type='cumulus' and m:role/m:roleTerm = 'last-modified-by']">
                                <xsl:call-template name="get-names">
                                    <xsl:with-param name="record_identifier" select="$record-id"/>
                                    <xsl:with-param name="cataloging_language" select="$cataloging_language"/>
                                    <xsl:with-param name="agent_type" select="'Person'"/>
                                </xsl:call-template>
                            </xsl:for-each>
                        </f:array>
                        <xsl:for-each select="m:recordInfo/m:recordCreationDate">
                             NOTE: generally not available in test records, do we need this?
                            <f:string key="kb:record_created">
                                <xsl:value-of select="."/>
                            </f:string>
                        </xsl:for-each>
                        <xsl:for-each select="m:recordInfo/m:recordChangeDate">
                             NOTE: generally not available in test records, do we need this?
                            <f:string key="kb:record_revised">
                                <xsl:value-of select="."/>
                            </f:string>
                        </xsl:for-each> -->
                        <f:string key="kb:catalogingLanguage">
                            <xsl:value-of select="m:recordInfo/m:languageOfCataloging/m:languageTerm"/>
                        </f:string>
                        <f:string key="kb:localIdentifier">
                            <xsl:value-of select="m:identifier[@type='local']"/>
                        </f:string>
                        <xsl:if test="m:location/m:shelfLocator">
                            <f:string key="kb:shelfLocator">
                                <xsl:value-of select="m:location/m:shelfLocator"/>
                            </f:string>
                        </xsl:if>
                        <!-- if note field of type internal note exist extracts it, but remove empty prefixes for notes-->
                        <xsl:if test="m:note[@type='Intern note']">
                            <f:array key="kb:internalNotes">
                                <xsl:for-each select="m:note[@type='Intern note']">
                                    <xsl:if test=". !='' and . !='Intern note:' and . !='Ekstern note:' and . !='Alt. navn:' and . != 'Kunstnernote:' and . !='Aktiv:'">
                                        <f:string>
                                            <xsl:value-of select="f:replace(., 'zh\|', '')"/>
                                        </f:string>
                                    </xsl:if>
                                </xsl:for-each>
                            </f:array>
                        </xsl:if>
                    </f:map>
                    <xsl:if test="m:titleInfo/m:title">
                        <xsl:call-template name="get-title">
                            <xsl:with-param name="record_identifier" select="$recordID" />
                            <xsl:with-param name="cataloging_language" select="$cataloging_language" />
                            <xsl:with-param name="mods" select="$mods" />
                        </xsl:call-template>
                    </xsl:if>

                    <xsl:for-each select="distinct-values(m:name/m:role/m:roleTerm)">
                        <xsl:variable name="term" select="."/>
                        <xsl:if test="not(contains($term,'last-modified-by'))">
                            <f:array>
                                <xsl:attribute name="key"><xsl:value-of select="$roles/roles/role[@key=$term]"/></xsl:attribute>
                                <xsl:for-each select="$mods//m:name[m:role/m:roleTerm = $term]">
                                    <xsl:call-template name="get-names">
                                        <xsl:with-param name="record_identifier" select="$recordID"/>
                                        <xsl:with-param name="cataloging_language" select="$cataloging_language" />
                                    </xsl:call-template>
                                </xsl:for-each>
                            </f:array>
                        </xsl:if>
                    </xsl:for-each>
                    <xsl:if test="m:subject/m:hierarchicalGeographic">
                        <f:array key="contentLocation">
                            <f:map>
                                <f:string key="@type">Place</f:string>
                                <f:string key="description">
                                    <xsl:value-of select="m:subject/m:hierarchicalGeographic/m:area"/>
                                </f:string>

                                <!-- kb:address is quite internal. Place above is more schema.org like-->
                                <!-- Would it make sense to keep the kb: namespace. I am not sure what we are using it for?-->
                                <!--<f:map key="kb:address">
                                    <f:string key="@type">kb:place</f:string>
                                    <xsl:for-each select="m:subject/m:hierarchicalGeographic">
                                        <xsl:for-each select="m:area">
                                            <xsl:element name="f:string">
                                                <xsl:attribute name="key">kb:<xsl:value-of select="@areaType"/></xsl:attribute>
                                                <xsl:value-of select="."/>
                                            </xsl:element>
                                        </xsl:for-each>
                                        <xsl:for-each select="m:citySection">
                                            <xsl:element name="f:string">
                                                <xsl:attribute name="key">kb:<xsl:value-of select="@citySectionType"/></xsl:attribute>
                                                <xsl:value-of select="."/>
                                            </xsl:element>
                                        </xsl:for-each>
                                        <xsl:if test="m:city">
                                            <f:string key="kb:city"><xsl:value-of select="m:city"/></f:string>
                                        </xsl:if>
                                    </xsl:for-each>
                                </f:map>-->
                                <xsl:for-each select="m:subject/m:cartographics/m:coordinates[1]">
                                    <xsl:if test="not(contains(.,'0.0,0.0'))">
                                        <f:string key="latitude"><xsl:value-of select="substring-before(.,',')"/></f:string>
                                        <f:string key="longitude"><xsl:value-of select="substring-after(.,',')"/></f:string>
                                    </xsl:if>
                                </xsl:for-each>
                            </f:map>
                        </f:array>
                    </xsl:if>
                    <xsl:if test="m:originInfo/m:place">
                        <f:map key="locationCreated">
                            <f:string key="@type">Place</f:string>
                            <f:string key="name"><xsl:value-of select="normalize-space(m:originInfo/m:place)"/></f:string>
                        </f:map>
                    </xsl:if>
                    <f:array key="about">
                        <xsl:if test="./m:relatedItem[@type='event']/node() or m:note[@type='situation']/node()">
                            <f:map>
                                <f:string key="@type">Event</f:string>
                                <f:string key="name">
                                    <xsl:for-each select="./m:note[@type='situation']">
                                        <xsl:value-of select="."/>
                                    </xsl:for-each>
                                </f:string>
                                <xsl:for-each select="./m:relatedItem[@type='event']">
                                    <xsl:if test="./m:note">
                                        <f:array key="description">
                                            <xsl:for-each select="./m:note">
                                                <f:string><xsl:value-of select="."/></f:string>
                                            </xsl:for-each>
                                        </f:array>
                                    </xsl:if>
                                    <xsl:for-each select="m:originInfo">
                                        <f:string key="startDate">
                                            <xsl:value-of select="m:dateIssued"/>
                                        </f:string>
                                        <f:string key="endDate">
                                            <xsl:value-of select="m:dateIssued"/>
                                        </f:string>
                                        <f:string key="location">
                                            <xsl:value-of select="m:place/m:placeTerm"/>
                                        </f:string>
                                    </xsl:for-each>
                                </xsl:for-each>
                            </f:map>
                        </xsl:if>
                        <!-- *********************** Subjects, Categories etc ******************** -->
                        <xsl:if test="m:subject/m:name[@type='personal']">
                            <xsl:for-each select="$mods/m:subject/m:name[@type='personal']">
                                    <xsl:call-template name="get-names">
                                        <xsl:with-param name="record_identifier" select="$recordID"/>
                                        <xsl:with-param name="cataloging_language" select="$cataloging_language" />
                                    </xsl:call-template>
                            </xsl:for-each>
                        </xsl:if>

                        <xsl:if test="m:note[@displayLabel='Description']">
                            <f:string><xsl:value-of select="m:note[@displayLabel='Description']"/></f:string>
                        </xsl:if>

                        <xsl:for-each select="distinct-values(m:subject/m:topic)">
                            <f:string><xsl:value-of select="."/></f:string>
                        </xsl:for-each>
                        <xsl:if test="m:subject/m:geographic">
                            <xsl:for-each select="distinct-values(m:subject/m:geographic)">
                                <f:string><xsl:value-of select="."/></f:string>
                            </xsl:for-each>
                        </xsl:if>
                        <!-- Notes of type content -->
                        <!-- if note field of type content exists extract it-->
                        <xsl:if test="m:note[@type='content']">
                            <xsl:for-each select="m:note[@type='content']">
                                <xsl:if test=". != ''">
                                    <f:string>
                                        <xsl:value-of select="f:replace(., 'zh\|', '')"/>
                                    </f:string>
                                </xsl:if>
                            </xsl:for-each>
                        </xsl:if>
                    </f:array>
                    <!-- Extract keywords from categories field-->
                    <f:array key="keywords">
                        <xsl:variable name="categories" as="xs:string *">
                            <xsl:value-of select="m:genre[@type='Categories']"/>
                        </xsl:variable>
                        <xsl:for-each select="distinct-values(tokenize(replace($categories, ', ', ','), ','))" >
                                <xsl:if test=". != '' and not(matches(. , '\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}'))">
                                    <xsl:variable name="subject" select="normalize-space(.)"/>
                                    <f:string>
                                        <xsl:value-of select="$subject"/>
                                    </f:string>
                                </xsl:if>
                        </xsl:for-each>
                    </f:array>
                    <!-- Insert dateCreated if only one date present or dateCreated and temporal
                            If dateCreated has start and end point -->
                    <xsl:choose>
                        <xsl:when test="m:originInfo[@altRepGroup='original']/m:dateCreated[@point]">
                            <f:string key="dateCreated">
                                <xsl:value-of select="m:originInfo[@altRepGroup='original']/m:dateCreated[@point='end']"/>
                            </f:string>
                            <f:string key="temporal">
                                <xsl:value-of select="concat('Created between ', m:originInfo[@altRepGroup='original']/m:dateCreated[@point='start'], ' and ', m:originInfo[@altRepGroup='original']/m:dateCreated[@point='end'])"/>
                            </f:string>
                        </xsl:when>
                        <xsl:when test="m:originInfo[@altRepGroup='original']/m:dateCreated">
                            <f:string key="dateCreated">
                                <xsl:value-of select="m:originInfo[@altRepGroup='original']/m:dateCreated"/>
                            </f:string>
                        </xsl:when>
                    </xsl:choose>

                    <xsl:variable name="to_date">
                        <xsl:choose>
                            <xsl:when test="m:originInfo/m:dateCreated/@t:notAfter">
                                <xsl:for-each select="m:originInfo/m:dateCreated/@t:notAfter">
                                    <xsl:value-of select="."/>
                                </xsl:for-each>
                            </xsl:when>
                            <xsl:when test="m:dateCreated/@t:notAfter">
                                <xsl:for-each select="m:dateCreated/@t:notAfter">
                                    <xsl:value-of select="."/>
                                </xsl:for-each>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:if test="processing-instruction('cobject_not_after')">
                                    <xsl:value-of select="processing-instruction('cobject_not_after')"/>
                                </xsl:if>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:variable>
                    <xsl:variable name="from_date">
                        <xsl:choose>
                            <xsl:when test="m:originInfo/m:dateCreated/@t:notBefore">
                                <xsl:for-each select="m:originInfo/m:dateCreated/@t:notBefore">
                                    <xsl:value-of select="."/>
                                </xsl:for-each>
                            </xsl:when>
                            <xsl:when test="m:dateCreated/@t:notBefore">
                                <xsl:for-each select="m:dateCreated/@t:notBefore">
                                    <xsl:value-of select="."/>
                                </xsl:for-each>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:if test="processing-instruction('cobject_not_before')">
                                    <xsl:value-of select="processing-instruction('cobject_not_before')"/>
                                </xsl:if>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:variable>
                    <xsl:variable name="visible_date">
                        <xsl:for-each select="m:originInfo/m:dateCreated|m:dateCreated">
                            <f:string><xsl:value-of select="."/></f:string>
                        </xsl:for-each>
                    </xsl:variable>
                    <xsl:if test="$visible_date/string() or $to_date/string() or $from_date/string()">
                        <f:map key="publication">
                            <f:string key="@type">PublicationEvent</f:string>

                            <xsl:if test="$to_date/string()">
                                <f:string key="endDate"><xsl:value-of select="$to_date"/></f:string>
                            </xsl:if>

                            <xsl:if test="$from_date/string()">
                                <f:string key="startDate"><xsl:value-of select="$from_date"/></f:string>
                            </xsl:if>

                            <xsl:if test="$visible_date/string()">
                                <f:array key="description"><xsl:copy-of select="$visible_date"/></f:array>
                            </xsl:if>

                        </f:map>
                    </xsl:if>
                    <!-- physical description and the like -->
                    <xsl:if test="m:physicalDescription[m:form
                              | m:reformattingQuality
                              | m:internetMediaType
                              | m:extent
                              | m:digitalOrigin
                              | m:note[not(@displayLabel='Pageorientation' or @type='AIM Color Codes')]]">

                        <xsl:for-each select="m:physicalDescription[m:form
                              | m:reformattingQuality
                              | m:internetMediaType
                              | m:extent
                              | m:digitalOrigin
                              | m:note[not(@displayLabel='Pageorientation' or @type='AIM Color Codes')]]">
                            <xsl:variable name="label">
                                <xsl:choose>
                                    <xsl:when test="@displayLabel"><xsl:value-of select="@displayLabel"/></xsl:when>
                                    <xsl:when test="@type"><xsl:value-of select="@type"/></xsl:when>
                                    <xsl:otherwise>
                                        <xsl:value-of select="local-name(.)"/>
                                    </xsl:otherwise>
                                </xsl:choose>
                            </xsl:variable>
                            <f:map>
                                <xsl:attribute name="key">
                                    <xsl:value-of select="my:escape_stuff(lower-case($label))"/>
                                </xsl:attribute>

                            <!--Populates material map with metadata on materials used -->
                            <xsl:for-each select="m:form
                                            | m:reformattingQuality
                                            | m:internetMediaType
                                            | m:extent
                                            | m:digitalOrigin
                                            | m:note[not(@displayLabel='Pageorientation' or @type='AIM Color Codes')]">

                                <xsl:variable name="label">
                                    <xsl:choose>
                                        <xsl:when test="@displayLabel"><xsl:value-of select="@displayLabel"/></xsl:when>
                                        <xsl:when test="@type"><xsl:value-of select="@type"/></xsl:when>
                                        <xsl:otherwise>
                                            <xsl:value-of select="local-name(.)"/>
                                        </xsl:otherwise>
                                    </xsl:choose>
                                </xsl:variable>
                                <xsl:variable name="the_field">
                                    <xsl:choose>
                                        <xsl:when test="string-length($label) &gt; 0">
                                            <xsl:value-of select="my:escape_stuff(lower-case($label))"/>
                                        </xsl:when>
                                        <xsl:when test="@type='Dimensions'">
                                            <xsl:value-of select="my:escape_stuff(lower-case(@type))"/>
                                        </xsl:when>
                                        <xsl:when test="@type">
                                            <xsl:value-of select="my:escape_stuff(lower-case(@type))"/>
                                        </xsl:when>
                                        <xsl:otherwise>
                                            <xsl:value-of select="my:escape_stuff(lower-case(local-name(.)))"/>
                                        </xsl:otherwise>
                                    </xsl:choose>
                                </xsl:variable>
                                <f:map>
                                    <xsl:attribute name="key">
                                        <xsl:value-of select="$the_field"/>
                                    </xsl:attribute>
                                    <xsl:choose>
                                        <xsl:when test="contains($the_field,'xtent')">
                                            <f:string key="@type">QuantitativeValue</f:string>
                                            <f:string key="unitText">
                                                <xsl:choose>
                                                    <xsl:when test="matches(.,'^.*(fol|blad).*$')">folios</xsl:when>
                                                    <xsl:otherwise>pages</xsl:otherwise>
                                                </xsl:choose>
                                            </f:string>
                                        </xsl:when>
                                        <xsl:otherwise>
                                            <xsl:choose>
                                                <xsl:when test="$the_field='size'">
                                                    <f:string key="@type">Text</f:string>
                                                </xsl:when>
                                                <xsl:otherwise>
                                                    <f:string key="@type">Product</f:string>
                                                </xsl:otherwise>
                                            </xsl:choose>
                                        </xsl:otherwise>
                                    </xsl:choose>
                                    <f:string key="value">
                                        <xsl:choose>
                                            <xsl:when test="contains($the_field,'xtent')">
                                                <!-- xsl:value-of select="replace(.,'^.*(\d+).*$','$1')"/ -->
                                                <xsl:value-of select="."/>
                                            </xsl:when>
                                            <xsl:otherwise>
                                                <xsl:value-of select="."/>
                                            </xsl:otherwise>
                                        </xsl:choose>
                                    </f:string>
                                </f:map>
                            </xsl:for-each>
                            </f:map>
                        </xsl:for-each>
                    </xsl:if>
                    <!--Extracts all possible identifiers-->
                    <f:array key="identifier">
                        <f:map>
                            <f:string key="@type">PropertyValue</f:string>
                            <f:string key="PropertyID">Origin</f:string>
                            <f:string key="value"><xsl:value-of select="$origin"/></f:string>
                        </f:map>
                        <xsl:for-each select="m:identifier[@type='uri']">
                            <f:map>
                                <f:string key="@type">PropertyValue</f:string>
                                <f:string key="PropertyID">UUID</f:string>
                                <f:string key="value"><xsl:value-of select="substring-after(., 'urn:uuid:')"/></f:string>
                            </f:map>
                        </xsl:for-each>
                        <xsl:if test="m:location/m:shelfLocator">
                            <xsl:for-each select="m:location/m:shelfLocator">
                                <f:map>
                                    <f:string key="@type">PropertyValue</f:string>
                                    <f:string key="PropertyID">ShelfLocator</f:string>
                                    <f:string key="value"><xsl:value-of select="."/></f:string>
                                </f:map>
                            </xsl:for-each>
                        </xsl:if>
                        <xsl:for-each select="m:identifier[@type='local']">
                            <f:map>
                                <f:string key="@type">PropertyValue</f:string>
                                <f:string key="PropertyID">localIdentifier</f:string>
                                <f:string key="value"><xsl:value-of select="."/></f:string>
                            </f:map>
                        </xsl:for-each>
                        <xsl:if test="m:identifier[@type='accession number']">
                            <xsl:for-each select="m:identifier[@type='accession number']">
                                <f:map>
                                    <f:string key="@type">PropertyValue</f:string>
                                    <f:string key="PropertyID">accessionNumber</f:string>
                                    <f:string key="value"><xsl:value-of select="."/></f:string>
                                </f:map>
                            </xsl:for-each>
                        </xsl:if>
                        <xsl:if test="m:location/m:physicalLocation">
                            <xsl:for-each select="m:location/m:physicalLocation">
                                <f:map>
                                    <f:string key="@type">PropertyValue</f:string>
                                    <f:string key="PropertyID">physicalLocation</f:string>
                                    <f:string key="value"><xsl:value-of select="."/></f:string>
                                </f:map>
                            </xsl:for-each>
                        </xsl:if>
                        <xsl:for-each select="m:relatedItem[@type='original']/m:identifier">
                            <f:map>
                                <f:string key="@type">PropertyValue</f:string>
                                <f:string key="additionalType">originalObjectIdentifier</f:string>
                                <f:string key="@value"><xsl:value-of select="."/></f:string>
                            </f:map>
                        </xsl:for-each>
                        <xsl:for-each select="m:identifier[@type='domsGuid']">
                            <f:map>
                                <f:string key="@type">PropertyValue</f:string>
                                <f:string key="additionalType">domsGuid</f:string>
                                <f:string key="@value"><xsl:value-of select="."/></f:string>
                            </f:map>
                        </xsl:for-each>
                    </f:array>
                    <!-- Adds information on which collections/publications the given CreativeWork is a part of-->
                    <xsl:if test="m:relatedItem[@type='host']">
                        <f:array key="isPartOf">
                            <xsl:variable name="collectionTitle" select="m:relatedItem[@type='host']/m:titleInfo/m:title"/>
                            <xsl:variable name="collectionDescription" select="m:relatedItem[@type='host']/m:note[@type='URL-tekst']"/>
                            <xsl:variable name="collectionURL" select="m:relatedItem[@type='host']/m:identifier[@type='URL']"/>
                            <f:map>
                                <f:string key="@type">Collection</f:string>
                                <f:string key="name"><xsl:value-of select="$collectionTitle"/></f:string>
                                <f:string key="description">
                                    <xsl:value-of select="$collectionDescription"/>
                                </f:string>
                                <f:string key="url">
                                    <xsl:value-of select="$collectionURL"/>
                                </f:string>
                            </f:map>
                            <xsl:if test="m:relatedItem[@displayLabel='Publication']">
                                <f:map>
                                    <f:string key="@type">Periodical</f:string>
                                    <f:string key="name">
                                        <xsl:value-of select="m:relatedItem[@displayLabel='Publication']/m:titleInfo/m:title"/>
                                    </f:string>
                                </f:map>
                            </xsl:if>
                        </f:array>
                    </xsl:if>
                    <!--Extract metadata on the digital image-->
                    <xsl:element name="f:map">
                        <xsl:attribute name="key">image</xsl:attribute>
                        <f:string key="@type">ImageObject</f:string>
                        <xsl:for-each select="//mets:amdSec/mets:techMD[@ID='PremisObject1']//premis:objectCharacteristics">
                        <xsl:if test="premis:size">
                            <f:string key="contentSize">
                                <xsl:value-of select="xs:long(premis:size)"/>
                            </f:string>
                        </xsl:if>
                        <f:string key="contentURL">
                            <xsl:value-of select="concat($imageserver, $imageIdentifierEncoded)"/>
                        </f:string>
                        <f:string key="thumbnail">
                            <xsl:value-of select="$imageUrl"/>
                        </f:string>
                        <!-- Extracts the height of the digital image-->
                        <xsl:if test="premis:objectCharacteristicsExtension/mix:mix/mix:BasicImageInformation/mix:BasicImageCharacteristics/mix:imageHeight">
                            <f:string key="height">
                                <xsl:value-of select="xs:long(premis:objectCharacteristicsExtension/mix:mix/mix:BasicImageInformation/mix:BasicImageCharacteristics/mix:imageHeight)"/>
                            </f:string>
                        </xsl:if>
                        <!-- Extracts the width of the digital image-->
                        <xsl:if test="premis:objectCharacteristicsExtension/mix:mix/mix:BasicImageInformation/mix:BasicImageCharacteristics/mix:imageWidth">
                            <f:string key="width">
                                <xsl:value-of select="xs:long(premis:objectCharacteristicsExtension/mix:mix/mix:BasicImageInformation/mix:BasicImageCharacteristics/mix:imageWidth)"/>
                            </f:string>
                        </xsl:if>
                        <!-- Calculates the size of the digital image in pixels. Does not have a direct equivalent in schema.org-->
                        <!--<xsl:if test="xs:long(premis:objectCharacteristicsExtension/mix:mix/mix:BasicImageInformation/mix:BasicImageCharacteristics/mix:imageHeight * premis:objectCharacteristicsExtension/mix:mix/mix:BasicImageInformation/mix:BasicImageCharacteristics/mix:imageWidth)">
                            <f:string key="image_size_pixels">
                                <xsl:value-of select="xs:long(premis:objectCharacteristicsExtension/mix:mix/mix:BasicImageInformation/mix:BasicImageCharacteristics/mix:imageHeight * premis:objectCharacteristicsExtension/mix:mix/mix:BasicImageInformation/mix:BasicImageCharacteristics/mix:imageWidth)"/>
                            </f:string>
                        </xsl:if> -->
                        </xsl:for-each>
                        <xsl:if test="m:originInfo[@altRepGroup='surrogate']/m:dateCaptured">
                            <f:string key="dateCreated">
                                <xsl:value-of select="m:originInfo[@altRepGroup='surrogate']/m:dateCaptured"/>
                            </f:string>
                        </xsl:if>
                    </xsl:element>
                    <!-- Create audience. This is not in our test files but part of MODS standard.
                              Could be used in other collections. -->
                    <xsl:if test="m:targetInfo">
                        <f:map>
                            <xsl:attribute name="key">audience</xsl:attribute>
                            <f:string key="@type">Audience</f:string>
                            <f:string key="name">
                                <xsl:value-of select="m:targetInfo"/>
                            </f:string>
                        </f:map>
                    </xsl:if>
                    <xsl:if test="m:language/m:languageTerm[@authority='rfc4646']">
                        <f:array key="inLanguage">
                            <xsl:for-each select="m:language/m:languageTerm[@authority='rfc4646']">
                                <f:string><xsl:value-of select="."/></f:string>
                            </xsl:for-each>
                        </f:array>
                    </xsl:if>
                    <!--
    This is perhaps not obvious: Normally text is stored
    in the order it is to be read. However, from the point
    of view of people used to read western languages (LTR
    scripts) it might seem odd click on a left-arrow to
    get next page, but that is the way people reading
    Chinese, Arabic and Hebrew thinks (RTL scripts). And
    that is true for languages using those scripts, like
    Persian (using Arabic script) and Yiddish and Ladino
    using Hebrew script. Judeo-Arabic is a dialect of
    Arabic written using Hebrew script. We have all these
    in our collections.

    We have all these in our digital
    collections. However, around 2005-2010 someone
    decided that the staff doing the digitization
    cannot learn to recognize RTL or LTR objects, so a
    lot of texts has been digitized in what was
    claimed to be the "logical" direction, namely LTR.
    Instead of correcting the data we have done this
    in software.

-->

                    <!-- kb:read_direction is in a kb namespace because
                         there isn't any corresponding element or anything
                         in schema.org -->

                    <xsl:for-each select="m:physicalDescription/m:note[@displayLabel='Pageorientation'][1]">
                        <f:string key="kb:read_direction"><xsl:value-of select="."/></f:string>
                    </xsl:for-each>
                </xsl:for-each>
            </f:map>
        </xsl:variable>
        <xsl:value-of select="f:xml-to-json($json)"/>
    </xsl:template>

    <!--Template for title extraction. Reused from old codebase-->
    <xsl:template name="get-title">
        <xsl:param name="cataloging_language"/>
        <xsl:param name="record_identifier"/>
        <xsl:param name="mods" />
        <xsl:if test="m:titleInfo[not(@type)]">
            <f:array key="headline">
                <xsl:for-each select="m:titleInfo[not(@type)]">
                    <xsl:variable name="xml_lang">
                        <xsl:choose>
                            <xsl:when test="@xml:lang"><xsl:value-of select="@xml:lang"/></xsl:when>
                            <xsl:otherwise><xsl:value-of select="$cataloging_language"/></xsl:otherwise>
                        </xsl:choose>
                    </xsl:variable>
                    <xsl:for-each select="m:title">
                        <f:map>
                            <f:string key="value"><xsl:value-of select="."/></f:string>
                            <f:string key="@language"><xsl:value-of select="$xml_lang"/></f:string>
                        </f:map>
                    </xsl:for-each>
                </xsl:for-each>
            </f:array>
        </xsl:if>
        <xsl:if test="m:titleInfo/@type or m:titleInfo/m:subTitle">
            <f:array key="alternativeHeadline">
                <xsl:for-each select="m:titleInfo[@type]">
                    <xsl:variable name="xml_lang"><xsl:value-of select="@xml:lang"/></xsl:variable>
                    <xsl:for-each select="m:title">
                        <f:map>
                            <f:string key="value"><xsl:value-of select="."/></f:string>
                            <f:string key="@language"><xsl:value-of select="$xml_lang"/></f:string>
                        </f:map>
                    </xsl:for-each>
                </xsl:for-each>
                <xsl:for-each select="m:titleInfo/m:subTitle">
                    <xsl:variable name="xml_lang">
                        <xsl:choose>
                            <xsl:when test="@xml:lang"><xsl:value-of select="@xml:lang"/></xsl:when>
                            <xsl:otherwise><xsl:value-of select="$cataloging_language"/></xsl:otherwise>
                        </xsl:choose>
                    </xsl:variable>
                    <f:map>
                        <f:string key="value"><xsl:value-of select="."/></f:string>
                        <f:string key="@language"><xsl:value-of select="$xml_lang"/></f:string>
                    </f:map>
                </xsl:for-each>
            </f:array>
        </xsl:if>
    </xsl:template>

    <!-- Template for name extraction. Has been modified to new metadata format-->
    <xsl:template name="get-names">
        <xsl:param name="record_identifier"/>
        <xsl:param name="cataloging_language"/>
        <xsl:param name="agent_type" select="''" />

        <xsl:variable name="inferred_originator_type">
            <xsl:choose>
                <xsl:when test="$agent_type"><xsl:value-of select="$agent_type"/></xsl:when>
                <xsl:otherwise>
                    <xsl:choose>
                        <xsl:when test="contains($record_identifier,'pamphlets')">Organization</xsl:when>
                        <xsl:otherwise>Person</xsl:otherwise>
                    </xsl:choose>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <f:map>
            <f:string key="@type">
                <xsl:choose>
                    <xsl:when test="contains(@type,'corporate')">Organization</xsl:when>
                    <xsl:when test="m:affiliation and not(m:namePart)">Organization</xsl:when>
                    <xsl:otherwise><xsl:value-of select="$inferred_originator_type"/></xsl:otherwise>
                </xsl:choose>
            </f:string>
            <xsl:if test="@authorityURI">
                <f:string key="sameAs"><xsl:value-of select="@authorityURI"/></f:string>
            </xsl:if>
            <xsl:variable name="language"><xsl:value-of select="@xml:lang"/></xsl:variable>
            <!-- Creates name for persons -->
            <xsl:if test="m:namePart[@type='given'] or m:namePart[@type='family']">
                <xsl:element name="f:string">
                    <xsl:attribute name="key">name</xsl:attribute>
                    <xsl:for-each select="concat(m:namePart[@type='given'],' ', m:namePart[@type='family'])">
                        <xsl:value-of select="."/>
                    </xsl:for-each>
                </xsl:element>
            </xsl:if>
            <!-- Creates givenName for persons -->
            <xsl:if test="m:namePart[@type='given']">
                <xsl:element name="f:string">
                    <xsl:attribute name="key">givenName</xsl:attribute>
                    <xsl:for-each select="m:namePart[@type='given']">
                        <xsl:value-of select="."/>
                    </xsl:for-each>
                </xsl:element>
            </xsl:if>
            <!-- Creates familyName for persons -->
            <xsl:if test="m:namePart[@type='family']">
                <xsl:element name="f:string">
                    <xsl:attribute name="key">familyName</xsl:attribute>
                    <xsl:for-each select="m:namePart[@type='family']">
                        <xsl:value-of select="."/>
                    </xsl:for-each>
                </xsl:element>
            </xsl:if>
            <!-- Creates birthDate for persons -->
            <xsl:if test="substring-before(m:namePart[@type='date'], '/') != ''">
                <xsl:element name="f:string">
                    <xsl:attribute name="key">birthDate</xsl:attribute>
                    <xsl:for-each select="substring-before(m:namePart[@type='date'], '/')">
                        <xsl:value-of select="."/>
                    </xsl:for-each>
                </xsl:element>
            </xsl:if>
            <!-- Creates deathDate for persons -->
            <xsl:if test="substring-after(m:namePart[@type='date'], '/') != ''">
                <xsl:element name="f:string">
                    <xsl:attribute name="key">deathDate</xsl:attribute>
                    <xsl:for-each select="substring-after(m:namePart[@type='date'], '/')">
                        <xsl:value-of select="."/>
                    </xsl:for-each>
                </xsl:element>
            </xsl:if>
            <!-- Creates affiliation for persons -->
            <xsl:if test="m:affiliation">
                <xsl:element name="f:string">
                    <xsl:attribute name="key">affiliation</xsl:attribute>
                    <xsl:for-each select="m:affiliation" >
                        <xsl:value-of select="."/>
                    </xsl:for-each>
                </xsl:element>
            </xsl:if>
            <!-- Creates description for persons-->
            <xsl:if test="m:description">
                <xsl:element name="f:string">
                    <xsl:attribute name="key">description</xsl:attribute>
                    <xsl:for-each select="m:description" >
                        <xsl:value-of select="."/>
                    </xsl:for-each>
                </xsl:element>
            </xsl:if>
            <!-- TODO: Figure out which schema.org field is most appropriate for termsOfAddress content.-->
            <!-- Terms of adress often relates to occupation. As of now it gets represented in hasOccupation -->
            <xsl:if test="m:namePart[@type='termsOfAddress']">
                <xsl:element name="f:map">
                    <xsl:attribute name="key">hasOccupation</xsl:attribute>
                    <f:string key="@type">Occupation</f:string>
                    <f:string key="name">
                        <xsl:value-of select="m:namePart[@type='termsOfAddress']"/>
                    </f:string>
                </xsl:element>
            </xsl:if>
            <xsl:if test="t:residence">
                <xsl:element name="f:array">
                    <xsl:attribute name="key">
                        <xsl:choose>
                            <xsl:when test="contains(@type,'corporate')">location</xsl:when>
                            <xsl:otherwise>homeLocation</xsl:otherwise>
                        </xsl:choose>
                    </xsl:attribute>
                    <xsl:for-each select="t:residence/*">
                        <f:string><xsl:value-of select="."/></f:string>
                    </xsl:for-each>
                </xsl:element>
            </xsl:if>
        </f:map>
    </xsl:template>
    <xsl:template name="make_page_field">
        <xsl:param name="mods"/>
        <xsl:param name="cataloging_language"/>
        <xsl:param name="record_identifier"/>
        <xsl:choose>
            <xsl:when test="m:identifier[@displayLabel='iiif']">
                <f:map>
                    <f:string key="@type">MediaObject</f:string>
                    <xsl:call-template name="get-title">
                        <xsl:with-param name="cataloging_language" select="$cataloging_language"/>
                        <xsl:with-param name="mods" select="$mods"/>
                        <xsl:with-param name="record_identifier" select="$record_identifier"/>
                    </xsl:call-template>
                    <f:array key="url">
                        <xsl:for-each select="$mods//m:identifier[@displayLabel='iiif'][string()]">
                            <xsl:call-template name="find-pages"/>
                        </xsl:for-each>
                    </f:array>
                </f:map>
                <xsl:for-each select="m:relatedItem[@type='constituent'][m:identifier[@displayLabel='iiif']]">
                    <xsl:call-template name="make_page_field">
                        <xsl:with-param name="cataloging_language" select="$cataloging_language"/>
                        <xsl:with-param name="mods" select="$mods"/>
                        <xsl:with-param name="record_identifier" select="$record_identifier"/>
                    </xsl:call-template>
                </xsl:for-each>
            </xsl:when>
            <xsl:otherwise>
                <f:map>
                    <f:string key="@type">MediaObject</f:string>
                    <xsl:call-template name="get-title"/>
                    <f:array key="url">
                        <xsl:for-each select="m:identifier[contains(.,'.tif')]">
                            <xsl:call-template name="find-pages"/>
                        </xsl:for-each>
                    </f:array>
                </f:map>
                <xsl:for-each select="m:relatedItem[@type='constituent'][m:identifier[contains(.,'.tif')]]">
                    <xsl:call-template name="make_page_field"/>
                </xsl:for-each>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template name="find-pages">
        <xsl:variable name="img">
            <xsl:choose>
                <xsl:when test="./@displayLabel='iiif'">
                    <xsl:value-of select="."/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:choose>
                        <xsl:when test="contains(.,'.tif')">
                            <xsl:value-of select="substring-before(.,'.tif')"/>
                        </xsl:when>
                        <xsl:when test="contains(.,'.TIF')">
                            <xsl:value-of select="substring-before(.,'.TIF')"/>
                        </xsl:when>
                        <xsl:when test="contains(.,'.jp2')">
                            <xsl:value-of select="substring-before(.,'.jp2')"/>
                        </xsl:when>
                    </xsl:choose>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:if test="string-length($img) &gt; 0">
            <f:string>
                <xsl:choose>
                    <xsl:when test="contains($img,'.json')">
                        <xsl:value-of select="$img"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="concat('https://kb-images.kb.dk/',$img,'/info.json')"/>
                    </xsl:otherwise>
                </xsl:choose>
            </f:string>
        </xsl:if>
    </xsl:template>
    <!-- Old function that is still in use. Used to map from descriptions in MODS to fields in Schema.org-->
    <xsl:function name="my:escape_stuff">
        <xsl:param name="arg"/>
        <xsl:choose>
            <xsl:when test="contains($arg,'medium')">material</xsl:when>
            <xsl:when test="contains($arg,'extent')">materialExtent<!-- numberOfPages--></xsl:when>
            <xsl:when test="contains($arg,'physicaldescription')">material</xsl:when>
            <xsl:when test="contains($arg, 'dimensions')">size</xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="replace($arg,'\s',$sep_string,'s')"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
</xsl:transform>
