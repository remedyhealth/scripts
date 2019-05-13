<?php
require_once('utilities.php');

$host = askQuestion('database host: ');
$port = askQuestion('database port: ');
$username = askQuestion('database username: ');
$password = askQuestion('database password: ');
$database = askQuestion('database name: ');

$connection = mysqli_connect($host, $username, $password, $database, $port);

// a query for retrieving all the relevant tables & columns in the database
$queryRelevantTablesAndColumns = "
    SELECT c.TABLE_NAME, c.COLUMN_NAME, c.COLUMN_TYPE
        FROM INFORMATION_SCHEMA.COLUMNS c
        WHERE TABLE_NAME IN
        (
            SELECT TABLE_NAME
                FROM INFORMATION_SCHEMA.TABLES
                WHERE TABLE_TYPE = 'BASE TABLE'
                AND TABLE_SCHEMA='{$database}'
        )
        AND (
            c.COLUMN_TYPE LIKE '%varchar%' OR
            c.COLUMN_TYPE LIKE '%text%' OR
            c.COLUMN_TYPE LIKE '%blob%' OR
            c.COLUMN_TYPE LIKE '%char%'
        )
";

// a query that looks in a provided table & column and uses a regex to search
// for http
// 1 table
// 2 column
$queryFindHttp = '
  SELECT %2$s FROM %1$s WHERE %2$s RLIKE \'[[:<:]]http[[:>:]]\'
';

echo "\n";
// a variable to hold a list of tables that contain no http matches
$noMatches = [];
// a variable to hold the list of columns to migrate, added by interaction
// with the command line user
$migrate = [];
// a variable to hold the list of columns not to migrate, added by interaction
// with the command line user
$blacklist = [];
// a variable to hold the list of all URLs found in db
$allHttpUrls = [];

// ask questions about what to output as we go
$showContent = askYesNoQuestion('Show content?');
$showAllContent = $showContent ? askYesNoQuestion('Show all content?') : false;
$showHttpUrl = askYesNoQuestion('Show HTTP URLS in real time?');
$showHttpsUrl = askYesNoQuestion('Show HTTPs URLS in real time?');
$showUrlsUnavailableOverHttps = askYesNoQuestion('Show URLs unavailable over HTTPS in real time?');
$markForMigration = askYesNoQuestion('Mark columns for migration as you go?');

$loopThruResultsForEachColumn = $showContent || $showHttpUrl || $showHttpsUrl || $showUrlsUnavailableOverHttps;

if (mysqli_connect_errno()) {
    echo "Failed to connect to MySQL: {${mysqli_connect_error()}}";
} else {
  // get a list of relevant columns
  if ($relevantTablesAndColumns = $connection->query($queryRelevantTablesAndColumns)) {
    echo "==================================================================\n";
    echo "= Found {$relevantTablesAndColumns->num_rows} matching database columns\n";
    echo "==================================================================\n";

    // for each column
    while ($relevantColumn = $relevantTablesAndColumns->fetch_assoc()) {
        $table = $relevantColumn['TABLE_NAME'];
        $column = $relevantColumn['COLUMN_NAME'];
        $tableColumn = $table . "." . $column;

        if (in_array($tableColumn, $blacklist) || isset($migrate[$tableColumn])) {
            // if this column is in the hardcoded list of ones to skip during
            // migrating, continue on to the next result
            continue;
        }

        // find all entires that have http in them with word boundries around it
        $foundHttp = $connection->query(sprintf($queryFindHttp, $table, $column));

        if ($foundHttp->num_rows) {
            echo "== Found {$foundHttp->num_rows} matches rows in {$table}.{$column}\n";
            echo "==================================================================\n";

            while ($loopThruResultsForEachColumn && ($stringWithHttp = $foundHttp->fetch_assoc())) {
                $content = $stringWithHttp[$column];
                if ($showContent) {
                    echo "=== Content from {$tableColumn}\n";
                    echo "==================================================================\n";
                    echo $content;
                    echo "==================================================================\n";
                }
                $matchUrls = findHttpUrlsInString($content);
                foreach ($matchUrls as $httpUrl) {
                    if ($showHttpUrl) {
                        echo "=== HTTP URL: {$httpUrl}\n";
                    }
                    $httpsUrl = replacementUrl($httpUrl);

                    if ($showHttpsUrl && $httpsUrl) {
                        echo "=== HTTPS URL {$httpsUrl}\n";
                    }

                    if ($showUrlsUnavailableOverHttps && !$httpsUrl) {
                        echo "=== HTTP URL not available over HTTPS: {$httpUrl}\n";
                    }
                }

                $allHttpUrls = array_merge($allHttpUrls, $matchUrls);
                $showAnother = $showAllContent ? true : askYesNoQuestion('Show another?');
                if (!$showAnother) {
                    break;
                }
            }
            // ask user what to do with this table?
            if ($markForMigration) {
                echo "==================================================================\n";
                if (askYesNoQuestion('Mark column for migration?')) {
                    array_push($migrate, [$table, $column]);
                } else {
                    array_push($blacklist, "{$tableColumn}");
                }
                echo "==================================================================\n";
            }
        } else {
            array_push($noMatches, "{$table}.{$column}");
        }

        // $foundHttp->close();
    }
    $relevantTablesAndColumns->close();
  }
}
$connection->close();

// ask questions about what results to output (& output those results when told)
askQuestionPrintArray("Show columns without matches?", $noMatches);
if ($markForMigration) {
    askQuestionPrintArray("Show columns marked for migration?", $migration);
    askQuestionPrintArray("Show columns marked not to migratate", $blacklist);
}

if ($loopThruResultsForEachColumn) {
    askQuestionPrintArray("Show all URLs?", $allHttpUrls);
    askQuestionPrintArray("Show all URLs unavailable over HTTPS?", getAllUrlsUnavailableOverHttps());
    askQuestionPrintArray("Show all URLs available over HTTPS?", getAllMappedUrls());
}

echo "\n";
