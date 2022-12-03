const unicodeid=@import("unicodeid.zig");
const expect=@import("std").testing.expect;
test {
	var i:usize=0;
	const utf8str="\x65\xCD\xBA\xE0\xA0\x96\xF0\x91\xB5\xA1..";
	var j:bool=undefined;
	j=unicodeid.isID_Start(utf8str,&i).? ;
	try expect(j);
	try expect(!unicodeid.isXID_Start(utf8str,&i).?);
	try expect(unicodeid.isID_Continue(utf8str,&i).?);
	try expect(unicodeid.isXID_Continue(utf8str,&i).?);
}