//virtualbox images read/write operations

unit vdi;

{$IFDEF FPC}
  {$MODE Delphi}
{$ENDIF}

interface

uses
  windows,
  sysutils;

const INVALID_SET_FILE_POINTER = $FFFFFFFF;

type
VDIDISKGEOMETRY=record
    //** Cylinders. */
        cCylinders:dword;
    //** Heads. */
        cHeads:dword;
    //** Sectors per track. */
        cSectors:dword;
    //** Sector size. (bytes per sector) */
        cbSector:dword;
end;

PVDIPREHEADER=^VDIPREHEADER;
VDIPREHEADER = record
szFileInfo : array[0..63] of ansiChar;
u32Signature : dword;
u32Version : dword;
end;

PVDIHEADER1=^VDIHEADER1;
VDIHEADER1 = record
cbHeader : cardinal;
u32Type : cardinal;
fFlags : cardinal;
szComment : array[0..255] of ansiChar;
offBlocks : cardinal;
offData : cardinal;
Geometry : VDIDISKGEOMETRY;
u32Translation : cardinal; 
cbDisk : int64;
cbBlock : cardinal;
cbBlockExtra : cardinal; 
cBlocks : cardinal;
cBlocksAllocated : cardinal;
uuidCreate : TGuid;
uuidModify : TGuid;
uuidLinkage : TGuid;
uuidParentModify : TGuid;
end;

function vdi_read_buffer_at_offset(handle:thandle;buffer:pointer;size:cardinal; offset:int64):integer;stdcall;
function vdi_write_buffer_at_offset(handle:thandle;buffer:pointer;size:cardinal; offset:int64):integer;stdcall;
function vdi_open(filename:pansichar;read_only:integer):thandle;stdcall;
function vdi_close(handle:thandle):boolean;stdcall;
function vdi_get_media_size():int64;stdcall;
function vdi_get_offset_datas():int64;stdcall;
function vdi_get_offset_blocks():int64;stdcall;
function vdi_get_blocks_allocated():int64;stdcall;

implementation

var
BlockSize,offblocks,offData,BlocksAllocated:cardinal;
IndexMap:array of dword;
media_size:int64;

function round512(n:cardinal):cardinal;
begin
if n mod 512=0
  then result:= (n div 512) * 512
  else result:= (1 + (n div 512)) * 512
end;

function vdi_get_media_size():int64;stdcall;
begin
result:=media_size;
end;

function vdi_get_offset_datas():int64;stdcall;
begin
result:=offData ;
end;

function vdi_get_offset_blocks():int64;stdcall;
begin
result:=offblocks  ;
end;

function vdi_get_blocks_allocated():int64;stdcall;
begin
result:=BlocksAllocated ;
end;


{
Hsize = 512 + 4N + (508 + 4N) mod 512  = offdata
Zblock = int( Z / BlockSize )
Zoffset = Z mod BlockSize
Fblock = IndexMap[Zblock]
Fposition = Hsize + ( Fblock * BlockSize ) + ZOffset
}
function vdi_read_buffer_at_offset(handle:thandle;buffer:pointer;size:cardinal; offset:int64):integer;stdcall;
var
readbytes:cardinal;
zblock,zoffset:integer;
fposition:int64;
fblock:dword;
begin
result:=0;
if offset>=media_size then exit;
zblock:=offset div BlockSize ;
zoffset:= offset mod BlockSize ;
fblock:=IndexMap[zblock];
if fblock=high(dword) then
  begin
  {$i-}writeln('vdi_read_buffer_at_offset  block not found:'+inttostr(zblock));{$i+}
  zeromemory(buffer,size);
  result:=size;
  exit;
  end;
fposition:=offData + (fblock * BlockSize ) + zoffset ;
{$i-}writeln('vdi_read_buffer_at_offset - size:'+inttostr(size)+' offset:'+inttostr(fposition));{$i+}
try
readbytes:=0;
//if SetFilePointer(handle, fposition, nil, FILE_BEGIN)<>INVALID_SET_FILE_POINTER
if SetFilePointer(handle, int64rec(fposition).lo, @int64rec(fposition).hi, FILE_BEGIN)<>INVALID_SET_FILE_POINTER
  then readfile(handle,buffer^,size,readbytes,nil);
