/* Assign a permanent SAS library */
libname spo_lib '/directory/'; 

/* Import the CSV file into the permanent library */
DATA spo_lib.spotify;
    INFILE '/spotify_cleaned.csv'
        DELIMITER = ',' 
        MISSOVER 
        DSD 
        FIRSTOBS=2 
        LRECL=32767;

    LENGTH track_id $22. 
           artists $400.    /*changed*/
           album_name $200. /*changed*/ 
           track_name $200. /*changed*/
           popularity duration_ms 8. 
           explicit $6. 
           danceability 8 energy 8 key 8 loudness 8 mode 8
           speechiness 8 acousticness 8 instrumentalness 8 liveness 8 valence 8 tempo 8 time_signature $12.
           track_genre $200.; 

    INPUT "Unnamed: 0"
          track_id $ 
          artists $ 
          album_name $ 
          track_name $ 
          popularity 
          duration_ms 
          explicit $ 
          danceability 
          energy 
          key 
          loudness 
          mode 
          speechiness 
          acousticness 
          instrumentalness 
          liveness 
          valence 
          tempo 
          time_signature 
          track_genre $;
RUN;

/* Observation 65900, ID:1kR4gIb7nGxHPI3D2ifs59 get deleted, only row with missing values */
data spo_lib.spotify;
   set spo_lib.spotify;
   if track_id = "1kR4gIb7nGxHPI3D2ifs59" then delete;
run;

/* Check for invalid characters, SAS can not work with non ASC-II characters like japanese language symbols, 
although songs with these symbols are important it is much harder to work with them so they have to be deleted*/

data spo_lib.spotify_cleaned;
    set spo_lib.spotify;
    
    array _chars[*] _character_;  /* Create an array of all character variables */
    invalid_row = 0;
    
    do i = 1 to dim(_chars);
        if prxmatch('/[^[:print:]]/', _chars[i]) then do;
            invalid_row = 1;
            leave;
        end;
    end;
    
    if invalid_row then delete;
run;

/* Handle outliers - Example: Remove tracks with duration_ms less than 60,000 (1 minute) */
data spo_lib.spotify_cleaned;
    set spo_lib.spotify_cleaned;
    if duration_ms < 60000 then delete;
run;

/* Create derived variables - Example: Extract hour from tempo, */
data spo_lib.spotify_cleaned;
    set spo_lib.spotify_cleaned;
    tempo_category = ifc(tempo >= 100, 'High',
                          ifc(tempo >= 80, 'Medium', 'Low'));
run;

/* Filter records based on popularity - Example: Keep tracks with popularity >= 50 */
data spo_lib.spotify_cleaned;
    set spo_lib.spotify_cleaned;
    if popularity >= 50;
run;

/* Creation of new data set of combined genres and succsecuent mer*/
*Step 1: Create a frequency table for the 'track_name' column;
proc freq data = spo_lib.spotify_cleaned noprint;
    tables track_name / out= WORK.freq_table; /*Frequency table sent to work folder*/
run;
/* Merge the frequency table with the original dataset */
proc sql;
    create table filtered_data as
    select a.*, b.count as name_count
    from spo_lib.spotify_cleaned as a
    left join freq_table as b
    on a.track_name = b.track_name;
quit;
/* Filter the data where the count is greater than 1 */
data spo_lib.final_filtered_data;
    set filtered_data;
    if name_count > 1;
run;

/* Creation of new data set of combined genres */
proc sort data= spo_lib.final_filtered_data; 
   by track_id; 
run;
/* Create a combined genres column */
data spo_lib.final_filtered_data_combined;
    set spo_lib.final_filtered_data;
    by track_id;

    length combined_genres $200;  /* Adjust the length to an appropriate value */
    
    retain combined_genres;

    if first.track_id then do;
        combined_genres = track_genre;
    end;
    else do;
        combined_genres = catx(';', combined_genres, track_genre);
    end;

    if last.track_id then output;

    /* Drop the original track_genre column */
    drop track_genre;

    /* Rename combined_genres to track_genre */
    rename combined_genres = track_genre;
run;
*Final step merging all;
proc sort data= spo_lib.spotify_cleaned nodupkey;
   by track_id;
run;
proc sort data= spo_lib.final_filtered_data_combined nodupkey;
   by track_id;
run;
data spo_lib.spotify_cleaned;
   merge spo_lib.spotify_cleaned(in=a) spo_lib.final_filtered_data_combined(in=b);
   by track_id;
   if b or first.track_id; /* Keep the row from small_data (b), or if it's the first occurrence of id in big_data (a)*/
run;

/* Change Order of variables and delete unecesarry colunms */
data spo_lib.spotify_cleaned;
    format track_id track_name popularity artists album_name duration_ms explicit danceability energy key loudness mode speechiness acousticness instrumentalness liveness valence tempo time_signature track_genre tempo_category; 
	set spo_lib.spotify_cleaned;
run;
data spo_lib.spotify_cleaned;
	set spo_lib.spotify_cleaned;
    keep track_id track_name popularity artists album_name duration_ms explicit danceability energy key loudness mode speechiness acousticness instrumentalness liveness valence tempo time_signature track_genre tempo_category;
run;

/* We do have an apple code. However, I did not work on the apple code for SAS, this is the code that I worked on. */
* linguist-vendored=false
*.sas linguist-detectable=true
*.sas linguist-language=SAS
