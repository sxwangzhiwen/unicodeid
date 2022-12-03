// Get and generate data from
// https://www.unicode.org/Public/UCD/latest/ucd/DerivedCoreProperties.txt

// This is used for unicode identifier.
// The starting index position of UTF8 encoding in the UTF8 string is given,
// and it is judged as ID_Start and other property.

const std=@import("std");
const expect=std.testing.expect;
const uniIDdata=@import("unicodeiddata.zig");

// input: buf: utf8 string, index: start post,
// return null: buf[index..] not is not a legal utf8
// return true: is ID_Start
// return false: not is ID_Start
// index: when return is true or false, index is next position of utf8 encoding.
// index: when return is null, index not change.
pub fn isID_Start(buf:[]const u8,index:*usize) ?bool{
	const i=strictgetutf8(buf,index);
	if(i==null) return null;
	var l=uniIDdata.IDXID_Common.len;
	var slice:[]const uniIDdata.IDitem=uniIDdata.IDXID_Common[0..l];
	if(haveID(.{.s=i.?},slice)) return true;
	l=uniIDdata.ID_Start.len;
	slice=uniIDdata.ID_Start[0..l];
	if(haveID(.{.s=i.?},slice)) return true;
	return false;
}
test "isID_Start" {
	var i:usize=0;
	try expect(isID_Start("\x65\x64",&i).?);
	i=0;
	try expect(!isID_Start("\xC2\xB7",&i).?);
}

pub fn isID_Continue(buf:[]const u8,index:*usize) ?bool{
	const i=strictgetutf8(buf,index);
	if(i==null) return null;
	var l=uniIDdata.IDXID_Common.len;
	var slice:[]const uniIDdata.IDitem=uniIDdata.IDXID_Common[0..l];
	if(haveID(.{.s=i.?},slice)) return true;
	l=uniIDdata.ID_Continue.len;
	slice=uniIDdata.ID_Continue[0..l];
	if(haveID(.{.s=i.?},slice)) return true;
	return false;
}
test "isID_Continue" {
	var i:usize=0;
	try expect(isID_Continue("\x65\x64",&i).?);
	i=0;
	try expect(isID_Continue("\xC2\xB7",&i).?);
}

pub fn isXID_Start(buf:[]const u8,index:*usize) ?bool{
	const i=strictgetutf8(buf,index);
	if(i==null) return null;
	var l=uniIDdata.IDXID_Common.len;
	var slice:[]const uniIDdata.IDitem=uniIDdata.IDXID_Common[0..l];
	if(haveID(.{.s=i.?},slice)) return true;
	l=uniIDdata.XID_Start.len;
	slice=uniIDdata.XID_Start[0..l];
	if(haveID(.{.s=i.?},slice)) return true;
	return false;
}
test "isXID_Start" {
	var i:usize=0;
	try expect(!isXID_Start("\xCD\xBA",&i).?);
	i=0;
	try expect(isXID_Start("\xE0\xB8\xB2",&i).?);
}

pub fn isXID_Continue(buf:[]const u8,index:*usize) ?bool{
	const i=strictgetutf8(buf,index);
	if(i==null) return null;
	var l=uniIDdata.IDXID_Common.len;
	var slice:[]const uniIDdata.IDitem=uniIDdata.IDXID_Common[0..l];
	if(haveID(.{.s=i.?},slice)) return true;
	l=uniIDdata.XID_Continue.len;
	slice=uniIDdata.XID_Continue[0..l];
	if(haveID(.{.s=i.?},slice)) return true;
	return false;
}
test "isXID_Continue" {
	var i:usize=0;
	try expect(isXID_Continue("\xD2\x84..",&i).?);
}