result:=readbytes;
except
on e:exception do {$i-}writeln(e.message);{$i+}
end;
end;

function rewrite_indexmap(handle:thandle):boolean;
var readbytes,writtenbytes:cardinal;
buffer:array[0..511] of byte;
p:pointer;
begin
//
SetFilePointer(handle, 0, nil, FILE_BEGIN);
ReadFile(handle, buffer, sizeof(buffer), readbytes, nil);
PVDIHEADER1(@buffer[sizeof(VDIPREHEADER)])^.cBlocksAllocated:=BlocksAllocated ;
writtenbytes:=0;
if SetFilePointer(handle, 0, nil, FILE_BEGIN)<>INVALID_SET_FILE_POINTER then writefile(handle,buffer,sizeof(buffer),writtenbytes,nil);
//
getmem(p,length(indexmap)*sizeof(dword));
copymemory(p,@indexmap[0],length(indexmap)*sizeof(dword));
writtenbytes:=0;
if SetFilePointer(handle, offblocks, nil, FILE_BEGIN)<>INVALID_SET_FILE_POINTER then writefile(handle,p^,length(indexmap)*sizeof(dword),writtenbytes,nil);
freemem(p);
end;

function vdi_write_buffer_at_offset(handle:thandle;buffer:pointer;size:cardinal; offset:int64):integer;stdcall;
var writtenbytes:cardinal;
zblock,zoffset:integer;
fposition:int64;
fblock:dword;
begin
zblock:=offset div BlockSize ;
zoffset:= offset mod BlockSize ;
fblock:=IndexMap[zblock];
if fblock=high(dword) then
  begin
  //{$i-}writeln('vdi_write_buffer_at_offset - offset:'+inttostr(offset)+ ' block not found:'+inttostr(zblock));{$i+}
  {$i-}writeln('vdi_write_buffer_at_offset - allocating new block:'+inttostr(zblock));{$i+}
  IndexMap[BlocksAllocated]:=1+IndexMap[BlocksAllocated-1];
  BlocksAllocated:=BlocksAllocated+1;
  rewrite_indexmap(handle);
  fblock:=IndexMap[zblock];
  //result:=0;
  //exit;
  end;
fposition:=offData + (fblock * BlockSize ) + zoffset ;
{$i-}writeln('vdi_write_buffer_at_offset - size:'+inttostr(size)+' offset:'+inttostr(fposition));{$i+}
try
writtenbytes:=0;
if SetFilePointer(handle, fposition, nil, FILE_BEGIN)<>INVALID_SET_FILE_POINTER then writefile(handle,buffer^,size,writtenbytes,nil);
result:=writtenbytes;
except
on e:exception do {$i-}writeln(e.message);{$i+}
end;
if writtenbytes =0 then {$i-}writeln('vdi_write_buffer_at_offset - offset:'+inttostr(fposition)+' error:'+inttostr(getlasterror));{$i+}
end;

function vdi_close(handle:thandle):boolean;stdcall;
begin
result:=Closehandle(handle); { *Converti depuis CloseHandle* }
end;

