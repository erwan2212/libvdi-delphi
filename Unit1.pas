unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ComCtrls,vdi;

type
  TForm1 = class(TForm)
    Button1: TButton;
    Memo1: TMemo;
    OpenDialog1: TOpenDialog;
    ProgressBar1: TProgressBar;
    Button2: TButton;
    Button3: TButton;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
  private
    { Private declarations }
    function VDI2RAW(source,target:string):boolean;
  public
    { Public declarations }
  end;



var
  Form1: TForm1;
  CancelFlag:boolean;

implementation

{$R *.dfm}

function round512(n:cardinal):cardinal;
begin
if n mod 512=0
  then result:= (n div 512) * 512
  else result:= (1 + (n div 512)) * 512
end;

{
/** Normal dynamically growing base image file. */
    VDI_IMAGE_TYPE_NORMAL = 1,
    /** Preallocated base image file of a fixed size. */
    VDI_IMAGE_TYPE_FIXED,
    /** Dynamically growing image file for undo/commit changes support. */
    VDI_IMAGE_TYPE_UNDO,
    /** Dynamically growing image file for differencing support. */
    VDI_IMAGE_TYPE_DIFF,

    /** First valid image type value. */
    VDI_IMAGE_TYPE_FIRST  = VDI_IMAGE_TYPE_NORMAL,
    /** Last valid image type value. */
    VDI_IMAGE_TYPE_LAST   = VDI_IMAGE_TYPE_DIFF
}

procedure TForm1.Button1Click(Sender: TObject);
var
Src,dst:thandle;
buffer:array[0..511] of byte;
byteswritten,readbytes:dword;
//blocks:array[0..4095] of dword;
blocks:array of dword;
i:word;
data,p:pointer;
filename,dd:string;
mapsize:cardinal;
begin
memo1.Clear ;
openDialog1.Filter :='VDI files|*.vdi';
if OpenDialog1.Execute =false then exit;
filename:=OpenDialog1.FileName ;
Src:=CreateFile(pchar(filename), GENERIC_READ, FILE_SHARE_READ, nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0); //FILE_FLAG_NO_BUFFERING
if src<>dword(-1) then
  begin
  fillchar(buffer,sizeof(buffer),0);
  ReadFile(Src, buffer, sizeof(buffer), readbytes, nil);

  memo1.Lines.Add ('szFileInfo:'+strpas(PVDIPREHEADER(@buffer[0])^.szFileInfo));
  memo1.Lines.Add ('u32Signature:'+inttohex(PVDIPREHEADER(@buffer[0])^.u32Signature,4));
  memo1.Lines.Add ('u32Version:'+inttostr(PVDIPREHEADER(@buffer[0])^.u32Version));

  memo1.Lines.Add ('cbHeader:'+inttostr(PVDIHEADER1(@buffer[sizeof(VDIPREHEADER)])^.cbHeader));
  memo1.Lines.Add ('u32Type:'+inttostr(PVDIHEADER1(@buffer[sizeof(VDIPREHEADER)])^.u32Type));
  memo1.Lines.Add ('fFlags:'+inttostr(PVDIHEADER1(@buffer[sizeof(VDIPREHEADER)])^.fFlags));
  memo1.Lines.Add ('szComment:'+strpas(PVDIHEADER1(@buffer[sizeof(VDIPREHEADER)])^.szComment));
  memo1.Lines.Add ('offBlocks:'+inttostr(PVDIHEADER1(@buffer[sizeof(VDIPREHEADER)])^.offBlocks));
  memo1.Lines.Add ('offData:'+inttostr(PVDIHEADER1(@buffer[sizeof(VDIPREHEADER)])^.offData));
  memo1.Lines.Add ('cCylinders:'+inttostr(PVDIHEADER1(@buffer[sizeof(VDIPREHEADER)])^.Geometry.cCylinders ));
  memo1.Lines.Add ('cHeads:'+inttostr(PVDIHEADER1(@buffer[sizeof(VDIPREHEADER)])^.Geometry.cHeads ));
  memo1.Lines.Add ('cSectors:'+inttostr(PVDIHEADER1(@buffer[sizeof(VDIPREHEADER)])^.Geometry.cSectors ));
  memo1.Lines.Add ('cbSector:'+inttostr(PVDIHEADER1(@buffer[sizeof(VDIPREHEADER)])^.Geometry.cbSector ));
  memo1.Lines.Add ('cbSector:'+inttostr(PVDIHEADER1(@buffer[sizeof(VDIPREHEADER)])^.u32Translation ));
  memo1.Lines.Add ('cbDisk:'+inttostr(PVDIHEADER1(@buffer[sizeof(VDIPREHEADER)])^.cbDisk ));
  memo1.Lines.Add ('cbBlock:'+inttostr(PVDIHEADER1(@buffer[sizeof(VDIPREHEADER)])^.cbBlock ));
  memo1.Lines.Add ('cbBlockExtra:'+inttostr(PVDIHEADER1(@buffer[sizeof(VDIPREHEADER)])^.cbBlockExtra ));
  memo1.Lines.Add ('cBlocks:'+inttostr(PVDIHEADER1(@buffer[sizeof(VDIPREHEADER)])^.cBlocks ));
  memo1.Lines.Add ('cBlocksAllocated:'+inttostr(PVDIHEADER1(@buffer[sizeof(VDIPREHEADER)])^.cBlocksAllocated ));

  //dynamic
  if PVDIHEADER1(@buffer[sizeof(VDIPREHEADER)])^.u32Type=1 then
    begin
    ProgressBar1.Max := PVDIHEADER1(@buffer[sizeof(VDIPREHEADER)])^.cBlocksAllocated;
    dd:=ChangeFileExt(filename,'.dd');
    dst:=CreateFile(pchar(dd), GENERIC_write, FILE_SHARE_write, nil, CREATE_ALWAYS , FILE_ATTRIBUTE_NORMAL, 0);

    SetFilePointer(src, PVDIHEADER1(@buffer[sizeof(VDIPREHEADER)])^.offBlocks, nil, FILE_BEGIN);

    //fillchar(blocks,sizeof(blocks),0);
    //readfile(src,blocks,sizeof(blocks),readbytes,nil);

    mapsize:=round512(PVDIHEADER1(@buffer[sizeof(VDIPREHEADER)])^.cBlocks);
    setlength(blocks,mapsize);
    getmem(p,mapsize*sizeof(dword));
    readfile(src,p^,mapsize*sizeof(dword),readbytes,nil);
    copymemory(@blocks[0],p,mapsize*sizeof(dword));
    freemem(p);


    getmem(data,PVDIHEADER1(@buffer[sizeof(VDIPREHEADER)])^.cbBlock);
    for i:=0 to PVDIHEADER1(@buffer[sizeof(VDIPREHEADER)])^.cBlocksAllocated-1 do
      begin
      if SetFilePointer(src, PVDIHEADER1(@buffer[sizeof(VDIPREHEADER)])^.offData+(blocks[i]*PVDIHEADER1(@buffer[sizeof(VDIPREHEADER)])^.cbBlock), nil, FILE_BEGIN)<>INVALID_SET_FILE_POINTER
        then readfile(src,data^,PVDIHEADER1(@buffer[sizeof(VDIPREHEADER)])^.cbBlock,readbytes,nil);
      if readbytes >0
        then writefile(dst,data^,readbytes,byteswritten,nil)
        else break;

      ProgressBar1.Position :=i;
      end;
    CloseHandle(dst);
    end;


  CloseHandle(Src);
  end;
