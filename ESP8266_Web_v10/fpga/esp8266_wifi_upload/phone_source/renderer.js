// Generated from the exact v10 LCD RTL by tools/transpile_renderer.py.
// Do not hand-edit glyphs, coordinates or colors here.
(function(root){'use strict';
function u(v,w){return w>32?BigInt.asUintN(w,BigInt(v)):w===32?Number(v)>>>0:Number(v)&(2**w-1)}
function bits(v,start,w){if(typeof v==='bigint')return w>32?BigInt.asUintN(w,v>>BigInt(start)):Number(BigInt.asUintN(w,v>>BigInt(start)));return u(Math.floor(Number(v)/2**Number(start)),w)}
function cat(p){let n=0;for(const [v,w]of p)n=n*2**w+Number(v);return n}
function character(line,n){let character=0;{
character=u(32,8);
switch(line){
case 0:switch(n){
case 0:character=u(83,8);
break;
case 1:character=u(84,8);
break;
case 2:character=u(65,8);
break;
case 3:character=u(82,8);
break;
case 4:character=u(84,8);
break;
case 6:character=u(77,8);
break;
case 7:character=u(69,8);
break;
case 8:character=u(78,8);
break;
case 9:character=u(85,8);
break;
}
break;
case 1:switch(n){
case 0:character=u(49,8);
break;
case 2:character=u(80,8);
break;
case 3:character=u(76,8);
break;
case 4:character=u(65,8);
break;
case 5:character=u(89,8);
break;
case 7:character=u(76,8);
break;
case 8:character=u(73,8);
break;
case 9:character=u(86,8);
break;
case 10:character=u(69,8);
break;
}
break;
case 2:switch(n){
case 0:character=u(50,8);
break;
case 2:character=u(83,8);
break;
case 3:character=u(68,8);
break;
case 5:character=u(77,8);
break;
case 6:character=u(85,8);
break;
case 7:character=u(83,8);
break;
case 8:character=u(73,8);
break;
case 9:character=u(67,8);
break;
}
break;
case 3:switch(n){
case 0:character=u(51,8);
break;
case 2:character=u(70,8);
break;
case 3:character=u(79,8);
break;
case 4:character=u(76,8);
break;
case 5:character=u(76,8);
break;
case 6:character=u(79,8);
break;
case 7:character=u(87,8);
break;
case 9:character=u(80,8);
break;
case 10:character=u(76,8);
break;
case 11:character=u(65,8);
break;
case 12:character=u(89,8);
break;
}
break;
case 4:switch(n){
case 0:character=u(67,8);
break;
case 1:character=u(79,8);
break;
case 2:character=u(77,8);
break;
case 3:character=u(73,8);
break;
case 4:character=u(78,8);
break;
case 5:character=u(71,8);
break;
case 7:character=u(83,8);
break;
case 8:character=u(79,8);
break;
case 9:character=u(79,8);
break;
case 10:character=u(78,8);
break;
}
break;
case 5:switch(n){
case 0:character=u(83,8);
break;
case 1:character=u(49,8);
break;
case 3:character=u(68,8);
break;
case 4:character=u(79,8);
break;
case 5:character=u(85,8);
break;
case 6:character=u(66,8);
break;
case 7:character=u(76,8);
break;
case 8:character=u(69,8);
break;
case 10:character=u(66,8);
break;
case 11:character=u(65,8);
break;
case 12:character=u(67,8);
break;
case 13:character=u(75,8);
break;
}
break;
case 6:switch(n){
case 0:character=u(83,8);
break;
case 1:character=u(68,8);
break;
case 3:character=u(83,8);
break;
case 4:character=u(79,8);
break;
case 5:character=u(78,8);
break;
case 6:character=u(71,8);
break;
case 7:character=u(83,8);
break;
}
break;
case 7:switch(n){
case 0:character=u(70,8);
break;
case 1:character=u(79,8);
break;
case 2:character=u(76,8);
break;
case 3:character=u(76,8);
break;
case 4:character=u(79,8);
break;
case 5:character=u(87,8);
break;
case 7:character=u(83,8);
break;
case 8:character=u(79,8);
break;
case 9:character=u(78,8);
break;
case 10:character=u(71,8);
break;
case 11:character=u(83,8);
break;
}
break;
case 8:switch(n){
case 0:character=u(82,8);
break;
case 1:character=u(69,8);
break;
case 2:character=u(65,8);
break;
case 3:character=u(68,8);
break;
case 4:character=u(73,8);
break;
case 5:character=u(78,8);
break;
case 6:character=u(71,8);
break;
case 8:character=u(83,8);
break;
case 9:character=u(68,8);
break;
}
break;
case 9:switch(n){
case 0:character=u(67,8);
break;
case 1:character=u(65,8);
break;
case 2:character=u(82,8);
break;
case 3:character=u(68,8);
break;
case 5:character=u(69,8);
break;
case 6:character=u(82,8);
break;
case 7:character=u(82,8);
break;
case 8:character=u(79,8);
break;
case 9:character=u(82,8);
break;
}
break;
case 10:switch(n){
case 0:character=u(78,8);
break;
case 1:character=u(79,8);
break;
case 3:character=u(87,8);
break;
case 4:character=u(65,8);
break;
case 5:character=u(86,8);
break;
case 7:character=u(70,8);
break;
case 8:character=u(73,8);
break;
case 9:character=u(76,8);
break;
case 10:character=u(69,8);
break;
}
break;
case 11:switch(n){
case 0:character=u(80,8);
break;
case 1:character=u(76,8);
break;
case 2:character=u(65,8);
break;
case 3:character=u(89,8);
break;
case 4:character=u(73,8);
break;
case 5:character=u(78,8);
break;
case 6:character=u(71,8);
break;
}
break;
case 12:switch(n){
case 0:character=u(68,8);
break;
case 1:character=u(79,8);
break;
case 2:character=u(78,8);
break;
case 3:character=u(69,8);
break;
}
break;
case 13:switch(n){
case 0:character=u(76,8);
break;
case 1:character=u(79,8);
break;
case 2:character=u(65,8);
break;
case 3:character=u(68,8);
break;
case 4:character=u(73,8);
break;
case 5:character=u(78,8);
break;
case 6:character=u(71,8);
break;
}
break;
case 14:switch(n){
case 0:character=u(80,8);
break;
case 1:character=u(82,8);
break;
case 2:character=u(69,8);
break;
case 3:character=u(83,8);
break;
case 4:character=u(83,8);
break;
case 6:character=u(75,8);
break;
case 7:character=u(69,8);
break;
case 8:character=u(89,8);
break;
}
break;
case 15:switch(n){
case 0:character=u(70,8);
break;
case 1:character=u(79,8);
break;
case 2:character=u(76,8);
break;
case 3:character=u(76,8);
break;
case 4:character=u(79,8);
break;
case 5:character=u(87,8);
break;
}
break;
case 16:switch(n){
case 0:character=u(78,8);
break;
case 1:character=u(79,8);
break;
case 3:character=u(83,8);
break;
case 4:character=u(67,8);
break;
case 5:character=u(79,8);
break;
case 6:character=u(82,8);
break;
case 7:character=u(69,8);
break;
}
break;
case 17:switch(n){
case 0:character=u(52,8);
break;
case 2:character=u(87,8);
break;
case 3:character=u(73,8);
break;
case 4:character=u(45,8);
break;
case 5:character=u(70,8);
break;
case 6:character=u(73,8);
break;
case 8:character=u(85,8);
break;
case 9:character=u(80,8);
break;
case 10:character=u(76,8);
break;
case 11:character=u(79,8);
break;
case 12:character=u(65,8);
break;
case 13:character=u(68,8);
break;
}
break;
case 18:switch(n){
case 0:character=u(67,8);
break;
case 1:character=u(79,8);
break;
case 2:character=u(78,8);
break;
case 3:character=u(78,8);
break;
case 4:character=u(69,8);
break;
case 5:character=u(67,8);
break;
case 6:character=u(84,8);
break;
case 8:character=u(70,8);
break;
case 9:character=u(80,8);
break;
case 10:character=u(71,8);
break;
case 11:character=u(65,8);
break;
case 12:character=u(45,8);
break;
case 13:character=u(77,8);
break;
case 14:character=u(85,8);
break;
case 15:character=u(83,8);
break;
case 16:character=u(73,8);
break;
case 17:character=u(67,8);
break;
}
break;
case 19:switch(n){
case 0:character=u(79,8);
break;
case 1:character=u(80,8);
break;
case 2:character=u(69,8);
break;
case 3:character=u(78,8);
break;
case 5:character=u(49,8);
break;
case 6:character=u(57,8);
break;
case 7:character=u(50,8);
break;
case 8:character=u(46,8);
break;
case 9:character=u(49,8);
break;
case 10:character=u(54,8);
break;
case 11:character=u(56,8);
break;
case 12:character=u(46,8);
break;
case 13:character=u(52,8);
break;
case 14:character=u(46,8);
break;
case 15:character=u(49,8);
break;
}
break;
case 20:switch(n){
case 0:character=u(80,8);
break;
case 1:character=u(82,8);
break;
case 2:character=u(69,8);
break;
case 3:character=u(83,8);
break;
case 4:character=u(83,8);
break;
case 6:character=u(83,8);
break;
case 7:character=u(49,8);
break;
case 9:character=u(84,8);
break;
case 10:character=u(79,8);
break;
case 12:character=u(83,8);
break;
case 13:character=u(84,8);
break;
case 14:character=u(65,8);
break;
case 15:character=u(82,8);
break;
case 16:character=u(84,8);
break;
}
break;
case 21:switch(n){
case 0:character=u(67,8);
break;
case 1:character=u(79,8);
break;
case 2:character=u(86,8);
break;
case 3:character=u(69,8);
break;
case 4:character=u(82,8);
break;
case 5:character=u(46,8);
break;
case 6:character=u(66,8);
break;
case 7:character=u(77,8);
break;
case 8:character=u(80,8);
break;
case 10:character=u(69,8);
break;
case 11:character=u(82,8);
break;
case 12:character=u(82,8);
break;
case 13:character=u(79,8);
break;
case 14:character=u(82,8);
break;
}
break;
case 22:switch(n){
case 0:character=u(82,8);
break;
case 1:character=u(69,8);
break;
case 2:character=u(65,8);
break;
case 3:character=u(68,8);
break;
case 4:character=u(73,8);
break;
case 5:character=u(78,8);
break;
case 6:character=u(71,8);
break;
case 8:character=u(67,8);
break;
case 9:character=u(79,8);
break;
case 10:character=u(86,8);
break;
case 11:character=u(69,8);
break;
case 12:character=u(82,8);
break;
case 13:character=u(46,8);
break;
case 14:character=u(66,8);
break;
case 15:character=u(77,8);
break;
case 16:character=u(80,8);
break;
}
break;
case 23:switch(n){
case 0:character=u(69,8);
break;
case 1:character=u(82,8);
break;
case 2:character=u(82,8);
break;
case 3:character=u(79,8);
break;
case 4:character=u(82,8);
break;
case 6:character=u(67,8);
break;
case 7:character=u(79,8);
break;
case 8:character=u(68,8);
break;
case 9:character=u(69,8);
break;
}
break;
}
}
return character;}
function glyph_row(ch,r){let glyph_row=0;{
glyph_row=u(0,5);
switch(ch){
case 65:switch(r){
case 0:glyph_row=u(14,5);
break;
case 1:case 2:glyph_row=u(17,5);
break;
case 3:glyph_row=u(31,5);
break;
case 4:case 5:case 6:glyph_row=u(17,5);
break;
}
break;
case 66:switch(r){
case 0:case 3:glyph_row=u(30,5);
break;
case 1:case 2:case 4:case 5:glyph_row=u(17,5);
break;
case 6:glyph_row=u(30,5);
break;
}
break;
case 67:switch(r){
case 0:case 6:glyph_row=u(15,5);
break;
case 1:case 2:case 3:case 4:case 5:glyph_row=u(16,5);
break;
}
break;
case 68:switch(r){
case 0:case 6:glyph_row=u(30,5);
break;
case 1:case 2:case 3:case 4:case 5:glyph_row=u(17,5);
break;
}
break;
case 69:switch(r){
case 0:case 3:case 6:glyph_row=u(31,5);
break;
case 1:case 2:case 4:case 5:glyph_row=u(16,5);
break;
}
break;
case 70:switch(r){
case 0:glyph_row=u(31,5);
break;
case 1:case 2:case 4:case 5:case 6:glyph_row=u(16,5);
break;
case 3:glyph_row=u(30,5);
break;
}
break;
case 71:switch(r){
case 0:case 6:glyph_row=u(15,5);
break;
case 1:case 2:glyph_row=u(16,5);
break;
case 3:glyph_row=u(23,5);
break;
case 4:case 5:glyph_row=u(17,5);
break;
}
break;
case 72:switch(r){
case 0:case 1:case 2:case 4:case 5:case 6:glyph_row=u(17,5);
break;
case 3:glyph_row=u(31,5);
break;
}
break;
case 73:switch(r){
case 0:case 6:glyph_row=u(31,5);
break;
case 1:case 2:case 3:case 4:case 5:glyph_row=u(4,5);
break;
}
break;
case 74:switch(r){
case 0:glyph_row=u(7,5);
break;
case 1:case 2:case 3:case 4:glyph_row=u(2,5);
break;
case 5:glyph_row=u(18,5);
break;
case 6:glyph_row=u(12,5);
break;
}
break;
case 75:switch(r){
case 0:case 6:glyph_row=u(17,5);
break;
case 1:case 5:glyph_row=u(18,5);
break;
case 2:case 4:glyph_row=u(20,5);
break;
case 3:glyph_row=u(24,5);
break;
}
break;
case 76:switch(r){
case 0:case 1:case 2:case 3:case 4:case 5:glyph_row=u(16,5);
break;
case 6:glyph_row=u(31,5);
break;
}
break;
case 77:switch(r){
case 0:case 5:case 6:glyph_row=u(17,5);
break;
case 1:glyph_row=u(27,5);
break;
case 2:case 3:case 4:glyph_row=u(21,5);
break;
}
break;
case 78:switch(r){
case 0:case 6:glyph_row=u(17,5);
break;
case 1:glyph_row=u(25,5);
break;
case 2:glyph_row=u(21,5);
break;
case 3:case 4:glyph_row=u(19,5);
break;
case 5:glyph_row=u(17,5);
break;
}
break;
case 79:switch(r){
case 0:case 6:glyph_row=u(14,5);
break;
case 1:case 2:case 3:case 4:case 5:glyph_row=u(17,5);
break;
}
break;
case 80:switch(r){
case 0:case 3:glyph_row=u(30,5);
break;
case 1:case 2:glyph_row=u(17,5);
break;
case 4:case 5:case 6:glyph_row=u(16,5);
break;
}
break;
case 81:switch(r){
case 0:glyph_row=u(14,5);
break;
case 1:case 2:case 3:glyph_row=u(17,5);
break;
case 4:glyph_row=u(21,5);
break;
case 5:glyph_row=u(18,5);
break;
case 6:glyph_row=u(13,5);
break;
}
break;
case 82:switch(r){
case 0:case 3:glyph_row=u(30,5);
break;
case 1:case 2:glyph_row=u(17,5);
break;
case 4:glyph_row=u(20,5);
break;
case 5:glyph_row=u(18,5);
break;
case 6:glyph_row=u(17,5);
break;
}
break;
case 83:switch(r){
case 0:glyph_row=u(15,5);
break;
case 1:case 2:glyph_row=u(16,5);
break;
case 3:glyph_row=u(14,5);
break;
case 4:case 5:glyph_row=u(1,5);
break;
case 6:glyph_row=u(30,5);
break;
}
break;
case 84:switch(r){
case 0:glyph_row=u(31,5);
break;
case 1:case 2:case 3:case 4:case 5:case 6:glyph_row=u(4,5);
break;
}
break;
case 85:switch(r){
case 0:case 1:case 2:case 3:case 4:case 5:glyph_row=u(17,5);
break;
case 6:glyph_row=u(14,5);
break;
}
break;
case 86:switch(r){
case 0:case 1:case 2:case 3:glyph_row=u(17,5);
break;
case 4:case 5:glyph_row=u(10,5);
break;
case 6:glyph_row=u(4,5);
break;
}
break;
case 87:switch(r){
case 0:case 1:case 2:case 6:glyph_row=u(17,5);
break;
case 3:case 4:case 5:glyph_row=u(21,5);
break;
}
break;
case 88:switch(r){
case 0:case 6:glyph_row=u(17,5);
break;
case 1:case 5:glyph_row=u(10,5);
break;
case 2:case 3:case 4:glyph_row=u(4,5);
break;
}
break;
case 89:switch(r){
case 0:case 1:glyph_row=u(17,5);
break;
case 2:glyph_row=u(10,5);
break;
case 3:case 4:case 5:case 6:glyph_row=u(4,5);
break;
}
break;
case 90:switch(r){
case 0:case 6:glyph_row=u(31,5);
break;
case 1:glyph_row=u(1,5);
break;
case 2:glyph_row=u(2,5);
break;
case 3:glyph_row=u(4,5);
break;
case 4:glyph_row=u(8,5);
break;
case 5:glyph_row=u(16,5);
break;
}
break;
case 48:switch(r){
case 0:case 6:glyph_row=u(14,5);
break;
case 1:case 2:case 3:case 4:case 5:glyph_row=u(17,5);
break;
}
break;
case 49:switch(r){
case 0:glyph_row=u(4,5);
break;
case 1:glyph_row=u(12,5);
break;
case 2:case 3:case 4:case 5:glyph_row=u(4,5);
break;
case 6:glyph_row=u(14,5);
break;
}
break;
case 50:switch(r){
case 0:glyph_row=u(14,5);
break;
case 1:glyph_row=u(17,5);
break;
case 2:glyph_row=u(1,5);
break;
case 3:glyph_row=u(2,5);
break;
case 4:glyph_row=u(4,5);
break;
case 5:glyph_row=u(8,5);
break;
case 6:glyph_row=u(31,5);
break;
}
break;
case 51:switch(r){
case 0:glyph_row=u(30,5);
break;
case 1:glyph_row=u(1,5);
break;
case 2:glyph_row=u(1,5);
break;
case 3:glyph_row=u(14,5);
break;
case 4:case 5:glyph_row=u(1,5);
break;
case 6:glyph_row=u(30,5);
break;
}
break;
case 52:switch(r){
case 0:glyph_row=u(2,5);
break;
case 1:glyph_row=u(6,5);
break;
case 2:glyph_row=u(10,5);
break;
case 3:glyph_row=u(18,5);
break;
case 4:glyph_row=u(31,5);
break;
case 5:case 6:glyph_row=u(2,5);
break;
}
break;
case 53:switch(r){
case 0:glyph_row=u(31,5);
break;
case 1:case 2:glyph_row=u(16,5);
break;
case 3:glyph_row=u(30,5);
break;
case 4:case 5:glyph_row=u(1,5);
break;
case 6:glyph_row=u(30,5);
break;
}
break;
case 54:switch(r){
case 0:glyph_row=u(15,5);
break;
case 1:case 2:glyph_row=u(16,5);
break;
case 3:glyph_row=u(30,5);
break;
case 4:case 5:glyph_row=u(17,5);
break;
case 6:glyph_row=u(14,5);
break;
}
break;
case 55:switch(r){
case 0:glyph_row=u(31,5);
break;
case 1:case 2:glyph_row=u(1,5);
break;
case 3:glyph_row=u(2,5);
break;
case 4:glyph_row=u(4,5);
break;
case 5:case 6:glyph_row=u(8,5);
break;
}
break;
case 56:switch(r){
case 0:case 3:case 6:glyph_row=u(14,5);
break;
case 1:case 2:case 4:case 5:glyph_row=u(17,5);
break;
}
break;
case 57:switch(r){
case 0:glyph_row=u(14,5);
break;
case 1:case 2:glyph_row=u(17,5);
break;
case 3:glyph_row=u(15,5);
break;
case 4:case 5:glyph_row=u(1,5);
break;
case 6:glyph_row=u(30,5);
break;
}
break;
case 95:switch(r){
case 6:glyph_row=u(31,5);
break;
}
break;
case 45:switch(r){
case 3:glyph_row=u(31,5);
break;
}
break;
case 46:switch(r){
case 6:glyph_row=u(4,5);
break;
}
break;
}
}
return glyph_row;}
function font_row(glyph,row){let font_row=0;{
font_row=u(0,5);
switch(glyph){
case 0:switch(row){
case 0:font_row=u(15,5);
break;
case 1:font_row=u(16,5);
break;
case 2:font_row=u(16,5);
break;
case 3:font_row=u(16,5);
break;
case 4:font_row=u(16,5);
break;
case 5:font_row=u(16,5);
break;
case 6:font_row=u(15,5);
break;
}
break;
case 1:switch(row){
case 0:font_row=u(30,5);
break;
case 1:font_row=u(17,5);
break;
case 2:font_row=u(17,5);
break;
case 3:font_row=u(17,5);
break;
case 4:font_row=u(17,5);
break;
case 5:font_row=u(17,5);
break;
case 6:font_row=u(30,5);
break;
}
break;
case 2:switch(row){
case 0:font_row=u(31,5);
break;
case 1:font_row=u(16,5);
break;
case 2:font_row=u(16,5);
break;
case 3:font_row=u(30,5);
break;
case 4:font_row=u(16,5);
break;
case 5:font_row=u(16,5);
break;
case 6:font_row=u(31,5);
break;
}
break;
case 3:switch(row){
case 0:font_row=u(31,5);
break;
case 1:font_row=u(16,5);
break;
case 2:font_row=u(16,5);
break;
case 3:font_row=u(30,5);
break;
case 4:font_row=u(16,5);
break;
case 5:font_row=u(16,5);
break;
case 6:font_row=u(16,5);
break;
}
break;
case 4:switch(row){
case 0:font_row=u(15,5);
break;
case 1:font_row=u(16,5);
break;
case 2:font_row=u(16,5);
break;
case 3:font_row=u(23,5);
break;
case 4:font_row=u(17,5);
break;
case 5:font_row=u(17,5);
break;
case 6:font_row=u(15,5);
break;
}
break;
case 5:switch(row){
case 0:font_row=u(14,5);
break;
case 1:font_row=u(17,5);
break;
case 2:font_row=u(17,5);
break;
case 3:font_row=u(31,5);
break;
case 4:font_row=u(17,5);
break;
case 5:font_row=u(17,5);
break;
case 6:font_row=u(17,5);
break;
}
break;
case 6:switch(row){
case 0:font_row=u(30,5);
break;
case 1:font_row=u(17,5);
break;
case 2:font_row=u(17,5);
break;
case 3:font_row=u(30,5);
break;
case 4:font_row=u(17,5);
break;
case 5:font_row=u(17,5);
break;
case 6:font_row=u(30,5);
break;
}
break;
case 7:switch(row){
case 0:font_row=u(2,5);
break;
case 1:font_row=u(6,5);
break;
case 2:font_row=u(10,5);
break;
case 3:font_row=u(18,5);
break;
case 4:font_row=u(31,5);
break;
case 5:font_row=u(2,5);
break;
case 6:font_row=u(2,5);
break;
}
break;
case 8:switch(row){
case 0:font_row=u(31,5);
break;
case 1:font_row=u(16,5);
break;
case 2:font_row=u(16,5);
break;
case 3:font_row=u(30,5);
break;
case 4:font_row=u(1,5);
break;
case 5:font_row=u(1,5);
break;
case 6:font_row=u(30,5);
break;
}
break;
case 9:switch(row){
case 0:case 1:case 2:case 4:case 5:case 6:font_row=u(17,5);
break;
case 3:font_row=u(31,5);
break;
}
break;
case 10:switch(row){
case 0:case 6:font_row=u(31,5);
break;
case 1:case 2:case 3:case 4:case 5:font_row=u(4,5);
break;
}
break;
case 11:switch(row){
case 0:case 1:case 2:case 3:case 4:case 5:font_row=u(16,5);
break;
case 6:font_row=u(31,5);
break;
}
break;
case 12:switch(row){
case 0:case 5:case 6:font_row=u(17,5);
break;
case 1:font_row=u(27,5);
break;
case 2:case 3:case 4:font_row=u(21,5);
break;
}
break;
case 13:switch(row){
case 0:case 6:font_row=u(14,5);
break;
case 1:case 2:case 3:case 4:case 5:font_row=u(17,5);
break;
}
break;
case 14:switch(row){
case 0:case 3:font_row=u(30,5);
break;
case 1:case 2:font_row=u(17,5);
break;
case 4:font_row=u(20,5);
break;
case 5:font_row=u(18,5);
break;
case 6:font_row=u(17,5);
break;
}
break;
case 15:switch(row){
case 0:font_row=u(15,5);
break;
case 1:case 2:font_row=u(16,5);
break;
case 3:font_row=u(14,5);
break;
case 4:case 5:font_row=u(1,5);
break;
case 6:font_row=u(30,5);
break;
}
break;
default:font_row=u(0,5);
break;
}
}
return font_row;}
function live_glyph(card,ch){let live_glyph=0;{
live_glyph=u(0,4);
switch(card){
case 0:switch(ch){
case 0:live_glyph=u(15,4);
break;
case 1:live_glyph=u(13,4);
break;
case 2:live_glyph=u(11,4);
break;
}
break;
case 1:switch(ch){
case 0:live_glyph=u(11,4);
break;
case 1:live_glyph=u(5,4);
break;
}
break;
case 2:switch(ch){
case 0:live_glyph=u(15,4);
break;
case 1:live_glyph=u(10,4);
break;
}
break;
case 3:switch(ch){
case 0:live_glyph=u(9,4);
break;
case 1:live_glyph=u(10,4);
break;
case 2:live_glyph=u(4,4);
break;
case 3:live_glyph=u(9,4);
break;
case 4:live_glyph=u(1,4);
break;
case 5:live_glyph=u(13,4);
break;
}
break;
case 4:switch(ch){
case 0:live_glyph=u(1,4);
break;
case 1:live_glyph=u(13,4);
break;
}
break;
case 5:switch(ch){
case 0:live_glyph=u(14,4);
break;
case 1:live_glyph=u(2,4);
break;
}
break;
case 6:switch(ch){
case 0:live_glyph=u(12,4);
break;
case 1:live_glyph=u(10,4);
break;
}
break;
case 7:switch(ch){
case 0:live_glyph=u(3,4);
break;
case 1:live_glyph=u(5,4);
break;
}
break;
}
}
return live_glyph;}
function menuPixel(x,y,s){
let mode=s.mode;
let selection=s.selection;
let song_selection=s.song;
let song_count=s.count;
let song_names=s.namesBits;
let catalog_ready=s.catalog;
let sd_busy=s.busy;
let sd_playing=s.playing;
let sd_error=s.error;
let score_ready=s.scoreReady;
let score_done=s.done;
let volume=s.volume;
let fsr_active=s.fsr;
let fsr_bend=s.bend;
let timbre_a=s.a;
let timbre_b=s.b;
let voice_mode=s.voice;
let effect_mode=s.fx;
let metronome=s.beat;
let beat_phase_ms=s.phase;
let timing_hint=s.hint;
let final_percent=s.percent;
let result_valid=s.result;
let latency_tenth_ms=s.latency;
let latency_valid=s.latencyValid;
let rgb=0,line=0,text_x=0,text_y=0,char_index=0,font_x=0,font_y=0,pixels=0,highlighted=0,text_valid=0,text_is_song=0,row_local=0,row_abs=0,row_name=0n,text_character=0,vol_x=0,vol_y=0,fsr_x=0,fsr_y=0,status_x=0,status_y=0,effect_x=0,effect_y=0,extra_x=0,extra_y=0,extra_char=0;
let volume_product=u((volume*93),16);
let volume_fill=u(bits(volume_product,8,8),8);
let fsr_product=u((fsr_bend*57),16);
let fsr_fill=u(bits(fsr_product,8,8),8);
let score_tens=u((final_percent/10),7);
let score_ones=u((final_percent%10),7);
let pipe_ms=u((latency_tenth_ms/10),8);
let pipe_dec=u((latency_tenth_ms%10),8);
{
rgb=u(2115,16);
line=u(0,5);
text_x=u(0,10);
text_y=u(0,9);
char_index=u(0,5);
font_x=u(0,3);
font_y=u(0,3);
pixels=u(0,5);
highlighted=u(0,1);
text_valid=u(0,1);
text_is_song=u(0,1);
row_local=u(0,2);
row_abs=u(0,4);
row_name=u(0,64);
text_character=u(32,8);
vol_x=u(0,10);
vol_y=u(0,9);
fsr_x=u(0,10);
fsr_y=u(0,9);
status_x=u(0,10);
status_y=u(0,9);
effect_x=u(0,10);
effect_y=u(0,9);
extra_x=u(0,10);
extra_y=u(0,9);
extra_char=u(32,8);
if((mode==0)){
if(((((y>=42)&&(y<90))&&(x>=26))&&(x<454))){
highlighted=u(((selection==0)),1);
rgb=u((highlighted?1715:6408),16);
if(((((x<29)||(x>=451))||(y<45))||(y>=87)))rgb=u((highlighted?32767:21140),16);
}
else if(((((y>=96)&&(y<144))&&(x>=26))&&(x<454))){
highlighted=u(((selection==1)),1);
rgb=u((highlighted?1715:6408),16);
if(((((x<29)||(x>=451))||(y<99))||(y>=141)))rgb=u((highlighted?32767:21140),16);
}
else if(((((y>=150)&&(y<198))&&(x>=26))&&(x<454))){
highlighted=u(((selection==2)),1);
rgb=u((highlighted?1715:6408),16);
if(((((x<29)||(x>=451))||(y<153))||(y>=195)))rgb=u((highlighted?32767:21140),16);
}
else if(((((y>=204)&&(y<252))&&(x>=26))&&(x<454))){
highlighted=u(((selection==3)),1);
rgb=u((highlighted?1715:6408),16);
if(((((x<29)||(x>=451))||(y<207))||(y>=249)))rgb=u((highlighted?32767:21140),16);
}
if(((((x>=44)&&(x<364))&&(y>=21))&&(y<35))){
text_valid=u(1,1);
line=u(0,5);
text_x=u((x-44),10);
text_y=u((y-21),9);
}
else if(((((x>=56)&&(x<376))&&(y>=58))&&(y<72))){
text_valid=u(1,1);
line=u(1,5);
text_x=u((x-56),10);
text_y=u((y-58),9);
}
else if(((((x>=56)&&(x<376))&&(y>=112))&&(y<126))){
text_valid=u(1,1);
line=u(2,5);
text_x=u((x-56),10);
text_y=u((y-112),9);
}
else if(((((x>=56)&&(x<376))&&(y>=166))&&(y<180))){
text_valid=u(1,1);
line=u(3,5);
text_x=u((x-56),10);
text_y=u((y-166),9);
}
else if(((((x>=56)&&(x<376))&&(y>=220))&&(y<234))){
text_valid=u(1,1);
line=u(17,5);
text_x=u((x-56),10);
text_y=u((y-220),9);
}
}
else if((mode==7)){
rgb=u(2115,16);
if(((((y>=30)&&(y<36))&&(x>=40))&&(x<440)))rgb=u(1715,16);
if(((((x>=96)&&(x<384))&&(y>=106))&&(y<120))){
text_valid=u(1,1);
text_x=u((x-96),10);
text_y=u((y-106),9);
line=u((((sd_error!=0))?21:22),5);
}
else if((((((sd_error!=0)&&(x>=96))&&(x<384))&&(y>=132))&&(y<146))){
text_valid=u(1,1);
text_x=u((x-96),10);
text_y=u((y-132),9);
line=u(23,5);
}
else if(((((x>=96)&&(x<384))&&(y>=176))&&(y<190))){
text_valid=u(1,1);
text_x=u((x-96),10);
text_y=u((y-176),9);
line=u(20,5);
}
}
else if(((mode==2)||(mode==3))){
if(((((x>=35)&&(x<445))&&(y>=12))&&(y<50)))rgb=u(6408,16);
if(((((x>=48)&&(x<368))&&(y>=23))&&(y<37))){
text_valid=u(1,1);
line=u((((mode==2))?6:7),5);
text_x=u((x-48),10);
text_y=u((y-23),9);
}
if((catalog_ready&&(song_count!=0))){
if(((y>=58)&&(y<100)))row_local=u(0,2);
else if(((y>=108)&&(y<150)))row_local=u(1,2);
else if(((y>=158)&&(y<200)))row_local=u(2,2);
else if(((y>=208)&&(y<250)))row_local=u(3,2);
row_abs=u((cat([[0,1],[bits(song_selection,2,1),1],[0,2]])+cat([[0,2],[row_local,2]])),4);
if(((((x>=28)&&(x<452))&&(row_abs<song_count))&&(((((((y>=58)&&(y<100)))||(((y>=108)&&(y<150))))||(((y>=158)&&(y<200))))||(((y>=208)&&(y<250))))))){
highlighted=u(((song_selection==bits(row_abs,0,3))),1);
rgb=u((highlighted?1715:6408),16);
if(((x<31)||(x>=449)))rgb=u((highlighted?32767:21140),16);
if(((x>=54)&&(x<374))){
text_valid=u(1,1);
text_is_song=u(1,1);
text_x=u((x-54),10);
switch(row_local){
case 0:text_y=u((y-71),9);
break;
case 1:text_y=u((y-121),9);
break;
case 2:text_y=u((y-171),9);
break;
case 3:text_y=u((y-221),9);
break;
}
if((text_y>=14))text_valid=u(0,1);
}
}
}
else if(((((x>=54)&&(x<374))&&(y>=122))&&(y<136))){
text_valid=u(1,1);
text_x=u((x-54),10);
text_y=u((y-122),9);
if((sd_error!=0))line=u(9,5);
else if((sd_busy||(!catalog_ready)))line=u(8,5);
else line=u((((mode==3))?16:10),5);
}
}
else if((mode==4)){
if(((((x>=34)&&(x<446))&&(y>=56))&&(y<150)))rgb=u(6408,16);
if(((((x>=60)&&(x<380))&&(y>=75))&&(y<89))){
text_valid=u(1,1);
line=u(2,5);
text_x=u((x-60),10);
text_y=u((y-75),9);
}
else if(((((x>=60)&&(x<380))&&(y>=118))&&(y<132))){
text_valid=u(1,1);
text_x=u((x-60),10);
text_y=u((y-118),9);
if((sd_error!=0))line=u(9,5);
else if(sd_playing)line=u(11,5);
else if(sd_busy)line=u(13,5);
else line=u(12,5);
}
else if(((((x>=70)&&(x<390))&&(y>=220))&&(y<234))){
text_valid=u(1,1);
line=u(5,5);
text_x=u((x-70),10);
text_y=u((y-220),9);
}
}
else if((mode==6)){
if(((((x>=30)&&(x<450))&&(y>=48))&&(y<242)))rgb=u(6408,16);
if(((((x>=50)&&(x<370))&&(y>=80))&&(y<94))){
text_valid=u(1,1);
line=u(17,5);
text_x=u((x-50),10);
text_y=u((y-80),9);
}
else if(((((x>=50)&&(x<370))&&(y>=135))&&(y<149))){
text_valid=u(1,1);
line=u(18,5);
text_x=u((x-50),10);
text_y=u((y-135),9);
}
else if(((((x>=50)&&(x<370))&&(y>=190))&&(y<204))){
text_valid=u(1,1);
line=u(19,5);
text_x=u((x-50),10);
text_y=u((y-190),9);
}
}
else if((mode==5)){
if(((y<21)||(y>=249)))rgb=u(6408,16);
if(((((x>=32)&&(x<352))&&(y>=2))&&(y<16))){
text_valid=u(1,1);
line=u(15,5);
text_x=u((x-32),10);
text_y=u((y-2),9);
}
else if(((((x>=32)&&(x<352))&&(y>=253))&&(y<267))){
text_valid=u(1,1);
text_x=u((x-32),10);
text_y=u((y-253),9);
if((sd_error!=0))line=u(9,5);
else if(score_done)line=u(12,5);
else if(score_ready)line=u(14,5);
else line=u(13,5);
}
}
char_index=u(bits(text_x,4,5),5);
font_x=u(bits(text_x,1,3),3);
font_y=u(bits(text_y,1,3),3);
if((text_is_song&&(row_abs<song_count))){
row_name=u(bits(song_names,cat([[bits(row_abs,0,3),3],[0,6]]),64),64);
if((char_index==0))text_character=u((49+bits(row_abs,0,3)),8);
else if(((char_index>=2)&&(char_index<10)))text_character=u(bits(row_name,(((char_index-2))*8),8),8);
}
else text_character=u(character(line,char_index),8);
if((((mode==7)&&(line==23))&&(char_index==11)))text_character=u((48+cat([[0,4],[sd_error,32]])),8);
pixels=u(glyph_row(text_character,font_y),5);
if(((text_valid&&(font_x<5))&&bits(pixels,(4-font_x),1)))rgb=u(65535,16);
if((((((mode==5)&&(y>=142))&&(y<147))&&(x>=80))&&(x<334))){
if((x>=330))rgb=u(65535,16);
else rgb=u(((((x-80)<cat([[0,2],[bits(beat_phase_ms,1,8),8]])))?2016:12678),16);
}
if((((((mode==5)&&(y>=126))&&(y<140))&&(x>=32))&&(x<208))){
extra_x=u((x-32),10);
extra_y=u((y-126),9);
char_index=u(bits(extra_x,4,4),5);
switch(timing_hint){
case 1:switch(char_index){
case 0:extra_char=u(69,8);
break;
case 1:extra_char=u(65,8);
break;
case 2:extra_char=u(82,8);
break;
case 3:extra_char=u(76,8);
break;
case 4:extra_char=u(89,8);
break;
}
break;
case 2:switch(char_index){
case 0:extra_char=u(79,8);
break;
case 1:extra_char=u(78,8);
break;
case 3:extra_char=u(84,8);
break;
case 4:extra_char=u(73,8);
break;
case 5:extra_char=u(77,8);
break;
case 6:extra_char=u(69,8);
break;
}
break;
case 3:switch(char_index){
case 0:extra_char=u(76,8);
break;
case 1:extra_char=u(65,8);
break;
case 2:extra_char=u(84,8);
break;
case 3:extra_char=u(69,8);
break;
}
break;
default:switch(char_index){
case 0:extra_char=u(66,8);
break;
case 1:extra_char=u(69,8);
break;
case 2:extra_char=u(65,8);
break;
case 3:extra_char=u(84,8);
break;
}
break;
}
font_x=u(bits(extra_x,1,3),3);
font_y=u(bits(extra_y,1,3),3);
pixels=u(glyph_row(extra_char,font_y),5);
if(((font_x<5)&&bits(pixels,(4-font_x),1)))rgb=u(((timing_hint==2)?2016:((((timing_hint==1)||(timing_hint==3)))?65056:65535)),16);
}
if(((((((mode==5)&&latency_valid)&&(y>=126))&&(y<140))&&(x>=266))&&(x<458))){
extra_x=u((x-266),10);
extra_y=u((y-126),9);
char_index=u(bits(extra_x,4,4),5);
extra_char=u(32,8);
switch(char_index){
case 0:extra_char=u(80,8);
break;
case 1:extra_char=u(73,8);
break;
case 2:extra_char=u(80,8);
break;
case 3:extra_char=u(69,8);
break;
case 5:extra_char=u((48+pipe_ms),8);
break;
case 6:extra_char=u(46,8);
break;
case 7:extra_char=u((48+pipe_dec),8);
break;
case 8:extra_char=u(77,8);
break;
case 9:extra_char=u(83,8);
break;
}
font_x=u(bits(extra_x,1,3),3);
font_y=u(bits(extra_y,1,3),3);
pixels=u(glyph_row(extra_char,font_y),5);
if(((font_x<5)&&bits(pixels,(4-font_x),1)))rgb=u(48631,16);
}
if(((((((mode==3)&&result_valid)&&(y>=38))&&(y<52))&&(x>=266))&&(x<458))){
extra_x=u((x-266),10);
extra_y=u((y-38),9);
char_index=u(bits(extra_x,4,4),5);
extra_char=u(32,8);
switch(char_index){
case 0:extra_char=u(83,8);
break;
case 1:extra_char=u(67,8);
break;
case 2:extra_char=u(79,8);
break;
case 3:extra_char=u(82,8);
break;
case 4:extra_char=u(69,8);
break;
case 6:extra_char=u(((final_percent==100)?49:48),8);
break;
case 7:extra_char=u((48+(((final_percent==100)?0:score_tens))),8);
break;
case 8:extra_char=u((48+(((final_percent==100)?0:score_ones))),8);
break;
}
font_x=u(bits(extra_x,1,3),3);
font_y=u(bits(extra_y,1,3),3);
pixels=u(glyph_row(extra_char,font_y),5);
if(((font_x<5)&&bits(pixels,(4-font_x),1)))rgb=u(2016,16);
}
if((((((mode!=7)&&(y>=5))&&(y<19))&&(x>=312))&&(x<360))){
vol_x=u((x-312),10);
vol_y=u((y-5),9);
font_x=u(bits(vol_x,1,3),3);
font_y=u(bits(vol_y,1,3),3);
switch(bits(vol_x,4,2)){
case 0:text_character=u(86,8);
break;
case 1:text_character=u(79,8);
break;
default:text_character=u(76,8);
break;
}
pixels=u(glyph_row(text_character,font_y),5);
if(((font_x<5)&&bits(pixels,(4-font_x),1)))rgb=u(65535,16);
}
if((((((mode!=7)&&(x>=370))&&(x<470))&&(y>=5))&&(y<22))){
rgb=u(65535,16);
if(((((x>=374)&&(x<466))&&(y>=9))&&(y<18)))rgb=u(((((x-374)<volume_fill))?2016:8452),16);
}
if(((((((((mode==1)||(mode==4))||(mode==5)))&&(x>=174))&&(x<294))&&(y>=5))&&(y<22))){
rgb=u(65535,16);
if(((((x>=177)&&(x<291))&&(y>=8))&&(y<19)))rgb=u(8452,16);
if(((((x>=232)&&(x<288))&&(y>=9))&&(y<18)))rgb=u(((((x-232)<fsr_fill))?2016:8452),16);
if(((((x>=180)&&(x<228))&&(y>=6))&&(y<20))){
fsr_x=u((x-180),10);
fsr_y=u((y-6),9);
char_index=u(bits(fsr_x,4,2),5);
font_x=u(bits(fsr_x,1,3),3);
font_y=u(bits(fsr_y,1,3),3);
switch(char_index){
case 0:text_character=u(70,8);
break;
case 1:text_character=u(83,8);
break;
default:text_character=u(82,8);
break;
}
pixels=u(glyph_row(text_character,font_y),5);
if(((font_x<5)&&bits(pixels,(4-font_x),1)))rgb=u((fsr_active?65535:48631),16);
}
}
if((((((((((mode==1)||(mode==4)))&&(x>=12))&&(x<140))&&(y>=5))&&(y<19)))||((((((mode==5)&&(x>=350))&&(x<478))&&(y>=253))&&(y<267))))){
if((mode==5)){
status_x=u((x-350),10);
status_y=u((y-253),9);
}
else {
status_x=u((x-12),10);
status_y=u((y-5),9);
}
char_index=u(bits(status_x,4,3),5);
font_x=u(bits(status_x,1,3),3);
font_y=u(bits(status_y,1,3),3);
switch(char_index){
case 0:text_character=u(65,8);
break;
case 1:switch(timbre_a){
case 0:text_character=u(84,8);
break;
case 1:text_character=u(83,8);
break;
default:text_character=u(80,8);
break;
}
break;
case 3:text_character=u(66,8);
break;
case 4:switch(timbre_b){
case 0:text_character=u(84,8);
break;
case 1:text_character=u(83,8);
break;
default:text_character=u(80,8);
break;
}
break;
case 6:text_character=u(77,8);
break;
case 7:text_character=u((48+cat([[0,6],[voice_mode,32]])),8);
break;
default:text_character=u(32,8);
break;
}
pixels=u(glyph_row(text_character,font_y),5);
if(((font_x<5)&&bits(pixels,(4-font_x),1)))rgb=u(65535,16);
}
if(((((((mode==1)||(mode==4))||(mode==5)))&&(y>=5))&&(y<19))){
if(((x>=296)&&(x<312))){
effect_x=u((x-296),10);
effect_y=u((y-5),9);
font_x=u(bits(effect_x,1,3),3);
font_y=u(bits(effect_y,1,3),3);
switch(effect_mode){
case 1:text_character=u(86,8);
break;
case 2:text_character=u(68,8);
break;
default:text_character=u(45,8);
break;
}
pixels=u(glyph_row(text_character,font_y),5);
if(((font_x<5)&&bits(pixels,(4-font_x),1)))rgb=u(65535,16);
}
if(((metronome&&(x>=150))&&(x<166))){
effect_x=u((x-150),10);
effect_y=u((y-5),9);
font_x=u(bits(effect_x,1,3),3);
font_y=u(bits(effect_y,1,3),3);
pixels=u(glyph_row(66,font_y),5);
if(((font_x<5)&&bits(pixels,(4-font_x),1)))rgb=u(2016,16);
}
}
}
return rgb;}
function pixel(ax,ay,s){let visible=1,menu_rgb=menuPixel(ax,ay,s);
let frame_keys=s.keys;
let frame_mode=s.mode;
let frame_score=s.mask;
let dx0=u(ax-16,10),dx1=u(ax-132,10),dx2=u(ax-248,10),dx3=u(ax-364,10),dy0=u(ay-24,9),dy1=u(ay-148,9);
let in_card=0,card_col=0,card_row=0,local_x=0,local_y=0,glyph_x=0,text_y=0,live_key_bit=0,live_char=0,char_x=0,live_active=0,guide_active=0,glyph_bits=0,rgb565=0,card_id=0;
{
card_col=u(0,2);
card_row=u(0,1);
in_card=u(0,1);
local_x=u(0,7);
local_y=u(0,7);
glyph_x=u(0,7);
text_y=u(0,7);
glyph_bits=u(0,5);
card_id=u(0,4);
live_key_bit=u(0,3);
live_char=u(0,3);
char_x=u(0,7);
live_active=u(0,1);
guide_active=u(0,1);
rgb565=u(2115,16);
if(((ax>=16)&&(ax<120))){
card_col=u(0,2);
local_x=u(bits(dx0,0,7),7);
in_card=u(1,1);
}
else if(((ax>=132)&&(ax<236))){
card_col=u(1,2);
local_x=u(bits(dx1,0,7),7);
in_card=u(1,1);
}
else if(((ax>=248)&&(ax<352))){
card_col=u(2,2);
local_x=u(bits(dx2,0,7),7);
in_card=u(1,1);
}
else if(((ax>=364)&&(ax<468))){
card_col=u(3,2);
local_x=u(bits(dx3,0,7),7);
in_card=u(1,1);
}
if(((ay>=24)&&(ay<124))){
card_row=u(0,1);
local_y=u(bits(dy0,0,7),7);
}
else if(((ay>=148)&&(ay<248))){
card_row=u(1,1);
local_y=u(bits(dy1,0,7),7);
}
else in_card=u(0,1);
card_id=u(cat([[0,1],[card_row,1],[card_col,2]]),4);
switch(card_id){
case 0:live_key_bit=u(4,3);
break;
case 1:live_key_bit=u(5,3);
break;
case 2:live_key_bit=u(6,3);
break;
case 3:live_key_bit=u(7,3);
break;
case 4:live_key_bit=u(0,3);
break;
case 5:live_key_bit=u(1,3);
break;
case 6:live_key_bit=u(2,3);
break;
case 7:live_key_bit=u(3,3);
break;
}
live_active=u(bits(frame_keys,live_key_bit,1),1);
guide_active=u(bits(frame_score,live_key_bit,1),1);
if(((visible&&in_card)&&(((frame_mode==1)||(frame_mode==5))))){
if((frame_mode==5)){
if((guide_active&&live_active))rgb565=u(992,16);
else if(guide_active)rgb565=u(65056,16);
else if(live_active)rgb565=u(43008,16);
else rgb565=u(6408,16);
}
else rgb565=u((live_active?402:6408),16);
if(((((local_x<3)||(local_x>=101))||(local_y<3))||(local_y>=97)))rgb565=u((((live_active||(((frame_mode==5)&&guide_active))))?28671:21140),16);
if((((((card_id==3)&&(local_y>=43))&&(local_y<57))&&(local_x>=16))&&(local_x<88))){
glyph_x=u((local_x-16),7);
if((glyph_x<12)){
live_char=u(0,3);
char_x=u(glyph_x,7);
}
else if((glyph_x<24)){
live_char=u(1,3);
char_x=u((glyph_x-12),7);
}
else if((glyph_x<36)){
live_char=u(2,3);
char_x=u((glyph_x-24),7);
}
else if((glyph_x<48)){
live_char=u(3,3);
char_x=u((glyph_x-36),7);
}
else if((glyph_x<60)){
live_char=u(4,3);
char_x=u((glyph_x-48),7);
}
else {
live_char=u(5,3);
char_x=u((glyph_x-60),7);
}
text_y=u((local_y-43),7);
glyph_bits=u(font_row(live_glyph(bits(card_id,0,3),live_char),bits(text_y,1,3)),5);
if(((bits(char_x,1,3)<5)&&bits(glyph_bits,(4-bits(char_x,1,3)),1)))rgb565=u((((live_active||(((frame_mode==5)&&guide_active))))?65535:48631),16);
}
else if((((((card_id!=3)&&(local_y>=36))&&(local_y<64))&&(local_x>=((((card_id==0))?16:28))))&&(local_x<((((card_id==0))?88:76))))){
glyph_x=u((local_x-((((card_id==0))?16:28))),7);
if((glyph_x<24)){
live_char=u(0,3);
char_x=u(glyph_x,7);
}
else if((glyph_x<48)){
live_char=u(1,3);
char_x=u((glyph_x-24),7);
}
else {
live_char=u(2,3);
char_x=u((glyph_x-48),7);
}
text_y=u((local_y-36),7);
glyph_bits=u(font_row(live_glyph(bits(card_id,0,3),live_char),bits(text_y,2,3)),5);
if(((bits(char_x,2,3)<5)&&bits(glyph_bits,(4-bits(char_x,2,3)),1)))rgb565=u((((live_active||(((frame_mode==5)&&guide_active))))?65535:48631),16);
}
}
if(((frame_mode!=1)&&(frame_mode!=5)))rgb565=u(menu_rgb,16);
if(((frame_mode==5)&&((((ay<22)||(((ay>=126)&&(ay<148))))||(ay>=250)))))rgb565=u(menu_rgb,16);
if(((((((frame_mode==1)||(frame_mode==5)))&&(((((ax>=174)&&(ax<312)))||(((ax>=308)&&(ax<471))))))&&(ay>=3))&&(ay<23)))rgb565=u(menu_rgb,16);
if((((frame_mode==1)&&(ax<174))&&(ay<23)))rgb565=u(menu_rgb,16);
if((!visible))rgb565=u(0,16);
}
return rgb565;}
function decode(p){let namesBits=0n;for(let i=87;i>=24;i--)namesBits=(namesBits<<8n)|BigInt(p[i]);return {mode:p[3],selection:p[4],song:p[5],count:p[6],catalog:p[7]&1,busy:(p[7]>>1)&1,playing:(p[7]>>2)&1,scoreReady:(p[7]>>3)&1,done:(p[7]>>4)&1,result:(p[7]>>5)&1,cover:(p[7]>>6)&1,locked:(p[7]>>7)&1,keys:p[8],mask:p[9],volume:p[10],bend:p[11],fsr:p[11]?1:0,a:p[12],b:p[13],voice:p[14],fx:p[15],beat:p[16],hint:p[17],percent:p[18],latency:p[19],latencyValid:p[20],phase:p[21]|p[22]<<8,error:p[23],namesBits}}
const api={pixel,decode};if(typeof module!=='undefined')module.exports=api;else root.LCD=api;
})(typeof globalThis!=='undefined'?globalThis:this);
