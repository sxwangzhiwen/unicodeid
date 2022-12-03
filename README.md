# unicodeid
Zig unicode identifier

This is used for unicode identifier.

In the UTF-8 string, judge UTF-8 encoding derived Property.


Get and generate data from

https://www.unicode.org/Public/UCD/latest/ucd/DerivedCoreProperties.txt

# Features
* isID_Start() UTF-8 Derived Property is ID_Start
* isID_Continue() UTF-8 Derived Property is ID_Continue
* isXID_Start() UTF-8 Derived Property is XID_Start
* isXID_Continue() UTF-8 Derived Property is XID_Continue

# Example

```
const unicodeid=@import("unicodeid.zig");
var i:usize=0;
const utf8str="\x65\xCD\xBA\xE0\xA0\x96\xF0\x91\xB5\xA1..";
var j:bool = unicodeid.isID_Start(utf8str,&i).? ;
```

See examples.zig for more examples.
