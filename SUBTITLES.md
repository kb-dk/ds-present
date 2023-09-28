# Temporal search

Experiments for temporal media in Solr with search results providing timestamps with search results. Primary case is for indexing speech-to-text results from radio- and television-material, e.g. subtitles& transcriptions.

## Idea 1: Existing plugin

The [Solr OCR Highlighting Plugin](https://dbmdz.github.io/solr-ocrhighlighting/0.8.3/) extends Solr with a mechanism for using external files with OCR-oriented data for indexing and retrieving spatial informations for words and phrases matching a query. This has the advantage of minimizing Solr index size overhead.

The idea was to change the code or hack around to use the plugin for temporal search in subtitles.

Further pondering led to abandoning this approach: The overhead of storing timestamps in Solr is fairly low, especially if those timestamps are at the sentence level, and the logistic requirement of having an external data provider for search is a hassle.

## Idea 2: Stock Solr Highlighting

We specify a timestamp tag that is unlikely to match any searches and insert tags directly in the text to index, then use the [Unified Highlighter](https://solr.apache.org/guide/solr/latest/query-guide/highlighting.html#unified-highlighter) for providing snippets that includes the tag by bumping `hl.fragsize` high enough.

Untested and off-the-bat idea, where the numbers are seconds:

```
ɣ119ɣ The quick brown fox ɣ122ɣ jumps over the ɣ124ɣ lazy dog.
```

Main problem with this hack are that the tags, e.g. `ɣ122ɣ` will be indexed:

1. The tags won't match plain searches due to the gamma (ɣ), but fuzzy searches for numbers will be practically unusable
2. Phrase searching across tags will require slopes > 0 to compensate for the extra terms

* **TODO:** The solution to #2 would be to index timetags with the same offset as the term that follows the tag.
* **TODO:** Check if storing can be avoided

Building on this, a better tag format might be to specify a maximum amount of seconds, e.g. 99999 (a bit more than a day) and add preceeding zeroes:

```
ɣ00119ɣ The quick brown fox ɣ00122ɣ jumps over the ɣ00124ɣ lazy dog.
```

This makes it possible to retrieve the text from the highlighter for a given time offset by range searching:
```
subtitles:["ɣ00120ɣ" TO "ɣ00180}
```

Looking at the SRT-format (for represneting subtitles) it seems that second granularity is too coarse, so maybe milliseconds instead of seconds?
```
ɣ00119123ɣ The quick brown fox ɣ00122456ɣ jumps over the ɣ00124789ɣ lazy dog.
```
Not as easy to read for humans, takes up more space in the index :-(


## Practical

The script `temporal2solr` takes care of converting text to timetagged format and producing a mock Solr document which is the indexed.

If handles 3 different timestamped input formatt: SRC, hms (`12:34:56 Foo`) and seconds (`123.45  Bar`). Activate with

```
FORMAT=seconds ./temporal2solr Flyvende_tallerken.txt
FORMAT=hms ./temporal2solr 5min*.txt
FORMAT=srt ./temporal2solr 0_q1ot8iv4.srt 
```

The base text output for the `text` field is milliseconds, aligned to 8 digits (a bit more than a day)


```
ɣ00000270ɣ Bare for at sige Vi skal passe godt på Danmarks
ɣ00003359ɣ grundvand. Det kan der ikke være to meninger om,
ɣ00005789ɣ og derfor er jeg også optaget af, at vi får taget
ɣ00008939ɣ det næste skridt. Men der er jo nogle skridt, vi har
```


After indexing a search can be performed and temporal sub hits extracted with

```
curl -s 'http://localhost:10007/solr/ds/select?indent=true&q=text:"der+er"&facet=false&hl.method=unified&hl.fl=text&hl.fragsize=500&hl.snippets=20' | grep '<em>der er</em>'
```
or more elaborate
```
Q="Danmark" ; curl -s 'http://localhost:10007/solr/ds/select' -d 'indent=true' -d 'facet=false' -d 'hl.method=unified' -d 'hl.fl=text' -d 'hl.fragsize=500' -d 'hl.snippets=20' -d "q=text:$Q" | jq -r .highlighting[].text[] | sed 's/^.\(.....\)\(...\)./\1.\2/' | grep '<em>[^<]*</em>'
```
which results in something like
```
00316.399 i <em>Danmark</em>, og prognosen går jo på, at vi får behov
00930.429 <em>Danmark</em> har gavn af speciallægerne.
00983.700 af <em>Danmark</em>, som plekter oplever lægedækningen
01292.459 på fordeling af de steder til de steder <em>Danmark</em>,
01315.329 dag forskellige steder i <em>Danmark</em>, hvor man har brug
01837.040 steder i <em>Danmark</em>, der mangler forskellige former
01877.939 det godt. Det gør mænd, men i <em>Danmark</em> har vi brug
01906.709 skal være læger i hele <em>Danmark</em>, og der skal være
```

## Reflection

### Caveats

This first take relies on the letter gamma (ɣ) and inserts timetags directly in the stored text.

* For plain text retrieval, the caller needs to filter the timetags from the result. It is solvable by having a parallel field without timetags, but that of course increases index size.
* Phrase searches are affected as timestamps might appear inside of sentences. It is technically solvable by adjusting offsets for the timetags. Currently it is unknown if this can be done without witing a custom Solr index plugin.

