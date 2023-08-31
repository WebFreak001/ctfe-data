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
mixin template injectCTFEMixin(alias data)
{
	import ldc.attributes : section, assumeUsed;

	static immutable @assumeUsed @section("_ctfe_inject_" ~ typeof(data).stringof) typeof(data) datarow = data;
}

/// ditto
static void injectCTFE(alias data)()
{
	mixin injectCTFEMixin!(data);
}
