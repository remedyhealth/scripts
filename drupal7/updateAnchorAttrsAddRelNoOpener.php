<?php
require_once('utilities.php');

$host = askQuestion('database host: ');
$port = askQuestion('database port: ');
$username = askQuestion('database username: ');
$password = askQuestion('database password: ');
$database = askQuestion('database name: ');

$connection = mysqli_connect($host, $username, $password, $database, $port);

// a query that looks in a provided table & column and uses a regex to search
// for anchor tags
// 1 table
// 2 column to be set
// 3 columns used to identify line uniquely
$queryFindAnchors = '
  SELECT %2$s, %3$s FROM %1$s WHERE %2$s RLIKE \'<a [^>]*>\'
';

// 1 table
// 2 set
// 3 content
// 4 where
$updateContent = '
  UPDATE bw.%1$s SET %2$s = \'%3$s\' WHERE %4$s
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
      $queryFindAnchors,
      $table,
      $columns['set'],
      implode(', ', $columns['where'])
    );
    $foundHttp = $connection->query($select);
    if ($foundHttp->num_rows) {
      echo "== Found {$foundHttp->num_rows} matches rows in {$table}.{$columns["set"]} {$type} \n";
      echo "==================================================================\n";
      $rowCount = 1;
      while ($stringWithAnchor = $foundHttp->fetch_assoc()) {
        $content = $stringWithAnchor[$columns['set']];
        $migratedContent = changeAnchorTagsInContent($content);
        echo "{$rowCount} of {$foundHttp->num_rows} ";
        if ($migratedContent !== $content) {
            $whereConditionals = [];
            foreach ($columns['where'] as $column) {
                $escapedValue = mysqli_real_escape_string($connection, $stringWithAnchor[$column]);
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

echo "\n";
