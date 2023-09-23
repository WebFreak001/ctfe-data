///
module ctfe_inject;

/// Injects the arbitrarily typed `data` argument into the compiled object file.
/// All injected values from all compiled object files in an executable can
/// later be extracted from the executable again, without the need to execute it,
/// by using the `:extractor` sub-package.
///
/// Injected data is grouped by type name (`typeof(data).stringof`), which does
/// not include any module name or scope. So make sure your data has a unique
/// type name if you don't want to accidentally mix with other code that uses
/// this library. Ideally include the name of your package in the type, such as
/// `struct MyPackageEntry { ... }`.
///
/// This can be simply called in CTFE / put anywhere in runtime code and emit at
/// CTFE by using the `injectCTFE` method, or it can be used on a declaration
/// level, like inside structs, etc., by using `mixin injectCTFEMixin!data;`
mixin template injectCTFEMixin(alias data, string avoid_cache1 = __FILE__, size_t avoid_cache2 = __LINE__)
{
	version (LDC)
		import ldc.attributes : section, assumeUsed;
	else version (GNU)
		import gcc.attributes : section, assumeUsed;
	else
		static assert(false, "unsupported compiler");

	private string hashTypeName(string s)
	{
		// mirror with ctfe_extract.d
		enum chars = "0123456789abcdef";
		import std.digest.crc;
		auto crc = crc32Of(s);
		return [
			chars[crc[0] >> 4], chars[crc[0] & 0xF],
			chars[crc[1] >> 4], chars[crc[1] & 0xF],
			chars[crc[2] >> 4], chars[crc[2] & 0xF],
			chars[crc[3] >> 4], chars[crc[3] & 0xF],
		];
	}

	version (OSX)
	{
		@assumeUsed @section("__DATA,_ctfeinj" ~ hashTypeName(typeof(data).stringof))
		static immutable typeof(data) datarow = data;
		@assumeUsed @section("__DATA,_ctfeinj_types")
		static immutable string typename = typeof(data).stringof ~ " -> " ~ hashTypeName(typeof(data).stringof);
	}
	else
	{
		@assumeUsed @section("_ctfeinj" ~ hashTypeName(typeof(data).stringof))
		static immutable typeof(data) datarow = data;
		@assumeUsed @section("__DATA,_ctfeinj_types")
		static immutable string typename = typeof(data).stringof ~ " -> " ~ hashTypeName(typeof(data).stringof);
	}
}

/// ditto
static void injectCTFE(alias data, string avoid_cache1 = __FILE__, size_t avoid_cache2 = __LINE__)()
{
	mixin injectCTFEMixin!(data, avoid_cache1, avoid_cache2);
}
