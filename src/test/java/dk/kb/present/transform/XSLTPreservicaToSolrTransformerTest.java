package dk.kb.present.transform;

import dk.kb.present.TestFiles;
import dk.kb.present.TestUtil;
import dk.kb.present.util.TestFileProvider;
import dk.kb.util.Files;
import dk.kb.util.Resolver;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.File;
import java.io.IOException;
import java.nio.file.Path;
import java.util.Arrays;
import java.util.function.Consumer;

import static dk.kb.present.TestUtil.prettyPrintJson;
import static dk.kb.present.transform.XSLTPreservicaSchemaOrgTransformerTest.PRESERVICA2SCHEMAORG;
import static org.junit.Assert.fail;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 *
 *  To run these tests, the test metadata has to be fetched from the internal aegis project.
 *  With aegis running this can be done by running 'kb init' in this repository.
 */

@Tag("integration")
public class XSLTPreservicaToSolrTransformerTest extends XSLTTransformerTestBase {
    public static final String SCHEMA2SOLR =  "xslt/schemaorg2solr.xsl";
    private static final Logger log = LoggerFactory.getLogger(XSLTPreservicaToSolrTransformerTest.class);

    @Override
    String getXSLT() {
        return PRESERVICA2SCHEMAORG + " AND " + SCHEMA2SOLR;
    }

    @BeforeAll
    public static void beforeMethod() {
        if (Resolver.getPathFromClasspath("internal_test_files/preservica7") == null){
            fail("Internal test files are not present. Unittest 'XSLTPreservicaToSolrTransformerTest' is therefore not run.");
        }
        
    }

    @Test
    public void testExtraction() {
        assertPvicaContains(TestFiles.PVICA_RECORD_e683b0b8, "\"id\":\"ds.test:e683b0b8-425b-45aa-be86-78ac2b4ef0ca.xml\"");
    }

    @Test
    public void testTitles() {
        assertPvicaContains(TestFiles.PVICA_RECORD_e683b0b8, "\"title\":\"Ugen der gik\"");

        assertPvicaContains(TestFiles.PVICA_RECORD_df3dc9cf, "\"title\":\"Før Bjørnen Er Skudt\"");
    }

    @Test
    public void testDirectDuration() {
        assertPvicaContains(TestFiles.PVICA_RECORD_3006e2f8,"\"duration_ms\":\"1509000\"");
    }

    @Test
    public void testCalculatedDuration() {
        assertPvicaContains(TestFiles.PVICA_RECORD_3945e2d1,"\"duration_ms\":\"2700000\"");
    }

    @Test
    public void testGenrePresent() {
        assertPvicaContains(TestFiles.PVICA_RECORD_b346acc8, "\"genre\":\"");
    }

    @Test
    void testGenreContent() {
        assertPvicaContains(TestFiles.PVICA_RECORD_a8aafb121,"\"categories\":[\"Serier\",\"Krimiserie\"");
        assertPvicaNotContains(TestFiles.PVICA_RECORD_a8aafb121, "\"categories\":[\"hovedgenre: Serier ritzau\",\"undergenre: Krimiserie ritzau\"");
    }

    @Test
    void testEmptyGenre(){
        assertPvicaNotContains(TestFiles.PVICA_RECORD_0b3f6a54, "\"categories\":");
        assertPvicaNotContains(TestFiles.PVICA_RECORD_0b3f6a54, "\"genre\":");
    }

    @Test
    void testMainGenre() {
        assertPvicaContains(TestFiles.PVICA_RECORD_a8aafb121,"\"genre\":\"Serier\"");
    }

    @Test
    void testSubGenre() {
        assertPvicaContains(TestFiles.PVICA_RECORD_a8aafb121, "\"genre_sub\":\"Krimiserie\"");
    }

    @Test
    public void testNoGenre() {
        assertPvicaNotContains(TestFiles.PVICA_RECORD_0b3f6a54, "\"genre\":[\"");
    }

    @Test
    public void testResourceDescription() {
        assertPvicaNotContains(TestFiles.PVICA_RECORD_3006e2f8, "\"resource_description\": \"Moving Image\"");
    }

