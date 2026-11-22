# Using the Bloom filter tool to configure a URL filter

Create the files a URL filter needs for its Bloom prefilter.

As described in [Filtering traffic by URL](https://developer.apple.com/documentation/networkextension/filtering-traffic-by-url), the [URL filters API](https://developer.apple.com/documentation/networkextension/url-filters) depends on a high-performance _Bloom filter_ to make an initial assessment of whether to permit a given URL request.
The `SimpleURLFilter` sample contains a built-in Bloom filter and a configuration for a PIR server that excludes a small list of URLs, like [https://example.com](https://example.com).
To create your own filters, the workspace also includes a command-line tool for creating Bloom filter datasets, `BloomFilterTool`.
Use this tool to create prefilter data for arbitrarily large datasets.

See the article [Using the Bloom filter tool to configure a URL filter](https://developer.apple.com/documentation/networkextension/using-the-bloom-filter-tool) for more information on building and running the Bloom filter tool.

## See also

* Filtering traffic by URL](https://developer.apple.com/documentation/networkextension/filtering-traffic-by-url)
* [Setting up a PIR server for URL filtering](https://developer.apple.com/documentation/networkextension/setting-up-a-pir-server-for-url-filtering)
