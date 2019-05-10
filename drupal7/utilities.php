<?php

/**
  * Asks the command line user a question and printing out an array if they say
  * yes
  *
  * @param string $question A yes/no question to ask the user on the command line
  * @param array $array The array to print out if the user answers yes
  * @return null
  */
function askQuestionPrintArray ($question, $array) {
  if (askYesNoQuestion($question)) {
      print_r($array);
  }
}

/**
  * Asks the command line user a question
  *
  * @param string $question A question to ask the user on the command line
  * @return string What the user typed
  */
function askQuestion ($question) {
  echo "{$question}";
  $handle = fopen ("php://stdin","r");
  $answer = trim(fgets($handle));
  fclose($handle);
  return $answer;
}

/**
  * Asks the command line user a yes/no question
  *
  * @param string $question A yes/no question to ask the user on the command line
  * @return boolean	true if the user answered y, false otherwise
  */
function askYesNoQuestion ($question) {
  $answer = askQuestion("{$question} (y/n): ");
  if (trim($answer) == 'y') {
      return true;
  } else {
      return false;
  }
}

// a hash of urls found to valid https urls when available
if (!is_array($mapUrls)) {
  $mapUrls = [];
}

/**
  * Checks if there is a cached HTTPS version of a URL
  *
  * @param string $url A url
  * @return boolean	true if is there is already a URL mapped to an HTTPS URL
  * false otherwise
  */
function isUrlMappedToHttpsUrl ($url) {
  global $mapUrls;
  return array_key_exists($url, $mapUrls);
}

/**
  * Adds an HTTPs version of a URL to the cache of HTTP to HTTPS URLs
  *
  * @param string $httpUrl A url
  * @return null
  */
function setUrlMappedToHttpsUrl ($httpUrl, $httpsUrl) {
  global $mapUrls;
  $mapUrls[$httpUrl] = $httpsUrl;
}

/**
  * Grabs an already cached an HTTPS version of a URL
  *
  * @param string $httpUrl A url
  * @return string The HTTPS url
  */
function getSavedHttpsUrl ($url) {
  global $mapUrls;
  return $mapUrls[$url];
}

/**
  * Grabs the full associative array of HTTP URLs to HTTPS URLs
  *
  * @return string[] An associative array where the key is the HTTP url and the
  * value is the HTTPS url
  */
function getAllMappedUrls () {
  global $mapUrls;
  return $mapUrls;
}

// a hash of urls not available over https
if (!is_array($unavailableOverHttps)) {
  $unavailableOverHttps = [];
}

/**
  * Checks if the input URL has already been confirmed to be unavailable over
  * HTTPS
  *
  * @param string $url A url
  * @return boolean	true if is we already have that URL mapped to an HTTPS url
  * false otherwise
  */
function isUrlMappedAsUnavailableOverHttps ($url) {
  global $unavailableOverHttps;
  return array_key_exists($url, $unavailableOverHttps);
}

/**
  * Adds a URL to the cache of URLs unavailable over HTTPS
  *
  * @param string $httpUrl A url
  * @return null
  */
function setUrlAsUnavailableOverHttps ($url) {
  global $unavailableOverHttps;
  $unavailableOverHttps[$url] = false;
}

/**
  * Returns an array of HTTP URLs not available over HTTPS
  *
  * @return string[] An array of HTTP urls that did not respond over HTTPS
  */
function getAllUrlsUnavailableOverHttps () {
  global $unavailableOverHttps;
  return array_keys($unavailableOverHttps);
}

/**
  * Makes an HTTPS URL out of an HTTP url
  *
  * @param string $url An http url
  * @return string An https url
  */
function makeHttpsVersionOfUrl($url) {
  return str_replace("http://","https://", $url);
}

/**
  * Finds the HTTPS version of an HTTP URL
  *
  * @param string $url An http url
  * @return string|false An HTTPS URL if available for the input URL, false
  * otherwise
  */
function replacementUrl ($url) {
  global $mapUrls, $unavailableOverHttps;
  if (isUrlMappedToHttpsUrl($url)) {
      return getSavedHttpsUrl($url);
  } else if (isUrlMappedAsUnavailableOverHttps($url)) {
      return false;
  } else {
      $httpsUrl = makeHttpsVersionOfUrl($url);
      if (isBerkeleyWellnessUrl($url) || isUrlGood($httpsUrl)) {
          setUrlMappedToHttpsUrl($url, $httpsUrl);
      } else {
          setUrlAsUnavailableOverHttps($url);
      }
      // recure to use initial logic on what to return in what circumstances
      return replacementUrl($url);
  }
}

/**
  * Checks if a URL is for a Berkeley Wellness domain or subdomain
  *
  * @param string $url A URL
  * @return boolean true if the URL is for Berkeley Wellness, false otherwise
  */
function isBerkeleyWellnessUrl ($url) {
  // if the URL begins with one of the below, then it's a bw URL
  // https?://admin.berkeleywellness.com
  // https?://alerts.berkeleywellness.com
  // https?://www.berkeleywellness.com
  // https?://berkeleywellness.com
  // https?://www.berkeleywellnessalerts.com
  // https?://www.wellnessletter.com
  $regex1 = '/^https?:\/\/((admin|alerts|www)\.)?berkeleywellness\.com/';
  $regex2 = '/^https?:\/\/www\.berkeleywellnessalerts\.com/';
  $regex3 = '/^https?:\/\/www\.wellnessletter\.com/';
  if (preg_match($regex1, $url) ||
      preg_match($regex2, $url) ||
      preg_match($regex3, $url)
  ) {
    return true;
  } else {
    return false;
  }
}