    @Test
    public void testCollection() {
        assertPvicaNotContains(TestFiles.PVICA_RECORD_3006e2f8, "\"collection\": \"Det Kgl. Bibliotek; Radio/TV-Samlingen\"");
    }

    @Test
    public void testCreatorAffiliation() {
        assertPvicaContains(TestFiles.PVICA_RECORD_3006e2f8, "\"creator_affiliation\":\"DR1\"");
    }

    @Test
    public void testNoCreatorAffiliation() {
        assertPvicaNotContains(TestFiles.PVICA_RECORD_0b3f6a54, "\"creator_affiliation\"");
    }

    @Test
    public void testBroadcaster() {
        assertPvicaContains(TestFiles.PVICA_RECORD_3006e2f8, "\"broadcaster\":\"DR\"");
    }
    @Test
    public void testCreatorAffiliationGeneric() {
        assertPvicaContains(TestFiles.PVICA_RECORD_e683b0b8, "\"creator_affiliation_generic\":\"drp1\"");
    }

    @Test
    public void testNotes() {
        assertPvicaContains(TestFiles.PVICA_RECORD_a8aafb121, "\"notes\":[\"Eng. krimiserie\",\"To begravelser er planlagt.");
    }

    @Test
    void testDescription() {
        assertPvicaContains(TestFiles.PVICA_RECORD_a8aafb121, "\"description\":\"To begravelser er planlagt. Den ene for Sir Magnus Pye, den anden for Alan Conway.");
    }

    @Test
    void testShortDescription(){
        assertPvicaContains(TestFiles.PVICA_RECORD_a8aafb121, "\"abstract\":\"Eng. krimiserie\",");
    }


    @Test
    public void testOrigin(){
        assertPvicaContains(TestFiles.PVICA_RECORD_a8aafb121, "\"origin\":\"ds.test\"");
    }

    @Test
    void testEpisode(){
        assertPvicaContains(TestFiles.PVICA_RECORD_a8aafb121, "\"episode\":");
        assertPvicaNotContains(TestFiles.PVICA_RECORD_3006e2f8, "\"episode\":");
    }

    @Test
    void testNumberOfEpisodes() {
        assertPvicaContains(TestFiles.PVICA_RECORD_a8aafb121, "\"number_of_episodes\":");
        assertPvicaNotContains(TestFiles.PVICA_RECORD_0b3f6a54, "\"number_of_episodes\":");
        assertPvicaNotContains(TestFiles.PVICA_RECORD_3006e2f8, "\"number_of_episodes\":");
    }

    @Test
    void testEpisodeButNoTotalNumberOfEpisodes(){
        assertPvicaContains(TestFiles.PVICA_RECORD_b346acc8, "\"episode\"");
        assertPvicaNotContains(TestFiles.PVICA_RECORD_b346acc8, "\"number_of_episode\"");
    }

    @Test
    void testLive(){
        assertPvicaContains(TestFiles.PVICA_RECORD_74e22fd8, "\"live_broadcast\":\"true\"");
        assertPvicaContains(TestFiles.PVICA_RECORD_a8aafb121, "\"live_broadcast\":\"false\"");
    }

    @Test
    void testEpisodeTitle(){
        assertPvicaContains(TestFiles.PVICA_RECORD_3945e2d1, "\"episode_title\":\"Kagerester\"");
        assertPvicaNotContains(TestFiles.PVICA_RECORD_74e22fd8, "\"episode_title\"");
    }

    @Test
    void testVideoQuality(){
        //ikke hd
        assertPvicaContains(TestFiles.PVICA_RECORD_a8aafb121, "\"video_quality\":\"ikke hd\"");
        //Not defined
        // TODO: find a test file where videoquality haven't been specified
        //assertPvicaNotContains(TestFiles.PVICA_RECORD_3006e2f8, "\"video_quality\":");
        //TODO: We dont have any test files that are HD=true. Either find one when more data is available or create a mock
    }

    @Test
    void testSurround(){
        assertPvicaContains(TestFiles.PVICA_RECORD_4b18d02d, "\"surround_sound\":\"true\"");
        assertPvicaContains(TestFiles.PVICA_RECORD_3945e2d1, "\"surround_sound\":\"false\"");

    }

    @Test
    void testInternalFormatIdentifier(){
        assertPvicaContains(TestFiles.PVICA_RECORD_3945e2d1, "\"internal_format_identifier_ritzau\":\"81318588\"");
    }

