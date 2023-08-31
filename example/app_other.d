module app_other;

import common;
import ctfe_inject;

static foreach (i; 0 .. 10)
	mixin injectCTFEMixin!(ExamplePerson("other " ~ i.stringof, i + 1000));
