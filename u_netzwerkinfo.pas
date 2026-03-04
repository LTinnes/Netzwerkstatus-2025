unit u_netzwerkinfo;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, StrUtils, BaseUnix, Dialogs;

type
  TNetzInfoItem = record
      pid:       string;
      cmdline:   string;
      protokoll: string;
      status:    string;
      zielip:    string;
      zielport:  string;
      quellip:   string;
      quellport: string;
      inode:     string;
  end;

type
  TNetzInfoSnap = class
    public
      items:array of TNetzInfoItem;
      constructor create();
      procedure refresh;
      function get_count():integer;
    private
      count: integer;
      s: string;
      error: boolean;
      procedure GenerateItemIPv4(sprotocol:string);
      procedure GenerateItemIPv6(sprotocol:string);
      function Hex2IPv4(shex:string):string;
      function Hex2IPv6(shex:string):string;
      function pidtocmdline(in_spid: string):string;
      function inodetopid(inode: string):string;
  end;


implementation


constructor TNetzInfoSnap.create();
begin
   //lock := false;
   error := false;
   refresh();
   //lock := true;
   //curr_items := items;
   //lock := false;
end;

function TNetzInfoSnap.pidtocmdline(in_spid: string):string;
var
  sln : string;
  fd: TextFile;
  path: string;
begin
  result := '';
  try
    path := '/proc/'+in_spid+'/cmdline';
    AssignFile(fd,path);
    Reset(fd);
    while not EOF(fd) do
    begin
       readln(fd,sln);
       result := result + sln;
    end;
    CloseFile(fd);
  except
    result := 'Kein Zugriff';
  end;
end;

function TNetzInfoSnap.inodetopid(inode: string):string;
var
  Info,Info2: TSearchRec;
  spid,procpidfd,procpidfdsock: string;
  //pid: integer;
  statinfo: stat;
begin
  result := 'Kein Zugriff';
  If FindFirst ('/proc/*',faDirectory,Info)=0 then
    begin
    Repeat
      With Info do
        begin
        If (Attr and faDirectory) = faDirectory then
            spid := string(Name);
        end;

       try
         //pid := StrToInt(spid);
         procpidfd := '/proc/' + spid + '/fd/';

         If FindFirst (procpidfd+'*',faSymLink,Info2)=0 then
         begin
         Repeat
               if Info2.Attr <> faDirectory then
               begin
                    procpidfdsock := procpidfd + Info2.Name;
                      if fpstat (ShortString(procpidfdsock),statinfo)<>0 then
                      begin
                           writeln('Fstat failed. file: '+procpidfdsock+' Error: ',fpgeterrno);
                      end else
                      begin
                           //writeln(procpidfdsock+' ['+spid+'] '+IntToStr(statinfo.st_ino)+ ' = '+ inode + ' ???');

                           if trim(IntToStr(statinfo.st_ino)) = trim(inode) then
                           begin
                                result := spid;
                                exit;
                           end;
                      end;
               end;
         Until FindNext(info2)<>0;
         end;
        FindClose(Info2);

       except
         //writeln('No valid PID');
       end;

    Until FindNext(info)<>0;
    end;
  FindClose(Info);

end;



/// Die Funktion stimmt aktuell leider noch nicht
function TNetzInfoSnap.Hex2IPv6(shex:string):string;
var
  block: string;
  i : integer;
  //sl: TStringList;
begin
  //sl := TStringList.Create;
  result := '';
  if Length(shex) <> 32 then
  begin
       result := 'ERROR';
  end else
  begin
     for i := 0 to 7 do
     begin
         block := shex[i*4+1];
         block := block + shex[i*4+2];
         block := block + shex[i*4+3];
         block := block + shex[i*4+4];
         if (block[1] = '0') and (block[2] = '0') and (block[3] = '0') then
         begin
              result := result + block[4];
         end else
         begin
            if (block[1] = '0') and (block[2] = '0') then
            begin
                result := result + block[3] + block[4];
            end else
            begin
               if block[1] = '0' then
               begin
                  result := result + block[2] + block[3] + block[4];
               end else
               begin
                  result := result + block;
               end;
            end;
         end;
         if i < 7 then
         begin
              result := result + ':';
         end;
     end;
  end;
  //result := shex;