    @Test
    void testRetransmission(){
        // TODO: find a record which is a retransmission
        //assertPvicaContains(TestFiles.PVICA_RECORD_44979f67, "\"retransmission\":\"true\"");
        assertPvicaContains(TestFiles.PVICA_RECORD_4b18d02d, "\"retransmission\":\"false\"");
    }

    @Test
    void testHovedgenreId() {
        assertPvicaContains(TestFiles.PVICA_RECORD_3945e2d1,"\"internal_maingenre_id\":\"10\"");
    }

    @Test
    void testChannelId(){
        assertPvicaContains(TestFiles.PVICA_RECORD_3945e2d1, "\"internal_channel_id\":\"3\"");
    }

    @Test
    void testCountryOfOriginId(){
        assertPvicaContains(TestFiles.PVICA_RECORD_3945e2d1, "\"internal_country_of_origin_id\":\"0\"");
    }

    @Test
    void testRitzauProgramID(){
        assertPvicaContains(TestFiles.PVICA_RECORD_3945e2d1, "\"internal_ritzau_program_id\":\"25101143\"");
    }

    @Test
    void testProgramOphold(){
        assertPvicaContains(TestFiles.PVICA_RECORD_3945e2d1, "\"internal_program_ophold\":\"false\"");
        //TODO: Test true value with test file which contains program_ophold:program_ophold
    }

    @Test
    void testSubGenreId(){
        assertPvicaContains(TestFiles.PVICA_RECORD_3945e2d1, "\"internal_subgenre_id\":\"736\"");
    }

    @Test
    void testEpisodeId(){
        assertPvicaContains(TestFiles.PVICA_RECORD_3945e2d1, "\"internal_episode_id\":\"0\"");
    }

    @Test
    void testSeasonId(){
        assertPvicaContains(TestFiles.PVICA_RECORD_3945e2d1, "\"internal_season_id\":\"174278\"");
    }

    @Test
    void testSeriesId(){
        assertPvicaContains(TestFiles.PVICA_RECORD_3945e2d1, "\"internal_series_id\":\"146180\"");
    }
    @Test
    void testSubtitles(){
        assertPvicaContains(TestFiles.PVICA_RECORD_3945e2d1, "\"has_subtitles\":\"false\"");
        // TODO: Create test for has_subtitles:true, with custom test file
    }
    @Test
    void testSubtitlesHearingImpaired(){
        assertPvicaContains(TestFiles.PVICA_RECORD_3945e2d1, "\"has_subtitles_for_hearing_impaired\":\"false\"");
        // TODO: Create test for has_subtitles_for_hearing_impaired:true, with custom test file
    }

    @Test
    void testTeletext(){
        assertPvicaContains(TestFiles.PVICA_RECORD_3945e2d1, "\"internal_is_teletext\":\"false\"");
        // TODO: Create test for internal_is_teletext:true, with custom test file
    }
    @Test
    void testShowviewcode(){
        assertPvicaContains(TestFiles.PVICA_RECORD_3945e2d1, "\"internal_showviewcode\":\"0\"");
        // TODO: Create test for internal_is_teletext:true, with custom test file
    }

    @Test
    void testPaddingSeconds(){
        assertPvicaContains(TestFiles.PVICA_RECORD_3945e2d1, "\"internal_padding_seconds\":\"15\"");
        // TODO: Create test for internal_is_teletext:true, with custom test file
    }

    @Test
    void testAccessMetadata(){
        assertPvicaContains(TestFiles.PVICA_RECORD_3945e2d1, "\"internal_access_individual_prohibition\":\"Nej\"," +
                                                 "\"internal_access_claused\":\"Nej\"," +
                                                 "\"internal_access_malfunction\":\"Nej\"");
        //TODO: Add test that contains internal_access_comments
    }

    @Test
    void testPid(){
        assertPvicaContains(TestFiles.PVICA_RECORD_3945e2d1, "\"pid\":\"109.1.4\\/3945e2d1-83a2-40d8-af1c-30f7b3b94390\"");
    }

