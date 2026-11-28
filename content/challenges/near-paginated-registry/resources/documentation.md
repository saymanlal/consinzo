# Background: pagination in NEAR view methods

- View methods are free to call but still execute with a gas limit, and their result must fit in a response. A method that returns "everything" eventually stops working as the contract grows.
- NEAR standards use a `from_index` / `limit` pair for enumeration methods (for example `nft_tokens(from_index, limit)`). Clients fetch page after page, advancing `from_index` by the number of items received, until a page comes back empty or short.
- Good pagination has three properties: the work per call is bounded by a maximum page size, out-of-range requests return an empty page rather than failing, and consecutive pages neither overlap nor skip items.
- `LookupMap` cannot be iterated. Ordered access is built from a counter plus index-keyed entries; secondary orderings (such as "items of one owner") need their own index maintained at write time.
