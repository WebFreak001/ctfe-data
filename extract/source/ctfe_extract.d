module ctfe_extract;

import elf;
import elf.low;

/// Extracts all data of type `T` that has been injected into the executable at
/// CTFE using `injectCTFE` or `injectCTFEMixin` during the compilation cycle of
/// that executable. Ordering between modules is undefined, order within a
/// module is the same as lexically defined.
///
/// Currently only supported on the same architecture as the running
/// architecture. Only tested on linux.
T[] extractCTFEData(T, bool printWarnings = true)(string executableName)
{
	import std.algorithm : sort;
	import std.bitmanip : peek, Endian;
	import std.traits;

	static if (printWarnings)
		import std.stdio : stderr;

	ELF elf = ELF.fromFile(executableName);
	auto contents = elf.m_file[0 .. $];

	T[] rows;

	size_t[2][] translations;
	foreach (section; elf.sections)
	{
		if (section.type != SectionType.relocation)
			continue;

		size_t i = 0;

		while (i < section.size)
		{
			auto from = peek!(size_t, Endian.littleEndian)(section.contents, &i);
			auto info = peek!(size_t, Endian.littleEndian)(section.contents, &i);
			auto to = peek!(size_t, Endian.littleEndian)(section.contents, &i);
			translations ~= [from, to];
		}
	}

	auto sorted_rels = translations.sort!"a[0]<b[0]";

	U* lookupRelocatedPointer(U)(void* addr)
	{
		size_t[2] q;
		q[0] = cast(size_t)addr;
		auto eq = sorted_rels.equalRange(q);
		if (eq.empty)
			return null;
		return cast(U*)(contents.ptr + eq.front[1]);
	}

	foreach (section; elf.sections)
	{
		if (section.name != "_ctfe_inject_" ~ T.stringof)
			continue;

		rows ~= cast(T[])cast(void[])section.contents.dup;
		if (section.contents.length % T.sizeof != 0)
			assert(false, "type alignment does not match what is in the executable!");
		foreach (i, ref row; rows)
		{
			static foreach (mi, member; row.tupleof)
			{
				static if (is(typeof(member) == U[], U))
				{
					auto ptr = cast(void*)(section.address + member.offsetof + size_t.sizeof + i * T.sizeof);
					auto resolved = lookupRelocatedPointer!U(ptr);
					if (resolved)
					{
						row.tupleof[mi] = cast(typeof(member)) resolved[0 .. row.tupleof[mi].length].dup;
					}
					else
					{
						static if (printWarnings)
							stderr.writeln("failed to resolve member " ~ T.stringof ~ "." ~ member.stringof ~ " at address ", ptr);
						row.tupleof[mi] = null;
					}
				}
				else static if (!__traits(isPOD, typeof(member))
					|| isAssociativeArray!(typeof(member))
					|| isPointer!(typeof(member)))
					static assert(false, "cannot extract field " ~ T.stringof ~ "." ~ member.stringof ~ " of type " ~ typeof(member).stringof);
			}
		}
	}

	return rows;
}
