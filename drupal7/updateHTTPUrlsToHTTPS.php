<?php
require_once('utilities.php');

$host = askQuestion('database host: ');
$password = askQuestion('database port: ');
$username = askQuestion('database username: ');
$password = askQuestion('database password: ');
$database = askQuestion('database name: ');

$connection = mysqli_connect($host, $username, $password, $database, $port);

// a query that looks in a provided table & column and uses a regex to search
// for http
// 1 table
// 2 column to be set
// 3 columns used to identify line uniquely
$queryFindHttp = '
  SELECT %2$s, %3$s FROM %1$s WHERE %2$s RLIKE \'[[:<:]]http[[:>:]]\'
';

// 1 table
// 2 set
// 3 content
// 4 where
$updateContent = '
  UPDATE %1$s SET %2$s = \'%3$s\' WHERE %4$s
';

echo "\n";

// tables and columns to migrate and how to identify unique rows in them
$migrations = [
    "block_custom" => ["set" => "body", "where" => ["bid"]],
    "field_data_body" => ["set" => "body_value", "where" => ["revision_id"]],
    "field_data_field_body_link_intel" => ["set" => "field_body_link_intel_value", "where" => ["revision_id"]],
    "field_data_field_description" => ["set" => "field_description_value", "where" => ["revision_id"]],
    "field_data_field_note_description" => ["set" => "field_note_description_value", "where" => ["revision_id"]],
    "field_data_field_photo_source" => ["set" => "field_photo_source_value", "where" => ["revision_id"]],
    "field_data_field_photo_url" => ["set" => "field_photo_url_value", "where" => ["revision_id"]],
    "field_data_field_redirect_url" => ["set" => "field_redirect_url_value", "where" => ["field_redirect_url_value"]],
    "field_data_field_slide_photo_source" => ["set" => "field_slide_photo_source_value", "where" => ["revision_id"]],
    "field_data_field_slide_photo_url" => ["set" => "field_slide_photo_url_value", "where" => ["revision_id"]],
    "field_data_field_social_image" => ["set" => "field_social_image_value", "where" => ["revision_id"]],
    "link_keywords" => ["set" => "keyword_url", "where" => ["kid"]],
    "menu_links" => ["set" => "link_path", "where" => ["mlid"]],
    "profile_value" => ["set" => "value", "where" => ["fid", "uid"]],
    "redirect" => ["set" => "redirect", "where" => ["rid"]],
    "variable" => ["set" => "value", "where" => ["name"]], // serialized
    "views_display" => ["set" => "display_options", "where" => ["vid", "id"]], // serialized, but also has PHP and html
    // "watchdog" => ["set" => "location", "where" => "wid"],
    // "watchdog" => ["set" => "referer", "where" => "wid"]
];

// special serialized columns
$serialized = [
    "variable.value" => true,
    "views_display.display_options" => true,
];

// ask questions about what to output as we go
$isDryRun = !askYesNoQuestion('Migrate instead of doing a dry run?');
$updateCount = 0;

if (mysqli_connect_errno()) {
  echo "Failed to connect to MySQL: {${mysqli_connect_error()}}";
} else {
    foreach ($migrations as $table => $columns) {
        $select = sprintf(
            $queryFindHttp,
            $table,
            $columns['set'],
            implode(', ', $columns['where'])
        );
        $foundHttp = $connection->query($select);
        if ($foundHttp->num_rows) {
            echo "== Found {$foundHttp->num_rows} matches rows in {$table}.{$columns["set"]} {$type} \n";
            echo "==================================================================\n";
            $rowCount = 1;
            while ($stringWithHttp = $foundHttp->fetch_assoc()) {
                $content = $stringWithHttp[$columns['set']];

                if (array_key_exists("{$table}.{$columns["set"]}", $serialized)) {
                    echo "this is serialized";
                    $unserializedContent = unserialize($content);
                    if (is_string($unserializedContent)) {
                        $migratedContent = replaceHttpForHttpsInContent($unserializedContent);
                    } else if (is_array($unserializedContent)) {
                        // loop over the values, and by reference so updates to
                        // the variable created for the loop ($value1 & $value2)
                        // update the corresponding value in $unserializedContent
                        foreach ($unserializedContent as $key1 => &$value1) {
                            if(is_array($value1)) {
                                foreach ($value1 as $key2 => &$value2) {
                                    if (preg_match('/^php/', $key2) &&
                                        array_key_exists("php_output", $value2) &&
                                        is_string($value2["php_output"])
                                    ) {
                                        // if key2 is like php, php_1, php2, run migration over content
                                        $value2["php_output"] = replaceHttpForHttpsInContent($value2["php_output"]);
                                    }
                                }
                            }
                        }
                        $migratedContent = $unserializedContent;
                    }
                    $migratedContent = serialize($migratedContent);
                } else {
                    $migratedContent = replaceHttpForHttpsInContent($content);
                }
                echo "{$rowCount} of {$foundHttp->num_rows} ";
                if ($migratedContent !== $content) {
                    $whereConditionals = [];
                    foreach ($columns['where'] as $column) {
                        $escapedValue = mysqli_real_escape_string($connection, $stringWithHttp[$column]);
                        $conditional = "{$column} = '{$escapedValue}'";
                        array_push($whereConditionals, $conditional);
                    }
                    $where = implode(" AND ", $whereConditionals);
                    $escapedContent = mysqli_real_escape_string($connection, $migratedContent);
                    $update = sprintf($updateContent, $table, $columns['set'], $escapedContent, $where);
                    if ($isDryRun) {
                        // echo out the update statement
                        echo $update;
                    } else {
                        // run the update statement
                        if ($connection->query($update) === TRUE) {
                            echo "Record updated successfully";
                            $updateCount++;
                        } else {
                            echo "Error updating record: {$connection->error}";
                        }
                    }
                } else {
                    echo "Nothing to update";
                }
                echo "\n";
                $rowCount++;
            }
        }
    }
}

$connection->close();

echo "{$updateCount} records updated\n";
// ask questions about what results to output (& output those results when told)
askQuestionPrintArray("Show all URLs unavailable over HTTPS?", getAllUrlsUnavailableOverHttps());
askQuestionPrintArray("Show all URLs available over HTTPS?", getAllMappedUrls());

echo "\n";