end;

function TNetzInfoSnap.Hex2IPv4(shex:string):string;
var
  tmp: string;
begin
   if Length(shex) <> 8 then
   begin
   result := 'ERROR';
   end
   else
   begin
     result := '';
     tmp := shex[7] + shex[8];
     result := result + IntToStr(Hex2Dec(tmp));
     result := result + '.';
     tmp := shex[5] + shex[6];
     result := result + IntToStr(Hex2Dec(tmp));
     result := result + '.';
     tmp := shex[3] + shex[4];
     result := result + IntToStr(Hex2Dec(tmp));
     result := result + '.';
     tmp := shex[1] + shex[2];
     result := result + IntToStr(Hex2Dec(tmp));
   end;
end;

procedure TNetzInfoSnap.GenerateItemIPv6(sprotocol:string);
var
  i: integer;
  sl,sl2: TStringList;
  item: TNetzInfoItem;
begin
   // init item
   item.zielport:='';
   item.status:='';
   item.zielip:='';
   item.protokoll:=sprotocol;
   item.quellip:='';
   item.quellport:='';
   item.cmdline:='';
   item.pid := '';

   sl := TStringList.Create;
   sl.Delimiter:=' ';
   sl.DelimitedText:=s;
   for i :=0 to sl.Count-1 do
   begin
     //ShowMessage(IntToStr(i)+': '+sl[i]);
     if i = 1 then
     begin
       // local address
       //ShowMessage(sl[i]);
       sl2 := TStringList.Create;
       sl2.Delimiter := ':';
       sl2.DelimitedText := sl[i];
       item.quellip := sl2[0];
       item.quellport := sl2[1];
       sl2.Free;
       //ShowMessage(item.quellip);
       //ShowMessage(item.quellport);
     end;

     if i = 2 then
     begin
       // remote address
       sl2 := TStringList.Create;
       sl2.Delimiter := ':';
       sl2.DelimitedText := sl[i];
       item.zielip := sl2[0];
       item.zielport := sl2[1];
       sl2.Free;
       //item.zielip:=sl[i];
     end;

     if i = 3 then
     begin
       // state
       case IntToStr(Hex2Dec(sl[i])) of
       '0': item.status:='';
       '1': item.status:='ESTABLISHED';
       '2': item.status:='SYN_SENT';
       '3': item.status:='SYN_RECV';
       '4': item.status:='FIN_WAIT1';
       '5': item.status:='FIN_WAIT2';
       '6': item.status:='TIME_WAIT';
       '7': item.status:='CLOSE';
       '8': item.status:='CLOSE_WAIT';
       '9': item.status:='LAST_ACK';
       '10': item.status:='LISTEN';
       '11': item.status:='CLOSING';
       end;
     end;

     if i = 9 then
     begin
       // inode
       item.cmdline := pidtocmdline(inodetopid(sl[i]));
       item.pid:= inodetopid(sl[i]);
       item.inode:=sl[i];
     end;
   end;

   sl.Free;

   item.quellport:= IntToStr(Hex2Dec(item.quellport));
   item.zielport:= IntToStr(Hex2Dec(item.zielport));
   item.zielip:= Hex2IPv6(item.zielip);
   item.quellip:= Hex2IPv6(item.quellip);

   SetLength(items,Length(items)+1);
    try
   items[High(items)] := item;
    except

    end;
end;

procedure TNetzInfoSnap.GenerateItemIPv4(sprotocol:string);
var
  i: integer;
  sl,sl2: TStringList;
  item: TNetzInfoItem;