function vdi_open(filename:pansichar;read_only:integer):thandle;stdcall;
var
Src:thandle;
buffer:array[0..511] of byte;
mapsize,readbytes:cardinal;
p:pointer;
begin
result:=dword(-1);

  if read_only=1
    then Src:=CreateFileA(filename, GENERIC_READ, 0, nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0)
    else Src:=CreateFileA(filename, GENERIC_READ or GENERIC_WRITE, 0, nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);

  if src<>dword(-1) then
  begin
  fillchar(buffer,sizeof(buffer),0);
  ReadFile(Src, buffer, sizeof(buffer), readbytes, nil);

  {$i-}writeln ('szFileInfo:'+strpas(PVDIPREHEADER(@buffer[0])^.szFileInfo)); {$i+}
  {$i-}writeln ('u32Signature:'+inttohex(PVDIPREHEADER(@buffer[0])^.u32Signature,4));{$i+}
  {$i-}writeln ('u32Version:'+inttostr(PVDIPREHEADER(@buffer[0])^.u32Version));{$i+}

  {$i-}writeln ('cbHeader:'+inttostr(PVDIHEADER1(@buffer[sizeof(VDIPREHEADER)])^.cbHeader));{$i+}
  {$i-}writeln ('u32Type:'+inttostr(PVDIHEADER1(@buffer[sizeof(VDIPREHEADER)])^.u32Type));{$i+}
  {$i-}writeln ('fFlags:'+inttostr(PVDIHEADER1(@buffer[sizeof(VDIPREHEADER)])^.fFlags));{$i+}
  {$i-}writeln ('szComment:'+strpas(PVDIHEADER1(@buffer[sizeof(VDIPREHEADER)])^.szComment));{$i+}
  {$i-}writeln ('offBlocks:'+inttostr(PVDIHEADER1(@buffer[sizeof(VDIPREHEADER)])^.offBlocks));{$i+}
  {$i-}writeln ('offData:'+inttostr(PVDIHEADER1(@buffer[sizeof(VDIPREHEADER)])^.offData));{$i+}
  {$i-}writeln ('cCylinders:'+inttostr(PVDIHEADER1(@buffer[sizeof(VDIPREHEADER)])^.Geometry.cCylinders ));{$i+}
  {$i-}writeln ('cHeads:'+inttostr(PVDIHEADER1(@buffer[sizeof(VDIPREHEADER)])^.Geometry.cHeads ));{$i+}
  {$i-}writeln ('cSectors:'+inttostr(PVDIHEADER1(@buffer[sizeof(VDIPREHEADER)])^.Geometry.cSectors ));{$i+}
  {$i-}writeln ('cbSector:'+inttostr(PVDIHEADER1(@buffer[sizeof(VDIPREHEADER)])^.Geometry.cbSector ));{$i+}
  {$i-}writeln ('cbSector:'+inttostr(PVDIHEADER1(@buffer[sizeof(VDIPREHEADER)])^.u32Translation ));{$i+}
  {$i-}writeln ('cbDisk:'+inttostr(PVDIHEADER1(@buffer[sizeof(VDIPREHEADER)])^.cbDisk )); {$i+}
  {$i-}writeln ('cbBlock:'+inttostr(PVDIHEADER1(@buffer[sizeof(VDIPREHEADER)])^.cbBlock ));{$i+}
  {$i-}writeln ('cbBlockExtra:'+inttostr(PVDIHEADER1(@buffer[sizeof(VDIPREHEADER)])^.cbBlockExtra ));{$i+}
  {$i-}writeln ('cBlocks:'+inttostr(PVDIHEADER1(@buffer[sizeof(VDIPREHEADER)])^.cBlocks ));{$i+}
  {$i-}writeln ('cBlocksAllocated:'+inttostr(PVDIHEADER1(@buffer[sizeof(VDIPREHEADER)])^.cBlocksAllocated ));{$i+}

  //needed when reading
  media_size:=PVDIHEADER1(@buffer[sizeof(VDIPREHEADER)])^.cbDisk ;
  offblocks :=PVDIHEADER1(@buffer[sizeof(VDIPREHEADER)])^.offBlocks;
  offData := PVDIHEADER1(@buffer[sizeof(VDIPREHEADER)])^.offData;
  blocksize:=PVDIHEADER1(@buffer[sizeof(VDIPREHEADER)])^.cbBlock;
  BlocksAllocated:=PVDIHEADER1(@buffer[sizeof(VDIPREHEADER)])^.cBlocksAllocated;
  //

  //get indexmap
  SetFilePointer(src, offblocks, nil, FILE_BEGIN);
  mapsize:=round512(PVDIHEADER1(@buffer[sizeof(VDIPREHEADER)])^.cBlocks);
  setlength(IndexMap,mapsize);
  getmem(p,mapsize*4);
  readfile(src,p^,mapsize*4,readbytes,nil);
  copymemory(@IndexMap[0],p,mapsize*4);
  freemem(p);
  //
  result:=src;
  end;
end;

end.
