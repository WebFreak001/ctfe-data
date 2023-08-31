module app1;

import common;
import ctfe_inject;

mixin injectCTFEMixin!(ExamplePerson("Person from mixin", 1));

void main()
{
	injectCTFE!(ExamplePerson("Person inside main", 2));
}
