
const std=@import("std");
const Allocator=std.mem.Allocator;
const expect=std.testing.expect;
const expectError=std.testing.expectError;
const expectEqualSlices=std.testing.expectEqualSlices;
const sort=std.sort;
const print=std.debug.print;

const IDtype=enum{
	IDStart,
	IDContinue,
	XIDStart,
	XIDContinue,
};
const IDSpec=struct{
	idt:IDtype,
	idstr:[]const u8,
};
const IDSpecArr:[4]IDSpec=.{
	.{.idt=.IDStart,.idstr="; ID_Start #"},
	.{.idt=.IDContinue,.idstr="; ID_Continue #"},
	.{.idt=.XIDStart,.idstr="; XID_Start #"},
	.{.idt=.XIDContinue,.idstr="; XID_Continue #"},
};

const IDvalue=[2]u32;
const IDmap=std.StringArrayHashMap(IDvalue);

fn getHex(str:[]const u8,start:*usize) ?u32{
	var r:u32=0;
	const s=start.*;
	while(start.*<str.len):(start.*+=1){
		var i=switch(str[start.*]){
			'0'...'9' => |v| v-0x30,
			'A'...'F' => |v| v-0x41+10,
			'a'...'f' => |v| v-0x61+10,
			else => if(s==start.*) return null else break,
		};
		r=r*0x10+i;
	}
	return r;
}
test "getHex" {
	var i:usize=0;
	try expect(getHex("A05..",&i).?==0xA05);
	try expect(i==3);
	i=2;
	try expect(getHex("..a4b3..",&i).?==0xa4b3);
	try expect(i==6);
	i=3;
	try expect(getHex("...HM64,",&i)==null);
}

fn str_to_IDvalue(str:[]const u8) IDvalue{
	var r:IDvalue=.{0,0};
	var i:usize=0;
	r[0]=getHex(str,&i).?;
	r[0]=codepoint_to_utf8(r[0]) catch unreachable;
	if(str[i]!='.'){
		return r;
	}
	i+=2;
	r[1]=getHex(str,&i).?;
	r[1]=codepoint_to_utf8(r[1]) catch unreachable;
	return r;
}
test "str_to_IDvalue" {
	var r=str_to_IDvalue("0041..005A    ");
	try expect(r[0]==0x41);
	try expect(r[1]==0x5A);
	r=str_to_IDvalue("02AF          ");
	try expect(r[0]==0xCAAF);
	try expect(r[1]==0);
}

fn fillIDmap(idmap:*IDmap,buf:[]const u8,idt:IDtype) !void{
	const SPECSTARTPOST=14;
	const SPECENDPOST=30;
	var spec:[]const u8=undefined;
	for(IDSpecArr)|v|{
		if(idt==v.idt){
			spec=v.idstr;
			break;
		}
	}
	var linebegin:usize=0;
	while(linebegin<buf.len){
		var ls=linebegin+SPECSTARTPOST;
		if(ls+spec.len>buf.len){
			break; // last line
		}
		if(stringeql(buf[ls..ls+spec.len],spec)){
			var k=buf[linebegin..linebegin+SPECSTARTPOST];
			var v=str_to_IDvalue(k);
			try idmap.*.put(k,v);
			linebegin+=SPECENDPOST;
		}
		while(linebegin<buf.len):(linebegin+=1){
			 if(buf[linebegin]=='\n'){
				linebegin+=1;
				break;
			 }
		}
	}
}
inline fn stringeql(str1:[]const u8,str2:[]const u8) bool{
	const l=str1.len;
	if(l!=str2.len) return false;
	for(str1) |v,i|{
		if(v!=str2[i]){
			return false;
		}
	}
	return true;
}

var testal=std.testing.allocator;
test "fillIDmap" {
	var j1=IDmap.init(testal);
	try fillIDmap(&j1,teststr,.IDStart);
	var it=j1.iterator();
	it.reset();
	var e1=it.next().?;
	try expectEqualSlices(u8,e1.key_ptr.*,"0041..005A    ");
	try expect(e1.value_ptr.*[0]==0x41);
	try expect(e1.value_ptr.*[1]==0x5A);
	_=it.next().?;
	_=it.next().?;
	e1=it.next().?;
	try expectEqualSlices(u8,e1.key_ptr.*,"00B5          ");
	try expect(e1.value_ptr.*[0]==0xC2B5);
	try expect(e1.value_ptr.*[1]==0);
	try expect(it.len==13);
	j1.deinit();
	var j2=IDmap.init(testal);
	try fillIDmap(&j2,teststr,.IDContinue);
	it=j2.iterator();
	it.reset();
	try expect(it.len==16);
	j2.deinit();
	var j3=IDmap.init(testal);
	try fillIDmap(&j3,teststr,.XIDStart);
	it=j3.iterator();
	it.reset();
	try expect(it.len==13);
	j3.deinit();
	var j4=IDmap.init(testal);
	try fillIDmap(&j4,teststr,.XIDContinue);
	it=j4.iterator();
	it.reset();
	try expect(it.len==16);
	j4.deinit();
}