begin
   // init item
   item.zielport:='';
   item.status:='';
   item.zielip:='';
   item.protokoll:=sprotocol;
   item.quellip:='';
   item.quellport:='';
   item.cmdline:='';
   item.pid := '';

   sl := TStringList.Create;
   sl.Delimiter:=' ';
   sl.DelimitedText:=s;
   for i :=0 to sl.Count-1 do
   begin
     //ShowMessage(IntToStr(i)+': '+sl[i]);
     if i = 1 then
     begin
       // local address
       sl2 := TStringList.Create;
       sl2.Delimiter := ':';
       sl2.DelimitedText := sl[i];
       item.quellip := sl2[0];
       item.quellport := sl2[1];
       sl2.Free;

     end;

     if i = 2 then
     begin
       // remote address
       sl2 := TStringList.Create;
       sl2.Delimiter := ':';
       sl2.DelimitedText := sl[i];
       item.zielip := sl2[0];
       item.zielport := sl2[1];
       sl2.Free;
       //item.zielip:=sl[i];

     end;

     if i = 3 then
     begin
       // state
       case IntToStr(Hex2Dec(sl[i])) of
       '0': item.status:='';
       '1': item.status:='ESTABLISHED';
       '2': item.status:='SYN_SENT';
       '3': item.status:='SYN_RECV';
       '4': item.status:='FIN_WAIT1';
       '5': item.status:='FIN_WAIT2';
       '6': item.status:='TIME_WAIT';
       '7': item.status:='CLOSE';
       '8': item.status:='CLOSE_WAIT';
       '9': item.status:='LAST_ACK';
       '10': item.status:='LISTEN';
       '11': item.status:='CLOSING';
       end;
     end;

     if i = 9 then
     begin
       // inode
       item.cmdline := pidtocmdline(inodetopid(sl[i]));
       item.pid:= inodetopid(sl[i]);
       item.inode:= sl[i];
     end;
   end;

   sl.Free;

   item.quellport:= IntToStr(Hex2Dec(item.quellport));
   item.zielport:= IntToStr(Hex2Dec(item.zielport));
   item.zielip:= Hex2IPv4(item.zielip);
   item.quellip:= Hex2IPv4(item.quellip);

   SetLength(items,Length(items)+1);

   items[High(items)] := item;

end;

procedure TNetzInfoSnap.refresh();
var
  i: integer;
  tcpip4sockets,tcpip6sockets: TextFile;
  udpip4sockets,udpip6sockets: TextFile;
begin
   SetLength(items,0);
   count := -1;
   i := -1;
   try
      AssignFile(tcpip4sockets,'/proc/net/tcp');
      reset(tcpip4sockets);
      while EOF(tcpip4sockets) = false do
      begin
        Inc(count);
        readln(tcpip4sockets,s);
        if count > 0 then
        GenerateItemIPv4('TCP IPv4');
      end;
      CloseFile(tcpip4sockets);

      count := -1;
      AssignFile(udpip4sockets,'/proc/net/udp');
      reset(udpip4sockets);
      while EOF(udpip4sockets) = false do
      begin
        Inc(count);
        readln(udpip4sockets,s);
        if i > 0 then
        GenerateItemIPv4('UDP IPv4');
      end;
      CloseFile(udpip4sockets);
      i:= -1;
      AssignFile(tcpip6sockets,'/proc/net/tcp6');
      reset(tcpip6sockets);
      while EOF(tcpip6sockets) = false do
      begin
        Inc(i);
        readln(tcpip6sockets,s);
        if i > 0 then
        begin
           Inc(count);
           GenerateItemIPv6('TCP IPv6');
        end;
      end;
      CloseFile(tcpip6sockets);

      i:= -1;
      AssignFile(udpip6sockets,'/proc/net/udp6');
      reset(udpip6sockets);
      while EOF(udpip6sockets) = false do
      begin
        Inc(i);
        readln(udpip6sockets,s);
        if i > 0 then
        begin
           Inc(count);
           GenerateItemIPv6('UDP IPv6');
        end;
      end;
      CloseFile(udpip6sockets);
   except
     error := true;
     exit;
   end;
end;


function TNetzInfoSnap.get_count():integer;
begin
   result := count;
end;

end.