/**
  * Checks if a URL responds to requests with a good status code
  *
  * @param string $url A URL
  * @param int $timeout Optional parameter defaults to 5 and is used for how
  * long to wait for a response
  * @param boolean $echoResult Optional paramater default to false and is used
  * to decide if to echo out the whether the response was good and what status
  * code came back
  * @return boolean true if the URL is good and false if it is bad and either
  * did not respond or responded with a status code of 400 or higher
  */
function isUrlGood ($url, $timeout = 5, $echoResult = false) {
  $ch = curl_init();
  curl_setopt($ch, CURLOPT_URL, $url);
  curl_setopt($ch, CURLOPT_HEADER, TRUE);
  curl_setopt($ch, CURLOPT_NOBODY, TRUE);
  curl_setopt($ch, CURLOPT_RETURNTRANSFER, TRUE);
  curl_setopt($ch, CURLOPT_TIMEOUT, $timeout);

  $head = curl_exec($ch);
  $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
  curl_close($ch);

  if(!$head) {
    if ($echoResult) {
      echo "bad \n";
    }
    return FALSE;
  }

  if($httpCode < 400) {
    if ($echoResult) {
      echo "good {$httpCode} \n";
    }
    return TRUE;
  } else  {
    if ($echoResult) {
      echo "bad {$httpCode} \n";
    }
    return FALSE;
  }
}

/**
  * Finds all HTTP URLs in a string and replaces them with HTTPS URLs where
  * valid
  *
  * @param string $content The content that might contain HTTP URLs
  * @return string The content modified to update HTTP URLs to HTTPS where
  * those URLs either respond to requests with a good status code or are to a
  * whitelist set of domains
  */
function replaceHttpForHttpsInContent($content) {
  $migratedContent = $content;
  $matchUrls = findHttpUrlsInString($content);
  foreach ($matchUrls as $httpUrl) {
    $httpsUrl = replacementUrl($httpUrl);
    if ($httpsUrl) {
        $migratedContent = str_replace($httpUrl, $httpsUrl, $migratedContent);
    } else {
        echo "Unavailable over https: {$httpUrl}\n";
    }
  }
  return $migratedContent;
}

/**
  * Finds all HTML anchors in a string and do stuff
  *
  * @param string $content The content that might contain HTTP URLs
  * @return string The content modified to update
  */
function changeAnchorTagsInContent($content) {
  $migratedContent = $content;
  $matchTags = findAnchorsInString($content);
  foreach ($matchTags as $tag) {
    $attributes = findAnchorsAttributes($tag);
    $opensInNewWindow = (array_key_exists('target', $attributes) && $attributes['target'] == "_blank");
    if (!$opensInNewWindow) {
      continue;
    }

    preg_match('/^https?:\/\//', $attributes['href'], $matchesHttp);
    $isAbsoluteUrl = !empty($matchesHttp);
    preg_match('/^<\?php\s/', $attributes['href'], $matchesPhp);
    $isDynamic = !empty($matchesPhp);
    if ((!$isAbsoluteUrl && !$isDynamic) || isBerkeleyWellnessUrl($attributes['href'])) {
      continue;
    }

    $attributes['rel'] = "noopener";
    $newTag = makeAnchorTag($attributes);

    $migratedContent = str_replace($tag, $newTag, $migratedContent);
  }
  return $migratedContent;
}

/**
  * Finds all HTTP URLs in a string
  *
  * @param string $string The content to search for HTTP links
  * @return string[] An array of HTTP URLs found in the content
  */
function findHttpUrlsInString ($string) {
  preg_match_all('/\b(http:\/\/[^\s"\']+)/', $string, $matches);
  return $matches[1];
}

/**
  * Finds all anchor tags in a string
  *
  * @param string $string The content to search for HTTP links
  * @return string[] An array of HTTP URLs found in the content
  */
function findAnchorsInString ($string) {
  preg_match_all('/(<a\s([^><}]*(<\?php\s[^>]*\?>)?[^><]*)*>)/', $string, $matches);
  return $matches[1];
}

/**
  * Changes all attributes in an anchor tag into an associative array
  *
  * @param string $string A string version of an anchor tag
  * @return string[] An associative array of attributes from the HTML tag
  */
function findAnchorsAttributes ($string) {
  $attributesHash = [];
  preg_match_all('/([^\s]+)=("(.*?)")?/', $string, $result);
  foreach (array_keys($result[0]) as $key) {
    $attribute = $result[1][$key];
    $value = $result[3][$key];
    $attributesHash[$attribute] = $value;
  }
  return $attributesHash;
}

function makeAnchorTag ($attributes) {
  $pieces = [];
  foreach($attributes as $attribute => $value) {
    array_push($pieces, "{$attribute}=\"{$value}\"");
  }
  $attributeString = implode(" ", $pieces);
  return "<a {$attributeString}>";
}