const IDmaps=struct{
	IDS:IDmap,
	IDC:IDmap,
	XIDS:IDmap,
	XIDC:IDmap,
	common:IDmap,
	fn init(al:Allocator) IDmaps{
		return .{
			.IDS=IDmap.init(al),
			.IDC=IDmap.init(al),
			.XIDS=IDmap.init(al),
			.XIDC=IDmap.init(al),
			.common=IDmap.init(al),
		};
	}
	fn deinit(self:*IDmaps) void{
		self.IDS.deinit();
		self.IDC.deinit();
		self.XIDS.deinit();
		self.XIDC.deinit();
		self.common.deinit();

	}
};
//const in:[]const u8=undefined;
fn fillIDmaps(in:[]const u8,map:*IDmaps) !void{
	try fillIDmap(&map.*.IDS,in,.IDStart);
	try fillIDmap(&map.*.IDC,in,.IDContinue);
	try fillIDmap(&map.*.XIDS,in,.XIDStart);
	try fillIDmap(&map.*.XIDC,in,.XIDContinue);
	var temp=try map.*.IDS.clone();
	defer temp.deinit();
	var it=temp.iterator();
	it.reset();
	while(it.next()) |entry| {
		const k=entry.key_ptr.*;
		const v=entry.value_ptr.*;
		if(map.*.IDC.get(k)!=null and map.*.XIDS.get(k)!=null and map.*.XIDC.get(k)!=null){
			try map.*.common.put(k,v);
			_=map.*.IDS.orderedRemove(k);
			_=map.*.IDC.orderedRemove(k);
			_=map.*.XIDS.orderedRemove(k);
			_=map.*.XIDC.orderedRemove(k);
		}
	}
}

test "fillIDmaps" {
	var i=IDmaps.init(testal);
	defer i.deinit();
	try fillIDmaps(teststr,&i);
	const s1=i.IDS.unmanaged.entries.slice();
	const s2=i.IDC.unmanaged.entries.slice();
	const s3=i.XIDS.unmanaged.entries.slice();
	const s4=i.XIDC.unmanaged.entries.slice();
	const s5=i.common.unmanaged.entries.slice();
	try expect(s1.len==1);
	try expect(s2.len==4);
	try expect(s3.len==1);
	try expect(s4.len==4);
	try expect(s5.len==12);
	try expectEqualSlices(u8,s1.items(.key).ptr[0],"0294          ");
	try expectEqualSlices(u8,s2.items(.key).ptr[0],"0030..0039    ");
	try expectEqualSlices(u8,s3.items(.key).ptr[0],"0296          ");
	try expectEqualSlices(u8,s4.items(.key).ptr[0],"0030..0039    ");
	try expectEqualSlices(u8,s5.items(.key).ptr[0],"0041..005A    ");
}

const IDitem=union(enum){
	r:[2]u32,	//range , equal to r[0]...r[1]
	s:u32,		//single
};
const IDitemtypestr=
\\pub const IDitem=union(enum){
\\	r:[2]u32,	//range , equal to r[0]...r[1]
\\	s:u32,		//single
\\};
\\
\\
;

fn writeIDmapbody(m:IDmap,buf:*std.ArrayList(u8)) !void{
	var it=m.iterator();
	it.reset();
	while(it.next()) |entry| {
		var k=entry.key_ptr.*;
		var v=entry.value_ptr.*;
		if(v[1]==0){
			try buf.*.writer().print("    .{{.s=0x{X}}},            //{s}\n",.{v[0],k});
		}else{
			try buf.*.writer().print("    .{{.r=.{{0x{X},0x{X}}}}},  //{s}\n",.{v[0],v[1],k});
		}
	}
}
fn writeIDmap(m:IDmap,buf:*std.ArrayList(u8),idt:IDtype,iscommon:bool) !void{
	var head=switch(idt) {
		.IDStart => "ID_Start",
		.IDContinue => "ID_Continue",
		.XIDStart => "XID_Start",
		.XIDContinue => "XID_Continue",
	};
	if(iscommon){
		head="IDXID_Common";
	}
	try buf.*.writer().print("pub const {s}=[_]IDitem{{\n",.{head});
	try writeIDmapbody(m,buf);
	try buf.*.appendSlice("};\n\n");
}

