module reader;

import common;
import ctfe_extract;
import std.stdio;

void main(string[] args)
{
	foreach (row; extractCTFEData!ExamplePerson("./app1"))
		writeln("row: ", row);
}