fn getutf8(buf:[]const u8,index:*usize) ?u32{
	var p=index.*;
	var r:u32=buf[p];
	switch(@clz(~buf[p])) {
		0 => {
			index.* += 1;
			return r;
		},
		2 => {
			r=r*0x100 + buf[p+1];
			index.* += 2;
			return r;
		},
		3 => {
			r=r*0x10000 + @as(u32,buf[p+1])*0x100 + buf[p+2];
			index.* += 3;
			return r;
		},
		4 => {
			r=r*0x1000000 + @as(u32,buf[p+1])*0x10000 + @as(u32,buf[p+2])*0x100 + buf[p+3];
			index.* += 4;
			return r;
		},
		else => {
			return null;
		},
	}
}
test "getutf8" {
	var i:usize=0;
	try expect(getutf8("\x65\x70..",&i).?==0x65);
	try expect(i==1);
	i=2;
	try expect(getutf8("..\xCF\x88\x65",&i).?==0xCF88);
	try expect(i==4);
	i=0;
	try expect(getutf8("\xEF\x8F\x8F\x65",&i).?==0xEF8F8F);
	try expect(i==3);
	i=0;
	try expect(getutf8("\xF0\x8F\x8F\x8F\x65",&i).?==0xF08F8F8F);
	try expect(i==4);
	i=0;
	try expect(getutf8("\xFF",&i)==null);
}

fn strictgetutf8(buf:[]const u8,index:*usize) ?u32{
	var p=index.*;
	var r:u32=buf[p];
	switch(@clz(~buf[p])) {
		0 => {
			index.* += 1;
			return r;
		},
		2 => {
			if(@clz(~buf[p+1])!=1) return null;
			r=r*0x100 + buf[p+1];
			index.* += 2;
			return r;
		},
		3 => {
			if(@clz(~buf[p+1])!=1 or @clz(~buf[p+2])!=1) return null;
			r=r*0x10000 + @as(u32,buf[p+1])*0x100 + buf[p+2];
			index.* += 3;
			return r;
		},
		4 => {
			if(@clz(~buf[p+1])!=1 or @clz(~buf[p+2])!=1 or @clz(~buf[p+3])!=1) return null;
			r=r*0x1000000 + @as(u32,buf[p+1])*0x10000 + @as(u32,buf[p+2])*0x100 + buf[p+3];
			if(r>0xF48FBFBF) return null;  // max codepoint: 10FFFF  utf8: F48FBFBF
			index.* += 4;
			return r;
		},
		else => {
			return null;
		},
	}
}
test "strictgetutf8"{
	var i:usize=0;
	try expect(strictgetutf8("\xCF\x65",&i)==null);
	try expect(strictgetutf8("\xEF\x80\x65",&i)==null);
	try expect(strictgetutf8("\xF0\x80\x80\x65",&i)==null);
	try expect(strictgetutf8("\xF5\x80\x80\x65",&i)==null);
}

fn haveID(ids:uniIDdata.IDitem,idarr:[]const uniIDdata.IDitem) bool{
	return if(std.sort.binarySearch(uniIDdata.IDitem,ids,idarr,{},order_IDitem)!=null) true else false;
}
fn order_IDitem(context:void,lhs:uniIDdata.IDitem,rhs:uniIDdata.IDitem) std.math.Order{
	_=context;
	switch(lhs) {
		.r => |vlr| {
			switch(rhs) {
				.r => {
					unreachable;
				},
				.s => |vrs| {
					if(vlr[1]<vrs){
						return std.math.Order.lt;
					}
					if(vlr[0]>vrs){
						return std.math.Order.gt;
					}
					return std.math.Order.eq;
				},
			}
		},
		.s => |vls| {
			switch(rhs) {
				.r => |vrr| {
					if(vls<vrr[0]){
						return std.math.Order.lt;
					}
					if(vls>vrr[1]){
						return std.math.Order.gt;
					}
					return std.math.Order.eq;
				},
				.s => |vrs| {
					return std.math.order(vls,vrs);
				},
			}
		},
	}
}

test "haveID" {
	const l=uniIDdata.IDXID_Common.len;
	var i:[]const uniIDdata.IDitem=uniIDdata.IDXID_Common[0..l];
	try expect(haveID(.{.s=0xF0918CBD},i));
	try expect(!haveID(.{.s=0xF09EB9A5},i));
	try expect(haveID(.{.s=0xF09EB9B5},i));
}
