module app1;

import common;
import ctfe_inject;

mixin injectCTFEMixin!(ExamplePerson("Person from mixin", 1 | 0x420000));

void main()
{
	injectCTFE!(ExamplePerson("Person inside main", 2 | 0x420000));
}