end;

function TForm1.VDI2RAW(source,target:string):boolean;
var
handle,dst:thandle;
size,offset:int64;
blocksize,bytesread,byteswritten:cardinal;
buffer:pointer;
begin
CancelFlag :=false;
//
handle:=vdi_open(pchar(source),1);
if handle<>dword(-1) then
  begin
  size:=vdi_get_media_size;
  ProgressBar1.Max := size;
  blocksize:=1024*1024;
  getmem(buffer,blocksize );
  offset:=0;
  dst:=CreateFile(pchar(target), GENERIC_write, FILE_SHARE_write, nil, CREATE_ALWAYS , FILE_ATTRIBUTE_NORMAL, 0);
  while (CancelFlag =false) and (bytesread>0)  do
    begin
    ProgressBar1.Position :=offset;
    bytesread:=vdi_read_buffer_at_offset(handle,buffer,blocksize,offset);
    //if bytesread<>0 then
      //begin
      writefile(dst,buffer^,bytesread,byteswritten,nil);
      //memo1.lines.Add(inttostr(offset)+'/'+inttostr(size)+ ' read '+inttostr(bytesread)+' write '+inttostr(byteswritten));
      //end;
    offset:=offset+blocksize;
    end;
  vdi_close(handle);
  closehandle(dst);
  end;
end;

procedure TForm1.Button2Click(Sender: TObject);
var
filename,dd:string;
begin
memo1.Clear ;

openDialog1.Filter :='VDI files|*.vdi';
if OpenDialog1.Execute =false then exit;
filename:=OpenDialog1.FileName ;

dd:=ChangeFileExt(filename,'.dd');

VDI2RAW(filename,dd);

memo1.Lines.Add('done');
end;

procedure TForm1.Button3Click(Sender: TObject);
begin
CancelFlag :=true;
end;

end.
 