    @Test
    void testProgramStructure(){
        assertPvicaContains(TestFiles.PVICA_RECORD_2b462c63, "\"internal_program_structure_missing_seconds_start\":\"0\"," +
                                                 "\"internal_program_structure_missing_seconds_end\":\"0\"");

        //TODO: add tests for fields 'holes' and 'overlaps' with a constructed test file.
    }

    @Test
    void testStartTime(){
        assertPvicaContains(TestFiles.PVICA_RECORD_3006e2f8, "\"startTime\":\"2022-02-28T17:29:55Z\"");
    }

    @Test
    void testEndTime(){
        assertPvicaContains(TestFiles.PVICA_RECORD_3006e2f8, "\"endTime\":\"2022-02-28T17:55:04Z\"");
    }

    @Test
    void testTemporalSearchWinterFields(){
        // Sanity check time zone conversions at https://www.worldtimebuddy.com/
        assertPvicaContains(TestFiles.PVICA_RECORD_3006e2f8, "\"temporal_start_time_da_string\":\"18:29:55\"," +
                                                                        "\"temporal_start_hour_da\":\"18\"," +
                                                                        "\"temporal_start_date_da_string\":\"2022-02-28\"," +
                                                                        "\"temporal_start_year\":\"2022\"," +
                                                                        "\"temporal_start_month\":\"2\"," +
                                                                        "\"temporal_start_time_da_date\":\"9999-01-01T18:29:55Z\"," +
                                                                        "\"temporal_start_day_da\":\"Monday\"");
        assertPvicaContains(TestFiles.PVICA_RECORD_3006e2f8, "\"temporal_end_time_da_string\":\"18:55:04\"," +
                                                                        "\"temporal_end_date_da_string\":\"2022-02-28\"," +
                                                                        "\"temporal_end_time_da_date\":\"9999-01-01T18:55:04Z\"," +
                                                                        "\"temporal_end_day_da\":\"Monday\"");
    }

    // Adjusted version of testTemporalSearchFields, where the month has been changed from April to February to
    // check if Danish summer/winter time is obeyed.
    @Test
    void testTemporalSearchSummer() throws IOException {
        String summer = Resolver.resolveUTF8String(TestFiles.PVICA_RECORD_3006e2f8)
                .replace("2022-02-28T", "2022-05-28T");
        File summerFile = Path.of(Resolver.resolveURL("ds-present-openapi_v1.yaml").getPath())
                .getParent()
                .resolve("3006e2f8_summer.xml")
                .toFile();
        Files.saveString(summer, summerFile);

        assertPvicaContains(summerFile.getAbsolutePath(), "\"temporal_start_time_da_string\":\"19:29:55\"," +
                "\"temporal_start_hour_da\":\"19\"," +
                "\"temporal_start_date_da_string\":\"2022-05-28\"," +
                "\"temporal_start_year\":\"2022\"," +
                "\"temporal_start_month\":\"5\"," +
                "\"temporal_start_time_da_date\":\"9999-01-01T19:29:55Z\"," +
                "\"temporal_start_day_da\":\"Saturday\"");
        assertPvicaContains(summerFile.getAbsolutePath(), "\"temporal_end_time_da_string\":\"19:55:04\"," +
                "\"temporal_end_date_da_string\":\"2022-05-28\"," +
                "\"temporal_end_time_da_date\":\"9999-01-01T19:55:04Z\"," +
                "\"temporal_end_day_da\":\"Saturday\"");
    }

    @Test
    void testNoNotes(){
        assertPvicaNotContains(TestFiles.PVICA_RECORD_b346acc8, "\"notes\":");
    }

    @Test
    void testUrlPreservica7()  {
        assertPvicaContains(TestFiles.PVICA_RECORD_a8aafb121, "\"file_id\":\"8946d31d-a81c-447f-b84d-ff80644353d2.mp4\"");
    }

    /* disabled as they are not represented in solr
    @Test
    void testOverlaps() {
        assertPvicaContains(TestFiles.PVICA_RECORD_b346acc8, "\"internal_program_structure_overlap_type_two_length_ms\":\"3120\"");
        assertPvicaContains(TestFiles.PVICA_RECORD_b346acc8, "\"internal_program_structure_overlap_type_one_length_ms\":\"1320\"");
        assertPvicaContains(TestFiles.PVICA_RECORD_b346acc8, "\"internal_program_structure_overlap_type_one_file1UUID\":\"f73b69da-2bc0-4e06-b19b-95f24756804e\"");
        assertPvicaContains(TestFiles.PVICA_RECORD_b346acc8, "\"internal_program_structure_overlap_type_two_file2UUID\":\"f73b69da-2bc0-4e06-b19b-95f24756804e\"");
    }*/

