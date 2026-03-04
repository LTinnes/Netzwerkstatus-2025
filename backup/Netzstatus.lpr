program Netzstatus;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, u_mainwindow, u_netzwerkinfo, u_hostwindow
  { you can add units after this };

{$R *.res}

begin
  RequireDerivedFormResource:=True;
  Application.Scaled:=True;
  Application.Initialize;
  Application.CreateForm(THauptform, Hauptform);
  Application.CreateForm(TIPtoName, IPtoName);
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.

