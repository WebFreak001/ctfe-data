module ctfe_extract;

import elf;
import elf.low;

private string hashTypeName(string s)
{
	// mirror with ctfe_inject.d
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

/// Extracts all data of type `T` that has been injected into the executable at
/// CTFE using `injectCTFE` or `injectCTFEMixin` during the compilation cycle of
/// that executable. Ordering between modules is undefined, order within a
/// module is the same as lexically defined.
///
/// Currently only supported on the same architecture as the running
/// architecture. Only tested on linux.
///
/// If the input data is not 16-byte aligned, a lot more data will be GC
/// allocated!
TRaw[] extractCTFEData(TRaw, bool printWarnings = true)(string executableName)
{
	import std.algorithm : endsWith, sort, startsWith;
	import std.bitmanip : Endian, peek;
	import std.traits;

	static if (printWarnings)
		import std.stdio : stderr;

	ELF elf = ELF.fromFile(executableName);
	auto contents = elf.m_file[0 .. $];

	align(16)
	static struct T { TRaw raw; }

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

	int numTypes;

	ELFSection typenames;

	foreach (section; elf.sections)
	{
		if (section.name == "_ctfeinj_types" || section.name == "__DATA,_ctfeinj_types")
		{
			typenames = section;
			continue;
		}

		if (!section.name.startsWith("_ctfeinj", "__DATA,_ctfeinj"))
			continue;
		numTypes++;
		if (!section.name.endsWith(hashTypeName(T.stringof)))
			continue;

		if (!section.contents.length)
			return null;

		if (section.contents.length % T.sizeof != 0)
			assert(false, "type alignment does not match what is in the executable!");
		rows ~= cast(T[])cast(void[])section.contents.dup;
		foreach (i, ref row; rows)
		{
			static foreach (mi, member; row.raw.tupleof)
			{
				static if (is(typeof(member) == U[], U))
				{
					auto ptr = cast(void*)(section.address + member.offsetof + size_t.sizeof + i * T.sizeof);
					auto resolved = lookupRelocatedPointer!U(ptr);
					if (resolved)
					{
						row.raw.tupleof[mi] = cast(typeof(member)) resolved[0 .. row.raw.tupleof[mi].length].dup;
					}
					else
					{
						static if (printWarnings)
							stderr.writeln("failed to resolve member " ~ TRaw.stringof ~ "." ~ member.stringof ~ " at address ", ptr);
						row.raw.tupleof[mi] = null;
					}
				}
				else static if (!__traits(isPOD, typeof(member))
					|| isAssociativeArray!(typeof(member))
					|| isPointer!(typeof(member)))
					static assert(false, "cannot extract field " ~ TRaw.stringof ~ "." ~ member.stringof ~ " of type " ~ typeof(member).stringof);
			}
		}
	}

	static if (printWarnings)
		if (!rows.length)
		{
			stderr.writeln("unable to find any data of type " ~ TRaw.stringof ~ " in executable (found ", numTypes, " other types total)");
			stderr.writeln("available types:");

			string[] types = cast(string[])cast(void[])typenames.contents;
			foreach (i, ref type; types)
			{
				auto ptr = cast(void*)(typenames.address + size_t.sizeof + i * T.sizeof);
				auto resolved = lookupRelocatedPointer!(immutable(char))(ptr);
				if (resolved)
					stderr.writeln("\t", resolved[0 .. type.length]);
			}

			stderr.writeln("tried ", hashTypeName(T.stringof));
		}

	static if (T.sizeof == TRaw.sizeof)
		return cast(TRaw[]) cast(void[]) rows;
	else
	{
		import std.algorithm : map;
		import std.array : array;

		return rows.map!"a.raw".array;
	}
}