fn writeIDmaps(ms:IDmaps,buf:*std.ArrayList(u8)) !void{
	try buf.*.appendSlice(IDitemtypestr);
	try writeIDmap(ms.IDS,buf,.IDStart,false);
	try writeIDmap(ms.IDC,buf,.IDContinue,false);
	try writeIDmap(ms.XIDS,buf,.XIDStart,false);
	try writeIDmap(ms.XIDC,buf,.XIDContinue,false);
	try writeIDmap(ms.common,buf,.IDStart,true);
}

test "writeIDmaps" {
	var i=IDmaps.init(testal);
	defer i.deinit();
	try fillIDmaps(teststr,&i);
	var buf=std.ArrayList(u8).init(testal);
	defer buf.deinit();
	try writeIDmaps(i,&buf);
	print("\n{s}\n",.{buf.items});
}

fn getline(buf:[]const u8,linestart:*usize) []const u8{
	const s=linestart.*;
	while(linestart.*<buf.len):(linestart.*+=1){
		if(buf[linestart.*]=='\r'){
			if(buf[linestart.*+1]=='\n'){
				linestart.*+=2;
			}else{
				linestart.*+=1;
			}
			break;
		}else{
			if(buf[linestart.*]=='\n'){
				linestart.*+=1;
				break;
			}
		}
	}
	return buf[s..linestart.*];
}
pub fn main() !void{
	var arena=std.heap.ArenaAllocator.init(std.heap.page_allocator);
	defer arena.deinit();
	const al=arena.allocator();

	const MAXFILELEN:usize=0x10_0000*16; //16M
	var home=std.fs.cwd();
	defer home.close();
	var infile=try home.openFile("DerivedCoreProperties.txt",.{});
	defer infile.close();
	var in=try infile.readToEndAlloc(al,MAXFILELEN);

	var i=IDmaps.init(al);
	defer i.deinit();
	try fillIDmaps(in,&i);

	var out=std.ArrayList(u8).init(al);
	defer out.deinit();

	try out.appendSlice("//get from https://www.unicode.org/Public/UCD/latest/ucd/DerivedCoreProperties.txt");
	var ls:usize=0;
	try out.writer().print("//{s}",.{getline(in,&ls)});
	try out.writer().print("//{s}\n",.{getline(in,&ls)});

	try writeIDmaps(i,&out);
	
    var outfile=try home.createFile("unicodeiddata.zig",.{});
    defer outfile.close();
    try outfile.writeAll(out.items);

}

//codepoint 	UTF-8
//0AAA_AAAA 	0AAA_AAAA
//BBB_BBAA_AAAA 	110B_BBBB 10AA_AAAA
//CCCC_BBBB_BBAA_AAAA 	1110_CCCC 10BB_BBBB 10AA_AAAA
//D_DDCC_CCCC_BBBB_BBAA_AAAA 	1111_0DDD 10CC_CCCC 10BB_BBBB 10AA_AAAA

const unicodeIDerr=error{
	not_codepoint,
};
fn codepoint_to_utf8(cp:u32) !u32{
	switch(cp) {
		0...0b0111_1111 => {
			return cp;
		},
		0b1000_0000...0b111_1111_1111 => {
			const a= (cp & 0b11111_000000)<<2|0b11000000_10000000;
			const b= cp & 0b00000_111111;
			return a | b;
		},
		0b1000_0000_0000...0b1111_1111_1111_1111 => {
			const a= (cp & 0b1111_000000_000000)<<4 | 0b11100000_10000000_10000000;
			const b1= (cp & 0b111111_000000)<<2;
			const b2= cp & 0b111111;
			return a | b1 | b2;
		},
		0b1_0000_0000_0000_0000...0b1_0000_1111_1111_1111_1111 => {
			const a= (cp & 0b111_000000_000000_000000)<<6 | 0b11110000_10000000_10000000_10000000;
			const b1= (cp & 0b111111_000000_000000)<<4;
			const b2= (cp & 0b111111_000000)<<2;
			const b3= cp & 0b111111;
			return a | b1 | b2 | b3;
		},
		else => {
			return unicodeIDerr.not_codepoint;
		}
	}
}

