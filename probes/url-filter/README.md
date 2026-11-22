# Filtering traffic by URL

Perform fast and robust filtering of full URLs by managing URL filtering configurations.

## Overview

Perform fast and robust filtering of full URLs by managing URL filtering configurations.

Filtering requests by URL presents an efficiency challenge because real-world use of URL filters often involves testing against thousands, or even millions, of URLs.
To perform this filtering, the Network Extension framework's URL filtering API uses two steps:
1. A local _Bloom filter_ to rapidly make an initial decision about URLs that aren't in the filtering set
1. A configured Private Information Retrieval (PIR) server to consult for potential matches

The sample code project `SimpleURLFilter` demonstrates how to use both of these steps to create a working URL filter.

For more information, see the article [Filtering traffic by URL](https://developer.apple.com/documentation/networkextension/filtering-traffic-by-url)

## See also

* [Setting up a PIR server for URL filtering](https://developer.apple.com/documentation/networkextension/setting-up-a-pir-server-for-url-filtering)
* [Using the Bloom filter tool to configure a URL filter](https://developer.apple.com/documentation/networkextension/using-the-bloom-filter-tool)