    @Test
    void testAccessConditions(){
        assertPvicaContains(TestFiles.PVICA_RECORD_b346acc8, "\"conditions_of_access\":\"placeholderCondition\"");
    }

    @Test
    void testNoBroadcasterInformation(){
        assertPvicaNotContains(TestFiles.PVICA_RECORD_0b3f6a54, "\"publishedOn\"");
    }

    @Test
    void testMTime() {
        assertPvicaContains(TestFiles.PVICA_RECORD_3006e2f8, "\"internal_storage_mTime\":\"");
    }
     
    @Test
    void testNoEmptyGenreSubField(){
        assertPvicaNotContains(TestFiles.PVICA_RECORD_53ce4817, "\"genre_sub\"");
    }
    
    @Test
    void testNoSpecificOrigin(){
        assertPvicaContains(TestFiles.PVICA_EMPTY_RECORD, "\"origin\"");
    }

    @Test
    void testCountFields(){
        assertPvicaContains(TestFiles.PVICA_RECORD_a8aafb121, "\"categories_count\":\"2\"");
        assertPvicaContains(TestFiles.PVICA_RECORD_a8aafb121, "\"notes_count\":\"2\"");
    }

    @Test
    void testLengthFields(){
        assertPvicaContains(TestFiles.PVICA_RECORD_a8aafb121, "\"title_length\":\"25\"");
        assertPvicaContains(TestFiles.PVICA_RECORD_a8aafb121, "\"notes_length\":\"389\"");
        assertPvicaContains(TestFiles.PVICA_RECORD_a8aafb121, "\"abstract_length\":\"15\"");
        assertPvicaContains(TestFiles.PVICA_RECORD_a8aafb121, "\"description_length\":\"374\"");

    }

    /**
     * Wrapper for {@link #assertMultiTestsThroughSchemaTransformation(String, Consumer[])} which verifies that the
     * transformed record contains the given {@code substring}.
     * @param recordFile the file to load, transform and test.
     * @param substring must be present in the transformed record.
     */
    public void assertPvicaContains(String recordFile, String substring) {
        assertMultiTestsThroughSchemaTransformation(recordFile,
                solrDoc -> assertTrue(solrDoc.contains(substring))
        );
    }

    /**
     * Wrapper for {@link #assertMultiTestsThroughSchemaTransformation(String, Consumer[])} which verifies that the
     * transformed record does not contain the given {@code substring}.
     * @param recordFile the file to load, transform and test.
     * @param substring must be present in the transformed record.
     */
    public void assertPvicaNotContains(String recordFile, String substring) {
        assertMultiTestsThroughSchemaTransformation(recordFile,
                solrDoc -> assertFalse(solrDoc.contains(substring))
        );
    }

    /**
     * Checks that internal test files are available and if not, logs a warning and returns.
     * <p>
     * If the check passes, the content of the file {@code record} is transformed using two XSLTs.
     * At first the XML record is transformed to Schema.org JSON and then the schema.org JSON is transformed to solr
     * documents and the given tests are performed on the result.
     * @param record file with a record that is to be transformed.
     * @param tests Zero or more tests to perform on the transformed record.
     */
    @SafeVarargs
    public final void assertMultiTestsThroughSchemaTransformation(String record, Consumer<String>... tests){
        if (!TestFileProvider.hasSomeTestFiles()) {
            return;  // ensureTestFiles takes care of logging is there are no internal test files
        }
        String solrString;
        try {
            solrString = TestUtil.getTransformedToSolrJsonThroughSchemaJsonWithPreservica7File(PRESERVICA2SCHEMAORG, record);
        } catch (Exception e) {
            throw new RuntimeException(
                    "Unable to fetch and transform '" + record + "' using XSLT '" + getXSLT() + "'", e);
        }
        Arrays.stream(tests).forEach(test -> test.accept(solrString));
    }



}