test "codepoint_to_utf8" {
	try expect(try codepoint_to_utf8(0)==0);
	try expect(try codepoint_to_utf8(27)==27);
	try expect(try codepoint_to_utf8(127)==127);
	try expect(try codepoint_to_utf8(0x80)==0xC280);
	try expect(try codepoint_to_utf8(0x2AF)==0xCAAF);
	try expect(try codepoint_to_utf8(0x7FF)==0xDFBF);
	try expect(try codepoint_to_utf8(0x800)==0xE0A080);
	try expect(try codepoint_to_utf8(0x1A7D)==0xE1A9BD);
	try expect(try codepoint_to_utf8(0xFFFF)==0xEFBFBF);
	try expect(try codepoint_to_utf8(0x10000)==0xF0908080);
	try expect(try codepoint_to_utf8(0x12345)==0xF0928D85);
	try expect(try codepoint_to_utf8(0x10FFFF)==0xF48FBFBF);
	try expectError(unicodeIDerr.not_codepoint,codepoint_to_utf8(0x110000));
}

const teststr=
\\#    - Pattern_Syntax
\\#    - Pattern_White_Space
\\#  NOTE: See UAX #31 for more information
\\
\\0041..005A    ; ID_Start # L&  [26] LATIN CAPITAL LETTER A..LATIN CAPITAL LETTER Z
\\0061..007A    ; ID_Start # L&  [26] LATIN SMALL LETTER A..LATIN SMALL LETTER Z
\\00AA          ; ID_Start # Lo       FEMININE ORDINAL INDICATOR
\\00B5          ; ID_Start # L&       MICRO SIGN
\\00BA          ; ID_Start # Lo       MASCULINE ORDINAL INDICATOR
\\00C0..00D6    ; ID_Start # L&  [23] LATIN CAPITAL LETTER A WITH GRAVE..LATIN CAPITAL LETTER O WITH DIAERESIS
\\00D8..00F6    ; ID_Start # L&  [31] LATIN CAPITAL LETTER O WITH STROKE..LATIN SMALL LETTER O WITH DIAERESIS
\\00F8..01BA    ; ID_Start # L& [195] LATIN SMALL LETTER O WITH STROKE..LATIN SMALL LETTER EZH WITH TAIL
\\01BB          ; ID_Start # Lo       LATIN LETTER TWO WITH STROKE
\\01BC..01BF    ; ID_Start # L&   [4] LATIN CAPITAL LETTER TONE FIVE..LATIN LETTER WYNN
\\01C0..01C3    ; ID_Start # Lo   [4] LATIN LETTER DENTAL CLICK..LATIN LETTER RETROFLEX CLICK
\\01C4..0293    ; ID_Start # L& [208] LATIN CAPITAL LETTER DZ WITH CARON..LATIN SMALL LETTER EZH WITH CURL
\\0294          ; ID_Start # Lo       LATIN LETTER GLOTTAL STOP
\\
\\#    - Pattern_White_Space
\\#  NOTE: See UAX #31 for more information
\\
\\0030..0039    ; ID_Continue # Nd  [10] DIGIT ZERO..DIGIT NINE
\\0041..005A    ; ID_Continue # L&  [26] LATIN CAPITAL LETTER A..LATIN CAPITAL LETTER Z
\\005F          ; ID_Continue # Pc       LOW LINE
\\0061..007A    ; ID_Continue # L&  [26] LATIN SMALL LETTER A..LATIN SMALL LETTER Z
\\00AA          ; ID_Continue # Lo       FEMININE ORDINAL INDICATOR
\\00B5          ; ID_Continue # L&       MICRO SIGN
\\00B7          ; ID_Continue # Po       MIDDLE DOT
\\00BA          ; ID_Continue # Lo       MASCULINE ORDINAL INDICATOR
\\00C0..00D6    ; ID_Continue # L&  [23] LATIN CAPITAL LETTER A WITH GRAVE..LATIN CAPITAL LETTER O WITH DIAERESIS
\\00D8..00F6    ; ID_Continue # L&  [31] LATIN CAPITAL LETTER O WITH STROKE..LATIN SMALL LETTER O WITH DIAERESIS
\\00F8..01BA    ; ID_Continue # L& [195] LATIN SMALL LETTER O WITH STROKE..LATIN SMALL LETTER EZH WITH TAIL
\\01BB          ; ID_Continue # Lo       LATIN LETTER TWO WITH STROKE
\\01BC..01BF    ; ID_Continue # L&   [4] LATIN CAPITAL LETTER TONE FIVE..LATIN LETTER WYNN
\\01C0..01C3    ; ID_Continue # Lo   [4] LATIN LETTER DENTAL CLICK..LATIN LETTER RETROFLEX CLICK
\\01C4..0293    ; ID_Continue # L& [208] LATIN CAPITAL LETTER DZ WITH CARON..LATIN SMALL LETTER EZH WITH CURL
\\0295          ; ID_Continue # Lo       LATIN LETTER GLOTTAL STOP
\\
\\#        Merely ensures that if isIdentifer(string) then isIdentifier(NFKx(string))
\\#  NOTE: See UAX #31 for more information
\\
\\0041..005A    ; XID_Start # L&  [26] LATIN CAPITAL LETTER A..LATIN CAPITAL LETTER Z
\\0061..007A    ; XID_Start # L&  [26] LATIN SMALL LETTER A..LATIN SMALL LETTER Z
\\00AA          ; XID_Start # Lo       FEMININE ORDINAL INDICATOR
\\00B5          ; XID_Start # L&       MICRO SIGN
\\00BA          ; XID_Start # Lo       MASCULINE ORDINAL INDICATOR
\\00C0..00D6    ; XID_Start # L&  [23] LATIN CAPITAL LETTER A WITH GRAVE..LATIN CAPITAL LETTER O WITH DIAERESIS
\\00D8..00F6    ; XID_Start # L&  [31] LATIN CAPITAL LETTER O WITH STROKE..LATIN SMALL LETTER O WITH DIAERESIS
\\00F8..01BA    ; XID_Start # L& [195] LATIN SMALL LETTER O WITH STROKE..LATIN SMALL LETTER EZH WITH TAIL
\\01BB          ; XID_Start # Lo       LATIN LETTER TWO WITH STROKE
\\01BC..01BF    ; XID_Start # L&   [4] LATIN CAPITAL LETTER TONE FIVE..LATIN LETTER WYNN
\\01C0..01C3    ; XID_Start # Lo   [4] LATIN LETTER DENTAL CLICK..LATIN LETTER RETROFLEX CLICK
\\01C4..0293    ; XID_Start # L& [208] LATIN CAPITAL LETTER DZ WITH CARON..LATIN SMALL LETTER EZH WITH CURL
\\0296          ; XID_Start # Lo       LATIN LETTER GLOTTAL STOP
\\
\\
\\#  NOTE: See UAX #31 for more information
\\
\\0030..0039    ; XID_Continue # Nd  [10] DIGIT ZERO..DIGIT NINE
\\0041..005A    ; XID_Continue # L&  [26] LATIN CAPITAL LETTER A..LATIN CAPITAL LETTER Z
\\005F          ; XID_Continue # Pc       LOW LINE
\\0061..007A    ; XID_Continue # L&  [26] LATIN SMALL LETTER A..LATIN SMALL LETTER Z
\\00AA          ; XID_Continue # Lo       FEMININE ORDINAL INDICATOR
\\00B5          ; XID_Continue # L&       MICRO SIGN
\\00B7          ; XID_Continue # Po       MIDDLE DOT
\\00BA          ; XID_Continue # Lo       MASCULINE ORDINAL INDICATOR
\\00C0..00D6    ; XID_Continue # L&  [23] LATIN CAPITAL LETTER A WITH GRAVE..LATIN CAPITAL LETTER O WITH DIAERESIS
\\00D8..00F6    ; XID_Continue # L&  [31] LATIN CAPITAL LETTER O WITH STROKE..LATIN SMALL LETTER O WITH DIAERESIS
\\00F8..01BA    ; XID_Continue # L& [195] LATIN SMALL LETTER O WITH STROKE..LATIN SMALL LETTER EZH WITH TAIL
\\01BB          ; XID_Continue # Lo       LATIN LETTER TWO WITH STROKE
\\01BC..01BF    ; XID_Continue # L&   [4] LATIN CAPITAL LETTER TONE FIVE..LATIN LETTER WYNN
\\01C0..01C3    ; XID_Continue # Lo   [4] LATIN LETTER DENTAL CLICK..LATIN LETTER RETROFLEX CLICK
\\01C4..0293    ; XID_Continue # L& [208] LATIN CAPITAL LETTER DZ WITH CARON..LATIN SMALL LETTER EZH WITH CURL
\\0297          ; XID_Continue # Lo       LATIN LETTER GLOTTAL STOP
\\
;